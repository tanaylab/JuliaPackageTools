#!/bin/bash
set -e -o pipefail
# Resolve and instantiate the workspace, then precompile each of the package's projects: the package, its tests and its
# tools. The tests run with `--check-bounds=yes`, which needs its own compiled files, so the package and its tests are
# compiled both ways. A precompile of the whole workspace isn't enough: it skips the projects nested in the package's
# workspace (`Base.Precompilation` collects the members of the root workspace only).
julia --project=. -e '
using Pkg
using TOML
Pkg.resolve()
Pkg.instantiate()
plain = `` => Base.CacheFlags()
tests = `--check-bounds=yes` => Base.CacheFlags(; check_bounds = 1)
for project in vcat(["."], TOML.parsefile("Project.toml")["workspace"]["projects"])
    Pkg.activate(project)
    Pkg.precompile(; configs = project in (".", "test") ? [plain, tests] : [plain])
end
'
