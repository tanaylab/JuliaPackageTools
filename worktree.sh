#!/bin/bash
set -e -o pipefail
# Create a worktree of the package beside it, named after the package and the tag given as the first argument (e.g.
# `DataAxesFormats.jl.gate`). The optional second argument is the commit to check out (by default `HEAD`). The worktree
# uses the live trees of its sibling packages through `[sources]`, and gets a copy of the manifest of the workspace
# which holds the package.
julia --color=no deps/worktree.jl "$@"
