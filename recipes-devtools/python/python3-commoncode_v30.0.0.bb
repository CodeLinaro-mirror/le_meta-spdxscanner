SUMMARY = "python3-commoncode"
DESCRIPTION = "Commoncode provides a set of common functions and \
utilities for handling various things like paths, dates, files \
and hashes. It started as library in scancode-toolkit."
HOMEPAGE = "https://github.com/nexB/commoncode"
SECTION = "devel"

LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://apache-2.0.LICENSE;md5=86d3f3a95c324c9479bd8986968f4327"

DEPENDS += "${PYTHON_PN}-setuptools-scm-native"

inherit setuptools3

SRC_URI = "git://github.com/nexB/commoncode.git;protocol=https;branch=main"
SRCREV = "653225d58dcf5d1f75dbe572cac13f6d84ae755b"
S = "${WORKDIR}/git"
B = "${S}"

DEPENDS += " \
    python3-toml \
    python3-wheel \
    python3-pip \
"


BBCLASSEXTEND = "native"
