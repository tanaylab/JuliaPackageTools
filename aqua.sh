#!/bin/bash
set -e -o pipefail
julia --compiled-modules=strict --project=deps/aqua_env deps/aqua.jl
