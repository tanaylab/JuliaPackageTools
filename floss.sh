#!/bin/bash
set -e -o pipefail
julia --compiled-modules=strict --project=. deps/floss.jl
