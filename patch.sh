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
  