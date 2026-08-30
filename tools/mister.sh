#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
MISTER_HOST=${MISTER_HOST:-10.10.0.30}
MISTER_USER=${MISTER_USER:-root}
MISTER_PASS=${MISTER_PASS:-1}
CURL=(curl --silent --show-error --fail --globoff --user "$MISTER_USER:$MISTER_PASS")

usage() {
    cat >&2 <<'EOF'
usage:
  tools/mister.sh install [LOCAL_RBF] [REMOTE_RBF]
  tools/mister.sh screenshot [OUTPUT.png]
  tools/mister.sh screenshot-stream [SECONDS] [OUTPUT_DIRECTORY]
  tools/mister.sh log [OUTPUT.log]
  tools/mister.sh list [REMOTE_DIRECTORY]
  tools/mister.sh put LOCAL_FILE REMOTE_PATH
  tools/mister.sh get REMOTE_PATH LOCAL_FILE

install replaces the existing MediaPlayer RBF and verifies it. It does not make
a backup. screenshot-stream runs until Ctrl+C when SECONDS is omitted or zero.
Override the connection with MISTER_HOST, MISTER_USER, and MISTER_PASS.
EOF
    exit 2
}

remote_url() {
    local path=${1#/}
    printf 'ftp://%s//%s' "$MISTER_HOST" "$path"
}

put_file() {
    local source=$1
    local destination=$2
    [[ -f $source ]] || {
        printf 'mister.sh: missing file: %s\n' "$source" >&2
        exit 1
    }
    "${CURL[@]}" --ftp-create-dirs --upload-file "$source" "$(remote_url "$destination")"
}

get_file() {
    local source=$1
    local destination=$2
    mkdir -p "$(dirname -- "$destination")"
    "${CURL[@]}" --output "$destination" "$(remote_url "$source")"
}

list_directory() {
    local directory=${1:-/media/fat/}
    [[ $directory == */ ]] || directory="$directory/"
    "${CURL[@]}" --list-only "$(remote_url "$directory")"
}

delete_remote() {
    local path=$1
    "${CURL[@]}" --quote "DELE $path" "ftp://$MISTER_HOST/" >/dev/null 2>&1 || true
}

send_command() {
    local command=$1
    printf '%s\n' "$command" | \
        "${CURL[@]}" --upload-file - "$(remote_url /dev/MiSTer_cmd)"
}

installed_core() {
    local name
    local matches=()

    while IFS= read -r name; do
        name=${name%$'\r'}
        [[ $name == MediaPlayer*.rbf ]] && matches+=("$name")
    done < <(list_directory /media/fat/)

    case ${#matches[@]} in
        0) printf '/media/fat/MediaPlayer.rbf' ;;
        1) printf '/media/fat/%s' "${matches[0]}" ;;
        *)
            printf 'mister.sh: multiple MediaPlayer RBFs found; specify REMOTE_RBF:\n' >&2
            printf '  /media/fat/%s\n' "${matches[@]}" >&2
            exit 1
            ;;
    esac
}

install_core() (
    local source=${1:-$ROOT/output_files/MediaPlayer.rbf}
    local destination=${2:-}
    local readback local_hash remote_hash

    [[ -f $source ]] || {
        printf 'mister.sh: missing RBF: %s\n' "$source" >&2
        exit 1
    }
    [[ -n $destination ]] || destination=$(installed_core)

    printf 'Replacing %s\n' "$destination"
    put_file "$source" "$destination"

    readback=$(mktemp /tmp/MediaPlayer-readback.XXXXXX.rbf)
    trap 'rm -f -- "$readback"' EXIT
    get_file "$destination" "$readback"

    local_hash=$(sha256sum "$source" | awk '{print $1}')
    remote_hash=$(sha256sum "$readback" | awk '{print $1}')
    [[ $local_hash == "$remote_hash" ]] || {
        printf 'mister.sh: uploaded RBF failed read-back verification\n' >&2
        exit 1
    }

    printf 'Installed: %s\nSHA-256: %s\n' "$destination" "$local_hash"
)

png_is_complete() {
    local file=$1
    local header trailer

    [[ -s $file ]] || return 1
    header=$(od -An -tx1 -N8 "$file" | tr -d ' \n')
    trailer=$(tail -c 12 "$file" | od -An -tx1 | tr -d ' \n')
    [[ $header == 89504e470d0a1a0a && $trailer == 0000000049454e44ae426082 ]]
}

capture_screenshot() {
    local output=$1
    local stamp remote_name remote_path temporary attempt

    stamp=$(date +%Y%m%d_%H%M%S_%N)
    remote_name="mmp_${stamp}_$$.png"
    remote_path="/media/fat/screenshots/$remote_name"
    temporary=$(mktemp /tmp/mister-screenshot.XXXXXX.png)

    delete_remote "$remote_path"
    send_command "screenshot scaled $remote_name"

    for attempt in {1..50}; do
        if "${CURL[@]}" --output "$temporary" "$(remote_url "$remote_path")" 2>/dev/null && \
           png_is_complete "$temporary"; then
            mkdir -p "$(dirname -- "$output")"
            mv -f -- "$temporary" "$output"
            delete_remote "$remote_path"
            printf '%s\n' "$output"
            return 0
        fi
        sleep 0.1
    done

    rm -f -- "$temporary"
    delete_remote "$remote_path"
    printf 'mister.sh: screenshot was not completed within five seconds\n' >&2
    return 1
}

screenshot() {
    local output=${1:-screenshot_$(date +%Y%m%d_%H%M%S).png}
    [[ $output == *.png ]] || {
        printf 'mister.sh: screenshot output must end in .png\n' >&2
        exit 1
    }
    capture_screenshot "$output"
}

screenshot_stream() {
    local duration=${1:-0}
    local directory=${2:-screenshots_$(date +%Y%m%d_%H%M%S)}
    local start frame=1 running=1

    [[ $duration =~ ^[0-9]+$ ]] || {
        printf 'mister.sh: SECONDS must be a whole number\n' >&2
        exit 1
    }

    mkdir -p "$directory"
    start=$(date +%s)
    trap 'running=0' INT TERM
    printf 'Capturing to %s; press Ctrl+C to stop.\n' "$directory"

    while (( running )); do
        if ! capture_screenshot "$directory/frame_$(printf '%06d' "$frame").png"; then
            (( running )) || break
            return 1
        fi
        ((frame += 1))
        if (( duration > 0 && $(date +%s) - start >= duration )); then
            break
        fi
    done

    printf 'Captured %d frames in %s\n' "$((frame - 1))" "$directory"
}

case ${1:-} in
    install)
        [[ $# -le 3 ]] || usage
        install_core "${2:-}" "${3:-}"
        ;;
    screenshot)
        [[ $# -le 2 ]] || usage
        screenshot "${2:-}"
        ;;
    screenshot-stream)
        [[ $# -le 3 ]] || usage
        screenshot_stream "${2:-0}" "${3:-}"
        ;;
    log)
        [[ $# -le 2 ]] || usage
        get_file /tmp/MediaPlayer_ARM.log "${2:-MediaPlayer_ARM.log}"
        ;;
    list)
        [[ $# -le 2 ]] || usage
        list_directory "${2:-/media/fat/}"
        ;;
    put)
        [[ $# -eq 3 ]] || usage
        put_file "$2" "$3"
        ;;
    get)
        [[ $# -eq 3 ]] || usage
        get_file "$2" "$3"
        ;;
    *) usage ;;
esac
