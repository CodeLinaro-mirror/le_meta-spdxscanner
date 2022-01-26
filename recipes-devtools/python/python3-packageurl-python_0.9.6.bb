SUMMARY = "purl aka. Package URL parser and builder"
HOMEPAGE = "https://github.com/package-url/packageurl-python"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://mit.LICENSE;md5=ec425c78d8beabdb209b01c5fbcd38e0"

DEPENDS += "python3-wheel-native"

PYPI_PACKAGE = "packageurl-python"

SRC_URI[sha256sum] = "c01fbaf62ad2eb791e97158d1f30349e830bee2dd3e9503a87f6c3ffae8d1cf0"

inherit pypi
inherit setuptools3

BBCLASSEXTEND = "native"
