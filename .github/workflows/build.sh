
if [[ "$TRAVIS_OS_NAME" == "osx" ]]; then
  # webp, zstd, xz, libtiff cause a conflict with building webp and libtiff
  # curl from brew requires zstd, use system curl
  # if php is installed, brew tries to reinstall these after installing openblas
  brew remove --ignore-dependencies webp zstd xz libtiff curl php
fi

if [[ "$MB_PYTHON_VERSION" == pypy3* ]]; then
  MB_PYTHON_OSX_VER="10.9"
  if [[ "$PLAT" == "i686" ]]; then
    DOCKER_TEST_IMAGE="multibuild/xenial_$PLAT"
  else
    DOCKER_TEST_IMAGE="multibuild/focal_$PLAT"
  fi
fi


echo "::group::Install a virtualenv"
  source multibuild/common_utils.sh
  source multibuild/travis_steps.sh
  python3 -m pip install virtualenv
  before_install
echo "::endgroup::"

echo "::group::Build wheel"
  # https://github.com/multi-build/multibuild/pull/452
  function install_pypy {
      # Installs pypy.org PyPy
      # Parameter $version
      # Version given in major or major.minor or major.minor.micro e.g
      # "3" or "3.7" or "3.7.1".
      # Uses $PLAT
      # sets $PYTHON_EXE variable to python executable

      local version=$1
      case "$PLAT" in
      "x86_64")  if [ -n "$IS_MACOS" ]; then
                    suffix="osx64";
                else
                    suffix="linux64";
                fi;;
      "i686")    suffix="linux32";;
      "ppc64le") suffix="ppc64le";;
      "s390x")    suffix="s390x";;
      "aarch64")  suffix="aarch64";;
      *) echo unknown platform "$PLAT"; exit 1;;
      esac

      # Need to convert pypy-7.2 to pypy2.7-v7.2.0 and pypy3.6-7.3 to pypy3.6-v7.3.0
      local prefix=$(get_pypy_build_prefix $version)
      # since prefix is pypy3.6v7.2 or pypy2.7v7.2, grab the 4th (0-index) letter
      local major=${prefix:4:1}
      # get the pypy version 7.2.0
      if [[ $version =~ pypy([0-9]+)\.([0-9]+)-([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
          local py_version=${BASH_REMATCH[3]}.${BASH_REMATCH[4]}.${BASH_REMATCH[5]}
      else
          local py_version=$(fill_pypy_ver $(echo $version | cut -f2 -d-))
      fi

      local py_build=$prefix$py_version-$suffix
      local py_zip=$py_build.tar.bz2
      local zip_path=$DOWNLOADS_SDIR/$py_zip
      mkdir -p $DOWNLOADS_SDIR
      wget -nv $PYPY_URL/${py_zip} -P $DOWNLOADS_SDIR
      untar $zip_path
      # bug/feature: pypy package for pypy3 only has bin/pypy3 :(
      if [ "$major" == "3" ] && [ ! -x "$py_build/bin/pypy" ]; then
          ln $py_build/bin/pypy3 $py_build/bin/pypy
      fi
      PYTHON_EXE=$(realpath $py_build/bin/pypy)
      $PYTHON_EXE -mensurepip
      $PYTHON_EXE -mpip install --upgrade pip setuptools wheel
      if [ "$major" == "3" ] && [ ! -x "$py_build/bin/pip" ]; then
          ln $py_build/bin/pip3 $py_build/bin/pip
      fi
      PIP_CMD=pip
  }

  # https://github.com/multi-build/multibuild/pull/451
  function clean_code {
      local repo_dir=${1:-$REPO_DIR}
      local build_commit=${2:-$BUILD_COMMIT}
      [ -z "$repo_dir" ] && echo "repo_dir not defined" && exit 1
      [ -z "$build_commit" ] && echo "build_commit not defined" && exit 1
      # The package $repo_dir may be a submodule. git submodules do not
      # have a .git directory. If $repo_dir is copied around, tools like
      # Versioneer which require that it be a git repository are unable
      # to determine the version.  Give submodule proper git directory
      fill_submodule "$repo_dir"
      (cd $repo_dir \
          && git fetch origin --tags\
          && git checkout $build_commit \
          && git clean -fxd \
          && git reset --hard \
          && git submodule update --init --recursive)
  }
  clean_code $REPO_DIR $BUILD_COMMIT
  build_wheel $REPO_DIR $PLAT
  ls -l "${GITHUB_WORKSPACE}/${WHEEL_SDIR}/"
echo "::endgroup::"

if [[ $MACOSX_DEPLOYMENT_TARGET != "11.0" ]]; then
  echo "::group::Test wheel"
    install_run $PLAT
  echo "::endgroup::"
fi
