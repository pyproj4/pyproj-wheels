# Define custom utilities
# Test for macOS with [ -n "$IS_OSX" ]
PROJ_VERSION=7.0.0
DATUMGRID_VERSION=1.8
SQLITE_VERSION=3310100
LIBTIFF_VERSION=4.1.0
CURL_VERSION=7.69.1

export PROJ_WHEEL=true

function build_curl {
    if [ -e curl-stamp ]; then return; fi
    fetch_unpack https://curl.haxx.se/download/curl-${CURL_VERSION}.tar.gz
    (cd curl-${CURL_VERSION} \
        && ./configure --prefix=$BUILD_PREFIX \
        && make -j4 \
        && make install)
    touch curl-stamp
}

function build_libtiff {
    if [ -e libtiff-stamp ]; then return; fi
    fetch_unpack https://download.osgeo.org/libtiff/tiff-${LIBTIFF_VERSION}.tar.gz
    (cd tiff-${LIBTIFF_VERSION} \
        && ./configure --prefix=$BUILD_PREFIX \
        && make -j4 \
        && make install)
    touch libtiff-stamp
}

function build_sqlite {
    if [ -e sqlite-stamp ]; then return; fi
    fetch_unpack https://www.sqlite.org/2020/sqlite-autoconf-${SQLITE_VERSION}.tar.gz
    (cd sqlite-autoconf-${SQLITE_VERSION} \
        && ./configure --prefix=$BUILD_PREFIX \
        && make -j4 \
        && make install)
    touch sqlite-stamp
}

function build_proj {
    if [ -e proj-stamp ]; then return; fi
    fetch_unpack http://download.osgeo.org/proj/proj-${PROJ_VERSION}.tar.gz
    (cd proj-${PROJ_VERSION:0:5}/data \
        && curl http://download.osgeo.org/proj/proj-datumgrid-${DATUMGRID_VERSION}.zip > proj-datumgrid.zip \
        && unzip -o proj-datumgrid.zip \
        && rm proj-datumgrid.zip \
        && cd .. \
        && ./configure --prefix=$PROJ_DIR \
        && make -j4 \
        && make install)
    touch proj-stamp
}

function pre_build {
    # Any stuff that you need to do before you start building the wheels
    # Runs in the root directory of this repository.
    suppress build_zlib
    suppress build_sqlite
    suppress build_libtiff
    suppress build_curl
    export PROJ_DIR=$PWD/pyproj/pyproj/proj_dir
    build_proj
    if [ -z "$IS_OSX" ]; then
        # install updated auditwheel
        /opt/python/cp36-cp36m/bin/pip install auditwheel==3.1.0
    fi
}

function run_tests {
    pip install shapely || echo "Shapely install failed"
    # Runs tests on installed distribution from an empty directory
    python --version
    python -c "import pyproj; pyproj.Proj(init='epsg:4269')"
    # run all tests
    cd ../pyproj
    pytest -v -s
}
