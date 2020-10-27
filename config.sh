# Define custom utilities
# Test for macOS with [ -n "$IS_OSX" ]
PROJ_VERSION=7.2.0RC1
SQLITE_VERSION=3320300
LIBTIFF_VERSION=4.1.0
CURL_VERSION=7.71.1
NGHTTP2_VERSION=1.35.1

export PROJ_WHEEL=true

function build_nghttp2 {
    if [ -e nghttp2-stamp ]; then return; fi
    fetch_unpack https://github.com/nghttp2/nghttp2/releases/download/v${NGHTTP2_VERSION}/nghttp2-${NGHTTP2_VERSION}.tar.gz
    (cd nghttp2-${NGHTTP2_VERSION}  \
        && ./configure --enable-lib-only --prefix=$BUILD_PREFIX \
        && make -j4 \
        && make install)
    touch nghttp2-stamp
}

function build_curl_ssl {
    if [ -e curl-stamp ]; then return; fi
    CFLAGS="$CFLAGS -g -O2"
    CXXFLAGS="$CXXFLAGS -g -O2"
    local flags="--prefix=$BUILD_PREFIX --with-nghttp2=$BUILD_PREFIX --with-zlib=$BUILD_PREFIX"
    suppress build_nghttp2
    if [ -n "$IS_OSX" ]; then
        flags="$flags --with-darwinssl"
    else  # manylinux
        suppress build_openssl
        flags="$flags --with-ssl"
    fi
    fetch_unpack https://curl.haxx.se/download/curl-${CURL_VERSION}.tar.gz
    (cd curl-${CURL_VERSION} \
        && if [ -z "$IS_OSX" ]; then \
        LIBS=-ldl ./configure $flags; else \
        ./configure $flags; fi\
        && make -j4 \
        && make install)
    touch curl-stamp
}


function build_libtiff {
    build_simple tiff $LIBTIFF_VERSION https://download.osgeo.org/libtiff
}

function build_sqlite {
    if [ -e sqlite-stamp ]; then return; fi
    # if [ -n "$IS_OSX" ]; then
    #     brew install sqlite3
    #     sqlite3 --version
    # else
    build_simple sqlite-autoconf $SQLITE_VERSION https://www.sqlite.org/2020
    # fi
    touch sqlite-stamp
}

function build_proj {
    if [ -e proj-stamp ]; then return; fi
    fetch_unpack https://download.osgeo.org/proj/proj-${PROJ_VERSION}.tar.gz
    (cd proj-${PROJ_VERSION:0:5}\
        && ./configure --prefix=$PROJ_DIR --with-curl=$BUILD_PREFIX/bin/curl-config \
        && make -j4 \
        && make install)
    touch proj-stamp
}

function pre_build {
    # Any stuff that you need to do before you start building the wheels
    # Runs in the root directory of this repository.
    suppress build_zlib
    suppress build_curl_ssl
    suppress build_sqlite
    suppress build_libtiff
    export PROJ_DIR=$PWD/pyproj/pyproj/proj_dir
    build_proj
    if [ -z "$IS_OSX" ]; then
        # install updated auditwheel
        /opt/python/cp36-cp36m/bin/pip install auditwheel==3.1.0
    fi
}

function run_tests {
    pyproj -v
    python -m pip install shapely || echo "Shapely install failed"
    # Runs tests on installed distribution from an empty directory
    python --version
    python -c "import pyproj; pyproj.Proj(init='epsg:4269')"
    # run all tests
    cp -r ../pyproj/test .
    PROJ_NETWORK=ON python -m pytest -v -s
}

