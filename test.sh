#!/bin/bash
set -e -o pipefail
rm -rf deps/.did.test tracefile.info src/*.cov src/*/*.cov test/*.cov test/actual/*
# `make precompile` compiled everything the tests load, so neither Pkg nor the test process may compile anything.
JULIA_DEBUG="" JULIA_NUM_THREADS=4 JULIA_PKG_PRECOMPILE_AUTO=0 \
julia --compiled-modules=strict --color=no --code-coverage=tracefile.info deps/test.jl "$@" \
|| (deps/clean.sh && false)
