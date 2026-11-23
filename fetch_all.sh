#!/bin/bash
set -e -o pipefail
# Fetch the committed tools of this repository into every package in the given directory which uses them (see
# `tools_users.sh`), using `fetch_tools.sh`. Then move the manifest of each package to the pinned versions of the tools.
# Run from the root of this repository: `./fetch_all.sh ~/data/src`.
TOOLS=`pwd`
PACKAGES=`./tools_users.sh $1`
for PACKAGE in $PACKAGES
do
    echo "Fetching into: $PACKAGE"
    (cd $PACKAGE && $TOOLS/fetch_tools.sh $TOOLS)
done

# Packages in one workspace share its manifest, so it is updated once, from the tool environments of one of them. A
# targeted update only moves the dependencies of the environment it runs in.
julia -e '
using Pkg
using TOML
updated_manifest_paths = Set{String}()
for package_path in ARGS
    manifest_path = Base.project_file_manifest_path(joinpath(package_path, "Project.toml"))
    if manifest_path !== nothing
        if manifest_path in updated_manifest_paths
            continue
        end
        push!(updated_manifest_paths, manifest_path)
    end
    for environment_name in readdir(joinpath(package_path, "deps"))
        environment_path = joinpath(package_path, "deps", environment_name)
        if endswith(environment_name, "_env") && isdir(environment_path)
            println("Updating the tools of: $(environment_path)")
            Pkg.activate(environment_path)
            compat = get(TOML.parsefile(joinpath(environment_path, "Project.toml")), "compat", Dict())
            Pkg.update(collect(keys(compat)); preserve = Pkg.PRESERVE_NONE)
        end
    end
end
' $PACKAGES
