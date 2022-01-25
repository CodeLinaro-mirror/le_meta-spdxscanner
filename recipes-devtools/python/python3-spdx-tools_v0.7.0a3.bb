SUMMARY = "SPDX parser and tools"
HOMEPAGE = "https://github.com/spdx/tools-python"

LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://LICENSE;md5=dc7f21ccff0f672f2a7cd6f412ae627d"

DEPENDS += "\
             python3-click \
             python3-ply \
             python3-pyyaml \
             python3-rdflib \
             python3-six \
             python3-xmltodict \
            "

SRC_URI = "git://github.com/spdx/tools-python.git;protocol=https;branch=main"
SRCREV = "fd6aeba22ec0ad7650571d99db19d2a113ed0782"

S = "${WORKDIR}/git"

SRC_URI[sha256sum] = "9a1aaae051771e865705dd2fd374c3f73d0ad595c1056548466997551cbd7a81"

inherit setuptools3

BBCLASSEXTEND = "native"
