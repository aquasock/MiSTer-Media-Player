derive_pll_clocks
derive_clock_uncertainty

# core specific constraints

# kate - Phase 1P CDC/reset timing closure.
#
# The 40 MHz video and 54 MHz MPEG clocks are both PLL-derived, but the
# framebuffer deliberately transfers a few control/descriptor values through
# explicit synchronizer stages.  Do not mark the entire clock domains
# asynchronous: that would hide accidental future crossings.  Cut only the
# proven first-stage CDC paths; stage 2 and all ordinary same-clock logic remain
# timed normally.

# 54 MHz memory/decoder -> 40 MHz presentation descriptor handshake.
# picture_width_mem / picture_height_mem are captured before cache_ready is
# asserted and remain stable for the displayed picture.  cache_ready itself is
# synchronized separately.  These exceptions therefore cover only the first
# sampling registers in the 40 MHz domain.
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|picture_height_mem[*]}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|picture_height_r1[*]}]
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|picture_width_mem[*]}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|picture_width_r1[*]}]
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|cache_ready}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|cache_ready_r1}]

# 40 MHz presentation -> 54 MHz memory/decoder line-consumed handshake.
# line_done_number_rd is held stable while the toggle crosses the two-stage
# synchronizer.  Cut only the first 54 MHz sampling stage.
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|line_done_toggle_rd*}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|line_done_toggle_m1}]
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|line_done_number_rd[*]}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|line_done_number_m1[*]}]

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
# the independent 40 MHz read domain.  Cut only the asynchronous transfer from
# the already-synchronized MPEG reset output into that chain.
set_false_path \
    -from [get_keepers {*|reset_mpeg2_sync[2]}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|rd_reset_sync[*]}]

# Intel documents these first-stage DCFIFO ACLR exceptions when both
# write_aclr_synch and read_aclr_synch are enabled.  The generated instance
# names include version-dependent suffixes, so match only the documented
# wraclr/rdaclr synchronizer stage-0 structure rather than the whole FIFO.
set_false_path -to [get_keepers {*|dcfifo:*|dcfifo_*:auto_generated|dffpipe_*:wraclr|dffe*a[0]}]
set_false_path -to [get_keepers {*|dcfifo:*|dcfifo_*:auto_generated|dffpipe_*:rdaclr|dffe*a[0]}]
