SUMMARY = "plugincode is a library that provides plugin functionality for ScanCode toolkit"
HOMEPAGE = "https://github.com/nexB/plugincode"

LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://apache-2.0.LICENSE;md5=86d3f3a95c324c9479bd8986968f4327"

DEPENDS += "\
            python3-setuptools-scm-native \
            python3-toml-native \
            python3-wheel-native \
           "

PYPI_PACKAGE = "plugincode"

SRC_URI[sha256sum] = "97b5a2c96f0365c80240be103ecd86411c68b11a16f137913cbea9129c54907a"

inherit pypi
inherit setuptools3

BBCLASSEXTEND = "native"
