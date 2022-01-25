SUMMARY = "a fast and memory efficient library for multi-pattern string search"
HOMEPAGE = "http://github.com/WojciechMula/pyahocorasick"

LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://LICENSE;md5=629d983ff344da7b36a88f589f47ccc5"

PYPI_PACKAGE = "pyahocorasick"

SRC_URI[sha256sum] = "88f79307c74ae6a84f8d88c2522a082f1d21c425762aba7f7e4d14dd431d2fb7"

inherit pypi
inherit setuptools3

BBCLASSEXTEND = "native"
