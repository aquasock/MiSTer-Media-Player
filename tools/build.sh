#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
QUARTUS_BIN=${QUARTUS_BIN:-/home/vash/intelFPGA_lite/17.0/quartus/bin}
cd "$ROOT"
case "${1:-compile}" in
  compile) "$QUARTUS_BIN/quartus_sh" --flow compile MediaPlayer ;;
  timing) "$QUARTUS_BIN/quartus_sta" -t tools/phase1p_timing.tcl ;;
  *) echo 'usage: tools/build.sh [compile|timing]' >&2; exit 2 ;;
esac
