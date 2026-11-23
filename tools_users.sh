#!/bin/bash
set -e -o pipefail
# Print the directory of each package in the given directory which uses these tools: a directory with a `Project.toml`
# and a `deps/tools_version`, in the main checkout of a repository directly in the given directory. The package is the
# repository itself, or a directory in it (e.g. `SomeGraphs.js/julia`). Worktrees (e.g. one made by `make worktree`),
# and repositories nested deeper, are skipped.
SOURCES=`realpath $1`
for VERSIONS in $SOURCES/*/deps/tools_version $SOURCES/*/*/deps/tools_version
do
    PACKAGE=`dirname \`dirname $VERSIONS\``
    if [ -f $PACKAGE/Project.toml ]
    then
        GIT_DIRECTORY=`git -C $PACKAGE rev-parse --path-format=absolute --git-dir`
        COMMON_DIRECTORY=`git -C $PACKAGE rev-parse --path-format=absolute --git-common-dir`
        TOP_DIRECTORY=`realpath \`git -C $PACKAGE rev-parse --show-toplevel\``
        if [ "$GIT_DIRECTORY" == "$COMMON_DIRECTORY" ] && [ "`dirname $TOP_DIRECTORY`" == "$SOURCES" ]
        then
            echo $PACKAGE
        fi
    fi
done
