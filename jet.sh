#!/bin/bash
set -e -o pipefail
# With more threads, a report that several callers reach is listed under one of them at random, so NOJET misses it.
# JET loads Revise, which watches the folder of each loaded package. Each watch takes an inotify instance, and a machine
# may allow only 128 of them, after which every further package logs an error. Polling takes none.
JULIA_DEBUG="" JULIA_NUM_THREADS=1 JULIA_REVISE_POLL=1 \
julia --compiled-modules=strict --project=deps/jet_env --color=no deps/jet.jl 2>&1 \
| python3 deps/jet.py
