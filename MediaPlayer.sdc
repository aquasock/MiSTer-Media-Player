derive_pll_clocks
derive_clock_uncertainty

# core specific constraints

# hps_io.video_calc publishes slowly changing video measurements to the HPS
# through a clk_sys-selected status register.  The vid_* measurements are
# produced in clk_vid/clk_100 domains and are intentionally sampled as
# telemetry rather than synchronous control data.  Cut only those established
# measurement-register -> status-register crossings; keep both clock domains
# and every other crossing fully timed.
set_false_path \
    -from [get_keepers {*|hps_io:hps_io|video_calc:video_calc|vid_*}] \
    -to   [get_keepers {*|hps_io:hps_io|video_calc:video_calc|dout[*]}]

# kate - Phase 1P CDC/reset timing closure.
#
# The 54 MHz video and 60 MHz MPEG clocks are both PLL-derived, but the
# framebuffer deliberately transfers a few control/descriptor values through
# explicit synchronizer stages.  Do not mark the entire clock domains
# asynchronous: that would hide accidental future crossings.  Cut only the
# proven first-stage CDC paths; stage 2 and all ordinary same-clock logic remain
# timed normally.

# 60 MHz memory/decoder -> 54 MHz presentation descriptor handshake.
# picture_width_mem / picture_height_mem are captured before cache_ready is
# asserted and remain stable for the displayed picture.  cache_ready itself is
# synchronized separately.  These exceptions therefore cover only the first
# sampling registers in the 54 MHz domain.
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|picture_height_mem[*]}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|picture_height_r1[*]}]
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|picture_width_mem[*]}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|picture_width_r1[*]}]
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|cache_ready}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|cache_ready_r1}]
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|native_interlaced_mem}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|native_interlaced_r1}]
# Film chroma uses the same stable descriptor/cache_ready handshake. Only
# its first sampling register is asynchronous; r1 -> r2 remains fully timed.
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|progressive_chroma_mem}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|progressive_chroma_r1}]
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|first_field_mem}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|first_field_r1}]
set_false_path \
    -from [get_keepers {*|mpeg2_new_framebuffer_generation[*]}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|framebuffer_generation_r1[*]}]

# Entry 809: authored-menu overlay stable-bus/toggle handshakes cross between
# the 60 MHz DDR service and 54 MHz video domains through explicit sampling
# stages.  Cut only each source -> first-stage path.  The second sampling
# stages, toggle detection, line-cache controls, compositor and all other
# 54/60 MHz paths remain timed normally.
#
# 54 MHz video -> 60 MHz DDR row-request handshake.
set_false_path \
    -from [get_keepers {*|mpeg2_h262_dvd_overlay:*|row_request_value_video*}] \
    -to   [get_keepers {*|mpeg2_h262_dvd_overlay:*|row_request_value_m1*}]
set_false_path \
    -from [get_keepers {*|mpeg2_h262_dvd_overlay:*|row_request_toggle_video[*]}] \
    -to   [get_keepers {*|mpeg2_h262_dvd_overlay:*|row_request_toggle_sync0[*]}]

# Schema 21 observes video-domain event counters through registered Gray code.
# Cut only the Gray source -> first synchronizer stage; the second stage and
# Gray-to-binary diagnostic decode remain timed in the 60 MHz domain.
set_false_path \
    -from [get_keepers {*|mpeg2_h262_dvd_overlay:*|debug_video_gray[*]}] \
    -to   [get_keepers {*|mpeg2_h262_dvd_overlay:*|debug_video_gray_sync0[*]}]

# 60 MHz DDR -> 54 MHz style publication handshake.
set_false_path \
    -from [get_keepers {*|mpeg2_h262_dvd_overlay:*|published_normal[*]}] \
    -to   [get_keepers {*|mpeg2_h262_dvd_overlay:*|normal_v1[*]}]
set_false_path \
    -from [get_keepers {*|mpeg2_h262_dvd_overlay:*|published_highlight[*]}] \
    -to   [get_keepers {*|mpeg2_h262_dvd_overlay:*|highlight_v1[*]}]
set_false_path \
    -from [get_keepers {*|mpeg2_h262_dvd_overlay:*|published_x1[*]}] \
    -to   [get_keepers {*|mpeg2_h262_dvd_overlay:*|x1_v1[*]}]
set_false_path \
    -from [get_keepers {*|mpeg2_h262_dvd_overlay:*|published_y1[*]}] \
    -to   [get_keepers {*|mpeg2_h262_dvd_overlay:*|y1_v1[*]}]
set_false_path \
    -from [get_keepers {*|mpeg2_h262_dvd_overlay:*|published_x2[*]}] \
    -to   [get_keepers {*|mpeg2_h262_dvd_overlay:*|x2_v1[*]}]
set_false_path \
    -from [get_keepers {*|mpeg2_h262_dvd_overlay:*|published_y2[*]}] \
    -to   [get_keepers {*|mpeg2_h262_dvd_overlay:*|y2_v1[*]}]
set_false_path \
    -from [get_keepers {*|mpeg2_h262_dvd_overlay:*|published_visible}] \
    -to   [get_keepers {*|mpeg2_h262_dvd_overlay:*|visible_v1}]
set_false_path \
    -from [get_keepers {*|mpeg2_h262_dvd_overlay:*|published_menu}] \
    -to   [get_keepers {*|mpeg2_h262_dvd_overlay:*|menu_v1}]
set_false_path \
    -from [get_keepers {*|mpeg2_h262_dvd_overlay:*|style_toggle_mem}] \
    -to   [get_keepers {*|mpeg2_h262_dvd_overlay:*|style_toggle_sync[0]}]

# 60 MHz DDR -> 54 MHz line-cache tag handshakes.
set_false_path \
    -from [get_keepers {*|mpeg2_h262_dvd_overlay:*|row_tag_mem[0][*]}] \
    -to   [get_keepers {*|mpeg2_h262_dvd_overlay:*|row_tag0_v1[*]}]
set_false_path \
    -from [get_keepers {*|mpeg2_h262_dvd_overlay:*|row_tag_mem[1][*]}] \
    -to   [get_keepers {*|mpeg2_h262_dvd_overlay:*|row_tag1_v1[*]}]
set_false_path \
    -from [get_keepers {*|mpeg2_h262_dvd_overlay:*|row_tag_toggle_mem[0]}] \
    -to   [get_keepers {*|mpeg2_h262_dvd_overlay:*|row_tag_toggle0_sync[0]}]
set_false_path \
    -from [get_keepers {*|mpeg2_h262_dvd_overlay:*|row_tag_toggle_mem[1]}] \
    -to   [get_keepers {*|mpeg2_h262_dvd_overlay:*|row_tag_toggle1_sync[0]}]

# 54 MHz presentation -> 60 MHz memory/decoder line-consumed handshake.
# kate - Phase 1S removed the old asynchronous 11-bit line-number bus.  Only the
# event toggle now crosses domains; the 54 MHz side derives source-line identity
# from a local sequential counter.  Cut only the first toggle synchronizer stage.
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|line_done_toggle_rd*}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|line_done_toggle_m1}]

# Entry 525: completed per-bank cache tags freeze in mem_clk before their
# individual toggles cross to rd_clk.  Cut only each stable bundle's source to
# its explicit first sampling stage and each toggle to synchronizer stage zero.
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|luma_tag_*_mem*}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|luma_tag_*_r1*}]
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|luma_tag_toggle_bank0_mem}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|luma_tag_toggle_bank0_sync_rd[0]}]
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|luma_tag_toggle_bank1_mem}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|luma_tag_toggle_bank1_sync_rd[0]}]

# Each completed video-domain line comparison freezes its provenance bundle
# before the event toggle crosses back to mem_clk.  Later stages, profiler
# capture and every cache-control path remain timed normally.
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|luma_provenance_*_rd*}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|luma_provenance_*_m1*}]
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|luma_provenance_toggle_rd}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|luma_provenance_toggle_sync[0]}]

# The passive line-cache overlap diagnostic registers the active scan state and
# selected cache banks in the 54 MHz presentation domain, then samples each
# single-bit level through an explicit two-stage synchronizer in the 60 MHz
# memory domain. Cut only the source -> first-stage paths; the second stages and
# sticky overlap detector remain fully timed.
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|cache_scan_active_rd}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|cache_scan_active_sync[0]}]
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|cache_scan_y_bank_rd}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|cache_scan_y_bank_sync[0]}]
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|cache_scan_c_bank_rd}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|cache_scan_c_bank_sync[0]}]

# kate - Phase 1S publication scheduling adds one single-bit video-domain
# blanking-window level. It is registered in the 54 MHz domain, then sampled by
# an explicit three-stage synchronizer in the 60 MHz decoder/DDRAM domain. Cut
# only the asynchronous source -> first synchronizer stage; later stages and the
# scheduler remain fully timed.
set_false_path \
    -from [get_keepers {*|mpeg2_new_swap_window_video}] \
    -to   [get_keepers {*|mpeg2_new_swap_window_sync[0]}]
set_false_path \
    -from [get_keepers {*|mpeg2_new_cadence_window_video}] \
    -to   [get_keepers {*|mpeg2_new_cadence_window_sync[0]}]

# Film mode is a session-stable decoder level. Physical field/active are
# video-domain registers sampled before the delayed field swap window.
# Cut only these source -> first-stage crossings, matching the existing
# native-control convention. No later-stage or decoder path is excepted.
set_false_path \
    -from [get_keepers {*|mpeg2_h262_native_field_order:*|film_mode*}] \
    -to   [get_keepers {*|mpeg2_new_film_mode_video_sync[0]}]
set_false_path \
    -from [get_keepers {*|mpeg2_video_output_timing:*|interlaced_field *|mpeg2_video_output_timing:*|interlaced_active*}] \
    -to   [get_keepers {*|mpeg2_new_native_field_sync[0]}]

# Native presentation mode is requested from the 60 MHz decoder domain and
# acknowledged back from the 54 MHz timing domain through explicit two/three
# stage synchronizers. Cut only the asynchronous inputs to their first stages.
set_false_path \
    -to [get_keepers {*|mpeg2_video_output_timing:*|interlaced_request_sync[0]}]
set_false_path \
    -to [get_keepers {*|mpeg2_video_output_timing:*|top_field_first_sync[0]}]
set_false_path \
    -to [get_keepers {*|mpeg2_new_native_active_sync[0]}]

# Entry 512: the framebuffer's video-domain publication levels cross into
# explicit three-stage decoder-domain synchronizers for passive telemetry.
# Cut only each asynchronous source-to-stage-zero path. The two synchronous
# stage-to-stage delivery paths remain fully timed.
set_false_path \
    -to [get_keepers {*|mpeg2_new_framebuffer_picture_present_sync[0]}]
set_false_path \
    -to [get_keepers {*|mpeg2_new_framebuffer_prefill_missed_sync[0]}]

# Entry 516: the additional per-field readout evidence uses the same idiom.
# The DDR service toggles and the region sampling are generated on clk_mpeg2
# itself and stay fully timed, so only this one video-domain source needs a
# stage-zero cut.
set_false_path \
    -to [get_keepers {*|mpeg2_new_framebuffer_phase_error_sync[0]}]

# Native diagnostic menu controls originate in the framework status bus and
# enter explicit two-stage video-domain synchronizers. Cut only their
# asynchronous source-to-stage-zero paths.
set_false_path \
    -from [get_keepers {*|hps_io:hps_io|status[123]}] \
    -to   [get_keepers {*|native_timing_pattern_sync[0]}]
set_false_path \
    -from [get_keepers {*|hps_io:hps_io|status[125]}] \
    -to   [get_keepers {*|native_timing_pattern_motion_sync[0]}]

# MiSTer's framework treats the 20 MHz system controls and raster pipeline as
# separate functional clock domains. The old harmonic 20/40 MHz pair happened
# to offer a wide related edge; 20/54 MHz exposes the OSD, scaler and HDMI
# configuration crossings at a 1.852 ns closest edge. Group only this framework
# pair asynchronously. The 54 MHz video / 60 MHz MPEG relationship remains
# fully timed except for the explicit synchronizers documented above.
set_clock_groups -asynchronous \
    -group [get_clocks {*|general[0].gpll*|divclk}] \
    -group [get_clocks {*|general[1].gpll*|divclk}]

# Entry 238: ioctl_download is registered in clk_sys and sampled only by the
# first stage of an explicit three-register clk_mpeg2 synchronizer.  Cut that
# asynchronous source-to-stage-zero path only; both later synchronizer stages
# and all rearm control remain timed in clk_mpeg2.
set_false_path \
    -from [get_keepers {*|hps_io:hps_io|ioctl_download}] \
    -to   [get_keepers {*|mpeg2_h262_download_rearm:*|download_sync[0]}]

# Entry 873: the audio UI loader exports one level from clk_mpeg2 solely to
# blank the video while the first complete UI frame is uploaded.  The level is
# sampled by an explicit three-register clk_video synchronizer.  Cut only the
# asynchronous source -> first sampling stage; the settling stages and all
# video-domain blanking logic remain timed in clk_video.
set_false_path \
    -to [get_keepers {*|audio_ui_initial_loading_video_sync[0]}]

# Entry 245: the frozen hardware-cadence snapshot is produced in clk_mpeg2 and
# remains stable permanently before its trailing ready level can enable the
# video overlay.  The snapshot bus uses two explicit clk_video sampling stages;
# ready uses three and trails the data stages.  Cut only each asynchronous
# source -> first sampling stage.  The settling stages, overlay serializer, and
# all ordinary decoder/video logic remain timed normally.
set_false_path \
    -from [get_keepers {*|mpeg2_h262_hardware_cadence_profiler:*|snapshot_mpeg2[*]}] \
    -to   [get_keepers {*|mpeg2_h262_hardware_cadence_profiler:*|snapshot_sync_1[*]}]
# Quartus may merge snapshot_ready_mpeg2 with the constant-one snapshot magic
# bit because both freeze on the same event, so identify this single-bit CDC by
# its first-stage destination rather than by an optimization-dependent source.
set_false_path \
    -to [get_keepers {*|mpeg2_h262_hardware_cadence_profiler:*|snapshot_ready_sync[0]}]

# Asynchronous reset request sources.
# status[0] and cfg[1] are the HPS reset controls that reach reset_request;
# RESET is the external reset input.  These are intentional asynchronous
# assertion paths into the reset synchronizer registers, not synchronous data
# transfers.  Scope the exceptions to those reset chains only so no other HPS
# control path is hidden.  The synchronous stage-to-stage release paths remain
# fully timed.
set_false_path \
    -from [get_keepers {*|hps_io:hps_io|status[0]}] \
    -to   [get_keepers {*|reset_mpeg2_sync[*]}]
set_false_path \
    -from [get_keepers {*|hps_io:hps_io|status[0]}] \
    -to   [get_keepers {*|reset_video_sync[*]}]
set_false_path \
    -from [get_keepers {*|hps_io:hps_io|cfg[1]}] \
    -to   [get_keepers {*|reset_mpeg2_sync[*]}]
set_false_path \
    -from [get_keepers {*|hps_io:hps_io|cfg[1]}] \
    -to   [get_keepers {*|reset_video_sync[*]}]
set_false_path \
    -from [get_ports {RESET}] \
    -to   [get_keepers {*|reset_mpeg2_sync[*]}]
set_false_path \
    -from [get_ports {RESET}] \
    -to   [get_keepers {*|reset_video_sync[*]}]

# The framebuffer reset reaches a second async-assert/sync-deassert chain in
# the independent 54 MHz read domain.  Cut only the asynchronous transfer from
# the already-synchronized MPEG reset output into that chain.
set_false_path \
    -from [get_keepers {*|reset_mpeg2_sync[2]}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|rd_reset_sync[*]}]

# kate - Phase 1R controlled frame-bank publication uses a four-cycle reset
# request generated entirely in the 60 MHz memory/decoder domain to restart the
# framebuffer memory-side prefill state after bank 1 has been completed.  That
# request also intentionally asserts the framebuffer's existing 54 MHz
# rd_reset_sync chain asynchronously; release is still synchronized by the
# chain itself.  Treat only this new assertion boundary like the original
# reset_mpeg2_sync boundary above.  Do not cut the stage-to-stage release paths
# or any other 60 MHz -> 54 MHz logic.
set_false_path \
    -from [get_keepers {*|mpeg2_h262_b_presentation_scheduler:*|framebuffer_swap_reset_count[*]}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|rd_reset_sync[*]}]

# Native-mode changes synchronously reset the 60 MHz framebuffer memory side
# and intentionally assert the same 54 MHz reset-release chain asynchronously.
# Cut only that assertion boundary; release still traverses rd_reset_sync.
set_false_path \
    -from [get_keepers {*|mpeg2_new_native_active_sync[*]}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|rd_reset_sync[*]}]

# Entry 238: a new download resets the framebuffer memory side synchronously
# in clk_mpeg2, but the same level intentionally asserts the existing rd_clk
# reset-release synchronizer asynchronously.  Cut only that controller-to-reset
# chain boundary; release inside rd_reset_sync and all ordinary crossings stay
# fully timed.
set_false_path \
    -from [get_keepers {*|mpeg2_h262_download_rearm:*|*}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|rd_reset_sync[*]}]

# Intel documents these first-stage DCFIFO ACLR exceptions when both
# write_aclr_synch and read_aclr_synch are enabled.  The generated instance
# names include version-dependent suffixes, so match only the documented
# wraclr/rdaclr synchronizer stage-0 structure rather than the whole FIFO.
set_false_path -to [get_keepers {*|dcfifo:*|dcfifo_*:auto_generated|dffpipe_*:wraclr|dffe*a[0]}]
set_false_path -to [get_keepers {*|dcfifo:*|dcfifo_*:auto_generated|dffpipe_*:rdaclr|dffe*a[0]}]

# Entry 561: single-bit startup request/bypass and visibility acknowledgement.
# Only the asynchronous source-to-first-stage transfers are cut; all following
# synchronizer stages, frame-window logic and scheduler admission remain timed.
set_false_path -from [get_keepers {*|mpeg2_h262_native_startup:*|bypass}] \
    -to [get_keepers {*|mpeg2_h262_native_startup:*|bypass_sync[0]}]
set_false_path -from [get_keepers {*|mpeg2_h262_native_startup:*|show_request}] \
    -to [get_keepers {*|mpeg2_h262_native_startup:*|show_request_sync[0]}]
set_false_path -from [get_keepers {*|mpeg2_h262_native_startup:*|shown}] \
    -to [get_keepers {*|mpeg2_h262_native_startup:*|shown_sync[0]}]
