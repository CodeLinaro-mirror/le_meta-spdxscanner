SUMMARY = "CSS selector library for python-beautifulsoup4"
HOMEPAGE = "https://github.com/facelessuser/soupsieve"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=33c3a77def9b3ad83e01c65bdcc1af67"

SRC_URI[sha256sum] = "b8d49b1cd4f037c7082a9683dfa1801aa2597fb11c3a1155b7a5b94829b4f1f9"

inherit pypi setuptools3 ptest

BBCLASSEXTEND = "native nativesdk"
