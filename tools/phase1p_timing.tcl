#==============================================================================
# MiSTer Media Player - Phase 1P TimeQuest critical-path extraction
#
# kate - This script does not alter constraints or RTL.  It opens the fitted
# MediaPlayer design, rebuilds the TimeQuest timing netlist from the project's
# existing SDC files, identifies the 60 MHz decoder and 27 MHz video clocks by
# their periods, and writes detailed path reports for timing-closure work.
#
# kate - Phase 1P same-clock separation:
#   The original reports filtered only by -to_clock.  After the inverse-quant
#   pipeline removed the previous long decoder datapath, the worst reported
#   "decoder" paths became unrelated crossings from another PLL output into the
#   60 MHz domain.  Explicit -from_clock/-to_clock reports are now generated so
#   genuine 60->60 and 27->27 register-to-register timing can be evaluated
#   independently of CDC paths.
#
# Run from the Quartus project root after a successful full compilation:
#
#   quartus_sta -t tools/phase1p_timing.tcl
#
# Output directory:
#   phase1p_timing_reports/
#==============================================================================

package require ::quartus::project
package require ::quartus::sta

set project_name "MediaPlayer"
set output_dir "phase1p_timing_reports"

file mkdir $output_dir

proc phase1p_find_clock_by_period {target_period tolerance description} {
    set matches [list]

    foreach_in_collection clk [get_clocks] {
        set clk_name   [get_clock_info $clk -name]
        set clk_period [get_clock_info $clk -period]

        if {[expr {abs(double($clk_period) - double($target_period)) <= double($tolerance)}]} {
            lappend matches [list $clk $clk_name $clk_period]
        }
    }

    if {[llength $matches] != 1} {
        puts "ERROR: Expected exactly one $description clock near ${target_period} ns."
        puts "ERROR: Found [llength $matches] matching clocks:"
        foreach match $matches {
            puts "  [lindex $match 1]  period=[lindex $match 2] ns"
        }
        error "Unable to identify $description clock uniquely."
    }

    set match [lindex $matches 0]
    puts "Phase 1P: $description clock = [lindex $match 1] ([lindex $match 2] ns)"
    return [lindex $match 0]
}

project_open $project_name

create_timing_netlist
read_sdc
update_timing_netlist

# Reject a build whose mailbox/VS control chains vanished or became shift RAMs.
# Check every stage of each required instance, not just a wildcard that could
# accidentally match one surviving synchronizer elsewhere in the design.
set profiler_regs [get_collection_size [get_registers -nowarn {*mpeg2_h262_hardware_cadence_profiler:*|*}]]
set diagnostic_audit [open "$output_dir/diagnostic_removal_audit.rpt" w]
puts $diagnostic_audit "Cadence profiler registers: $profiler_regs"
close $diagnostic_audit
if {$profiler_regs != 0} {error "Gate one still contains cadence profiler registers"}
# Reporting ports remain usable by standalone simulations, but no reporting
# state may survive in this production netlist. Functional clocks/errors remain.
set reporting_audit [open "$output_dir/reporting_removal_audit.rpt" w]
foreach pattern {
    {*video_config_cdc:media_telemetry_config|*}
    {*media_reservoir_min*}
    {*mp2_sample_toggle*} {*mp2_sample_sync*} {*mp2_samples_count*}
    {*mp2_underrun_sync*} {*mp2_timestamp_error_sync*}
    {*mpeg2_new_stc_seconds*} {*stc_pulse_sync*}
    {*media_file_reader:*|requests[*]} {*media_file_reader:*|completions[*]}
    {*media_file_reader:*|max_wait[*]}
    {*mp2_pcm_output:*|samples_played[*]} {*mp2_pcm_output:*|timestamp_error}
    {*mp2_pcm_output:*|underrun} {*mp2_decoder:*|frames_decoded[*]}
    {*mpeg2_h262_system_time_clock:*|second_counter[*]}
} {
    set count [get_collection_size [get_registers -nowarn $pattern]]
    puts $reporting_audit "$pattern: $count registers"
    if {$count != 0} {error "Gate two still contains reporting registers: $pattern"}
}
close $reporting_audit
# Gate three removes the independent tone path, not the movie PCM sink.
set audio_audit [open "$output_dir/audio_test_removal_audit.rpt" w]
foreach pattern {
    {*audio_pcm_test_source:*|*} {*audio_pcm_fifo:*|*}
    {*audio_pcm_output_adapter:*|*} {*audio_mode_src_fifo*}
    {*audio_restart_out_fifo*} {*audio_mode_*} {*audio_test_mode*}
    {*audio_fifo_reset_stretch*} {*audio_src_reset_count*}
    {*audio_out_reset_count*} {*reset_audio_out_sync*}
} {
    set count [get_collection_size [get_registers -nowarn $pattern]]
    puts $audio_audit "$pattern: $count registers"
    if {$count != 0} {error "Gate three still contains Audio test registers: $pattern"}
}
foreach pattern {{*mp2_pcm_output:*|*} {*mp2_pcm_fifo:*|*} {*mp2_finished_sync*}} {
    set count [get_collection_size [get_registers -nowarn $pattern]]
    puts $audio_audit "Retained $pattern: $count registers"
    if {$count == 0} {error "Gate three lost functional PCM state: $pattern"}
}
close $audio_audit
# All three production clients must use one physical arithmetic engine.
# Quartus duplicates high-fanout index bits during fitting. Count logical bits
# after stripping its observed duplicate suffix, and independently reject any
# other IDCT hierarchy (including engines without a surviving index register).
set shared_idct_audit [open "$output_dir/shared_idct_audit.rpt" w]
set expected_engine {emu:emu|mpeg2_h262_shared_idct:shared_idct|mpeg2_h262_idct:engine}
set engine_names [list]
foreach_in_collection reg [get_registers -nowarn {*mpeg2_h262_idct:*|*}] {
    set name [get_register_info $reg -name]
    if {![regexp {^(.*mpeg2_h262_idct:[^|]+)\|} $name unused engine]} {
        error "Unrecognized IDCT hierarchy: $name"
    }
    lappend engine_names $engine
}
set engine_names [lsort -unique $engine_names]
set index_names [list]
set physical_index_names [list]
foreach_in_collection reg [get_registers -nowarn {*mpeg2_h262_idct:*|transform_index[*]}] {
    set name [get_register_info $reg -name]
    lappend physical_index_names $name
    regsub {~DUPLICATE$} $name {} logical_name
    lappend index_names $logical_name
}
set index_names [lsort -unique $index_names]
set expected_indices [list]
for {set bit 0} {$bit < 6} {incr bit} {
    lappend expected_indices [format {%s|transform_index[%d]} $expected_engine $bit]
}
puts $shared_idct_audit "IDCT engine hierarchies: [llength $engine_names]"
puts $shared_idct_audit "Logical IDCT index bits: [llength $index_names]"
puts $shared_idct_audit "Physical IDCT index registers: [llength $physical_index_names]"
foreach name $engine_names {puts $shared_idct_audit "Engine: $name"}
foreach name [lsort $physical_index_names] {puts $shared_idct_audit "Register: $name"}
if {$engine_names ne [list $expected_engine] || $index_names ne $expected_indices} {
    close $shared_idct_audit
    error "Expected exactly one shared IDCT engine with all six logical index bits"
}
puts $shared_idct_audit "Shared IDCT audit: PASS"
close $shared_idct_audit
set cdc_audit [open "$output_dir/configuration_cdc_audit.rpt" w]
foreach instance {music_hint_cdc music_error_cdc music_total_cdc music_position_cdc config_ref config_cd clock_ack movie_idle_cdc cd_idle_cdc ready_cdc eof_generation_config eof_complete_config subtitle_command_config subtitle_ack_config player_ui_config seek_file_config seek_file_echo_config seek_probe_config playback_control_config playback_position_config playback_audio_config playback_hide_reset_config refresh_request_config refresh_applied_config color_mode_config display_color_config media_prefill_config media_fatal_config reader_error_config aspect_config playback_osd_config platform_aspect_config scaler_input_config scaler_output_config framebuffer_enable_config subcarrier_config hdmi_osd|video_config_cdc:osd_config vga_osd|video_config_cdc:osd_config} {
    if {[string first "|" $instance] < 0} {
        set prefix "*video_config_cdc:$instance"
    } else {
        set prefix "*osd:$instance"
    }
    foreach chain {req_sync ack_sync} {
        for {set stage 0} {$stage < 3} {incr stage} {
            set pattern [format {%s|%s[%d]} $prefix $chain $stage]
            set count [get_collection_size [get_registers $pattern]]
            puts $cdc_audit "$pattern: $count registers"
            if {$count != 1} {error "Expected one preserved configuration synchronizer register: $pattern, found $count"}
        }
    }
}
foreach chain {media_osd_sync hdmi_vs_sys_sync core_vs_sys_sync} {
    for {set stage 0} {$stage < 3} {incr stage} {
        set pattern [format {*%s[%d]} $chain $stage]
        set count [get_collection_size [get_registers $pattern]]
        puts $cdc_audit "$pattern: $count registers"
        if {$count != 1} {error "Expected one preserved VS synchronizer register: $pattern, found $count"}
    }
}
foreach chain {req_sync ack_sync} {
    for {set stage 0} {$stage < 3} {incr stage} {
        set pattern [format {*|media_session_control:*|%s[%d]} $chain $stage]
        set count [get_collection_size [get_registers $pattern]]
        puts $cdc_audit "$pattern: $count registers"
        if {$count != 1} {error "Missing session synchronizer: $pattern"}
    }
}
foreach chain {select_sync lock_sync mute_movie_sync wr_reset_sync rd_reset_sync} {
    for {set stage 0} {$stage < 3} {incr stage} {
        set pattern [format {*media_native_audio:*|%s[%d]} $chain $stage]
        set count [get_collection_size [get_registers $pattern]]
        puts $cdc_audit "$pattern: $count registers"
        if {$count != 1} {error "Missing native audio synchronizer: $pattern"}
    }
}
close $cdc_audit

# The formatter's multicycle exception is backed by a real modulo-four
# enable. Pixel processing, mailbox inputs and compositor outputs stay timed
# at the full HDMI rate; require the enable counter and scoped register set.
set scene_enable_regs [get_registers {*media_player_overlay:player_overlay|scene_phase*}]
set scene_enable_originals {}
set scene_enable_copies 0
foreach_in_collection scene_reg $scene_enable_regs {
    set scene_name [get_register_info -name $scene_reg]
    if {[regexp {\|scene_phase\[([01])\]$} $scene_name -> scene_bit]} {
        lappend scene_enable_originals $scene_bit
    } elseif {[regexp {\|scene_phase\[[01]\]~DUPLICATE(?:~[0-9]+)?$} $scene_name]} {
        incr scene_enable_copies
    } else {
        error "Unexpected scene clock-enable register: $scene_name"
    }
}
if {[lsort $scene_enable_originals] ne {0 1}} {error "Missing two-bit scene clock-enable counter"}
if {[get_collection_size $player_scene_ce_regs] < 400} {error "Missing scoped scene formatter registers"}
set scene_enable_audit [open "$output_dir/player_scene_enable_audit.rpt" w]
puts $scene_enable_audit "Enable counter: [llength $scene_enable_originals] registers"
puts $scene_enable_audit "Routing counter duplicates: $scene_enable_copies"
puts $scene_enable_audit "Four-cycle formatter registers: [get_collection_size $player_scene_ce_regs]"
close $scene_enable_audit

# Current PLL configuration:
#   decoder = 60.0 MHz = 16.667 ns
#   video   = 27.0 MHz = 37.037 ns
#
# Select by period instead of hierarchy-generated PLL names so the reports
# remain usable if Quartus changes generated-clock node naming.
set decoder_clock [phase1p_find_clock_by_period 16.667 0.010 "60 MHz decoder"]
set video_clock   [phase1p_find_clock_by_period 37.037 0.010 "27 MHz video"]

# Keep general summaries beside the detailed path reports.  These summaries
# intentionally include all launch clocks and therefore may still be dominated
# by CDC paths.  Use the *_same_clock reports below for datapath closure.
create_timing_summary \
    -setup \
    -file "$output_dir/phase1p_setup_summary.rpt"

create_timing_summary \
    -recovery \
    -file "$output_dir/phase1p_recovery_summary.rpt"

check_timing \
    -file "$output_dir/phase1p_check_timing.rpt"

# ---------------------------------------------------------------------------
# All paths ending in the 60 MHz decoder domain.
#
# These preserve the original Phase 1P reports because they remain useful for
# finding cross-clock timing relationships and unconstrained/suspicious CDCs.
# ---------------------------------------------------------------------------

report_timing \
    -setup \
    -to_clock $decoder_clock \
    -npaths 50 \
    -nworst 5 \
    -detail full_path \
    -show_routing \
    -file "$output_dir/phase1p_decoder_setup.rpt"

report_timing \
    -setup \
    -to_clock $decoder_clock \
    -npaths 50 \
    -nworst 1 \
    -detail path_and_clock \
    -file "$output_dir/phase1p_decoder_setup_diverse.rpt"

# ---------------------------------------------------------------------------
# Genuine 60 MHz -> 60 MHz decoder datapath.
#
# kate - These are the authoritative reports for deciding whether normal
# decoder register-to-register logic meets the 16.667 ns requirement.  CDC
# paths from other clock domains are excluded by the explicit -from_clock.
# ---------------------------------------------------------------------------

report_timing \
    -setup \
    -from_clock $decoder_clock \
    -to_clock $decoder_clock \
    -npaths 100 \
    -nworst 5 \
    -detail full_path \
    -show_routing \
    -file "$output_dir/phase1p_decoder_same_clock_setup.rpt"

report_timing \
    -setup \
    -from_clock $decoder_clock \
    -to_clock $decoder_clock \
    -npaths 100 \
    -nworst 1 \
    -detail path_and_clock \
    -file "$output_dir/phase1p_decoder_same_clock_setup_diverse.rpt"

# The existing build also has a recovery violation on the decoder clock.
# Capture asynchronous control/release paths separately instead of mixing them
# with normal register-to-register setup paths.
report_timing \
    -recovery \
    -to_clock $decoder_clock \
    -npaths 30 \
    -nworst 5 \
    -detail full_path \
    -show_routing \
    -file "$output_dir/phase1p_decoder_recovery.rpt"

# ---------------------------------------------------------------------------
# 27 MHz presentation domain.
#
# Keep the original all-launch-clocks report to expose CDC paths, and add a
# separate 27->27 report for genuine presentation-domain datapath timing.
# ---------------------------------------------------------------------------

report_timing \
    -setup \
    -to_clock $video_clock \
    -npaths 40 \
    -nworst 5 \
    -detail full_path \
    -show_routing \
    -file "$output_dir/phase1p_video_setup.rpt"

report_timing \
    -setup \
    -from_clock $video_clock \
    -to_clock $video_clock \
    -npaths 80 \
    -nworst 5 \
    -detail full_path \
    -show_routing \
    -file "$output_dir/phase1p_video_same_clock_setup.rpt"

report_timing \
    -setup \
    -from_clock $video_clock \
    -to_clock $video_clock \
    -npaths 80 \
    -nworst 1 \
    -detail path_and_clock \
    -file "$output_dir/phase1p_video_same_clock_setup_diverse.rpt"

puts ""
puts "Phase 1P timing extraction complete."
puts "Reports written to:"
puts "  $output_dir/phase1p_decoder_setup.rpt"
puts "  $output_dir/phase1p_decoder_setup_diverse.rpt"
puts "  $output_dir/phase1p_decoder_same_clock_setup.rpt"
puts "  $output_dir/phase1p_decoder_same_clock_setup_diverse.rpt"
puts "  $output_dir/phase1p_decoder_recovery.rpt"
puts "  $output_dir/phase1p_video_setup.rpt"
puts "  $output_dir/phase1p_video_same_clock_setup.rpt"
puts "  $output_dir/phase1p_video_same_clock_setup_diverse.rpt"
puts "  $output_dir/phase1p_setup_summary.rpt"
puts "  $output_dir/phase1p_recovery_summary.rpt"
puts "  $output_dir/phase1p_check_timing.rpt"
puts ""

# Include HDMI scaler paths and global hold failures in every build report.
set hdmi_clock [get_clocks {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}]
report_timing -setup -from_clock $hdmi_clock -to_clock $hdmi_clock \
    -npaths 50 -nworst 3 -detail full_path -show_routing \
    -file "$output_dir/phase1p_hdmi_same_clock_setup.rpt"
report_timing -hold -npaths 30 -nworst 3 -detail full_path -show_routing \
    -file "$output_dir/phase1p_global_hold.rpt"

# Quartus ignores -multi_corner for file reports. Enumerate every model.
set output_dir corner_timing_reports
file mkdir $output_dir
set index 0
foreach_in_collection op [get_available_operating_conditions] {
    set_operating_conditions $op
    update_timing_netlist
    set model [get_operating_conditions_info $op -model]
    puts "CHECK_CORNER $index $model"
    foreach kind {setup hold recovery removal mpw} {
        create_timing_summary -$kind -file "$output_dir/corner${index}_${kind}.rpt"
    }
    foreach kind {setup hold recovery removal} {
        report_timing -$kind -npaths 20 -nworst 3 -detail full_path -show_routing \
            -file "$output_dir/corner${index}_${kind}_paths.rpt"
    }
    report_min_pulse_width -nworst 20 -file "$output_dir/corner${index}_mpw_paths.rpt"
    incr index
}
puts "CHECKED_CORNERS $index"

delete_timing_netlist
project_close
