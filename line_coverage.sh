#!/bin/bash
set -e -o pipefail
julia --compiled-modules=strict --project=deps/coverage_env --color=no deps/line_coverage.jl 2>&1 \
| grep -v '\(Info: .*\(Detecting\|Searching\|processing\)\)\|Assuming file has no coverage' \
| sed 's/.*process_cov: //'
