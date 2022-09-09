# Define custom utilities
# Test for macOS with [ -n "$IS_OSX" ]
SQLITE_VERSION=3350500
LIBTIFF_VERSION=4.3.0
CURL_VERSION=7.76.1
NGHTTP2_VERSION=1.43.0

export PROJ_WHEEL=true
export PROJ_VERSION=9.1.0


function install_curl_certs {
    if [ -n "$IS_OSX" ]; then
        ${PYTHON_EXE} -m pip install certifi
        openssl x509 -outform PEM \
            -in $(${PYTHON_EXE} -c "import certifi; print(certifi.where())") \
            -out certifi.pem
        export CURL_CA_BUNDLE=$PWD/certifi.pem
    fi
}

function remove_curl_certs {
    if [ -n "$IS_OSX" ]; then
        unset CURL_CA_BUNDLE
    fi
}

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
    suppress build_nghttp2
    local flags="--prefix=$BUILD_PREFIX --with-nghttp2=$BUILD_PREFIX --with-zlib=$BUILD_PREFIX"
    if [ -n "$IS_OSX" ]; then
        flags="$flags --with-darwinssl"
    else  # manylinux
        suppress build_openssl
        flags="$flags --with-ssl"
        LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$BUILD_PREFIX/lib
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
    if [ -z "$IS_OSX" ]; then
        CFLAGS="$CFLAGS -DHAVE_PREAD64 -DHAVE_PWRITE64"
    fi
    if [ -e sqlite-stamp ]; then return; fi
    # if [ -n "$IS_OSX" ]; then
    #     brew install sqlite3
    #     sqlite3 --version
    # else
    build_simple sqlite-autoconf $SQLITE_VERSION https://www.sqlite.org/2021
    # fi
    touch sqlite-stamp
}

function build_proj {
    if [ -e proj-stamp ]; then return; fi
    get_modern_cmake
    fetch_unpack https://download.osgeo.org/proj/proj-${PROJ_VERSION}.tar.gz
    suppress build_curl_ssl
    (cd proj-${PROJ_VERSION:0:5} \
        && cmake . \
        -DCMAKE_INSTALL_PREFIX=$PROJ_DIR \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_IPO=ON \
        -DBUILD_APPS:BOOL=OFF \
        -DBUILD_TESTING:BOOL=OFF \
        -DCMAKE_PREFIX_PATH=$BUILD_PREFIX \
        -DCMAKE_INSTALL_LIBDIR=lib \
        && cmake --build . -j$(nproc) \
        && cmake --install .)
    touch proj-stamp
}

function pre_build {
    # Any stuff that you need to do before you start building the wheels
    # Runs in the root directory of this repository.
    install_curl_certs
    suppress build_zlib
    suppress build_sqlite
    suppress build_libtiff
    export PROJ_DIR=$PWD/pyproj/pyproj/proj_dir
    build_proj
    remove_curl_certs
    if [ -n "$IS_OSX" ]; then
        export LDFLAGS="${LDFLAGS} -Wl,-rpath,${PROJ_DIR}/lib"
    fi
}

function run_tests {
    pyproj -v
    python -m pip install shapely~=1.7.1 || echo "Shapely install failed"
    # Runs tests on installed distribution from an empty directory
    python --version
    python -c "import pyproj; pyproj.Proj(init='epsg:4269')"
    # run all tests
    cp -r ../pyproj/test .
    PROJ_NETWORK=ON python -m pytest -v -s
}

