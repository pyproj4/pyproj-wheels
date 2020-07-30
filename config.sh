# Define custom utilities
# Test for macOS with [ -n "$IS_OSX" ]
PROJ_VERSION=7.1.0
SQLITE_VERSION=3320300
LIBTIFF_VERSION=4.1.0
CURL_VERSION=7.71.1

export PROJ_WHEEL=true


function build_curl {
    build_simple curl $CURL_VERSION https://curl.haxx.se/download
}

function build_libtiff {
    build_simple tiff $LIBTIFF_VERSION https://download.osgeo.org/libtiff
}

function build_sqlite {
    if [ -e sqlite-stamp ]; then return; fi
    if [ -n "$IS_OSX" ]; then
        brew install sqlite3
        sqlite3 --version
    else
        build_simple sqlite-autoconf $SQLITE_VERSION https://www.sqlite.org/2020
    fi
    touch sqlite-stamp
}

function build_proj {
    if [ -e proj-stamp ]; then return; fi
    # fetch_unpack https://download.osgeo.org/proj/proj-${PROJ_VERSION}.tar.gz
    (cd proj-${PROJ_VERSION:0:5} \
        && ./configure --prefix=$PROJ_DIR --with-curl=${BUILD_PREFIX}/bin/curl-config \
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
    # unpack early because SSL support not added with custom curl
    fetch_unpack https://download.osgeo.org/proj/proj-${PROJ_VERSION}.tar.gz
    suppress build_curl
    export PROJ_DIR=$PWD/pyproj/pyproj/proj_dir
    build_proj
    if [ -z "$IS_OSX" ]; then
        # install updated auditwheel
        /opt/python/cp36-cp36m/bin/pip install auditwheel==3.1.0
    fi
}

function run_tests {
    pyproj -v
    pyproj sync --file us_noaa_alaska.tif --verbose
    pyproj sync --file us_noaa_emhpgn.tif --verbose
    pyproj sync --file us_noaa_conus.tif --verbose
    python -m pip install shapely || echo "Shapely install failed"
    # Runs tests on installed distribution from an empty directory
    python --version
    python -c "import pyproj; pyproj.Proj(init='epsg:4269')"
    # run all tests
    cp -r ../pyproj/test .
    python -m pytest -v -s
}

