#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
deps_dir="$root_dir/host/arm/.deps"
build_dir="$root_dir/host/build"
minimp3_commit=ea99364f61c14656440e8d77e9c233ccf3124633
minimp3_sha=57e437c5c1f0e8b243885d3929c8973b5e6c778451e0100ab4251d19915cb3ad
license_sha=6a1ee543e5282cd9061881edf462e6fdab181f328da71fc2c9a6950a80e94d01
miniaudio_commit=9634bedb5b5a2ca38c1ee7108a9358a4e233f14d
miniaudio_sha=ac7af4de748b7e26b777f37e01cee313a308a7296a3eb080e2906b320cc55c89
miniaudio_license_sha=457f1b500e0adf6bc059edddfa78a2f62012e7c3bb43476c20e0bd23b25ba0eb
# liba52 0.7.4 decodes AC-3.  Upstream ships only a release tarball, so the
# tarball itself is pinned and the five translation units the helper needs are
# extracted from it.  GPL-2, matching this project's own licence.
liba52_version=0.7.4
liba52_url=http://archive.ubuntu.com/ubuntu/pool/universe/a/a52dec/a52dec_0.7.4.orig.tar.gz
liba52_sha=a21d724ab3b3933330194353687df82c475b5dfb997513eef4c25de6c865ec33
# libdvdread provides ISO9660/UDF and IFO access; libdvdnav assembles the
# selected title's cells into playback order.  Both are GPL-2.0-or-later.
# The tracked patch makes the unencrypted-only product boundary enforceable:
# even a runtime-installed libdvdcss cannot be discovered or used.
libdvdread_version=7.1.1
libdvdread_url=https://download.videolan.org/pub/videolan/libdvdread/last/libdvdread-7.1.1.tar.xz
libdvdread_sha=a0d47876548bec806774bbf8dbf20bb19ba139464383156b32eb8e59915b90a9
libdvdnav_version=7.0.0
libdvdnav_url=https://download.videolan.org/pub/videolan/libdvdnav/last/libdvdnav-7.0.0.tar.xz
libdvdnav_sha=a2a18f5ad36d133c74bf9106b6445806fa253b09141a46392550394b647b221e
libdvdread_patch="$root_dir/host/arm/libdvdread-disable-css.patch"
main_commit=0a8fb44ccec6d69c8b7f158abd5fe8065ab2bf4f
main_patch="$root_dir/host/main_mister/0001-mediaplayer-arm-loader.patch"

mkdir -p "$deps_dir" "$build_dir"

fetch_checked() {
    local url=$1
    local output=$2
    local expected=$3
    if [[ ! -f "$output" ]] || ! printf '%s  %s\n' "$expected" "$output" | sha256sum -c - >/dev/null 2>&1; then
        curl --fail --location --silent --show-error "$url" --output "$output"
    fi
    printf '%s  %s\n' "$expected" "$output" | sha256sum -c - >/dev/null
}

fetch_checked \
    "https://raw.githubusercontent.com/lieff/minimp3/$minimp3_commit/minimp3.h" \
    "$deps_dir/minimp3.h" "$minimp3_sha"
fetch_checked \
    "https://raw.githubusercontent.com/lieff/minimp3/$minimp3_commit/LICENSE" \
    "$deps_dir/LICENSE.minimp3" "$license_sha"
fetch_checked \
    "https://raw.githubusercontent.com/mackron/miniaudio/$miniaudio_commit/miniaudio.h" \
    "$deps_dir/miniaudio.h" "$miniaudio_sha"
fetch_checked \
    "https://raw.githubusercontent.com/mackron/miniaudio/$miniaudio_commit/LICENSE" \
    "$deps_dir/LICENSE.miniaudio" "$miniaudio_license_sha"

fetch_liba52() {
    local tarball="$deps_dir/a52dec-$liba52_version.tar.gz"
    local target="$deps_dir/liba52"
    local prefix="a52dec-$liba52_version"
    fetch_checked "$liba52_url" "$tarball" "$liba52_sha"
    mkdir -p "$target"
    tar -xzf "$tarball" -C "$target" --strip-components=2 \
        "$prefix/liba52/a52_internal.h" "$prefix/liba52/bit_allocate.c" \
        "$prefix/liba52/bitstream.c" "$prefix/liba52/bitstream.h" \
        "$prefix/liba52/downmix.c" "$prefix/liba52/imdct.c" \
        "$prefix/liba52/parse.c" "$prefix/liba52/tables.h"
    tar -xzf "$tarball" -C "$target" --strip-components=2 \
        "$prefix/include/a52.h" "$prefix/include/attributes.h" \
        "$prefix/include/mm_accel.h"
    tar -xzf "$tarball" -C "$deps_dir" --strip-components=1 "$prefix/COPYING"
    mv -f "$deps_dir/COPYING" "$deps_dir/LICENSE.liba52"
    # Upstream expects an autoconf config.h; supply the tracked replacement.
    cp -f "$root_dir/host/arm/liba52_config.h" "$target/config.h"
}

fetch_liba52

fetch_dvd_sources() {
    local read_tarball="$deps_dir/libdvdread-$libdvdread_version.tar.xz"
    local nav_tarball="$deps_dir/libdvdnav-$libdvdnav_version.tar.xz"
    local source_root="$deps_dir/dvd-source"
    local read_source="$source_root/libdvdread"
    local nav_source="$source_root/libdvdnav"
    local stamp="$source_root/.prepared"
    local expected_stamp

    expected_stamp="$libdvdread_sha $libdvdnav_sha $(sha256sum "$libdvdread_patch" | cut -d' ' -f1)"
    fetch_checked "$libdvdread_url" "$read_tarball" "$libdvdread_sha"
    fetch_checked "$libdvdnav_url" "$nav_tarball" "$libdvdnav_sha"
    if [[ -f "$stamp" ]] && [[ $(<"$stamp") == "$expected_stamp" ]]; then
        return
    fi
    rm -rf "$source_root"
    mkdir -p "$read_source" "$nav_source"
    tar -xJf "$read_tarball" -C "$read_source" --strip-components=1
    tar -xJf "$nav_tarball" -C "$nav_source" --strip-components=1
    patch -d "$read_source" -p1 < "$libdvdread_patch"
    printf '%s\n' "$expected_stamp" > "$stamp"
}

write_arm_cross_file() {
    local cross_file=$1
    local cc_path=$2
    local tool_prefix=${cc_path%gcc}

    cat > "$cross_file" <<EOF
[binaries]
c = '$cc_path'
ar = '${tool_prefix}ar'
strip = '${tool_prefix}strip'
pkg-config = 'pkg-config'

[host_machine]
system = 'linux'
cpu_family = 'arm'
cpu = 'armv7'
endian = 'little'

[properties]
needs_exe_wrapper = true
EOF
}

build_dvd_libraries() {
    local flavour=$1
    local cross_file=${2:-}
    local source_root="$deps_dir/dvd-source"
    local read_build="$deps_dir/dvd-build-$flavour/libdvdread"
    local nav_build="$deps_dir/dvd-build-$flavour/libdvdnav"
    local install_root="$deps_dir/dvd-install-$flavour"
    local cross_args=()

    fetch_dvd_sources
    if [[ -n "$cross_file" ]]; then
        cross_args=(--cross-file "$cross_file")
    fi
    meson setup --wipe "$read_build" "$source_root/libdvdread" \
        "${cross_args[@]}" --prefix="$install_root" --libdir=lib \
        --default-library=static -Dlibdvdcss=disabled -Denable_docs=false \
        -Dc_args=-DMMP_DISABLE_DVDCSS=1
    meson compile -C "$read_build"
    meson install -C "$read_build"
    PKG_CONFIG_PATH="$install_root/lib/pkgconfig" \
        meson setup --wipe "$nav_build" "$source_root/libdvdnav" \
            "${cross_args[@]}" --prefix="$install_root" --libdir=lib \
            --default-library=static -Denable_docs=false -Denable_examples=false
    meson compile -C "$nav_build"
    meson install -C "$nav_build"
}

build_native() {
        build_dvd_libraries native
        make -B -C "$root_dir/host/arm" DEPS_DIR="$deps_dir" \
            DVD_PREFIX="$deps_dir/dvd-install-native" \
            OUTPUT="$build_dir/media_player_helper.native"
}

find_arm_cc() {
        arm_cc=${ARM_CC:-arm-none-linux-gnueabihf-gcc}
        if ! command -v "$arm_cc" >/dev/null 2>&1; then
            printf 'ARM compiler not found: %s\n' "$arm_cc" >&2
            printf 'Set ARM_CC to MiSTer Main\047s ARM GNU 10.2 compiler.\n' >&2
            exit 2
        fi
}

build_arm_helper() {
        find_arm_cc
        local arm_cc_path
        local cross_file="$deps_dir/arm-meson-cross.txt"
        local flavour

        arm_cc_path=$(command -v "$arm_cc")
        flavour=$(basename -- "$arm_cc")
        write_arm_cross_file "$cross_file" "$arm_cc_path"
        build_dvd_libraries "$flavour" "$cross_file"
        make -B -C "$root_dir/host/arm" CC="$arm_cc" DEPS_DIR="$deps_dir" \
            DVD_PREFIX="$deps_dir/dvd-install-$flavour" \
            CFLAGS='-O2 -Wall -Wextra -Werror -std=c11' \
            LDFLAGS='-static -s' \
            OUTPUT="$build_dir/MediaPlayer_Helper"
}

build_main() {
        find_arm_cc
        local temporary
        temporary=$(mktemp -d -t mediaplayer_main_build.XXXXXX)
        trap 'rm -r "$temporary"' EXIT
        git clone --quiet https://github.com/MiSTer-devel/Main_MiSTer.git "$temporary/Main_MiSTer"
        git -C "$temporary/Main_MiSTer" checkout --quiet "$main_commit"
        git -C "$temporary/Main_MiSTer" apply --check "$main_patch"
        git -C "$temporary/Main_MiSTer" apply "$main_patch"
        PATH="$(dirname -- "$(command -v "$arm_cc")"):$PATH" \
            make -C "$temporary/Main_MiSTer" -j"$(nproc)"
        cp "$temporary/Main_MiSTer/bin/MiSTer" "$build_dir/MiSTer"
        rm -r "$temporary"
        trap - EXIT
}

mode=${1:---native}
case "$mode" in
    --native)
        build_native
        ;;
    --arm)
        build_arm_helper
        ;;
    --main)
        build_main
        ;;
    --all)
        build_arm_helper
        build_main
        ;;
    *)
        printf 'usage: %s [--native|--arm|--main|--all]\n' "$0" >&2
        exit 2
        ;;
esac
