#!/usr/bin/env bash
#
# MiSTer-Media-Player build/test driver.
#
# Holds the build, upload, timing and result-push steps that previously lived
# only as untracked [guitool] entries in .git/config. Those are per-clone local
# settings, so they did not survive the fresh clone that core.md requires for
# every release. The logic lives here; the git-gui menu entries should be thin
# wrappers that call this script.
#
# Usage:  tools/build.sh <command>
#
#   pull          git pull, then report the resulting HEAD
#   compile       full Quartus compile of the MediaPlayer revision
#   upload        send output_files/MediaPlayer.rbf to the MiSTer over FTP
#   timing        run the Phase-1P timing script
#   push-results  force-add the build/timing reports, commit, push
#   all           pull -> compile -> upload -> timing -> push-results
#   all-clean     wipe db/incremental_db/output_files, then compile -> upload -> timing
#
# Overridable environment:
#   QUARTUS_BIN   Quartus bin directory (default: the local 17.0.2 Lite install)
#   MISTER_HOST   MiSTer address       (default: 10.10.0.30)
#   MISTER_USER   FTP user             (default: root)
#   MISTER_PASS   FTP password         (default: 1, the MiSTer stock password)
#   MISTER_PATH   destination path     (default: /media/fat/MediaPlayer.rbf)
#   BUILD_BEEP    set to 0 to silence the completion tone
#
set -euo pipefail

QUARTUS_BIN="${QUARTUS_BIN:-/home/vash/intelFPGA_lite/17.0_T/quartus/bin}"
MISTER_HOST="${MISTER_HOST:-10.10.0.30}"
MISTER_USER="${MISTER_USER:-root}"
MISTER_PASS="${MISTER_PASS:-1}"
MISTER_PATH="${MISTER_PATH:-/media/fat/MediaPlayer.rbf}"
BUILD_BEEP="${BUILD_BEEP:-1}"

REVISION="MediaPlayer"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

# Reports pushed for agent review. They are gitignored, so -f is required.
REPORTS=(
    output_files/MediaPlayer.flow.rpt
    output_files/MediaPlayer.fit.rpt
    output_files/MediaPlayer.fit.summary
    output_files/MediaPlayer.sta.rpt
    phase1p_timing_reports/phase1p_setup_summary.rpt
    phase1p_timing_reports/phase1p_recovery_summary.rpt
    phase1p_timing_reports/phase1p_check_timing.rpt
    phase1p_timing_reports/phase1p_decoder_same_clock_setup.rpt
    phase1p_timing_reports/phase1p_decoder_recovery.rpt
    phase1p_timing_reports/phase1p_video_same_clock_setup.rpt
)

die() { printf 'build.sh: %s\n' "$*" >&2; exit 1; }

quartus() {
    local tool="$1"; shift
    if [ -x "$QUARTUS_BIN/$tool" ]; then
        "$QUARTUS_BIN/$tool" "$@"
    elif command -v "$tool" >/dev/null 2>&1; then
        "$tool" "$@"
    else
        die "$tool not found in QUARTUS_BIN ($QUARTUS_BIN) or on PATH"
    fi
}

# Audible completion tone. Never fails the build if sox is absent.
beep() {
    [ "$BUILD_BEEP" = "1" ] || return 0
    command -v play >/dev/null 2>&1 || return 0
    play -q -n synth 0.15 sine 1000 >/dev/null 2>&1 || true
}

cmd_pull() {
    git pull
    git rev-parse HEAD
}

cmd_compile() {
    quartus quartus_sh --flow compile "$REVISION"
    beep
}

cmd_upload() {
    [ -f output_files/MediaPlayer.rbf ] || die "output_files/MediaPlayer.rbf not found; compile first"
    curl -T output_files/MediaPlayer.rbf \
         -u "$MISTER_USER:$MISTER_PASS" \
         "ftp://$MISTER_HOST/$MISTER_PATH"
}

cmd_timing() {
    quartus quartus_sta -t tools/phase1p_timing.tcl
    beep
}

cmd_push_results() {
    local missing=()
    for f in "${REPORTS[@]}"; do
        [ -f "$f" ] || missing+=("$f")
    done
    [ ${#missing[@]} -eq 0 ] || die "missing report(s): ${missing[*]}"

    git add -f "${REPORTS[@]}"
    # The message must be one argument. The original guitool entry left the
    # command substitution unquoted, which split it into a pathspec and would
    # not commit as intended.
    git commit -m "$(git rev-parse --short HEAD) build update"
    git push
}

cmd_all() {
    cmd_pull
    cmd_compile
    cmd_upload
    cmd_timing
    cmd_push_results
    beep
}

cmd_all_clean() {
    rm -rf db incremental_db
    rm -f output_files/MediaPlayer.*
    cmd_compile
    cmd_upload
    cmd_timing
    beep
}

case "${1:-}" in
    pull)         cmd_pull ;;
    compile)      cmd_compile ;;
    upload)       cmd_upload ;;
    timing)       cmd_timing ;;
    push-results) cmd_push_results ;;
    all)          cmd_all ;;
    all-clean)    cmd_all_clean ;;
    *)
        sed -n '11,19p' "$0" | sed 's/^# \{0,1\}//' >&2
        exit 1
        ;;
esac
