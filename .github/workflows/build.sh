
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
