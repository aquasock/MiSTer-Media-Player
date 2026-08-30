#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
BUILD_HOST=${BUILD_HOST:-mister-build}
REMOTE_ROOT=${REMOTE_ROOT:-/tmp/MiSTer-Media-Player-build}
QUARTUS_BIN=${QUARTUS_BIN:-/home/vash/intelFPGA_lite/17.0_T/quartus/bin}
PROJECT=MediaPlayer

usage() {
    cat >&2 <<'EOF'
usage:
  tools/build.sh                 build on mister-build, check timing, fetch RBF
  tools/build.sh install         build, check timing, fetch and install RBF
  tools/build.sh timing          rerun timing checks on the last remote build
  tools/build.sh host [TARGET]   build Pi software: native, arm, main or all

Environment overrides: BUILD_HOST, REMOTE_ROOT, QUARTUS_BIN and BUILD_ID.

BUILD_ID is six digits. By default it uses the current Git commit date, making
repeated builds of the same commit reproducible instead of changing every day.
EOF
    exit 2
}

require() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'build.sh: required command not found: %s\n' "$1" >&2
        exit 1
    }
}

build_id() {
    local value=${BUILD_ID:-}

    if [[ -z $value ]]; then
        value=$(git -C "$ROOT" log -1 --format=%cd --date=format:%y%m%d)
    fi

    [[ $value =~ ^[0-9]{6}$ ]] || {
        printf 'build.sh: BUILD_ID must contain exactly six digits\n' >&2
        exit 1
    }

    printf '%s' "$value"
}

check_remote_root() {
    [[ $REMOTE_ROOT =~ ^/tmp/[A-Za-z0-9._/-]+$ && $REMOTE_ROOT != /tmp/ ]] || {
        printf 'build.sh: REMOTE_ROOT must be a simple directory below /tmp\n' >&2
        exit 1
    }
}

sync_source() {
    require ssh
    require rsync
    check_remote_root

    printf 'Syncing source to %s:%s\n' "$BUILD_HOST" "$REMOTE_ROOT"
    ssh "$BUILD_HOST" "mkdir -p -- '$REMOTE_ROOT'"
    rsync -az --delete \
        --exclude .git/ \
        --exclude .agents/ \
        --exclude .codex/ \
        --exclude db/ \
        --exclude incremental_db/ \
        --exclude output_files/ \
        --exclude phase1p_timing_reports/ \
        "$ROOT/" "$BUILD_HOST:$REMOTE_ROOT/"
}

run_remote() {
    local action=$1
    local id=$2

    ssh -tt "$BUILD_HOST" \
        "cd '$REMOTE_ROOT' && BUILD_ID='$id' QUARTUS_BIN='$QUARTUS_BIN' tools/build.sh '$action'"
}

fetch_rbf() {
    local remote_rbf="$BUILD_HOST:$REMOTE_ROOT/output_files/$PROJECT.rbf"
    local local_rbf="$ROOT/output_files/$PROJECT.rbf"
    local remote_hash local_hash

    mkdir -p "$ROOT/output_files"
    rsync -a "$remote_rbf" "$local_rbf"

    remote_hash=$(ssh "$BUILD_HOST" "sha256sum '$REMOTE_ROOT/output_files/$PROJECT.rbf'" | awk '{print $1}')
    local_hash=$(sha256sum "$local_rbf" | awk '{print $1}')
    [[ $remote_hash == "$local_hash" ]] || {
        printf 'build.sh: downloaded RBF hash does not match the build host\n' >&2
        exit 1
    }

    printf 'RBF: %s\nSHA-256: %s\n' "$local_rbf" "$local_hash"
}

timing_gate() {
    local report="output_files/$PROJECT.sta.rpt"

    [[ -f $report ]] || {
        printf 'build.sh: missing timing report: %s\n' "$report" >&2
        exit 1
    }

    awk '
        /Worst-case .* slack is/ {
            value = $NF + 0
            label = $0
            sub(/^.*Worst-case /, "", label)
            printf "  %s\n", label
            seen++
            if (value < 0) failed = 1
        }
        END {
            if (seen < 5) {
                print "build.sh: timing report is incomplete" > "/dev/stderr"
                exit 2
            }
            if (failed) {
                print "build.sh: timing failed; RBF will not be installed" > "/dev/stderr"
                exit 1
            }
        }
    ' "$report"
}

quartus() {
    local command=$1
    shift

    [[ -x "$QUARTUS_BIN/$command" ]] || {
        printf 'build.sh: %s was not found in %s\n' "$command" "$QUARTUS_BIN" >&2
        exit 1
    }

    "$QUARTUS_BIN/$command" "$@"
}

remote_timing() {
    quartus quartus_sta "$PROJECT" -c "$PROJECT"
    quartus quartus_sta -t tools/phase1p_timing.tcl
    printf 'Timing margins:\n'
    timing_gate
}

remote_build() {
    [[ ${BUILD_ID:-} =~ ^[0-9]{6}$ ]] || {
        printf 'build.sh: internal build requires a six-digit BUILD_ID\n' >&2
        exit 1
    }

    rm -rf -- db incremental_db output_files phase1p_timing_reports
    printf '`define BUILD_DATE "%s"' "$BUILD_ID" > build_id.v

    quartus quartus_map --read_settings_files=on --write_settings_files=off "$PROJECT" -c "$PROJECT"
    quartus quartus_fit --read_settings_files=off --write_settings_files=off "$PROJECT" -c "$PROJECT"
    quartus quartus_asm --read_settings_files=off --write_settings_files=off "$PROJECT" -c "$PROJECT"
    remote_timing
}

build() {
    local id
    id=$(build_id)
    sync_source
    printf 'Building %s with build ID %s\n' "$PROJECT" "$id"
    run_remote _remote-build "$id"
    fetch_rbf
}

rerun_timing() {
    local id
    id=$(build_id)
    require ssh
    check_remote_root
    run_remote _remote-timing "$id"
}

build_host_software() {
    local target=${1:-all}
    case $target in
        native|arm|main|all) exec "$ROOT/host/build_arm_stack.sh" "--$target" ;;
        *) usage ;;
    esac
}

case ${1:-build} in
    build)
        [[ $# -eq 0 || $# -eq 1 ]] || usage
        build
        ;;
    install)
        [[ $# -eq 1 ]] || usage
        build
        "$ROOT/tools/mister.sh" install "$ROOT/output_files/$PROJECT.rbf"
        ;;
    timing)
        [[ $# -eq 1 ]] || usage
        rerun_timing
        ;;
    host)
        [[ $# -le 2 ]] || usage
        build_host_software "${2:-all}"
        ;;
    _remote-build)
        remote_build
        ;;
    _remote-timing)
        remote_timing
        ;;
    *) usage ;;
esac
