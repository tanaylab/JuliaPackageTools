#!/bin/bash
set -e -o pipefail
# Fetch the committed tools of this repository into every package in the given directory (each `<name>.jl` with a
# `Project.toml`), using `fetch_tools.sh`. Then move the manifest which the packages share to the pinned versions of the
# tools. All the packages must be members of the workspace of the directory. Run from the root of this repository:
# `./fetch_all.sh ~/data/src`.
TOOLS=`pwd`
PACKAGES=""
for PACKAGE in $1/*.jl
do
    if [ -f $PACKAGE/Project.toml ]
    then
        echo "Fetching into: $PACKAGE"
        (cd $PACKAGE && $TOOLS/fetch_tools.sh $TOOLS)
        PACKAGES="$PACKAGES $PACKAGE"
    fi
done

# The shared manifest is the same from every package, so the tool environments of one of them are enough. A targeted
# update only moves the dependencies of the environment it runs in.
set -- $PACKAGES
for ENVIRONMENT in $1/deps/*_env
do
    echo "Updating the tools of: $ENVIRONMENT"
    julia --project=$ENVIRONMENT -e '
using Pkg
using TOML
pinned_names = collect(keys(get(TOML.parsefile(joinpath(ARGS[1], "Project.toml")), "compat", Dict{String, Any}())))
Pkg.update(pinned_names; preserve = Pkg.PRESERVE_NONE)
' $ENVIRONMENT
done
