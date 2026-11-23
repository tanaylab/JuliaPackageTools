#!/bin/bash
set -e -o pipefail
julia --compiled-modules=strict --project=deps/lint_env deps/lint.jl
