#!/bin/sh
# Run from MiSTer's Scripts menu after boot, and again after each playback.
# Collect evidence only: never update, reload a core, or restart the machine.
set -u

card=/media/fat
out="$card/Buildroot_Compatibility"
manifest="$out/expected.sha256"
umask 077
mkdir -p "$out" || exit 1
stamp="$(date +%Y%m%dT%H%M%S)-$$"
report="$out/environment-$stamp.txt"
status=0

{
    echo 'Buildroot MiSTer compatibility capture'
    date -Iseconds
    uname -a
    echo
    echo '--- Boot command line ---'
    cat /proc/cmdline
    echo
    case " $(cat /proc/cmdline) " in
        *' mem=511M '*) echo 'PASS: expected Linux memory limit is present' ;;
        *) echo 'WARNING: expected mem=511M boot argument is absent'; status=1 ;;
    esac
    case "$(uname -r)" in
        6.18.46) echo 'PASS: pinned non-RT kernel version' ;;
        *) echo 'WARNING: this is not the pinned 6.18.46 kernel'; status=1 ;;
    esac
    if [ -c /dev/mem ]; then
        echo 'INFO: /dev/mem exists; actual FPGA access needs hardware testing'
    else
        echo 'WARNING: /dev/mem is absent'; status=1
    fi
    echo
    echo '--- Memory ---'
    cat /proc/meminfo
    echo
    echo '--- Mounts ---'
    cat /proc/mounts
    echo
    echo '--- IPv4 addresses ---'
    ip -4 addr show
    echo
    echo '--- Installed-file checksums ---'
    if [ -f "$manifest" ]; then
        if (cd "$card" && sha256sum -c "$manifest"); then
            echo 'PASS: prepared files match the card manifest'
        else
            echo 'WARNING: prepared-file checksum mismatch'; status=1
        fi
    else
        echo 'WARNING: expected.sha256 is absent'; status=1
    fi
    echo
    echo '--- Recent kernel messages ---'
    dmesg | tail -n 200
    echo
    echo '--- Helper log ---'
    if [ -f /tmp/MediaPlayer_ARM.log ]; then
        helper="$out/helper-$stamp.log"
        if cp /tmp/MediaPlayer_ARM.log "$helper"; then
            echo "Copied to $helper (may be from an earlier playback)."
        else
            echo 'WARNING: helper log copy failed'; status=1
        fi
    else
        echo 'No helper log exists yet.'
    fi
    echo
    echo "Capture check status: $status"
    echo 'This report does not establish hardware playback acceptance.'
} > "$report" 2>&1 || exit 1

sync
echo "Report: $report"
echo "Capture check status: $status; inspect any warnings in the report."
echo 'For playback, also record modes, LEDs, sound, motion and a fresh terminal screenshot.'
exit "$status"
