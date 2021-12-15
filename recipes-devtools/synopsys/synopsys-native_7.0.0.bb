SUMMARY = "Download synopsys-detect-${PN}.jar"
DESCRIPTION = "Download synopsys-detect-${PN}.jar for blackduck-upload.bbclass."
HOMEPAGE = "https://sig-repo.synopsys.com/bds-integrations-release/com/synopsys/integration/synopsys-detect/"
SECTION = "devel"

LICENSE = "Synopsys End User Software License & Maintenance Agreement"
LIC_FILES_CHKSUM = "file://LICENSE;md5=700445109629d278c8224c1fd727a991"

inherit native

SRCREV = "2e2ff0f3c6d8be53ef80aa8df2e60abfa0866906"

S = "${WORKDIR}"

SRC_URI = "https://sig-repo.synopsys.com/bds-integrations-release/com/synopsys/integration/synopsys-detect/${PV}/synopsys-detect-${PV}.jar \
           file://LICENSE \
          "

SRC_URI[md5sum] = "44a4c3a4a07491ada8c2bfe76e266340"
SRC_URI[sha256sum] = "3a426bc1a0b5902e7a744c406257c80ff689e03575df42cdcaa4a58f6316c84d"

do_install(){
        install -d ${D}${datadir}/
        install -m 0755 ${DL_DIR}/synopsys-detect-${PV}.jar ${D}${datadir}/
}

