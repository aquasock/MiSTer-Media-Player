#==============================================================================
# MiSTer Media Player - Phase 1P TimeQuest critical-path extraction
#
# kate - This script does not alter constraints or RTL.  It opens the fitted
# MediaPlayer design, rebuilds the TimeQuest timing netlist from the project's
# existing SDC files, identifies the 54 MHz decoder and 40 MHz video clocks by
# their periods, and writes detailed path reports for timing-closure work.
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

# Current PLL configuration:
#   decoder = 54.0 MHz = 18.518 ns
#   video   = 40.0 MHz = 25.000 ns
#
# Select by period instead of hierarchy-generated PLL names so the reports
# remain usable if Quartus changes generated-clock node naming.
set decoder_clock [phase1p_find_clock_by_period 18.518 0.010 "54 MHz decoder"]
set video_clock   [phase1p_find_clock_by_period 25.000 0.010 "40 MHz video"]

# Keep a general summary beside the detailed path reports.
create_timing_summary \
    -setup \
    -file "$output_dir/phase1p_setup_summary.rpt"

create_timing_summary \
    -recovery \
    -file "$output_dir/phase1p_recovery_summary.rpt"

check_timing \
    -file "$output_dir/phase1p_check_timing.rpt"

# 54 MHz decoder setup:
# - Full path and expanded routing so we can distinguish logic depth from
#   placement/routing delay.
# - nworst=5 allows several paths to the same endpoint while still giving a
#   useful spread of endpoints.
report_timing \
    -setup \
    -to_clock $decoder_clock \
    -npaths 50 \
    -nworst 5 \
    -detail full_path \
    -show_routing \
    -multi_corner \
    -file "$output_dir/phase1p_decoder_setup.rpt"

# A second decoder report with only one path per endpoint makes it easier to
# see whether one RTL structure or several independent structures dominate.
report_timing \
    -setup \
    -to_clock $decoder_clock \
    -npaths 50 \
    -nworst 1 \
    -detail path_and_clock \
    -multi_corner \
    -file "$output_dir/phase1p_decoder_setup_diverse.rpt"

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
    -multi_corner \
    -file "$output_dir/phase1p_decoder_recovery.rpt"

# 40 MHz presentation domain.
report_timing \
    -setup \
    -to_clock $video_clock \
    -npaths 40 \
    -nworst 5 \
    -detail full_path \
    -show_routing \
    -multi_corner \
    -file "$output_dir/phase1p_video_setup.rpt"

puts ""
puts "Phase 1P timing extraction complete."
puts "Reports written to:"
puts "  $output_dir/phase1p_decoder_setup.rpt"
puts "  $output_dir/phase1p_decoder_setup_diverse.rpt"
puts "  $output_dir/phase1p_decoder_recovery.rpt"
puts "  $output_dir/phase1p_video_setup.rpt"
puts "  $output_dir/phase1p_setup_summary.rpt"
puts "  $output_dir/phase1p_recovery_summary.rpt"
puts "  $output_dir/phase1p_check_timing.rpt"
puts ""

delete_timing_netlist
project_close
