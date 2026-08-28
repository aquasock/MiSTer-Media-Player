#!/usr/bin/env bash
# Paired numerical proof. Neither half alone is original-DVD qualification.
# Isolated references require <=1 LSB per reconstructed sample. Real references
# require each sample's error <= measured reference error + 1 LSB, with exact
# picture/sample counts and all publication/ownership/error checks unchanged.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURES="$(realpath "${1:?usage: run_original_dvd_qualification.sh prepared-fixtures}")"
WORK="$ROOT/simulation/original_dvd_qualification"
mkdir -p "$WORK"
fingerprint() {
    (cd "$ROOT" && find rtl/mpeg2_new tools/streams -type f \
        \( -name '*.sv' -o -name '*.svh' -o -name '*.sh' -o -name '*.py' \) \
        -print0 | sort -z | xargs -0 sha256sum; sha256sum "$ROOT/files.qip")
}
fingerprint > "$WORK/source.before.sha256"
ORIGINAL_DVD_WORK="$WORK/isolated_build" \
    bash "$ROOT/tools/streams/run_original_dvd_pixels.sh" "$FIXTURES" +REFRESH_REFERENCES \
    "+PIXEL_REPORT=$WORK/isolated.csv" > "$WORK/isolated.log" 2>&1 &
isolated_pid=$!
ORIGINAL_DVD_WORK="$WORK/chain_build" \
    bash "$ROOT/tools/streams/run_original_dvd_pixels.sh" "$FIXTURES" +CHAIN_ERROR_BOUND \
    "+PIXEL_REPORT=$WORK/chain.csv" > "$WORK/chain.log" 2>&1 &
chain_pid=$!
isolated_status=0; chain_status=0
wait "$isolated_pid" || isolated_status=$?
wait "$chain_pid" || chain_status=$?
if (( isolated_status != 0 || chain_status != 0 )); then
    echo "ORIGINAL_DVD_NUMERICAL_FAIL isolated=$isolated_status chain=$chain_status" >&2
    exit 1
fi
fingerprint > "$WORK/source.after.sha256"
cmp "$WORK/source.before.sha256" "$WORK/source.after.sha256"
echo "ORIGINAL_DVD_NUMERICAL_PASS isolated_one_LSB=1 measured_chain_bound=1 unchanged_source=1"
