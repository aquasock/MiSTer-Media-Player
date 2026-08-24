#!/usr/bin/env bash
#
# Build the v0.7.0 input-envelope corpus and check each file against the
# expected verdict.
#
# The v0.7.0 goal is that users convert their own media, so the inputs that
# matter are the ones outside the envelope.  Every file here is generated
# deterministically by FFmpeg rather than committed, per the project's binary
# artifact policy.  The good cases must pass and the bad cases must fail with a
# named remedy; a bad case that passes is a hole in the checker, and a good case
# that fails is worse, because it would send users chasing a defect that is not
# there.
#
# The generated .mpg files are also the corpus for hardware failure-mode
# testing: each bad case must fail visibly and recoverably on the MiSTer rather
# than wedging it.
#
# Usage:  tools/streams/generate_compatibility_corpus.sh [OUTPUT_DIR]
#
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${1:-$ROOT/tools/streams/generated_compatibility/envelope}"
CHECK="$ROOT/tools/streams/check_media_compatibility.py"
FINALIZE="$ROOT/tools/streams/finalize_program_stream.py"

command -v ffmpeg >/dev/null || { echo "ffmpeg not found" >&2; exit 2; }
mkdir -p "$OUT"

V="-c:v mpeg2video -pix_fmt yuv420p -g 12 -bf 2 -q:v 6"

gen() {  # gen NAME EXPECTED_VERDICT FFMPEG_ARGS...
    local name=$1 expected=$2; shift 2
    echo "generate: $name (expect $expected)"
    # shellcheck disable=SC2086
    ffmpeg -v error -y "$@" "$OUT/$name.mpg"
    python3 "$FINALIZE" "$OUT/$name.mpg"
    printf '%s\n' "$expected" > "$OUT/$name.expected"
}

src_v() { printf -- "-f lavfi -i testsrc2=size=%s:rate=%s:duration=2" "$1" "$2"; }
src_a() { printf -- "-f lavfi -i sine=frequency=440:sample_rate=%s:duration=2" "$1"; }

# shellcheck disable=SC2046
gen good_480p_48k PASS $(src_v 720x480 24) $(src_a 48000) $V -c:a mp2 -ar 48000 -ac 2 -f vob
# shellcheck disable=SC2046
gen good_480p_44k PASS $(src_v 720x480 24) $(src_a 44100) $V -c:a mp2 -ar 44100 -ac 2 -f vob
# shellcheck disable=SC2046
gen good_video_only PASS $(src_v 720x480 24) $V -an -f vob
# shellcheck disable=SC2046
gen bad_geometry_720p FAIL $(src_v 1280x720 25) $(src_a 48000) $V -c:a mp2 -ar 48000 -ac 2 -f vob
# shellcheck disable=SC2046
gen bad_geometry_pal FAIL $(src_v 720x576 25) $(src_a 48000) $V -c:a mp2 -ar 48000 -ac 2 -f vob
# shellcheck disable=SC2046
gen bad_rate_50 FAIL $(src_v 720x480 50) $(src_a 48000) $V -r 50 -c:a mp2 -ar 48000 -ac 2 -f vob
# shellcheck disable=SC2046
gen bad_audio_rate FAIL $(src_v 720x480 24) $(src_a 32000) $V -c:a mp2 -ar 32000 -ac 2 -f vob
# shellcheck disable=SC2046
gen bad_audio_codec FAIL $(src_v 720x480 24) $(src_a 48000) $V -c:a ac3 -ar 48000 -ac 2 -f vob

echo "generate: bad_truncated (expect FAIL)"
head -c 60000 "$OUT/bad_geometry_720p.mpg" > "$OUT/bad_truncated.mpg"
printf 'FAIL\n' > "$OUT/bad_truncated.expected"

echo
failures=0
for expected_file in "$OUT"/*.expected; do
    name=$(basename "${expected_file%.expected}")
    expected=$(cat "$expected_file")
    if python3 "$CHECK" "$OUT/$name.mpg" >/dev/null 2>&1; then
        actual=PASS
    else
        actual=FAIL
    fi
    if [ "$actual" = "$expected" ]; then
        printf '  %-22s %s\n' "$name" "$actual"
    else
        printf '  %-22s %s  <-- expected %s\n' "$name" "$actual" "$expected"
        failures=$((failures + 1))
    fi
done

echo
if [ "$failures" -ne 0 ]; then
    echo "ENVELOPE_CORPUS_FAIL mismatches=$failures"
    exit 1
fi
echo "ENVELOPE_CORPUS_PASS cases=$(ls "$OUT"/*.expected | wc -l)"
