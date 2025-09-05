# This class integrates real-time license scanning, generation of SPDX standard
# output and verifiying license info during the building process.
# It is a combination of efforts from the OE-Core, SPDX and fossology projects.
#
# For more information on fossology REST API:
#   https://www.fossology.org/get-started/basic-rest-api-calls/
#
# For more information on SPDX:
#   http://www.spdx.org
#
# Note:
# 1) Make sure fossology (after 3.5.0)(https://hub.docker.com/r/fossology/fossology/) has beed started on your host
# 2) spdx files will be output to the path which is defined as[SPDX_DEPLOY_DIR].
#    By default, SPDX_DEPLOY_DIR is tmp/deploy/
# 3) Added TOKEN has been set in conf/local.conf
#
COPYLEFT_RECIPE_TYPES ?= 'target nativesdk'
inherit copyleft_filter

inherit spdx-api

do_foss_upload[dirs] = "${SPDX_TOPDIR}"
do_foss_upload[network] = "1"
do_schedule_jobs[dirs] = "${SPDX_TOPDIR}"
do_schedule_jobs[network] = "1"
do_get_report[dirs] = "${SPDX_OUTDIR}"
do_get_report[network] = "1"

CREATOR_TOOL = "fossology-python.bbclass in meta-spdxscanner"
FOSSOLOGY_SERVER ?= "http://127.0.0.1/repo"
WAIT_TIME ?= "20"
FOSSOLOGY_USER = "fossy"
FOSSOLOGY_PASSWORD = "fossy"
TOKEN_NAME = "fossy_token"

python () {
    from multiprocessing import Lock

    global create_folder_lock 

    create_folder_lock = Lock()

    pn = d.getVar('PN')
    #If not for target, won't creat spdx.
    if bb.data.inherits_class('nopackages', d) and not pn.startswith('gcc-source'):
        return

    assume_provided = (d.getVar("ASSUME_PROVIDED") or "").split()
    if pn in assume_provided:
        for p in d.getVar("PROVIDES").split():
            if p != pn:
                pn = p
                break

    # glibc-locale: do_fetch, do_unpack and do_patch tasks have been deleted,
    # so avoid archiving source here.
    if pn.startswith('glibc-locale'):
        return
    if (d.getVar('PN') == "libtool-cross"):
        return
    if (d.getVar('PN') == "libgcc-initial"):
        return
    if (d.getVar('PN') == "shadow-sysroot"):
        return

    # We just archive gcc-source for all the gcc related recipes
    if d.getVar('BPN') in ['gcc', 'libgcc'] \
            and not pn.startswith('gcc-source'):
        bb.debug(1, 'archiver: %s is excluded, covered by gcc-source' % pn)
        return

    def hasTask(task):
        return bool(d.getVarFlag(task, "task", False)) and not bool(d.getVarFlag(task, "noexec", False))

    manifest_dir = (d.getVar('SPDX_DEPLOY_DIR') or "")
    if not os.path.exists( manifest_dir ):
        bb.utils.mkdirhier( manifest_dir )

    info = {}
    info['pn'] = (d.getVar( 'PN') or "")
    info['pv'] = (d.getVar( 'PKGV') or "").replace('-', '+')
    info['pr'] = (d.getVar( 'PR') or "")
    
    if (d.getVar('BPN') == "perf"):
        info['pv'] = d.getVar("KERNEL_VERSION").split("-")[0]

    if 'AUTOINC' in info['pv']:
        info['pv'] = info['pv'].replace("AUTOINC", "0")

    if d.getVar('SAVE_SPDX_ACHIVE'): 
        if d.getVar('PACKAGES') or pn.startswith('gcc-source'):
           # Some recipes do not have any packaging tasks
           if hasTask("do_package_write_rpm") or hasTask("do_package_write_ipk") or hasTask("do_package_write_deb") or pn.startswith('gcc-source'):
               d.appendVarFlag('do_spdx', 'depends', ' %s:do_spdx_creat_tarball' % pn)

    spdx_outdir = d.getVar('SPDX_OUTDIR')
    spdx_name = get_spdx_name(d)

    info['outfile'] = os.path.join(manifest_dir, spdx_name)
    sstatefile = os.path.join(spdx_outdir, spdx_name)
    if os.path.exists(info['outfile']):
        bb.note(info['pn'] + " spdx file has been exist, do nothing")
        return
    if os.path.exists( sstatefile ):
        bb.note(info['pn'] + " spdx file has been exist, do nothing")
        create_manifest(info,sstatefile)
        return
    
    if d.getVar('PACKAGES') or pn.startswith('gcc-source'):
       # Some recipes do not have any packaging tasks
       if hasTask("do_package_write_rpm") or hasTask("do_package_write_ipk") or hasTask("do_package_write_deb") or pn.startswith('gcc-source'):
           d.appendVarFlag('do_foss_upload', 'depends', ' %s:do_spdx_creat_tarball' % pn)
           d.appendVarFlag('do_schedule_jobs', 'depends', ' %s:do_foss_upload' % pn)
           d.appendVarFlag('do_get_report', 'depends', ' %s:do_schedule_jobs' % pn)
           d.appendVarFlag('do_spdx', 'depends', ' %s:do_get_report' % pn)
           bb.build.addtask('do_foss_upload', 'do_configure', 'do_patch', d)
           bb.build.addtask('do_schedule_jobs', 'do_configure', 'do_foss_upload', d)
           bb.build.addtask('do_get_report', 'do_configure', 'do_schedule_jobs', d)
           bb.build.addtask('do_spdx', 'do_configure', 'do_get_report', d)
}

python do_foss_upload(){
    import logging, shutil,time
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    logging.basicConfig(level=logging.INFO)


    import os
    import sys
    import pathlib
    import secrets
    from getpass import getpass
    import requests
    from fossology import Fossology, fossology_token
    from fossology.obj import Group
    from fossology.enums import AccessLevel, TokenScope
    from fossology.exceptions  import FossologyApiError
    os.environ["FOSSOLOGY_USER"] = "fossy"
    os.environ["FOSSOLOGY_USER_PASS"] = "fossy"


    from tenacity import retry, TryAgain, stop_after_attempt

    fossology_server = d.getVar('FOSSOLOGY_SERVER')
    fossology_user = d.getVar('FOSSOLOGY_USER')
    if not d.getVar('TOKEN', False):
        path_to_token_file = pathlib.Path.cwd() / '.token'
        if not path_to_token_file.exists():
          if os.environ["FOSSOLOGY_USER"] and os.environ["FOSSOLOGY_USER_PASS"]:
              username =  os.environ["FOSSOLOGY_USER"]
              pw =  os.environ["FOSSOLOGY_USER_PASS"]
          else:
              bb.warn("Enter your Fossology credentials, e.g. in the test environment 'username: fossy' and 'password: fossy'")
              username = input("username: ")
              pw = getpass()
          token = fossology_token(
               fossology_server,
               fossology_user,
               pw,
               secrets.token_urlsafe(8), # TOKEN_NAME seen in the database
               TokenScope.WRITE,
           )
          with open(path_to_token_file, "w") as fp:
               token_len = fp.write(token)
        else:
          with open(".token", "r") as fp:
              token = fp.read()
    else:
        token=d.getVar('TOKEN')  
    
    foss = Fossology(fossology_server, token)
    
    filepath = d.getVar('SPDX_OUTDIR')
    
    if d.getVar('FOLDER_NAME', False):
        folder_name = d.getVar('FOLDER_NAME')
        folder = create_folder(d, foss, token, folder_name)
        time.sleep(int(d.getVar('WAIT_TIME')))
        bb.note("folder = " + folder.name)
    else:
        folder = foss.rootFolder
    
    bb.note("Begin to upload.")
    upload = get_upload(d, folder, foss)
    if upload == None:
        tar_file = get_tarball_name(d, d.getVar('WORKDIR'), 'patched', filepath)
        upload = upload_oss(d, folder, foss, tar_file)
        time.sleep(int(d.getVar('WAIT_TIME')))
    else:
        pn = (d.getVar( 'PN') or "")
        bb.warn(pn + " has already been uploaded, don't upload again.")
}
def get_upload(d, folder, foss):
    from fossology.exceptions import FossologyApiError

    filename = get_upload_file_name(d)
    try:
        upload_list, _ = foss.list_uploads(folder = folder, all_pages=True)
    except FossologyApiError as error:
        time.sleep(10)
        try:
            upload_list, _ = foss.list_uploads(folder = folder, all_pages=True)
        except FossologyApiError as error:
            bb.error(error.message)

    upload = None
    bb.note("Check tarball: %s ,has been uploaded?" % filename)
    for upload in upload_list:
        if upload.uploadname == filename and upload.foldername == folder.name:
            bb.note("Found " + upload.uploadname  + " in " + folder.name)
            bb.note("upload.hash.size  = %s" % upload.hash.size)
            return upload
    return None

def upload_oss(d, folder, foss, filepath):
    import os

    from fossology.exceptions import AuthorizationError, FossologyApiError
    from tenacity import TryAgain
    from fossology.enums import AccessLevel

    (work_dir, filename) = os.path.split(filepath)

    upload = None
    bb.note("Begin to upload..." + filename)
    try:
        upload = foss.upload_file(
        folder,
        file=filepath,
        access_level=AccessLevel.PUBLIC,
        group=None,
        wait_time=int(d.getVar('WAIT_TIME'))
        )
    except AttributeError as error:
        bb.error(error.message)
    except FossologyApiError as error:
        bb.error(error.message)
    except TryAgain:
        time.sleep(int(d.getVar('WAIT_TIME')))

    return upload

def get_upload_file_name(d):
    tarname = get_tar_name(d, 'patched')
    bb.note("get_upload_file_name :" + tarname)
    return tarname
 
def create_folder(d, foss, token, folder_name):
    exist = 0

    folder_list = foss.list_folders()
    for folder in folder_list:
        if folder.name == folder_name:
            exist = 1
            break

    if exist == 0:
        bb.note("create_folder :")
        create_folder_lock.acquire()
        folder = foss.create_folder(foss.rootFolder, folder_name, description=None)
        create_folder_lock.release()
        if folder.name != folder_name:
            bb.error("Folder %s couldn't be created" % folder_name)
    return folder

python do_schedule_jobs(){
    import os
    import re
    import time
    import logging
    import sys
    import pathlib
    import secrets
    from getpass import getpass
    import requests
    from fossology import Fossology, fossology_token
    from fossology.enums import AccessLevel, TokenScope
    from fossology.exceptions  import FossologyApiError
    os.environ["FOSSOLOGY_USER"] = "fossy"
    os.environ["FOSSOLOGY_USER_PASS"] = "fossy"


    pn = d.getVar( 'PN')
    #If not for target, won't creat spdx.
    if bb.data.inherits_class('nopackages', d) and not pn.startswith('gcc-source'):
        return

    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    logging.basicConfig(level=logging.INFO)

    from tenacity import retry, TryAgain, stop_after_attempt
    from fossology.obj import Agents
    fossology_server = d.getVar('FOSSOLOGY_SERVER')
    fossology_user = d.getVar('FOSSOLOGY_USER')
    if not d.getVar('TOKEN', False):
        path_to_token_file = pathlib.Path.cwd() / '.token'
        if not path_to_token_file.exists():
            if os.environ["FOSSOLOGY_USER"] and os.environ["FOSSOLOGY_USER_PASS"]:
                username =  os.environ["FOSSOLOGY_USER"]
                pw =  os.environ["FOSSOLOGY_USER_PASS"]
            else:
                bb.warn("Enter your Fossology credentials, e.g. in the test environment 'username: fossy' and 'password: fossy'")
                username = input("username: ")
                pw = getpass()
            token = fossology_token(fossology_server,
                    fossology_user,
                    pw,
                    secrets.token_urlsafe(8), # TOKEN_NAME seen in the database
                    TokenScope.WRITE,
            )
            with open(path_to_token_file, "w") as fp:
                token_len = fp.write(token)
        else:
            # Load the token
            with open(".token", "r") as fp:
                token = fp.read()
    else:
        token = d.getVar('TOKEN')
    foss = Fossology(fossology_server, token)

    bb.note("Begin to schedule jobs!")
    info = {}
    info['workdir'] = (d.getVar('WORKDIR') or "")
    info['pn'] = (d.getVar( 'PN') or "")
    info['pv'] = (d.getVar( 'PKGV') or "").replace('-', '+')
    info['pr'] = (d.getVar( 'PR') or "")
    if (d.getVar('BPN') == "perf"):
        info['pv'] = d.getVar("KERNEL_VERSION").split("-")[0]
    if 'AUTOINC' in info['pv']:
        info['pv'] = info['pv'].replace("AUTOINC", "0")

    if pn.startswith('gcc-source'):
        spdx_name = "gcc-" + info['pv'] + "-" + info['pr'] + ".spdx"
    else:
        spdx_name = info['pn'] + "-" + info['pv'] + "-" + info['pr'] + ".spdx"

    manifest_dir = (d.getVar('SPDX_DEPLOY_DIR') or "")
    if not os.path.exists( manifest_dir ):
        bb.utils.mkdirhier( manifest_dir )

    spdx_outdir = d.getVar('SPDX_OUTDIR')
    info['outfile'] = os.path.join(manifest_dir, spdx_name )
    sstatefile = os.path.join(spdx_outdir, spdx_name)
    if os.path.exists(info['outfile']):
        bb.note(info['pn'] + " spdx file has been exist, do nothing")
        return
    if os.path.exists( sstatefile ):
        bb.note(info['pn'] + " spdx file has been exist, do nothing")
        create_manifest(info,sstatefile)
        return

    if d.getVar('FOLDER_NAME', False):
        folder_name = d.getVar('FOLDER_NAME')
        folder = create_folder(d, foss, token, folder_name)
    else:
        folder = foss.rootFolder

    upload = get_upload(d, folder, foss)
    if upload == None:
        bb.error("%s has not been uploaded." + pn)

    jobs_spec = {
        "analysis": {
            "bucket": True,
            "copyright_email_author": True,
            "ecc": True,
            "keyword": True,
            "monk": True,
            "mime": True,
            "monk": True,
            "nomos": True,
            "ojo": True,
            "package": True,
            "specific_agent": True,
        },
        "decider": {
            "nomos_monk": True,
            "bulk_reused": True,
            "new_scanner": True,
            "ojo_decider": True,
        },
        "reuse": {
            "reuse_upload": 0,
            "reuse_group": 0,
            "reuse_main": True,
            "reuse_enhanced": True,
        },
    }

    jobs,pages = foss.list_jobs(upload=upload)
    if jobs == None:
        try:
            job = foss.schedule_jobs(folder, upload, jobs_spec)
            if job.name != upload.uploadname:
                bb.error("Job %s does not relate to the correct upload" % job.name )
        except FossologyApiError as error:
            bb.error(error.message)
    elif len(jobs) < 2:
        try:
            job = foss.schedule_jobs(folder, upload, jobs_spec)
            if job.name != upload.uploadname:
                bb.error("Job %s does not relate to the correct upload" % job.name )
        except FossologyApiError as error:
            bb.error(error.message)
    else:
        bb.note("%s jobs has existed " % len(jobs))

    time.sleep(int(d.getVar('WAIT_TIME')))
    bb.note("Schedule jobs is end!")
}

def check_jobs(d, foss, uploaded):
    i = 0
    job_wait = int(d.getVar('WAIT_TIME'))
    time_wait = int(d.getVar('WAIT_TIME'))

    while i < 20:
        i += 1
        try:
            jobs,pages = foss.list_jobs(upload=uploaded)
        except FossologyApiError as error:
            bb.error(error.message)

        bb.note("jobs[0].uploadId = %s" % jobs[0].uploadId)
        if len(jobs) < 2:
            if i == 4:
                bb.error("%s jobs start is still not completed." % uploaded.uploadname)
            else:
                bb.warn("%s jobs start not completed " % uploaded.uploadname)
            time.sleep(time_wait)
        else:
            break

    i = 0
    while i < 5:
        i += 1
        job = foss.detail_job(jobs[1].id, wait=True, timeout=job_wait)
        if job.status != "Completed":
            bb.warn("The Job is still not completed yet. Please comfirm your fossology server.")
            time.sleep(time_wait)
        else:
            bb.note("jobs has completed.")
            return job
    bb.error("The Job is still not completed yet. Please comfirm your fossology server.")

python do_get_report(){

    import os, sys, json, shutil, time
    import logging
    import subprocess
    import pathlib
    import secrets
    from getpass import getpass
    import requests
    from tenacity import TryAgain
    from fossology import Fossology, fossology_token
    from fossology.obj import Group
    from fossology.enums import AccessLevel, TokenScope
    from fossology.exceptions  import FossologyApiError
    from fossology.enums import ReportFormat
    os.environ["FOSSOLOGY_USER"] = "fossy"
    os.environ["FOSSOLOGY_USER_PASS"] = "fossy"

    i = 0
    wait_time = int(d.getVar('WAIT_TIME'))
    complete = False
    report_id = None
    report = None

    pn = d.getVar('PN')
    #If not for target, won't creat spdx.
    if bb.data.inherits_class('nopackages', d) and not pn.startswith('gcc-source'):
        return

    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    logging.basicConfig(level=logging.INFO)

    bb.note("Begin to get report!")

    fossology_server = d.getVar('FOSSOLOGY_SERVER')
    fossology_user = d.getVar('FOSSOLOGY_USER')
    if not d.getVar('TOKEN', False):
        path_to_token_file = pathlib.Path.cwd() / '.token'
        if not path_to_token_file.exists():
            if os.environ["FOSSOLOGY_USER"] and os.environ["FOSSOLOGY_USER_PASS"]:
                username =  os.environ["FOSSOLOGY_USER"]
                pw =  os.environ["FOSSOLOGY_USER_PASS"]
            else:
                bb.warn("Enter your Fossology credentials, e.g. in the test environment 'username: fossy' and 'password: fossy'")
                username = input("username: ")
                pw = getpass()
            token = fossology_token(
                fossology_server,
                fossology_user,
                pw,
                secrets.token_urlsafe(8), # TOKEN_NAME seen in the database
                TokenScope.WRITE,
            )
            with open(path_to_token_file, "w") as fp:
                token_len = fp.write(token)
        else:
            with open(".token", "r") as fp:
                token = fp.read()
    else:
         token = d.getVar('TOKEN')

    foss = Fossology(fossology_server, token)

    if d.getVar('FOLDER_NAME', False):
        folder_name = d.getVar('FOLDER_NAME')
        folder = create_folder(d, foss, token, folder_name)
    else:
        folder = foss.rootFolder
    manifest_dir = (d.getVar('SPDX_DEPLOY_DIR') or "")
    if not os.path.exists( manifest_dir ):
        bb.utils.mkdirhier( manifest_dir )

    spdx_workdir = d.getVar('SPDX_WORKDIR')
    temp_dir = os.path.join(d.getVar('WORKDIR'), "temp")
    spdx_temp_dir = os.path.join(spdx_workdir, "temp")
    spdx_outdir = d.getVar('SPDX_OUTDIR')

    cur_ver_code = get_ver_code(spdx_workdir).split()[0]
    info = {}
    
    info['workdir'] = (d.getVar('WORKDIR') or "")
    info['pn'] = (d.getVar( 'PN') or "")
    info['pv'] = (d.getVar( 'PKGV') or "").replace('-', '+')
    info['pr'] = (d.getVar( 'PR') or "")
    if (d.getVar('BPN') == "perf"):
        info['pv'] = d.getVar("KERNEL_VERSION").split("-")[0]
    if 'AUTOINC' in info['pv']:
        info['pv'] = info['pv'].replace("AUTOINC", "0")

    if pn.startswith('gcc-source'):
        spdx_name = "gcc-" + info['pv'] + "-" + info['pr'] + ".spdx"
    else:
        spdx_name = info['pn'] + "-" + info['pv'] + "-" + info['pr'] + ".spdx"

    info['package_download_location'] = (d.getVar( 'SRC_URI') or "")
    if info['package_download_location'] != "":
        info['package_download_location'] = info['package_download_location'].split()[0]
    info['spdx_version'] = (d.getVar('SPDX_VERSION') or '')
    info['outfile'] = os.path.join(manifest_dir, spdx_name )
    spdx_file = os.path.join(spdx_outdir, spdx_name )
    if os.path.exists(info['outfile']):
        bb.note(info['pn'] + " spdx file has been exist, do nothing")
        return
    if os.path.exists( spdx_file ):
        bb.note(info['pn'] + " spdx file has been exist, do nothing")
        create_manifest(info,spdx_file)
        return
    info['data_license'] = (d.getVar('DATA_LICENSE') or '')
    info['creator'] = {}
    info['creator']['Tool'] = (d.getVar('CREATOR_TOOL') or '')
    info['license_list_version'] = (d.getVar('LICENSELISTVERSION') or '')
    info['package_homepage'] = (d.getVar('HOMEPAGE') or "")
    info['package_summary'] = (d.getVar('SUMMARY') or "")
    info['package_summary'] = info['package_summary'].replace("\n","")
    info['package_summary'] = info['package_summary'].replace("'"," ")
    info['package_contains'] = (d.getVar('CONTAINED') or "")
    info['package_static_link'] = (d.getVar('STATIC_LINK') or "")
    info['modified'] = "false"
    info['external_refs'] = get_external_refs(d)
    info['purpose'] = get_pkgpurpose(d)
    info['release_date'] = (d.getVar('REALASE_DATE') or "")
    info['build_time'] = get_build_date(d)
    info['depends_on'] = get_depends_on(d)
    info['pkg_spdx_id'] = get_spdxid_pkg(d)
    srcuri = d.getVar("SRC_URI", False).split()
    length = len("file://")
    for item in srcuri:
        if item.startswith("file://"):
            item = item[length:]
            if item.endswith(".patch") or item.endswith(".diff"):
                info['modified'] = "true"
    upload = get_upload(d, folder, foss)
    if upload == None:
        bb.error("Has not been uploaded.")
    check_jobs(d, foss, upload)
    try:
        report_id = foss.generate_report(
            upload, report_format=ReportFormat.SPDX2TV
        )
    except FossologyApiError as error:
        bb.error(error.message)
    except AttributeError as error:
        bb.error("AttributeError! It seems fossology server is busy.")
    if report_id == None:
        bb.error("Get report id failed! Maybe fossology server is busy.")
        return
    while i < 20:
        i += 1
        try:
            report, name = foss.download_report(report_id, wait_time=wait_time*2)
        except TryAgain:
            bb.warn("SPDX file is still not ready, try again.")
            time.sleep(wait_time)
            continue
        except FossologyApiError as error:
            bb.warn("Dowload SPDX file failed, Try again.")
            continue
        if report == None:
            bb.error("Fail to download report.")
            break

    with open(spdx_file, "wb") as file:
        written = file.write(report)
        assert written == len(report)
        logger.info(
            f"Report written to file: report_name {name}  written to {spdx_file}"
        )
    file.close()
    
    subprocess.call(r"sed -i -e 's#\\n#\n#g' %s" % spdx_file, shell=True)

    if bb.data.inherits_class('packagegroup',d):
        return True
    if bb.data.inherits_class('image',d):
        return True
    if bb.data.inherits_class('packagegroup',d):
        return True
    if bb.data.inherits_class('image',d):
        return True

    file = open(spdx_file,'r+')
    line = file.readline()
    while line:
        if "LicenseID:" in line:
            complete = True
            break
        line = file.readline()
    file.close()

    write_cached_spdx(info,spdx_file,cur_ver_code)
    create_manifest(info,spdx_file)
    if complete == False:
        bb.warn("license info not complete, please confirm.")
    else:
        time.sleep(int(d.getVar('WAIT_TIME')))
        return True
}

SSTATETASKS += "do_spdx"
SSTATETASKS += "do_upload_recipe_source"
python do_spdx_setscene () {
    sstate_setscene(d)
}
addtask do_spdx_setscene
do_spdx () {
    """
    This task does nothing, only depends on get_report task.
    """

    echo "Create spdx file."
}

do_upload_recipe_source () {
    """
    This task is used to upload code and then trigger a scan.
    """

    echo "Upload recipe source to fossology server."
}

python do_check_recipe_license(){
    """
    This task compares the license info of OSS in recipe files with the 
    scanning results from fossology. Save the result to a pn-check-recipe-license.dot file.
    """

    import re
    from typing import List, Dict, Optional

    target_filenames_regex_list = []
    spdx_outdir = d.getVar('SPDX_OUTDIR')
    spdx_name = get_spdx_name(d)
    manifest_dir = (d.getVar('SPDX_DEPLOY_DIR') or "")
    spdx_file_path = os.path.join(manifest_dir, spdx_name)

    def get_search_keywords():
        target_filenames_keywords = []
        lic_files_list = get_licensefilelist_in_recipe(d)
        for url in lic_files_list:
            line_spdx = url
            target_filenames_keywords.append(line_spdx)
        return target_filenames_keywords

    target_filenames_regex_list = get_search_keywords()

    def extract_licenses_from_spdx_multiple_files(spdx_filepath, target_filenames): 
        results: Dict[str, List[str]] = {filename: [] for filename in target_filenames}
        spdx_content = ""
        
        compiled_patterns = []

        all_extracted_licenses = {}
        license_info_pattern = r"^LicenseInfoInFile: (.+)$"
        current_target_regex = None
        current_extracted_licenses = []

        for filename in target_filenames:
            escaped_filename = re.escape(filename)
        
            final_regex_pattern = re.compile(
            r"^.*?spdx_temp/sources/[^/]+/" + escaped_filename + r"$"
            )
            compiled_patterns.append((filename, final_regex_pattern))

            compiled_patterns.append((filename, final_regex_pattern))
        try:
            with open(spdx_filepath, 'r', encoding='utf-8') as f:
                spdx_content = f.read()
        except Exception as e:
            raise e
        if not spdx_content:
            return results

        file_blocks = re.split(r'\n##File\n', spdx_content)

        for block in file_blocks:
            if not block.strip(): 
                continue
            
            filename_match = re.search(r'FileName:\s*(.*)', block)
            if filename_match:
                current_full_filepath = filename_match.group(1).strip()
                matched_original_filename = None
                for original_filename, compiled_regex in compiled_patterns:
                    if compiled_regex.fullmatch(current_full_filepath): 
                        matched_original_filename = original_filename
                        break

                if matched_original_filename:
                    license_info_matches = re.findall(r'LicenseInfoInFile:\s*(.*)', block)
                    if license_info_matches:
                        unique_licenses = list(set(lic.strip() for lic in license_info_matches))
                        results[matched_original_filename].extend(unique_licenses)
        return results

    lic_files_in_spdx_result = extract_licenses_from_spdx_multiple_files(spdx_file_path, target_filenames_regex_list)
    export_license_results_to_dot(d, spdx_file_path, target_filenames_regex_list, lic_files_in_spdx_result)
}

addtask do_spdx_creat_tarball after do_patch
addtask do_foss_upload after do_spdx_creat_tarball 
addtask do_schedule_jobs after do_foss_upload
addtask do_get_report after do_schedule_jobs
addtask do_spdx
addtask do_upload_recipe_source after do_schedule_jobs
addtask do_check_recipe_license after do_get_report 
do_build[recrdeptask] += "do_spdx"
do_populate_sdk[recrdeptask] += "do_spdx"
do_get_report[depends] = "cve-update-nvd2-native:do_unpack"
