# This class integrates real-time license scanning, generation of SPDX standard
# output and verifiying license info during the building process.
# It is a combination of efforts from the OE-Core, SPDX and DoSOCSv2 projects.
#
# For more information on DoSOCSv2:
#   https://github.com/DoSOCSv2
#
# For more information on SPDX:
#   http://www.spdx.org
#
# Note:
# 1) Make sure fossdriver has beed installed in your host
# 2) By default,spdx files will be output to the path which is defined as[SPDX_DEPLOY_DIR] 
#    in ./meta/conf/spdx-dosocs.conf.
inherit spdx-common

do_spdx[network] = "1"
do_get_report[network] = "1"

FOSSOLOGY_SERVER ?= "http://127.0.0.1:8081/repo"
FOLDER_NAME ?= "Software Repository"
#upload OSS into No.1 folder of fossology
FOLDER_ID ?= "1"

HOSTTOOLS_NONFATAL += "curl"

CREATOR_TOOL = "fossology-rest.bbclass in meta-spdxscanner"

# If ${S} isn't actually the top-level source directory, set SPDX_S to point at
# the real top-level directory.
SPDX_S ?= "${S}"
addtask do_spdx before do_build after do_patch
python do_spdx () {
    import os, sys, shutil
    pn = d.getVar('PN', True)

    pn = d.getVar('PN')
    #If not for target, won't creat spdx.
    if bb.data.inherits_class('nopackages', d) and not pn.startswith('gcc-source'):
        return

    assume_provided = (d.getVar("ASSUME_PROVIDED", True) or "").split()
    if pn in assume_provided:
        for p in d.getVar("PROVIDES", True).split():
            if p != pn:
                pn = p
                break
    # The following: do_fetch, do_unpack and do_patch tasks have been deleted,
    # so avoid archiving do_spdx here.
    if pn.startswith('glibc-locale'):
        return
    #if (d.getVar('BPN') == "linux-yocto"):
    #    return
    if (d.getVar('PN', True) == "libtool-cross"):
        return
    if (d.getVar('PN', True) == "libgcc-initial"):
        return
    if (d.getVar('PN', True) == "shadow-sysroot"):
        return

    # We just archive gcc-source for all the gcc related recipes
    if d.getVar('BPN') in ['gcc', 'libgcc'] \
            and not pn.startswith('gcc-source'):
        bb.debug(1, 'archiver: %s is excluded, covered by gcc-source' % pn)
        return
    def hasTask(task):
        return bool(d.getVarFlag(task, "task", False)) and not bool(d.getVarFlag(task, "noexec", False))
    if d.getVar('PACKAGES') or pn.startswith('gcc-source'):
       # Some recipes do not have any packaging tasks
        if hasTask("do_package_write_rpm") or hasTask("do_package_write_ipk") or hasTask("do_package_write_deb") or pn.startswith('gcc-source'):
            d.appendVarFlag('do_get_report', 'depends', ' %s:do_spdx_creat_tarball' % pn)
            d.appendVarFlag('do_spdx', 'depends', ' %s:do_get_report' % pn)
            bb.build.addtask('do_get_report', 'do_configure', 'do_patch', d)
            bb.build.addtask('do_spdx', 'do_configure', 'do_get_report', d)


    manifest_dir = (d.getVar('SPDX_DEPLOY_DIR') or "")
    if not os.path.exists( manifest_dir ):
        bb.utils.mkdirhier( manifest_dir )

    info = {}
    info['pn'] = (d.getVar( 'PN') or "")
    info['pv'] = (d.getVar( 'PKGV') or "").replace('-', '+')
    info['pr'] = (d.getVar( 'PR') or "")

    if 'AUTOINC' in info['pv']:
        info['pv'] = info['pv'].replace("AUTOINC", "0")

    if d.getVar('SAVE_SPDX_ACHIVE'):
        if d.getVar('PACKAGES') or pn.startswith('gcc-source'):
           # Some recipes do not have any packaging tasks
           if hasTask("do_package_write_rpm") or hasTask("do_package_write_ipk") or hasTask("do_package_write_deb") or pn.startswith('gcc-source'):
               d.appendVarFlag('do_spdx', 'depends', ' %s:do_spdx_creat_tarball' % pn)

    spdx_outdir = d.getVar('SPDX_OUTDIR')
    if pn.startswith('gcc-source'):
        spdx_name = "gcc-" + info['pv'] + "-" + info['pr'] + ".spdx"
    else:
        spdx_name = info['pn'] + "-" + info['pv'] + "-" + info['pr'] + ".spdx"

    info['outfile'] = os.path.join(manifest_dir, spdx_name )
    sstatefile = os.path.join(spdx_outdir, spdx_name )
    if os.path.exists(info['outfile']):
        bb.note(info['pn'] + "spdx file has been exist, do nothing")
        return
    if os.path.exists( sstatefile ):
        bb.note(info['pn'] + "spdx file has been exist, do nothing")
        create_manifest(info,sstatefile)
        return

    spdx_outdir = d.getVar('SPDX_OUTDIR')
    if pn.startswith('gcc-source'):
        spdx_name = "gcc-" + info['pv'] + "-" + info['pr'] + ".spdx"
    else:
        spdx_name = info['pn'] + "-" + info['pv'] + "-" + info['pr'] + ".spdx"

    info['outfile'] = os.path.join(manifest_dir, spdx_name )
    sstatefile = os.path.join(spdx_outdir, spdx_name )
    if os.path.exists(info['outfile']):
        bb.note(info['pn'] + "spdx file has been exist, do nothing")
        return
    if os.path.exists( sstatefile ):
        bb.note(info['pn'] + "spdx file has been exist, do nothing")
        create_manifest(info,sstatefile)
        return

    if d.getVar('PACKAGES') or pn.startswith('gcc-source'):
       # Some recipes do not have any packaging tasks
        if hasTask("do_package_write_rpm") or hasTask("do_package_write_ipk") or hasTask("do_package_write_deb") or pn.startswith('gcc-source'):
            d.appendVarFlag('do_get_report', 'depends', ' %s:do_spdx_creat_tarball' % pn)
            d.appendVarFlag('do_spdx', 'depends', ' %s:do_get_report' % pn)
            bb.build.addtask('do_get_report', 'do_configure', 'do_patch', d)
            bb.build.addtask('do_spdx', 'do_configure', 'do_get_report', d)
}

def has_upload(d, tar_file, folder_id):
    import os
    import subprocess
    import json
    i = 0

    (work_dir, file_name) = os.path.split(tar_file) 

    server_url = (d.getVar('FOSSOLOGY_SERVER', True) or "")
    if server_url == "":
        bb.note("Please set fossology server URL by setting FOSSOLOGY_SERVER!\n")
        raise OSError(errno.ENOENT, "No setting of  FOSSOLOGY_SERVER")

    token = (d.getVar('TOKEN', True) or "")
    if token == "":
        bb.note("Please set token of fossology server by setting TOKEN!\n" + srcPath)
        raise OSError(errno.ENOENT, "No setting of TOKEN comes from fossology server.")

    rest_api_cmd = "curl -Ss -X GET " + server_url + "/api/v1/search" \
                   + " -H \"Authorization: Bearer " + token + "\"" \
                   + " -H \"filename: " + file_name + "\"" \
                   + " --noproxy 127.0.0.1"
    bb.note("Invoke rest_api_cmd = " + rest_api_cmd )
        
    try:
        upload_output = subprocess.check_output(rest_api_cmd, stderr=subprocess.STDOUT, shell=True).decode("utf-8")
    except subprocess.CalledProcessError as e:
        bb.error("curl failed: \n%s" % e.output.decode("utf-8"))
        return -1
    bb.note("upload_output = ")
    bb.note(str(upload_output))
    bb.note("has_upload: len of upload_output = ")
    upload_output = json.loads(upload_output) 
    bb.note(str(len(upload_output)))
    if len(upload_output) == 0:
        bb.note(file_name + "hasn't been uploaded yet.")
        return -1
    while i < len(upload_output):
        if (upload_output[0]["upload"]["folderid"] == folder_id):
            bb.note(file_name + "has been uploaded, uploadId = :" + str(upload_output[0]["upload"]["id"]))
            return upload_output[0]["upload"]["id"]
        i = i+1
    bb.note(file_name + "hasn't been uploaded yet.")
    return -1

def upload(d, tar_file, folder_id):
    import os
    import subprocess
    import json
    delaytime = 50
    i = 0
 
    server_url = (d.getVar('FOSSOLOGY_SERVER', True) or "")
    if server_url == "":
        bb.note("Please set fossology server URL by setting FOSSOLOGY_SERVER!\n")
        raise OSError(errno.ENOENT, "No setting of  FOSSOLOGY_SERVER")

    token = (d.getVar('TOKEN', True) or "")
    if token == "":
        bb.note("Please set token of fossology server by setting TOKEN!\n" + srcPath)
        raise OSError(errno.ENOENT, "No setting of TOKEN comes from fossology server.")
    
    rest_api_cmd = "curl -k -s -S -X POST " + server_url + "/api/v1/uploads" \ 
                    + " -H \'folderId: " + folder_id + "\'" \
                    + " -H \"Authorization: Bearer " + token + "\"" \
                    + " -H \'uploadDescription: created by REST\'" \
                    + " -H \'public: public\'"  \
                    + " -H \'uploadType:file\'" \
                    + " -H \'Content-Type: multipart/form-data\'"  \
                    + " -F \'fileInput=@\"" + tar_file + "\";type=application/octet-stream\'" \
                    + " --noproxy 127.0.0.1"
    bb.note("Upload : Invoke rest_api_cmd = " + rest_api_cmd )
    while i < 1:
        time.sleep(delaytime)
        try:
            upload = subprocess.check_output(rest_api_cmd, stderr=subprocess.STDOUT, shell=True)
        except subprocess.CalledProcessError as e:
            bb.error("Upload failed: \n%s" % e.output.decode("utf-8"))
            return False
        bb.note("Upload = ")
        bb.note(str(upload))
        upload = eval(upload)
        if upload["code"] == 201:
            return upload["message"]
        i += 1
    bb.note("Upload is fail, please check your fossology server.")
    return False
def has_analysis(d, file_name, upload_id):
    import os
    import subprocess
    import json
    delaytime = 100
    i = 0

    server_url = (d.getVar('FOSSOLOGY_SERVER', True) or "")
    if server_url == "":
        bb.note("Please set fossology server URL by setting FOSSOLOGY_SERVER!\n")
        raise OSError(errno.ENOENT, "No setting of  FOSSOLOGY_SERVER")

    token = (d.getVar('TOKEN', True) or "")
    if token == "":
        bb.note("Please set token of fossology server by setting TOKEN!\n" + srcPath)
        raise OSError(errno.ENOENT, "No setting of TOKEN comes from fossology server.")

    rest_api_cmd = "curl -k -s -S -X GET " + server_url + "/api/v1/jobs?upload=" + str(upload_id) \
                   + " -H \"Authorization: Bearer " + token + "\"" 
    bb.note("get analysis status : Invoke rest_api_cmd = " + rest_api_cmd )
    try:
        analysis_output = subprocess.check_output(rest_api_cmd, stderr=subprocess.STDOUT, shell=True).decode("utf-8")
    except subprocess.CalledProcessError as e:
        bb.error("curl failed: \n%s" % e.output.decode("utf-8"))
        return False
    bb.note("upload_output = ")
    bb.note(str(analysis_output))
    bb.note("has_upload: len of upload_output = ")
    analysis_output = json.loads(analysis_output)
    bb.note(str(len(analysis_output)))
    if len(analysis_output) == 0:
        bb.note(file_name + " hasn't been analysis yet.")
        return False
    bb.note(analysis_output[0]["status"])
    if analysis_output[0]["status"] == "Completed":
        bb.note(file_name + "has been analysis.")
        return True
    else:
        bb.note(file_name + "has not been analysis.")
        return False


def analysis(d, folder_id, upload_id):
    import os
    import subprocess
    delaytime = 100
    i = 0

    server_url = (d.getVar('FOSSOLOGY_SERVER', True) or "")
    if server_url == "":
        bb.note("Please set fossology server URL by setting FOSSOLOGY_SERVER!\n")
        raise OSError(errno.ENOENT, "No setting of  FOSSOLOGY_SERVER")

    token = (d.getVar('TOKEN', True) or "")
    if token == "":
        bb.note("Please set token of fossology server by setting TOKEN!\n" + srcPath)
        raise OSError(errno.ENOENT, "No setting of TOKEN comes from fossology server.")

    rest_api_cmd = "curl -k -s -S -X POST " + server_url + "/api/v1/jobs" \
                    + " -H \'folderId: " + str(folder_id) + "\'" \
                    + " -H \'uploadId: " + str(upload_id) + "\'" \
                    + " -H \"Authorization: Bearer " + token + "\"" \
                    + " -H \'Content-Type: application/json\'" \
                    + " --data \'{\"analysis\": {\"bucket\": true,\"copyright_email_author\": true,\"ecc\": true, \"keyword\": true,\"mime\": true,\"monk\": true,\"nomos\": true,\"package\": true},\"decider\": {\"nomos_monk\": true,\"bulk_reused\": true,\"new_scanner\": true}}\'" \
                    + " --noproxy 127.0.0.1"

    bb.note("Analysis : Invoke rest_api_cmd = " + rest_api_cmd )
    while i < 10:
        try:
            time.sleep(delaytime)
            analysis = subprocess.check_output(rest_api_cmd, stderr=subprocess.STDOUT, shell=True).decode("utf-8")
        except subprocess.CalledProcessError as e:
            bb.error("Analysis failed: \n%s" % e.output.decode("utf-8"))
            return False
        time.sleep(delaytime)
        bb.note("analysis  = ")
        bb.note(str(analysis))
        analysis = eval(analysis)
        if analysis["code"] == 201:
            return analysis["message"]
        elif analysis["code"] == 404:
            bb.note("analysis is still not complete.")
            time.sleep(delaytime*2)
        else:
            return False
        i += 1
        bb.note("Analysis is fail, will try again.")
    bb.note("Analysis is fail, please check your fossology server.")
    return False

def trigger(d, folder_id, upload_id):
    import os
    import subprocess
    import json
    delaytime = 100
    i = 0

    server_url = (d.getVar('FOSSOLOGY_SERVER', True) or "")
    if server_url == "":
        bb.note("Please set fossology server URL by setting FOSSOLOGY_SERVER!\n")
        raise OSError(errno.ENOENT, "No setting of  FOSSOLOGY_SERVER")

    token = (d.getVar('TOKEN', True) or "")
    if token == "":
        bb.note("Please set token of fossology server by setting TOKEN!\n" + srcPath)
        raise OSError(errno.ENOENT, "No setting of TOKEN comes from fossology server.")
    rest_api_cmd = "curl -k -s -S -X GET " + server_url + "/api/v1/report" \
                    + " -H \"Authorization: Bearer " + token + "\"" \
                    + " -H \'uploadId: " + str(upload_id) + "\'" \
                    + " -H \'reportFormat: spdx2tv\'" \
                    + " --noproxy 127.0.0.1"
    bb.note("trigger : Invoke rest_api_cmd = " + rest_api_cmd )
    while i < 10:
        time.sleep(delaytime)
        try:
            trigger = subprocess.check_output(rest_api_cmd, stderr=subprocess.STDOUT, shell=True).decode("utf-8")
        except subprocess.CalledProcessError as e:
            bb.error("Trigger failed: \n%s" % e.output.decode("utf-8"))
            return False
        time.sleep(delaytime)
        bb.note("trigger  = ")
        bb.note(str(trigger))
        trigger = json.loads(trigger)
        if trigger["code"] == 201:
            return trigger["message"].split("/")[-1]
        i += 1
        time.sleep(delaytime * 2)
        bb.note("Trigger is fail, will try again.")
    bb.note("Trigger is fail, please check your fossology server.")
    return False

def get_spdx(d, report_id, spdx_file):
    import os
    import subprocess
    import time
    delaytime = 100
    empty = True
    i = 0

    server_url = (d.getVar('FOSSOLOGY_SERVER', True) or "")
    if server_url == "":
        bb.note("Please set fossology server URL by setting FOSSOLOGY_SERVER!\n")
        raise OSError(errno.ENOENT, "No setting of  FOSSOLOGY_SERVER")

    token = (d.getVar('TOKEN', True) or "")
    if token == "":
        bb.note("Please set token of fossology server by setting TOKEN!\n" + srcPath)
        raise OSError(errno.ENOENT, "No setting of TOKEN comes from fossology server.")
    rest_api_cmd = "curl -k -s -S -X GET " + server_url + "/api/v1/report/" + report_id \
                    + " -H \'accept: text/plain\'" \
                    + " -H \"Authorization: Bearer " + token + "\"" \
                    + " --noproxy 127.0.0.1"
    bb.note("get_spdx : Invoke rest_api_cmd = " + rest_api_cmd )
    while i < 3:
        time.sleep(delaytime)
        file = open(spdx_file,'wt')
        try:
            p = subprocess.Popen(rest_api_cmd, shell=True, universal_newlines=True, stdout=file)
        except subprocess.CalledProcessError as e:
            bb.error("Get spdx failed: \n%s" % e.output.decode("utf-8"))
            return False
        ret_code = p.wait()
        file.flush()
        time.sleep(delaytime)
        file.close()
        file = open(spdx_file,'r+')
        first_line = file.readline()
        if "SPDXVersion" in first_line:
            line = file.readline()
            while line:
                if "LicenseID:" in line:
                    empty = False
                    break
                line = file.readline()
            file.close()
            if empty == True:
                bb.note("Hasn't get license info.")
            return True
        else:
            bb.note("Get the first line is " + first_line)
            bb.note("spdx is not correct, will try again.")
            file.close()
            os.remove(spdx_file)
        i += 1
        time.sleep(delaytime*2)
    bb.note("Get spdx failed, Please check your fossology server.")

def get_folder_id(d):
    import os
    import subprocess
    import json
    delaytime = 100
    i = 0

    server_url = (d.getVar('FOSSOLOGY_SERVER', True) or "")
    if server_url == "":
        bb.note("Please set fossology server URL by setting FOSSOLOGY_SERVER!\n")
        raise OSError(errno.ENOENT, "No setting of  FOSSOLOGY_SERVER")

    token = (d.getVar('TOKEN', True) or "")
    if token == "":
        bb.note("Please set token of fossology server by setting TOKEN!\n" + srcPath)
        raise OSError(errno.ENOENT, "No setting of TOKEN comes from fossology server.")

    folder_name = (d.getVar('FOLDER_NAME', True) or "")
    if folder_name == "":
        bb.note("Please set FOLDER_NAME !\n")
        raise OSError(errno.ENOENT, "No setting of FOLDER_NAME.")

    rest_api_cmd = "curl -k -s -S -X POST " + server_url + "/api/v1/folders" \
                   + " -H \'parentFolder: 1\'" \
                   + " -H \"folderName: " + folder_name + "\"" \
                   + " -H \"Authorization: Bearer " + token + "\""
    bb.note("POST folder status : Invoke rest_api_cmd = " + rest_api_cmd )
    try:
        folder_output = subprocess.check_output(rest_api_cmd, stderr=subprocess.STDOUT, shell=True).decode("utf-8")
    except subprocess.CalledProcessError as e:
        bb.error("curl failed: \n%s" % e.output.decode("utf-8"))
        return False
    folder_output = json.loads(folder_output)
    bb.note(str(folder_output))
    bb.note(str(len(folder_output)))
    if len(folder_output) < 1:
        bb.error("create folder fail.")
        return 0
    if (folder_output["code"] == 201 or folder_output["code"] == 200):
        rest_api_cmd = "curl -k -s -S -X GET " + server_url + "/api/v1/folders" \
                   + " -H \"Authorization: Bearer " + token + "\""
        bb.note("GET folder status : Invoke rest_api_cmd = " + rest_api_cmd )
        try:
            folder_output = subprocess.check_output(rest_api_cmd, stderr=subprocess.STDOUT, shell=True).decode("utf-8")
        except subprocess.CalledProcessError as e:
            bb.error("curl failed: \n%s" % e.output.decode("utf-8"))
            return False
        folder_output = json.loads(folder_output)
        bb.note(str(folder_output))
        bb.note(str(len(folder_output)))
        while i < len(folder_output):
            if (folder_output[i]["name"] == folder_name):
                bb.note("The id of " + folder_name + "is : " + str(folder_output[i]["id"]))
                return folder_output[i]["id"]
            i = i+1
    else:
        bb.error("Creat folder failed. Please check fossology server.")
        return 0
    
    bb.error("Not find created folder. Please try again.")
    return 0
 
python do_get_report(){
    import os, sys, json, shutil, time
    import logging

    i = 0

    spdx_workdir = d.getVar('SPDX_WORKDIR')
    temp_dir = os.path.join(d.getVar('WORKDIR'), "temp")
    spdx_temp_dir = os.path.join(spdx_workdir, "temp")
    spdx_outdir = d.getVar('SPDX_OUTDIR')
    cur_ver_code = get_ver_code(spdx_workdir).split()[0]
    info = {}

    manifest_dir = (d.getVar('SPDX_DEPLOY_DIR') or "")
    if not os.path.exists( manifest_dir ):
        bb.utils.mkdirhier( manifest_dir )

    pn = d.getVar('PN')
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
        bb.note(info['pn'] + "spdx file has been exist, do nothing")
        return
    if os.path.exists( spdx_file ):
        bb.note(info['pn'] + "spdx file has been exist, do nothing")
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
    srcuri = d.getVar("SRC_URI", False).split()
    length = len("file://")
    for item in srcuri:
        if item.startswith("file://"):
            item = item[length:]
            if item.endswith(".patch") or item.endswith(".diff"):
                info['modified'] = "true"
    tar_file = get_tarball_name(d, d.getVar('WORKDIR'), 'patched', spdx_outdir)

    folder_id = str(get_folder_id(d))
    upload_id = has_upload(d, tar_file, folder_id)
    if upload_id == -1:
        bb.note("Upload it to fossology server.")
        upload_id = upload(d, tar_file, folder_id)
        if upload_id == False:
            return False
    if has_analysis(d, folder_id, upload_id) == False:
        if analysis(d, folder_id, upload_id) == False:
            return False
    while i < 10:
        i += 1
        report_id = trigger(d, folder_id, upload_id)
        if report_id == False:
            return False
        spdx2tv = get_spdx(d, report_id, spdx_file)
        if spdx2tv == False:
            bb.note("get_spdx is unnormal. Will try again!")
        else:
            return True

    print("get_spdx of %s is unnormal. Please check your fossology server!")
    return False
}
addtask do_spdx_creat_tarball after do_patch
addtask do_get_report after do_spdx_creat_tarball
addtask do_spdx before do_package after do_get_report
do_build[recrdeptask] += "do_spdx"
do_populate_sdk[recrdeptask] += "do_spdx"

