SUMMARY = "fixes text for you"
HOMEPAGE = "http://github.com/LuminosoInsight/python-ftfy"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE.txt;md5=49e07a5dd7a24f453625e67c4f9ac59d"

DEPENDS += "python3-wcwidth-native"

PYPI_PACKAGE = "ftfy"

SRC_URI[sha256sum] = "ba71121a9c8d7790d3e833c6c1021143f3e5c4118293ec3afb5d43ed9ca8e72b"

inherit pypi
inherit setuptools3

BBCLASSEXTEND = "native"
