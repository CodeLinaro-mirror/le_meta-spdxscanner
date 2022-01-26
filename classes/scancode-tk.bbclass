# This class integrates real-time license scanning, generation of SPDX standard
# output and verifiying license info during the building process.
# It is a combination of efforts from the OE-Core, SPDX and scancode-toolkit projects.
#
# For more information on fossology REST API:
#   https://github.com/nexB/scancode-toolkit
#
# For more information on SPDX:
#   http://www.spdx.org

COPYLEFT_RECIPE_TYPES ?= 'target nativesdk'
inherit copyleft_filter

inherit spdx-common 

do_get_report[dirs] = "${SPDX_OUTDIR}"

CREATOR_TOOL = "scancode-tk.bbclass in meta-spdxscanner"

export EXTRACTCODE_LIBARCHIVE_PATH = "${STAGING_LIBDIR_NATIVE}/libarchive.so"
export EXTRACTCODE_7Z_PATH = "${STAGING_BINDIR_NATIVE}/7z"
export TYPECODE_LIBMAGIC_PATH = "${STAGING_LIBDIR_NATIVE}/libmagic.so"
export TYPECODE_LIBMAGIC_DB_PATH = "${STAGING_DATADIR_NATIVE}/magic.mgc"


python () {
    #If not for target, won't creat spdx.
    if bb.data.inherits_class('nopackages', d):
        return

    pn = d.getVar('PN')
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
    if d.getVar('BPN') in ['gcc', 'libgcc']:
        bb.debug(1, 'spdx: There is bug in scan of %s is, do nothing' % pn)
        return

    spdx_outdir = d.getVar('SPDX_OUTDIR')

    info = {}
    info['pn'] = (d.getVar( 'PN') or "")
    info['pv'] = (d.getVar( 'PV') or "")

    manifest_dir = (d.getVar('SPDX_DEPLOY_DIR') or "")
    if not os.path.exists( manifest_dir ):
        bb.utils.mkdirhier( manifest_dir )

    info['outfile'] = os.path.join(manifest_dir, info['pn'] + "-" + info['pv'] + ".spdx" )
    sstatefile = os.path.join(spdx_outdir, info['pn'] + "-" + info['pv'] + ".spdx" )
    if os.path.exists(info['outfile']):
        bb.note(info['pn'] + "spdx file has been exist, do nothing")
        return
    if os.path.exists( sstatefile ):
        bb.note(info['pn'] + "spdx file has been exist, do nothing")
        create_manifest(info,sstatefile)
        return

    def hasTask(task):
        return bool(d.getVarFlag(task, "task", False)) and not bool(d.getVarFlag(task, "noexec", False))
    
    if d.getVar('PACKAGES'):
       # Some recipes do not have any packaging tasks
       if hasTask("do_package_write_rpm") or hasTask("do_package_write_ipk") or hasTask("do_package_write_deb"):
           d.appendVarFlag('do_get_report', 'depends', ' scancode-toolkit-native:do_populate_sysroot')
           d.appendVarFlag('do_spdx', 'depends', ' %s:do_get_report' % pn)
           d.appendVarFlag('do_get_report', 'depends', ' %s:do_spdx_get_src' % pn)
           d.appendVarFlag('do_spdx', 'depends', ' %s:do_get_report' % pn)
           bb.build.addtask('do_spdx_get_src', 'do_configure', 'do_patch', d)
           bb.build.addtask('do_get_report', 'do_configure', 'do_patch', d)
           bb.build.addtask('do_spdx', 'do_configure', 'do_get_report', d)
}

python do_get_report(){

    import os, sys, json, shutil

    #If not for target, won't creat spdx.
    if bb.data.inherits_class('nopackages', d):
        return

    bb.note("Begin to get report!")

    pn = d.getVar('PN')

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
    info['pv'] = (d.getVar( 'PV') or "")
    info['package_download_location'] = (d.getVar( 'SRC_URI') or "")
    if info['package_download_location'] != "":
        info['package_download_location'] = info['package_download_location'].split()[0]
    info['spdx_version'] = (d.getVar('SPDX_VERSION') or '')
    info['outfile'] = os.path.join(manifest_dir, info['pn'] + "-" + info['pv'] + ".spdx" )
    spdx_file = os.path.join(spdx_outdir, info['pn'] + "-" + info['pv'] + ".spdx" )
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
        d.setVar('WORKDIR', d.getVar('SPDX_WORKDIR', True))
    info['sourcedir'] = spdx_workdir
    git_path = "%s/git/.git" % info['sourcedir']
    if os.path.exists(git_path):
        remove_dir_tree(git_path)
    invoke_scancode(info['sourcedir'],spdx_file)

    write_cached_spdx(info,spdx_file,cur_ver_code)
    create_manifest(info,spdx_file)
}

def invoke_scancode(OSS_src_dir, spdx_file):
    import subprocess
    import string
    import json
    import codecs
    import logging

    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    logging.basicConfig(level=logging.INFO)

    path = os.getenv('PATH')
    scancode_cmd = bb.utils.which(os.getenv('PATH'), "scancode")
    scancode_cmd = scancode_cmd + " -lpci --spdx-tv " + spdx_file + " " + OSS_src_dir
    print(scancode_cmd)
    try:
        subprocess.check_output(scancode_cmd,
                                stderr=subprocess.STDOUT,
                                shell=True)
    except subprocess.CalledProcessError as e:
        bb.fatal("Could not invoke scancode Command "
                 "'%s' returned %d:\n%s" % (scancode_cmd, e.returncode, e.output))

SSTATETASKS += "do_spdx"
python do_spdx_setscene () {
    sstate_setscene(d)
}
addtask do_spdx_setscene
do_spdx () {
    echo "Create spdx file."
}
addtask do_spdx_get_src after do_patch
addtask do_get_report after do_spdx_get_src
addtask do_spdx
do_build[recrdeptask] += "do_spdx"
do_populate_sdk[recrdeptask] += "do_spdx"

