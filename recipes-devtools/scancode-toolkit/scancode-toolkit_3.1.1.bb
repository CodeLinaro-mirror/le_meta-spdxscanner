SUMMARY = "ScanCode toolkit"
DESCRIPTION = "A typical software project often reuses hundreds of third-party \
packages. License and origin information is not always easy to find and not \
normalized: ScanCode discovers and normalizes this data for you."
HOMEPAGE = "https://github.com/nexB/scancode-toolkit"
SECTION = "devel"

LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://NOTICE;md5=da825e8d0e20b6f71daab410ce16ba77"


inherit setuptools3
DEPENDS += " \
    zlib \
    libxml2 \
    libxslt \
    bzip2 \
    python3-lxml \
    python3-click \
    python3-commoncode \
    python3-extractcode \
    python3-xmltodict \
    python3-urlpy \
    python3-charset-normalizer \
    python3-text-unidecode \
    python3-spdx-tools \
    python3-saneyaml \ 
    python3-pymaven-patch \
    python3-pygments \
    python3-pygmars \
    python3-pyahocorasick \
    python3-pluggy \
    python3-pkginfo \
    python3-pefile \
    python3-parameter-expansion-patched \
    python3-packageurl-python \
    python3-markupsafe \
    python3-license-expression \
    python3-jsonstreams \
    python3-jinja2 \
    python3-javaproperties \
    python3-jaraco-functools \
    python3-intbitset \
    python3-html5lib \
    python3-gemfileparser \
    python3-ftfy-native \
    python3-fingerprints \
    python3-fasteners \
    python3-dparse \
    python3-debian-inspector \
    python3-colorama \
    python3-bitarray \
    python3-beautifulsoup4 \
    python3-distro \
    python3-platformdirs \ 
"

SRC_URI = "git://github.com/nexB/scancode-toolkit.git;protocol=https;branch=develop"
SRCREV = "152abdaa73d1b8203a6f3cc6057d6c31c7c49e2b"
S = "${WORKDIR}/git"
B = "${S}"
BBCLASSEXTEND = "native"
