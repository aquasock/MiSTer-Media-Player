#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat >&2 <<'EOF'
usage:
  tools/media.sh probe INPUT
  tools/media.sh verify INPUT
  tools/media.sh clip INPUT OUTPUT [SECONDS] [START]
  tools/media.sh convert INPUT OUTPUT [SECONDS] [START]
  tools/media.sh test-pattern OUTPUT [SECONDS]
  tools/media.sh mpd-d2-create INPUT OUTPUT.vob [SECONDS] [START]
  tools/media.sh mpd-d2-verify INPUT.vob [MANIFEST]

clip stream-copies the first video and audio tracks. convert produces a
720x480 progressive MPEG-2 Program Stream with 48 kHz stereo AC-3 audio.
SECONDS defaults to 900 (15 minutes), and START defaults to zero.

mpd-d2-create produces the adopted NARA MPD-D2 frame-picture qualification
profile. It records hashes and provenance in OUTPUT.vob.mpd-d2.txt. Its
SECONDS default is 300. mpd-d2-verify checks the encoded properties, every
picture's interlace/TFF flags, optional manifest, and a complete decode.
EOF
    exit 2
}

require() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'media.sh: required command not found: %s\n' "$1" >&2
        exit 1
    }
}

mpd_d2_work_dir=
cleanup_mpd_d2_work_dir() {
    if [[ $mpd_d2_work_dir == /tmp/mmp-mpd-d2.* && -d $mpd_d2_work_dir ]]; then
        rm -rf -- "$mpd_d2_work_dir"
    fi
}

probe_stream_value() {
    local input=$1 selector=$2 field=$3
    ffprobe -v error -select_streams "$selector" -show_entries "stream=$field" \
        -of default=noprint_wrappers=1:nokey=1 "$input"
}

expect_value() {
    local label=$1 actual=$2 expected=$3
    [[ $actual == "$expected" ]] || {
        printf 'media.sh: %s is %q, expected %q\n' "$label" "$actual" "$expected" >&2
        return 1
    }
}

require_time_value() {
    local label=$1 value=$2
    [[ $value =~ ^[0-9]+([.][0-9]+)?$ ]] || {
        printf 'media.sh: %s must be a non-negative number: %s\n' "$label" "$value" >&2
        return 1
    }
}

mpd_d2_verify() {
    local input=$1 manifest=${2:-}
    local format_name stream_types video_count audio_count stream_count
    local frame_result output_hash manifest_hash

    [[ -f $input ]] || {
        printf 'media.sh: missing input: %s\n' "$input" >&2
        return 1
    }
    require ffprobe
    require ffmpeg
    require awk
    require sha256sum

    format_name=$(ffprobe -v error -show_entries format=format_name \
        -of default=noprint_wrappers=1:nokey=1 "$input")
    expect_value 'container' "$format_name" mpeg

    stream_types=$(ffprobe -v error -show_entries stream=codec_type \
        -of default=noprint_wrappers=1:nokey=1 "$input")
    stream_count=$(printf '%s\n' "$stream_types" | awk 'NF {count++} END {print count+0}')
    video_count=$(printf '%s\n' "$stream_types" | awk '$0=="video" {count++} END {print count+0}')
    audio_count=$(printf '%s\n' "$stream_types" | awk '$0=="audio" {count++} END {print count+0}')
    expect_value 'stream count' "$stream_count" 2
    expect_value 'video stream count' "$video_count" 1
    expect_value 'audio stream count' "$audio_count" 1

    expect_value 'video codec' "$(probe_stream_value "$input" v:0 codec_name)" mpeg2video
    expect_value 'video profile' "$(probe_stream_value "$input" v:0 profile)" Main
    expect_value 'video level' "$(probe_stream_value "$input" v:0 level)" 8
    expect_value 'video width' "$(probe_stream_value "$input" v:0 width)" 720
    expect_value 'video height' "$(probe_stream_value "$input" v:0 height)" 480
    expect_value 'video chroma format' "$(probe_stream_value "$input" v:0 pix_fmt)" yuv420p
    expect_value 'video frame rate' "$(probe_stream_value "$input" v:0 avg_frame_rate)" 30000/1001
    expect_value 'video field order' "$(probe_stream_value "$input" v:0 field_order)" tt
    expect_value 'video bit rate' "$(probe_stream_value "$input" v:0 bit_rate)" 8000000

    expect_value 'audio codec' "$(probe_stream_value "$input" a:0 codec_name)" ac3
    expect_value 'audio sample rate' "$(probe_stream_value "$input" a:0 sample_rate)" 48000
    expect_value 'audio channel count' "$(probe_stream_value "$input" a:0 channels)" 2
    expect_value 'audio bit rate' "$(probe_stream_value "$input" a:0 bit_rate)" 256000

    frame_result=$(ffprobe -v error -select_streams v:0 \
        -show_entries frame=interlaced_frame,top_field_first -of compact=p=0:nk=1 \
        "$input" | awk -F'|' '
            NF {count++; if ($1 != 1 || $2 != 1) bad++}
            END {
                if (!count) print "no_frames";
                else if (bad) print "bad_frames=" bad "/" count;
                else print "frames=" count;
            }')
    [[ $frame_result == frames=* ]] || {
        printf 'media.sh: interlaced TFF picture check failed: %s\n' "$frame_result" >&2
        return 1
    }

    ffmpeg -nostdin -hide_banner -v error -xerror -i "$input" \
        -map 0:v:0 -map 0:a:0 -f null -

    if [[ -z $manifest && -f $input.mpd-d2.txt ]]; then
        manifest=$input.mpd-d2.txt
    fi
    if [[ -n $manifest ]]; then
        [[ -f $manifest ]] || {
            printf 'media.sh: missing manifest: %s\n' "$manifest" >&2
            return 1
        }
        expect_value 'manifest profile' \
            "$(awk -F= '$1=="profile" {print $2}' "$manifest")" NARA-MPD-D2
        expect_value 'manifest video source bit rate' \
            "$(awk -F= '$1=="video_intermediate_bit_rate" {print $2}' "$manifest")" 8000000
        expect_value 'manifest audio source codec' \
            "$(awk -F= '$1=="audio_source_codec" {print $2}' "$manifest")" pcm_dvd
        expect_value 'manifest audio source sample format' \
            "$(awk -F= '$1=="audio_source_sample_format" {print $2}' "$manifest")" s16
        expect_value 'manifest audio source sample rate' \
            "$(awk -F= '$1=="audio_source_sample_rate" {print $2}' "$manifest")" 48000
        expect_value 'manifest audio source channels' \
            "$(awk -F= '$1=="audio_source_channels" {print $2}' "$manifest")" 2
        output_hash=$(sha256sum "$input" | awk '{print $1}')
        manifest_hash=$(awk -F= '$1=="output_sha256" {print $2}' "$manifest")
        expect_value 'manifest output SHA-256' "$manifest_hash" "$output_hash"
    fi

    printf 'MPD-D2 verification passed: %s (%s)\n' "$input" "$frame_result"
}

mpd_d2_create() {
    local input=$1 output=$2 seconds=${3:-300} start=${4:-0}
    local manifest=$output.mpd-d2.txt work_dir intermediate_source staged_output
    local source_hash intermediate_hash output_hash manifest_stage

    [[ -f $input ]] || {
        printf 'media.sh: missing input: %s\n' "$input" >&2
        return 1
    }
    [[ $output == *.vob ]] || {
        printf 'media.sh: MPD-D2 output must end in .vob: %s\n' "$output" >&2
        return 1
    }
    [[ $input != "$output" ]] || {
        printf 'media.sh: input and output must differ\n' >&2
        return 1
    }
    [[ ! -e $output && ! -e $manifest ]] || {
        printf 'media.sh: refusing to replace existing output or manifest: %s\n' "$output" >&2
        return 1
    }
    require_time_value SECONDS "$seconds"
    require_time_value START "$start"
    require ffmpeg
    require ffprobe
    require awk
    require sha256sum
    require mktemp

    work_dir=$(mktemp -d /tmp/mmp-mpd-d2.XXXXXX)
    [[ $work_dir == /tmp/mmp-mpd-d2.* && -d $work_dir ]] || {
        printf 'media.sh: unsafe temporary directory: %s\n' "$work_dir" >&2
        return 1
    }
    mpd_d2_work_dir=$work_dir
    trap cleanup_mpd_d2_work_dir EXIT
    intermediate_source=$work_dir/source_8mbps_tff_16bit.vob
    staged_output=$work_dir/qualification.vob
    manifest_stage=$work_dir/qualification.mpd-d2.txt

    ffmpeg -nostdin -hide_banner -v warning -ss "$start" -i "$input" -t "$seconds" \
        -map 0:v:0 -map 0:a:0 \
        -vf 'scale=720:480:flags=bicubic,format=yuv420p,setfield=tff' \
        -r 30000/1001 -c:v mpeg2video -profile:v main -level:v main \
        -flags:v +ildct+ilme+bitexact -g 15 -bf 2 \
        -sc_threshold 1000000000 -mpv_flags +strict_gop \
        -b:v 8000k -minrate:v 8000k -maxrate:v 8000k -bufsize:v 1835008 \
        -threads 1 -c:a pcm_dvd -sample_fmt s16 -ar 48000 -ac 2 \
        -fflags +bitexact -f vob "$intermediate_source"

    expect_value 'intermediate video codec' \
        "$(probe_stream_value "$intermediate_source" v:0 codec_name)" mpeg2video
    expect_value 'intermediate video profile' \
        "$(probe_stream_value "$intermediate_source" v:0 profile)" Main
    expect_value 'intermediate video level' \
        "$(probe_stream_value "$intermediate_source" v:0 level)" 8
    expect_value 'intermediate video bit rate' \
        "$(probe_stream_value "$intermediate_source" v:0 bit_rate)" 8000000
    expect_value 'intermediate video field order' \
        "$(probe_stream_value "$intermediate_source" v:0 field_order)" tt
    expect_value 'intermediate audio codec' \
        "$(probe_stream_value "$intermediate_source" a:0 codec_name)" pcm_dvd
    expect_value 'intermediate audio sample format' \
        "$(probe_stream_value "$intermediate_source" a:0 sample_fmt)" s16
    expect_value 'intermediate audio sample rate' \
        "$(probe_stream_value "$intermediate_source" a:0 sample_rate)" 48000
    expect_value 'intermediate audio channels' \
        "$(probe_stream_value "$intermediate_source" a:0 channels)" 2

    ffmpeg -nostdin -hide_banner -v warning -i "$intermediate_source" \
        -map 0:v:0 -map 0:a:0 -c:v copy -c:a ac3 -b:a 256k -ar 48000 -ac 2 \
        -flags:a +bitexact -fflags +bitexact -muxrate 10080k \
        -packetsize 2048 -f vob "$staged_output"

    mpd_d2_verify "$staged_output"

    source_hash=$(sha256sum "$input" | awk '{print $1}')
    intermediate_hash=$(sha256sum "$intermediate_source" | awk '{print $1}')
    output_hash=$(sha256sum "$staged_output" | awk '{print $1}')
    {
        printf 'profile=NARA-MPD-D2\n'
        printf 'generator=tools/media.sh mpd-d2-create\n'
        printf 'source=%s\n' "$input"
        printf 'source_sha256=%s\n' "$source_hash"
        printf 'source_start_seconds=%s\n' "$start"
        printf 'source_duration_seconds=%s\n' "$seconds"
        printf 'video_intermediate_codec=mpeg2video\n'
        printf 'video_intermediate_bit_rate=8000000\n'
        printf 'audio_source_codec=pcm_dvd\n'
        printf 'audio_source_sample_format=s16\n'
        printf 'audio_source_sample_rate=48000\n'
        printf 'audio_source_channels=2\n'
        printf 'intermediate_sha256=%s\n' "$intermediate_hash"
        printf 'output_sha256=%s\n' "$output_hash"
    } > "$manifest_stage"
    mpd_d2_verify "$staged_output" "$manifest_stage"

    mkdir -p "$(dirname -- "$output")"
    mv -- "$staged_output" "$output"
    mv -- "$manifest_stage" "$manifest"
    printf 'Created: %s\nManifest: %s\nSHA-256: %s\n' \
        "$output" "$manifest" "$output_hash"
}

case ${1:-} in
    probe)
        [[ $# -eq 2 ]] || usage
        require ffprobe
        ffprobe -hide_banner "$2"
        ;;
    verify)
        [[ $# -eq 2 ]] || usage
        require ffmpeg
        ffmpeg -hide_banner -v error -xerror -i "$2" -map 0:v:0 -f null -
        ;;
    clip)
        [[ $# -ge 3 && $# -le 5 ]] || usage
        require ffmpeg
        seconds=${4:-900}
        start=${5:-0}
        ffmpeg -hide_banner -v warning -y -ss "$start" -i "$2" -t "$seconds" \
            -map 0:v:0 -map '0:a:0?' -c copy -f vob "$3"
        ;;
    convert)
        [[ $# -ge 3 && $# -le 5 ]] || usage
        require ffmpeg
        seconds=${4:-900}
        start=${5:-0}
        ffmpeg -hide_banner -v warning -y -ss "$start" -i "$2" -t "$seconds" \
            -map 0:v:0 -map '0:a:0?' \
            -vf 'scale=720:480:force_original_aspect_ratio=decrease,pad=720:480:(ow-iw)/2:(oh-ih)/2' \
            -c:v mpeg2video -pix_fmt yuv420p -r 30000/1001 -g 15 -bf 2 \
            -b:v 6000k -maxrate 8000k -bufsize 1835008 \
            -c:a ac3 -ar 48000 -ac 2 -b:a 192k -f vob "$3"
        ;;
    test-pattern)
        [[ $# -ge 2 && $# -le 3 ]] || usage
        require ffmpeg
        seconds=${3:-15}
        ffmpeg -hide_banner -v warning -y \
            -f lavfi -i "testsrc2=size=720x480:rate=30000/1001:duration=$seconds" \
            -f lavfi -i "sine=frequency=440:sample_rate=48000:duration=$seconds" \
            -c:v mpeg2video -pix_fmt yuv420p -g 15 -bf 2 \
            -b:v 6000k -maxrate 8000k -bufsize 1835008 \
            -c:a ac3 -ar 48000 -ac 2 -b:a 192k -shortest -f vob "$2"
        ;;
    mpd-d2-create)
        [[ $# -ge 3 && $# -le 5 ]] || usage
        mpd_d2_create "$2" "$3" "${4:-300}" "${5:-0}"
        ;;
    mpd-d2-verify)
        [[ $# -ge 2 && $# -le 3 ]] || usage
        mpd_d2_verify "$2" "${3:-}"
        ;;
    *) usage ;;
esac
