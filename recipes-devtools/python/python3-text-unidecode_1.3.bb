SUMMARY = "the most basic port of the Text::Unidecode Perl library"
HOMEPAGE = "https://github.com/kmike/text-unidecode/"

LICENSE = "GPL-2.0 & Artistic-1.0"
LIC_FILES_CHKSUM = "file://LICENSE;md5=ccfb8875bc60bc3d6e91e42e5e8f5587"

PYPI_PACKAGE = "text-unidecode"

SRC_URI[sha256sum] = "bad6603bb14d279193107714b288be206cac565dfa49aa5b105294dd5c4aab93"

inherit pypi
inherit setuptools3

BBCLASSEXTEND = "native"
