#!/usr/bin/env bash
#
# MiSTer-Media-Player local build driver.
#
# Flat command chains matching the original .git/config [guitool] entries,
# kept here so they survive a fresh clone. Local build only: no git steps.
#
# Usage:  tools/build.sh <command>
#
#   compile     full Quartus compile of the MediaPlayer revision
#   timing      run the Phase-1P timing script
#   upload      send output_files/MediaPlayer.rbf to the MiSTer over FTP
#   all         compile -> upload -> timing
#   all-clean   wipe db/incremental_db/output_files, then compile -> upload -> timing
#
# git-gui guitool commands:
#   Build/Compile              tools/build.sh compile
#   Build/Run Timing Analysis  tools/build.sh timing
#   Build/Upload to Mister     tools/build.sh upload
#   Build/All                  tools/build.sh all
#   Build/All Clean            tools/build.sh all-clean

QUARTUS=/home/vash/intelFPGA_lite/17.0_T/quartus/bin
RBF=/run/media/vash/GIT/test1/MiSTer-Media-Player/output_files/MediaPlayer.rbf
MISTER=ftp://10.10.0.30//media/fat/MediaPlayer.rbf
BEEP="play -q -n synth 0.15 sine 1000"

case "$1" in

compile)
    $QUARTUS/quartus_sh --flow compile MediaPlayer && \
    $BEEP
    ;;

timing)
    $QUARTUS/quartus_sta -t tools/phase1p_timing.tcl && \
    $BEEP
    ;;

upload)
    curl -T $RBF -u root:1 $MISTER
    ;;

all)
    $QUARTUS/quartus_sh --flow compile MediaPlayer && \
    curl -T $RBF -u root:1 $MISTER && \
    $QUARTUS/quartus_sta -t tools/phase1p_timing.tcl && \
    $BEEP
    ;;

all-clean)
    rm -rf db incremental_db && \
    rm -f output_files/MediaPlayer.* && \
    $QUARTUS/quartus_sh --flow compile MediaPlayer && \
    curl -T $RBF -u root:1 $MISTER && \
    $QUARTUS/quartus_sta -t tools/phase1p_timing.tcl && \
    $BEEP
    ;;

*)
    sed -n '7,14p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;

esac
