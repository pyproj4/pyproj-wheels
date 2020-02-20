# Define custom utilities
# Test for macOS with [ -n "$IS_OSX" ]
PROJ_VERSION=6.3.1
DATUMGRID_VERSION=1.8
SQLITE_VERSION=3240000

export PROJ_WHEEL=true

function build_sqlite {
    if [ -e sqlite-stamp ]; then return; fi
    fetch_unpack https://www.sqlite.org/2018/sqlite-autoconf-${SQLITE_VERSION}.tar.gz
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
    export PROJ_DIR=$PWD/pyproj/pyproj/proj_dir
    build_proj
    if [ -z "$IS_OSX" ]; then
        # install updated auditwheel
        /opt/python/cp36-cp36m/bin/pip install git+https://github.com/pypa/auditwheel.git@6fdab9f 
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
