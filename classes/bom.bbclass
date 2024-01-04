# This class integrates real-time license scanning, generation of SPDX standard
# output and verifiying license info during the building process.
# It is a combination of efforts from the OE-Core, SPDX and bom projects.
#
# For more information on the following :
#   https://github.com/kubernetes-sigs/bom
#
# For more information on SPDX:
#   http://www.spdx.org
# install bom on your host:https://github.com/kubernetes-sigs/bom
HOSTTOOLS += "bom"

COPYLEFT_RECIPE_TYPES ?= 'target nativesdk'
inherit copyleft_filter
inherit spdx-common 
HOSTTOOLS += "bom"

do_get_report[dirs] = "${SPDX_OUTDIR}"

CREATOR_TOOL = "bom.bbclass in meta-spdxscanner"

python () {
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
        if hasTask("do_package_write_rpm") or hasTask("do_package_write_ipk") or hasTask("do_package_write_deb"):
            d.appendVarFlag('do_spdx', 'depends', ' %s:do_get_report' % pn)
            d.appendVarFlag('do_get_report', 'depends', ' %s:do_spdx_get_src' % pn)
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
    info['pv'] = (d.getVar( 'PV') or "").replace('-', '+')
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
        d.setVar('WORKDIR', d.getVar('SPDX_WORKDIR', True))
    info['sourcedir'] = spdx_workdir
    git_path = "%s/git/.git" % info['sourcedir']
    if os.path.exists(git_path):
        remove_dir_tree(git_path)
    invoke_bom(info['sourcedir'],spdx_file)
    bb.note("info['sourcedir'] = " + info['sourcedir'])
    write_cached_spdx(info,spdx_file,cur_ver_code)
    create_manifest(info,spdx_file)
}

def invoke_bom(OSS_src_dir, spdx_file):
    import subprocess
    import string
    import json
    import codecs
    import logging

    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    logging.basicConfig(level=logging.INFO)

    path = os.getenv('PATH')
    bom_cmd = bb.utils.which(os.getenv('PATH'), "bom")
    bom_cmd = bom_cmd + " generate -d " + OSS_src_dir + " --output=" + spdx_file
    bb.note("bom_cmd = " + bom_cmd)
    print(bom_cmd)
    try:
        subprocess.check_output(bom_cmd,
                                stderr=subprocess.STDOUT,
                                shell=True)
    except subprocess.CalledProcessError as e:
        bb.fatal("Could not invoke bom Command "
                 "'%s' returned %d:\n%s" % (bom_cmd, e.returncode, e.output))

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

