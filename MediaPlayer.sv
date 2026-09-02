//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	`include "sys/emu_ports.vh"
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE,
        SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS,
        SDRAM_nRAS, SDRAM_nCS} = 'Z;

assign VGA_SL = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;

// AUDIO_FORK_POINT[PCM_OUT]: advisory v0.5.0 handoff, not a permanent ABI.
// Replace these zeroes only at the top-level PCM/output boundary.  Keep codec
// decode behind a codec-independent PCM valid/ready contract so MP2/MP3/AC-3
// (and standalone-audio codecs) remain separate from MiSTer output formatting.
// Prefer serialized/time-multiplexed arithmetic: the integrated core values DSP
// headroom more than parallel per-codec datapaths.  AUDIO_S/MIX policy belongs
// here or in a sibling output adapter, not inside the H.262 video decoder.
// Entry 395: route the codec-independent PCM proof path into MiSTer's signed
// 16-bit audio ports. Mono duplication and sample-rate scheduling remain in
// the output adapter; future codecs will see only the valid/ready contract.
wire [15:0] audio_pcm_output_l;
wire [15:0] audio_pcm_output_r;
assign AUDIO_S = 1'b1;
assign AUDIO_L = audio_pcm_output_l;
assign AUDIO_R = audio_pcm_output_r;
assign AUDIO_MIX = 2'd0;

// Entry 699: this remains the user's exclusive HDMI/S/PDIF output selection.
// A separate in-band flag below distinguishes decoded PCM from IEC 61937
// bursts so ordinary audio is not incorrectly announced as non-audio.
assign AUDIO_SPDIF_MODE = status[126];

// kate - Commit 180 displaces the LED_DISK file-load indicator again so it can
// blink the progress_error conjunct sub-code, exactly as Commit 176 did and
// Commit 177 reverted.  The assignment now lives with the rest of the blink
// machinery in MediaPlayer.sv; restore this line when the diagnostic
// is retired.
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

// The first OSD option is the reset/default value. Keep bit 121 as the saved
// preference, but make zero mean the user's requested 16:9 default.
wire widescreen = !status[121];

assign VIDEO_ARX = widescreen ? 12'd16 : 12'd4;
assign VIDEO_ARY = widescreen ? 12'd9  : 12'd3;

`include "build_id.v"
localparam CONF_STR = {
	"MediaPlayer;;",
	"F1,DVD,Run DVD-Video;",
	"F1,M2VMPGMPEVOBISO,Open MPEG-2 Video;",
	"F1,WAVMP3FLCOGG,Open WAV, MP3, FLAC, OGG;",
	"-;",
	"O[121],Aspect Ratio,16:9,4:3;",
	"O[124],Deinterlacer Mode:,Bob,Weave;",
	"O[3:1],Audio Test,Off,44.1k Mono,44.1k Stereo,48k Mono,48k Stereo;",
	"O[126],Audio Output,HDMI,S/PDIF;",
	"O[125],Telemetry,Off,On;",
	"-;",
	"T[0],Reset;",
	"R[0],Reset and close OSD;",
	"v,2;",
	"V,v",`BUILD_DATE
};

wire forced_scandoubler;
wire   [1:0] buttons;
wire [127:0] status;
wire  [10:0] ps2_key;

// AUDIO_FORK_POINT[STREAM_SPLIT]: advisory v0.5.0 handoff, not a permanent ABI.
// ioctl_* currently carries one raw .m2v elementary video stream.  A future
// HPS/container/DVD demux should split compressed audio and video ABOVE this
// decoder boundary: keep mpeg2_stream_* video-only and add a sibling audio FIFO
// with its own data/valid/ready backpressure.  Do not route audio bytes through
// mpeg2_h262_frontend or mpeg2_h262_two_picture_probe in MediaPlayer.sv;
// those modules and their parser/reference state are deliberately video-private.
// ARM -> FPGA MPEG-2 elementary-stream transfer.
wire        ioctl_download;
wire [15:0] ioctl_index;
wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        mpeg2_stream_full;
wire [14:0] mpeg2_burst_credit;
wire        mpeg2_burst_ready, mpeg2_burst_fault;
wire [31:0] mpeg2_burst_words;
wire [15:0] mpeg2_burst_digest;
wire        mpeg2_stream_empty;
wire [7:0]  mpeg2_fifo_data;
wire [7:0]  mpeg2_stream_data;
wire [7:0]  mpeg2_new_extracted_stream_data;
wire        mpeg2_new_system_input_ready;
wire        mpeg2_new_system_input_valid;
wire        mpeg2_stream_rd;
wire        mpeg2_stream_wr;
wire        mpeg2_new_decode_stream_valid;
wire        mpeg2_new_extracted_stream_valid;
wire        mpeg2_new_clean_video_input_ready;
wire        mpeg2_new_stream_ready;
wire        mpeg2_new_decoder_stream_ready;
wire        mpeg2_new_b_presentation_hold;
wire        mpeg2_new_p_destination_ownership_hold;
wire [32:0] mpeg2_new_extracted_pts_90k;
wire        mpeg2_new_extracted_metadata_valid;
wire        mpeg2_new_extracted_metadata_ready;
wire [7:0]  display_record_data;
wire        display_record_start;
wire        display_record_last;
wire        display_record_valid;
wire        display_record_ready;
wire [7:0]  dvd_overlay_record_data;
wire        dvd_overlay_record_start;
wire        dvd_overlay_record_last;
wire        dvd_overlay_record_valid;
wire        dvd_overlay_record_ready;
wire [7:0]  audio_ui_record_data;
wire        audio_ui_record_start;
wire        audio_ui_record_last;
wire        audio_ui_record_valid;
wire        audio_ui_record_ready;
wire        dvd_overlay_extractor_error;
wire        display_record_router_error;
wire [543:0] dvd_overlay_debug_words;
wire         dvd_overlay_debug_commit_seen;

hps_io #(.CONF_STR(CONF_STR), .CONF_STR_BRAM(1), .WIDE(1), .MEDIA_BURST(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),

	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask(0),
	.ps2_key(ps2_key),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),

	.ioctl_wait(ioctl_download &&
	            (mpeg2_stream_full || !mpeg2_burst_ready)),
	.ioctl_burst_credit(mpeg2_burst_credit),
	.ioctl_burst_words(mpeg2_burst_words),
	.ioctl_burst_digest(mpeg2_burst_digest),
	.ioctl_burst_ready(mpeg2_burst_ready && ioctl_download && ioctl_index[5:0] == 6'd1),
	.ioctl_burst_fault(mpeg2_burst_fault)
);

///////////////////////   CLOCKS   ///////////////////////////////

// AUDIO_FORK_POINT[CLOCK_RESET]: advisory v0.5.0 handoff, not a permanent ABI.
// Add audio as a sibling clock/reset consumer.  Reusing clk_mpeg2 is acceptable
// only if its throughput and timing remain suitable; otherwise add an explicit
// audio clock domain and synchronize reset release/CDC using the same discipline
// below.  Audio FIFO readiness must not be ANDed into mpeg2_new_stream_ready:
// routine A/V synchronization belongs above the two independent decoder pipes.
wire clk_sys;
wire clk_video;
wire clk_mpeg2;
wire clk_mpeg2_mem;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(clk_video),
	.outclk_2(clk_mpeg2),
	.outclk_3(clk_mpeg2_mem)
);

// kate - Phase 1P CDC/reset closure.
//
// RESET, status[0], and buttons[1] originate outside the MPEG/video clock
// domains.  Treat their OR as an asynchronous reset request, then synchronize
// reset RELEASE independently into each destination domain.  Assertion is
// asynchronous into these small synchronizer chains, so even a short request
// is stretched until the destination clock has observed it.
//
// This is an implementation/timing-safety change, not an H.262 requirement.
wire reset_request = RESET | status[0] | buttons[1];

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] reset_mpeg2_sync;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] reset_video_sync;

always @(posedge clk_mpeg2 or posedge reset_request) begin
	if (reset_request)
		reset_mpeg2_sync <= 3'b111;
	else
		reset_mpeg2_sync <= {reset_mpeg2_sync[1:0], 1'b0};
end

always @(posedge clk_video or posedge reset_request) begin
	if (reset_request)
		reset_video_sync <= 3'b111;
	else
		reset_video_sync <= {reset_video_sync[1:0], 1'b0};
end

wire reset_mpeg2_base = reset_mpeg2_sync[2];
wire reset_video = reset_video_sync[2];

// Entry 237: every ioctl_download rising edge is a new elementary-stream
// session.  Rearm all MPEG-domain state for the same behavior as a first load,
// while leaving the dual-clock FIFO and video timing on their existing reset
// boundaries.  The rearm output is also an input-read gate below, preventing
// the first newly visible FIFO byte from being consumed on a reset edge.
wire mpeg2_download_rearm_reset;
mpeg2_h262_download_rearm mpeg2_h262_download_rearm
(
	.clk            (clk_mpeg2),
	.reset          (reset_mpeg2_base),
	.download_async (ioctl_download),
	.rearm_reset    (mpeg2_download_rearm_reset)
);

wire reset_mpeg2 = reset_mpeg2_base || mpeg2_download_rearm_reset;

// Entry 395: atomic Audio mode changes cross from clk_sys to clk_mpeg2 and
// CLK_AUDIO through dedicated DCFIFO mailboxes. Entry 410 sends the same reset
// event on every new file download so embedded PCM replay cannot inherit FIFO,
// source, scheduler or underrun state from the prior session.
wire [2:0] audio_test_mode = status[3:1];
reg  [2:0] audio_test_mode_prev;
reg        audio_download_prev;
reg  [4:0] audio_fifo_reset_stretch;

wire audio_mode_change_sys = (audio_test_mode != audio_test_mode_prev);
wire audio_download_start_sys = ioctl_download && !audio_download_prev;
wire audio_control_event_sys =
	audio_mode_change_sys || audio_download_start_sys;

always @(posedge clk_sys or posedge reset_request) begin
	if (reset_request) begin
		audio_test_mode_prev   <= 3'd0;
		audio_download_prev    <= 1'b0;
		audio_fifo_reset_stretch <= 5'd0;
	end
	else begin
		audio_test_mode_prev <= audio_test_mode;
		audio_download_prev  <= ioctl_download;
		if (audio_control_event_sys)
			audio_fifo_reset_stretch <= 5'd31;
		else if (audio_fifo_reset_stretch != 5'd0)
			audio_fifo_reset_stretch <= audio_fifo_reset_stretch - 5'd1;
	end
end

wire audio_fifo_reset_request =
	reset_request || (audio_fifo_reset_stretch != 5'd0);

reg  [2:0] audio_mode_pending_data;
reg        audio_mode_pending_valid;
wire       audio_mode_src_full;
wire       audio_mode_src_empty;
wire [2:0] audio_mode_src_data;
wire       audio_mode_src_wr;
wire       audio_mode_src_rd;
wire       audio_restart_out_full;
wire       audio_restart_out_empty;
wire       audio_restart_out_data;
wire       audio_restart_out_wr;
wire       audio_restart_out_rd;

wire audio_mode_send =
	audio_mode_pending_valid &&
	!audio_mode_src_full &&
	!audio_restart_out_full;

assign audio_mode_src_wr = audio_mode_send;
assign audio_restart_out_wr = audio_mode_send;

always @(posedge clk_sys or posedge reset_request) begin
	if (reset_request) begin
		audio_mode_pending_data  <= 3'd0;
		audio_mode_pending_valid <= 1'b0;
	end
	else if (audio_mode_pending_valid) begin
		if (audio_mode_send) begin
			if (audio_control_event_sys) begin
				audio_mode_pending_data  <= audio_test_mode;
				audio_mode_pending_valid <= 1'b1;
			end
			else begin
				audio_mode_pending_valid <= 1'b0;
			end
		end
		else if (audio_control_event_sys) begin
			audio_mode_pending_data <= audio_test_mode;
		end
	end
	else if (audio_control_event_sys) begin
		audio_mode_pending_data  <= audio_test_mode;
		audio_mode_pending_valid <= 1'b1;
	end
end

dcfifo #(
	.lpm_numwords         (4),
	.lpm_showahead        ("ON"),
	.lpm_type             ("dcfifo"),
	.lpm_width            (3),
	.lpm_widthu           (2),
	.overflow_checking    ("ON"),
	.underflow_checking   ("ON"),
	.use_eab              ("ON"),
	.rdsync_delaypipe     (4),
	.wrsync_delaypipe     (4),
	.write_aclr_synch     ("ON"),
	.read_aclr_synch      ("ON")
) audio_mode_src_fifo
(
	.aclr    (reset_request),
	.data    (audio_mode_pending_data),
	.wrclk   (clk_sys),
	.wrreq   (audio_mode_src_wr),
	.wrfull  (audio_mode_src_full),
	.q       (audio_mode_src_data),
	.rdclk   (clk_mpeg2),
	.rdreq   (audio_mode_src_rd),
	.rdempty (audio_mode_src_empty)
);

dcfifo #(
	.lpm_numwords         (4),
	.lpm_showahead        ("ON"),
	.lpm_type             ("dcfifo"),
	.lpm_width            (1),
	.lpm_widthu           (2),
	.overflow_checking    ("ON"),
	.underflow_checking   ("ON"),
	.use_eab              ("OFF"),
	.rdsync_delaypipe     (4),
	.wrsync_delaypipe     (4),
	.write_aclr_synch     ("ON"),
	.read_aclr_synch      ("ON")
) audio_restart_out_fifo
(
	.aclr    (reset_request),
	.data    (1'b1),
	.wrclk   (clk_sys),
	.wrreq   (audio_restart_out_wr),
	.wrfull  (audio_restart_out_full),
	.q       (audio_restart_out_data),
	.rdclk   (CLK_AUDIO),
	.rdreq   (audio_restart_out_rd),
	.rdempty (audio_restart_out_empty)
);

assign audio_mode_src_rd = !audio_mode_src_empty;
assign audio_restart_out_rd = !audio_restart_out_empty;

reg [6:0] audio_src_reset_count;
reg [2:0] audio_mode_src;

always @(posedge clk_mpeg2) begin
	if (reset_mpeg2_base) begin
		audio_src_reset_count <= 7'd127;
		audio_mode_src        <= 3'd0;
	end
	else begin
		if (audio_src_reset_count != 7'd0)
			audio_src_reset_count <= audio_src_reset_count - 7'd1;

		if (!audio_mode_src_empty) begin
			audio_src_reset_count <= 7'd127;
			audio_mode_src        <= audio_mode_src_data;
		end
	end
end

wire reset_audio_src =
	reset_mpeg2_base || (audio_src_reset_count != 7'd0);

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] reset_audio_out_sync;
reg [6:0] audio_out_reset_count;

always @(posedge CLK_AUDIO or posedge reset_request) begin
	if (reset_request)
		reset_audio_out_sync <= 3'b111;
	else
		reset_audio_out_sync <= {reset_audio_out_sync[1:0], 1'b0};
end

wire reset_audio_out_system = reset_audio_out_sync[2];

always @(posedge CLK_AUDIO) begin
	if (reset_audio_out_system)
		audio_out_reset_count <= 7'd127;
	else if (!audio_restart_out_empty)
		audio_out_reset_count <= 7'd127;
	else if (audio_out_reset_count != 7'd0)
		audio_out_reset_count <= audio_out_reset_count - 7'd1;
end

wire reset_audio_out =
	reset_audio_out_system || (audio_out_reset_count != 7'd0);

wire               audio_pcm_valid;
wire               audio_pcm_ready;
wire signed [15:0] audio_pcm_left;
wire signed [15:0] audio_pcm_right;
wire               audio_pcm_stereo;
wire               audio_pcm_rate_48k;
wire               audio_pcm_end;
wire               audio_pcm_fifo_full;
wire               audio_pcm_fifo_empty;
wire [34:0]        audio_pcm_fifo_data;
wire [13:0]        audio_pcm_fifo_used;
wire [13:0]        audio_pcm_fifo_read_used;
wire               audio_pcm_fifo_rd;
wire               audio_pcm_underrun;
wire               audio_pcm_playback_complete;

wire               audio_test_valid;
wire signed [15:0] audio_test_left;
wire signed [15:0] audio_test_right;
wire               audio_test_stereo;
wire               audio_test_rate_48k;
wire               mpeg2_new_inband_pcm_valid;
wire               mpeg2_new_inband_pcm_end;
wire [15:0]        mpeg2_new_inband_pcm_left;
wire [15:0]        mpeg2_new_inband_pcm_right;
wire               mpeg2_new_inband_pcm_stereo;
wire               mpeg2_new_inband_pcm_rate_48k;
wire               mpeg2_new_inband_pcm_non_audio;
wire               mpeg2_new_inband_pcm_ready;
wire [13:0]        mpeg2_new_inband_pcm_sample_count;
wire               mpeg2_new_inband_pcm_protocol_error;

wire audio_embedded_mode = (audio_mode_src == 3'd0);
wire audio_pcm_accepted = audio_pcm_valid && audio_pcm_ready;

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [1:0] audio_pcm_non_audio_sync;

always @(posedge CLK_AUDIO) begin
	if (reset_audio_out)
		audio_pcm_non_audio_sync <= 2'b00;
	else
		audio_pcm_non_audio_sync <=
			{audio_pcm_non_audio_sync[0],
			 audio_embedded_mode && mpeg2_new_inband_pcm_non_audio};
end

assign AUDIO_SPDIF_NONAUDIO = audio_pcm_non_audio_sync[1];

reg audio_pcm_session_seen;
reg audio_pcm_source_ended;

always @(posedge clk_mpeg2) begin
	if (reset_mpeg2 || reset_audio_src) begin
		audio_pcm_session_seen <= 1'b0;
		audio_pcm_source_ended <= 1'b0;
	end
	else if (audio_embedded_mode && audio_pcm_accepted) begin
		audio_pcm_session_seen <= 1'b1;
		if (audio_pcm_end)
			audio_pcm_source_ended <= 1'b1;
	end
end

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [1:0] audio_pcm_source_ended_sync;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [1:0] audio_pcm_complete_sync;

always @(posedge CLK_AUDIO) begin
	if (reset_audio_out)
		audio_pcm_source_ended_sync <= 2'b00;
	else
		audio_pcm_source_ended_sync <=
			{audio_pcm_source_ended_sync[0], audio_pcm_source_ended};
end

always @(posedge clk_mpeg2) begin
	if (reset_mpeg2 || reset_audio_src)
		audio_pcm_complete_sync <= 2'b00;
	else
		audio_pcm_complete_sync <=
			{audio_pcm_complete_sync[0], audio_pcm_playback_complete};
end

wire audio_pcm_terminal_pending =
	audio_embedded_mode &&
	audio_pcm_session_seen &&
	!audio_pcm_complete_sync[1];

assign audio_pcm_ready = !audio_pcm_fifo_full;
assign mpeg2_new_inband_pcm_ready =
	audio_embedded_mode ? audio_pcm_ready : 1'b1;
assign audio_pcm_valid = audio_embedded_mode ?
	(mpeg2_new_inband_pcm_valid || mpeg2_new_inband_pcm_end) :
	audio_test_valid;
assign audio_pcm_end =
	audio_embedded_mode && mpeg2_new_inband_pcm_end;
assign audio_pcm_left = audio_embedded_mode ?
	$signed(mpeg2_new_inband_pcm_left) : audio_test_left;
assign audio_pcm_right = audio_embedded_mode ?
	$signed(mpeg2_new_inband_pcm_right) : audio_test_right;
assign audio_pcm_stereo = audio_embedded_mode ?
	mpeg2_new_inband_pcm_stereo : audio_test_stereo;
assign audio_pcm_rate_48k = audio_embedded_mode ?
	mpeg2_new_inband_pcm_rate_48k : audio_test_rate_48k;

audio_pcm_test_source audio_pcm_test_source
(
	.clk      (clk_mpeg2),
	.reset    (reset_audio_src),
	.mode     (audio_mode_src),
	.ready    (!audio_embedded_mode && audio_pcm_ready),
	.valid    (audio_test_valid),
	.left     (audio_test_left),
	.right    (audio_test_right),
	.stereo   (audio_test_stereo),
	.rate_48k (audio_test_rate_48k)
);

audio_pcm_fifo audio_pcm_fifo
(
	.reset    (audio_fifo_reset_request),
	.wr_clk   (clk_mpeg2),
	.wr_data  ({audio_pcm_end, audio_pcm_rate_48k, audio_pcm_stereo,
	            audio_pcm_left, audio_pcm_right}),
	.wr_en    (audio_pcm_valid && audio_pcm_ready),
	.wr_full  (audio_pcm_fifo_full),
	.wr_used  (audio_pcm_fifo_used),
	.rd_clk   (CLK_AUDIO),
	.rd_en    (audio_pcm_fifo_rd),
	.rd_data  (audio_pcm_fifo_data),
	.rd_empty (audio_pcm_fifo_empty),
	.rd_used  (audio_pcm_fifo_read_used)
);

audio_pcm_output_adapter audio_pcm_output_adapter
(
	.clk        (CLK_AUDIO),
	.reset      (reset_audio_out),
	.fifo_data  (audio_pcm_fifo_data),
	.fifo_empty (audio_pcm_fifo_empty),
	.fifo_used  (audio_pcm_fifo_read_used),
	.source_ended(audio_pcm_source_ended_sync[1]),
	.fifo_rd    (audio_pcm_fifo_rd),
	.audio_l    (audio_pcm_output_l),
	.audio_r    (audio_pcm_output_r),
	.underrun   (audio_pcm_underrun),
	.playback_complete(audio_pcm_playback_complete)
);

reg [6:0] audio_pcm_fifo_peak;
reg [1:0] audio_pcm_underrun_sync;

// Entry 693: audio starves because the shared transport byte path halts while
// the clean video queue is full, so the quantity that sizes the audio FIFO is
// how long a single block lasts.  Measure it here, where the stall is visible,
// rather than inferring it from a drained FIFO.  The first-error snapshot
// latch reports only the first underrun, so count them instead: a run that
// still starves must say how often, not merely that it did.
reg [31:0] transport_block_longest;
reg [31:0] transport_block_current;
reg [15:0] transport_block_count;
reg [15:0] audio_pcm_underrun_count;
reg [13:0] audio_pcm_fifo_floor;
reg        audio_pcm_floor_armed;

wire transport_blocked =
	mpeg2_new_system_input_valid && !mpeg2_new_system_input_ready;

always @(posedge clk_mpeg2) begin
	if (reset_mpeg2) begin
		audio_pcm_fifo_peak      <= 7'd0;
		audio_pcm_underrun_sync <= 2'b00;
		transport_block_longest  <= 32'd0;
		transport_block_current  <= 32'd0;
		transport_block_count    <= 16'd0;
		audio_pcm_underrun_count <= 16'd0;
		audio_pcm_fifo_floor     <= 14'h3FFF;
		audio_pcm_floor_armed    <= 1'b0;
	end
	else begin
		audio_pcm_underrun_sync <=
			{audio_pcm_underrun_sync[0], audio_pcm_underrun};
		if (audio_pcm_fifo_full || |audio_pcm_fifo_used[13:7])
			audio_pcm_fifo_peak <= 7'h7F;
		else if (audio_pcm_fifo_used[6:0] > audio_pcm_fifo_peak)
			audio_pcm_fifo_peak <= audio_pcm_fifo_used[6:0];

		// Each rising edge of the synchronised underrun is one starvation.
		if (audio_pcm_underrun_sync[0] && !audio_pcm_underrun_sync[1] &&
		    !(&audio_pcm_underrun_count))
			audio_pcm_underrun_count <= audio_pcm_underrun_count + 1'b1;

		// A block is one continuous run of stalled transport bytes.  Close it
		// on the falling edge so only completed runs enter the maximum.
		if (transport_blocked) begin
			if (!(&transport_block_current))
				transport_block_current <= transport_block_current + 1'b1;
		end
		else if (|transport_block_current) begin
			if (transport_block_current > transport_block_longest)
				transport_block_longest <= transport_block_current;
			if (!(&transport_block_count))
				transport_block_count <= transport_block_count + 1'b1;
			transport_block_current <= 32'd0;
		end

		// Track the floor only once the FIFO has filled at least once, so the
		// empty start of a session is not reported as the minimum.
		if (audio_pcm_fifo_used[13:11] != 3'd0)
			audio_pcm_floor_armed <= 1'b1;
		if (audio_pcm_floor_armed && audio_pcm_fifo_used < audio_pcm_fifo_floor)
			audio_pcm_fifo_floor <= audio_pcm_fifo_used;
	end
end

// kate - Phase 1Ob: the streaming H.262 bitreader continues to own input
// backpressure while picture_data() advances across every slice of the first
// supported I-picture.  Slice boundaries remain inside the bitreader so no
// alignment or payload bytes are discarded.
// Before the first slice is selected, bytes flow continuously for start-code/header
// parsing.  During slice parsing the bitreader stalls this FIFO whenever its
// current payload byte has not been fully consumed, including IQ/IDCT waits.
assign mpeg2_stream_wr =
	ioctl_download &&
	ioctl_wr &&
	(ioctl_index[5:0] == 6'd1) &&
	mpeg2_burst_ready &&
	!mpeg2_stream_full;

// Phase 1V: the decoder owns syntax/persistence backpressure, while the top
// level additionally pauses between a persisted B and completion of its proven
// scratch->future-reference presentation transaction. This prevents a later
// P/B pair from overtaking the two-vblank display-order operation.
// kate - Commit 162 adds a second, P-only ownership pause after the following
// picture header has been consumed and classified.  It never blocks the header
// needed to distinguish a consecutive P from a following B.
assign mpeg2_new_stream_ready =
	!mpeg2_download_rearm_reset &&
	mpeg2_new_decoder_stream_ready &&
	!mpeg2_new_b_presentation_hold &&
	!mpeg2_new_p_destination_ownership_hold;

// Entry 217: downstream raster and DDR errors are sticky, but their engines
// cannot produce the persistence acknowledgement that normally releases the
// parser.  Drain the transport after any such fatal result without presenting
// discarded bytes as valid decoder input.  This lets ioctl_download retire so
// the existing post-load LED snapshot can report the first failure.
// Entry 369: synchronise the file-transfer lifetime into the decoder domain
// so the metadata extractor can flush its residual window.  Without this
// the final three bytes of every stream would stay in the window and the
// sequence_end_code would never reach the decoder.
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] mpeg2_download_active_sync;
always @(posedge clk_mpeg2 or posedge reset_mpeg2_base) begin
	if (reset_mpeg2_base)
		mpeg2_download_active_sync <= 3'b000;
	else
		mpeg2_download_active_sync <=
			{mpeg2_download_active_sync[1:0],ioctl_download};
end

wire mpeg2_new_system_input_end =
	!mpeg2_download_active_sync[2] &&
	!mpeg2_download_rearm_reset &&
	mpeg2_stream_empty;

wire mpeg2_new_transport_fatal_error =
	mpeg2_new_syntax_error ||
	mpeg2_new_phase1_probe_error ||
	mpeg2_new_pred_error ||
	mpeg2_new_inverse_quant_error ||
	mpeg2_new_inverse_quant_unsupported_matrix ||
	mpeg2_new_idct_error ||
	mpeg2_new_recon_error ||
	mpeg2_new_ddr_store_error ||
	mpeg2_new_ddr_cache_error ||
	mpeg2_new_b_presentation_error;

mpeg2_h262_stream_transport_gate mpeg2_h262_stream_transport_gate
(
	.clk              (clk_mpeg2),
	.reset            (reset_mpeg2),
	.fifo_empty       (mpeg2_stream_empty),
	.decoder_ready    (mpeg2_new_system_input_ready),
	.fatal_error      (mpeg2_new_transport_fatal_error),
	.fifo_read        (mpeg2_stream_rd),
	.decoder_valid    (mpeg2_new_system_input_valid)
);

mpeg2_h262_inband_metadata mpeg2_h262_inband_metadata
(
	.clk                (clk_mpeg2),
	.reset              (reset_mpeg2),
	.input_data         (mpeg2_fifo_data),
	.input_valid        (mpeg2_new_system_input_valid),
	.input_ready        (mpeg2_new_system_input_ready),
	.input_end          (mpeg2_new_system_input_end),
	.stream_data        (mpeg2_new_extracted_stream_data),
	.stream_valid       (mpeg2_new_extracted_stream_valid),
	.stream_ready       (mpeg2_new_clean_video_input_ready),
	.pts_90k            (mpeg2_new_extracted_pts_90k),
	.picture_structure  (mpeg2_new_inband_picture_structure),
	.top_field_first    (mpeg2_new_inband_top_field_first),
	.repeat_first_field (mpeg2_new_inband_repeat_first_field),
	.progressive_frame  (mpeg2_new_inband_progressive_frame),
	.metadata_valid     (mpeg2_new_extracted_metadata_valid),
	.metadata_ready     (mpeg2_new_extracted_metadata_ready),
	.metadata_count     (mpeg2_new_inband_count),
	.pcm_left           (mpeg2_new_inband_pcm_left),
	.pcm_right          (mpeg2_new_inband_pcm_right),
	.pcm_stereo         (mpeg2_new_inband_pcm_stereo),
	.pcm_rate_48k       (mpeg2_new_inband_pcm_rate_48k),
	.pcm_non_audio      (mpeg2_new_inband_pcm_non_audio),
	.pcm_valid          (mpeg2_new_inband_pcm_valid),
	.pcm_end            (mpeg2_new_inband_pcm_end),
	.pcm_ready          (mpeg2_new_inband_pcm_ready),
	.pcm_sample_count   (mpeg2_new_inband_pcm_sample_count),
	.pcm_protocol_error (mpeg2_new_inband_pcm_protocol_error),
	.overlay_data       (display_record_data),
	.overlay_start      (display_record_start),
	.overlay_last       (display_record_last),
	.overlay_valid      (display_record_valid),
	.overlay_ready      (display_record_ready),
	.overlay_protocol_error(dvd_overlay_extractor_error)
);

mpeg2_h262_display_record_router mpeg2_h262_display_record_router
(
    .clk(clk_mpeg2),.reset(reset_mpeg2),
    .record_data(display_record_data),
    .record_start(display_record_start),
    .record_last(display_record_last),
    .record_valid(display_record_valid),
    .record_ready(display_record_ready),
    .dvd_data(dvd_overlay_record_data),
    .dvd_start(dvd_overlay_record_start),
    .dvd_last(dvd_overlay_record_last),
    .dvd_valid(dvd_overlay_record_valid),
    .dvd_ready(dvd_overlay_record_ready),
    .ui_data(audio_ui_record_data),
    .ui_start(audio_ui_record_start),
    .ui_last(audio_ui_record_last),
    .ui_valid(audio_ui_record_valid),
    .ui_ready(audio_ui_record_ready),
    .protocol_error(display_record_router_error)
);

wire mpeg2_new_clean_video_pending;
mpeg2_h262_clean_video_queue mpeg2_h262_clean_video_queue
(
	.clk                   (clk_mpeg2),
	.reset                 (reset_mpeg2),
	.input_data            (mpeg2_new_extracted_stream_data),
	.input_valid           (mpeg2_new_extracted_stream_valid),
	.input_ready           (mpeg2_new_clean_video_input_ready),
	.input_metadata_pts    (mpeg2_new_extracted_pts_90k),
	.input_metadata_valid  (mpeg2_new_extracted_metadata_valid),
	.input_metadata_ready  (mpeg2_new_extracted_metadata_ready),
	.output_data           (mpeg2_stream_data),
	.output_valid          (mpeg2_new_decode_stream_valid),
	.output_ready          (mpeg2_new_stream_ready),
	.output_pending_debug  (mpeg2_new_clean_video_pending),
	.output_metadata_pts   (mpeg2_new_inband_pts_90k),
	.output_metadata_valid (mpeg2_new_inband_valid)
);

mpeg2_stream_fifo mpeg2_stream_fifo
(
	// kate - DCFIFO owns reset-release synchronization for wr_clk and rd_clk.
	.reset    (reset_request),
	// Every rising download edge starts a logically independent elementary
	// stream.  Flush bytes retained from the prior stream before accepting the
	// first new word; burst_ready keeps both legacy wait and burst transport
	// backpressured through the FIFO's synchronized reset release.
	.session_start(audio_download_start_sys),

	.wr_clk   (clk_sys),
	.wr_data  (mpeg2_stream_wr ? ioctl_dout : 16'd0),
	.wr_en    (mpeg2_stream_wr),
	.wr_full  (mpeg2_stream_full),
	.wr_attempt(ioctl_download && ioctl_wr && ioctl_index[5:0] == 6'd1),
	.burst_credit(mpeg2_burst_credit),
	.burst_ready(mpeg2_burst_ready),
	.burst_fault(mpeg2_burst_fault),
	.burst_words(mpeg2_burst_words),
	.burst_digest(mpeg2_burst_digest),

	.rd_clk   (clk_mpeg2),
	.rd_en    (mpeg2_stream_rd),
	.rd_data  (mpeg2_fifo_data),
	.rd_empty (mpeg2_stream_empty)
);

// AUDIO_FORK_POINT[DDR_CLIENT]: advisory v0.5.0 handoff, not a permanent ABI.
// If audio eventually needs external buffering, integrate it as an explicit
// additional DDR client at mpeg2_h262_ddram_arbiter in MediaPlayer.sv
// (or a successor system arbiter).  Allocate a separate address region and
// preserve the video writer/reader/prediction response ownership and the
// [17:16] frame-region protection.  Never reuse P/B prediction request signals
// as an implicit audio transport.  Prefer on-chip FIFO/RAM when practical.
// The DDR service and Phase 1S/1T clients run in the decoder clock domain.
assign DDRAM_CLK = clk_mpeg2;

///////////////////////   VIDEO TIMING   /////////////////////////

// AUDIO_FORK_POINT[AV_SYNC]: advisory v0.5.0 handoff, not a permanent ABI.
// Future A/V synchronization should observe the presentation side, not H.262
// syntax state.  Useful starting signals are display_v_pos here plus
// mpeg2_new_swap_window_pulse / mpeg2_new_b_presentation_complete in
// MediaPlayer.sv and the actual framebuffer swap in MediaPlayer.sv.  Export a
// clean video-present/timebase event to a higher-level A/V controller; let that
// controller use timestamps/buffer occupancy/drop-repeat policy rather than
// directly stalling either codec's internal parser for normal synchronization.
wire [11:0] display_h_pos;
wire [11:0] display_v_pos;
wire        display_pixel_ce;
wire        display_pixel_en;
wire        display_h_sync;
wire        display_v_sync;
wire        display_field;
wire        display_field_window;
wire        display_frame_window;
wire        display_field_swap_window;
wire        display_native_interlaced;
wire        display_hdmi_bob_deinterlace;
wire        mpeg2_new_native_active_mpeg2;

// MiSTer's scaler consumes this request only on its processed HDMI path.
// Direct video continues to carry the core's native interlaced timing.
assign HDMI_BOB_DEINT = display_hdmi_bob_deinterlace;

wire [7:0]  fb_video_r;
wire [7:0]  fb_video_g;
wire [7:0]  fb_video_b;
wire        fb_video_de;
wire        fb_video_hs;
wire        fb_video_vs;
wire [7:0]  presentation_base_r;
wire [7:0]  presentation_base_g;
wire [7:0]  presentation_base_b;
wire        presentation_base_de;
wire        presentation_base_hs;
wire        presentation_base_vs;
wire [7:0]  cadence_video_r;
wire [7:0]  cadence_video_g;
wire [7:0]  cadence_video_b;
wire [7:0]  dvd_overlay_video_r;
wire [7:0]  dvd_overlay_video_g;
wire [7:0]  dvd_overlay_video_b;
wire        cadence_snapshot_ready;

// ---------------------------------------------------------------------------
// Entry 389: presentation time base.
//
// The 90 kHz System Time Clock of H.222.0 is anchored to CLK_AUDIO (24.576
// MHz), the same domain sys/audio_out.sv clocks samples out on, so externally
// decoded audio will be consumed drift-free by construction once the PCM sink
// exists.  Entry 425 correction: this is no longer true.  Since the PTS
// timeline was wired in at MediaPlayer.sv, presentation is not
// free-running -- mpeg2_h262_pts_presentation_timeline drives the scheduler's
// timestamp admission gate, so timestamped pictures wait for this clock.
//
// Only a single bit crosses domains.  A multi-bit counter synchronised into
// clk_mpeg2 could tear across a carry, and a 33-bit gray decode would be a
// 33-level XOR chain -- a new timing problem on a design that just spent this
// development run recovering margin.  Instead the clock emits single-bit
// 90 kHz and 1 Hz pulses.  Each crosses through an ordinary synchroniser; the
// former advances the decoder-domain presentation timeline and the latter
// remains the cadence profiler's human-readable seconds counter.
// ---------------------------------------------------------------------------
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [1:0] stc_audio_reset_sync;
always @(posedge CLK_AUDIO or posedge reset_mpeg2_base) begin
	if (reset_mpeg2_base) stc_audio_reset_sync <= 2'b11;
	else                  stc_audio_reset_sync <= {stc_audio_reset_sync[0],1'b0};
end
wire stc_audio_reset = stc_audio_reset_sync[1];

wire        stc_pulse_1hz;
wire        stc_tick_90k_audio;
wire [32:0] stc_90k_value;

mpeg2_h262_system_time_clock mpeg2_h262_system_time_clock
(
	.clk           (CLK_AUDIO),
	.reset         (stc_audio_reset),
	.run           (1'b1),
	.load_valid    (1'b0),
	.load_value    (33'd0),
	.stc_90k       (stc_90k_value),
	.tick_90k      (stc_tick_90k_audio),
	.stc_180k_half (),
	.pulse_1hz     (stc_pulse_1hz)
);

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] stc_pulse_sync;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] stc_tick_90k_sync;
reg [13:0] mpeg2_new_stc_seconds;
wire mpeg2_new_stc_tick_90k =
	(stc_tick_90k_sync[2:1] == 2'b01);
always @(posedge clk_mpeg2) begin
	if (reset_mpeg2) begin
		stc_pulse_sync        <= 3'b000;
		stc_tick_90k_sync     <= 3'b000;
		mpeg2_new_stc_seconds <= 14'd0;
	end
	else begin
		stc_pulse_sync <= {stc_pulse_sync[1:0],stc_pulse_1hz};
		stc_tick_90k_sync <= {stc_tick_90k_sync[1:0],stc_tick_90k_audio};
		if (stc_pulse_sync[2:1] == 2'b01)
			mpeg2_new_stc_seconds <= mpeg2_new_stc_seconds + 14'd1;
	end
end
mpeg2_video_output_timing mpeg2_video_output_timing
(
	.clk                     (clk_video),
	.reset                   (reset_video),
	.interlaced_request_async(mpeg2_new_native_480i_request),
	.top_field_first_async   (mpeg2_new_native_top_field_first),
	.interlaced_active       (display_native_interlaced),
	.ce_pixel                (display_pixel_ce),
	.h_pos                   (display_h_pos),
	.v_pos                   (display_v_pos),
	.pixel_en                (display_pixel_en),
	.h_sync                  (display_h_sync),
	.v_sync                  (display_v_sync),
	.field                   (display_field),
	.field_window            (display_field_window),
	.field_swap_window       (display_field_swap_window),
	.frame_window            (display_frame_window)
);

mpeg2_hdmi_deinterlace_control mpeg2_hdmi_deinterlace_control
(
	.clk                     (clk_video),
	.reset                   (reset_video),
	.native_interlaced       (display_native_interlaced),
	.bob_selected_async      (!status[124]),
	.hdmi_bob_deint          (display_hdmi_bob_deinterlace)
);

///////////////////////   NEW H.262 DECODER   ////////////////////

wire        mpeg2_new_frontend_ready;
wire        mpeg2_new_phase1_supported;
wire        mpeg2_new_syntax_error;
wire [4:0]  mpeg2_new_syntax_error_source;
wire        mpeg2_new_sequence_seen;
wire        mpeg2_new_sequence_extension_seen;
wire        mpeg2_new_sequence_scalable_extension_seen;
wire        mpeg2_new_picture_seen;
wire        mpeg2_new_picture_coding_extension_seen;
wire        mpeg2_new_picture_coding_extension_valid;
wire        mpeg2_new_picture_coding_extension_top_field_first;
wire        mpeg2_new_slice_seen;
wire        mpeg2_new_sequence_end_seen;
wire [13:0] mpeg2_new_horizontal_size;
wire [13:0] mpeg2_new_vertical_size;
wire [3:0]  mpeg2_new_aspect_ratio_information;
wire [3:0]  mpeg2_new_frame_rate_code;
wire [7:0]  mpeg2_new_profile_and_level_indication;
wire        mpeg2_new_progressive_sequence;
wire [1:0]  mpeg2_new_chroma_format;
wire [9:0]  mpeg2_new_temporal_reference;
wire [2:0]  mpeg2_new_picture_coding_type;
wire [1:0]  mpeg2_new_intra_dc_precision;
wire [1:0]  mpeg2_new_picture_structure;
wire        mpeg2_new_frame_pred_frame_dct;
// Entry 650: field-ordered luma blocks for the macroblock being submitted.
wire        mpeg2_new_dct_type;
wire        mpeg2_new_concealment_motion_vectors;
wire        mpeg2_new_q_scale_type;
wire        mpeg2_new_intra_vlc_format;
wire        mpeg2_new_alternate_scan;
wire        mpeg2_new_progressive_frame;
wire        mpeg2_new_chroma_420_type;
// Picture field-order and repeat metadata feed native film presentation.
wire        mpeg2_new_top_field_first;
wire        mpeg2_new_native_film_mode;
wire        mpeg2_new_native_progressive_supported;
wire        mpeg2_new_native_film_supported;
wire        mpeg2_new_native_480i_supported;
wire        mpeg2_new_pce_repeat_first_field, mpeg2_new_pce_progressive_frame;
wire        mpeg2_new_native_field_order_locked;
wire        mpeg2_new_native_top_field_first;
wire        mpeg2_new_native_field_order_mismatch;

mpeg2_h262_native_field_order mpeg2_h262_native_field_order
(
	.clk                            (clk_mpeg2),
	.reset                          (reset_mpeg2),
	.picture_coding_extension_valid (mpeg2_new_picture_coding_extension_valid),
	.progressive_sequence           (mpeg2_new_progressive_sequence),
	.picture_top_field_first        (mpeg2_new_picture_coding_extension_top_field_first),
	.picture_progressive_frame      (mpeg2_new_pce_progressive_frame),
	.film_mode                      (mpeg2_new_native_film_mode),
	.locked                         (mpeg2_new_native_field_order_locked),
	.top_field_first                (mpeg2_new_native_top_field_first),
	.mismatch                       (mpeg2_new_native_field_order_mismatch)
);

wire mpeg2_new_native_480i_request =
    (mpeg2_new_phase1_supported ||
     mpeg2_new_native_480i_supported ||
     mpeg2_new_native_film_supported) &&
	!mpeg2_new_progressive_sequence &&
	mpeg2_new_native_field_order_locked &&
	!mpeg2_new_native_field_order_mismatch;
wire mpeg2_new_presentation_request =
    mpeg2_new_progressive_sequence ?
        mpeg2_new_native_progressive_supported :
        mpeg2_new_native_480i_request;
// Entry 369: picture metadata supplied by the HPS in band with the
// elementary stream.  Distinct from the frontend's parsed fields above:
// these come from the container, those from the bitstream.
wire [32:0] mpeg2_new_inband_pts_90k;
wire [1:0]  mpeg2_new_inband_picture_structure;
wire        mpeg2_new_inband_top_field_first;
wire        mpeg2_new_inband_repeat_first_field;
wire        mpeg2_new_inband_progressive_frame;
wire        mpeg2_new_inband_valid;
wire [7:0]  mpeg2_new_inband_count;
// Entry 372: timestamps carried through frame ownership to the displayed frame.
wire [32:0] mpeg2_new_display_pts;
wire        mpeg2_new_display_pts_valid;
wire        mpeg2_new_display_top_field_first;
wire        mpeg2_new_display_repeat_first_field, mpeg2_new_display_progressive_frame;
wire        mpeg2_new_display_descriptor_valid, mpeg2_new_candidate_top_field_first;
wire [7:0]  mpeg2_new_associated_count;
// Entry 389: timestamp-driven candidate presentation.  The scheduler exports
// only its already-stable next identity; timestamp ownership supplies the
// matching bank value and the local 90 kHz timeline decides when it is due.
wire        mpeg2_new_candidate_frame_valid;
wire        mpeg2_new_candidate_frame_scratch;
wire        mpeg2_new_candidate_scratch_bank;
wire [1:0]  mpeg2_new_candidate_frame_bank;
wire [32:0] mpeg2_new_candidate_pts;
wire        mpeg2_new_candidate_pts_valid;
wire        mpeg2_new_timestamp_candidate_active;
wire        mpeg2_new_timestamp_candidate_due;
wire        mpeg2_new_pts_timeline_anchored;
wire [32:0] mpeg2_new_pts_timeline_stc;
wire        mpeg2_new_repeat_first_field;
wire [3:0]  mpeg2_new_forward_f_code_horizontal;
wire [3:0]  mpeg2_new_forward_f_code_vertical;
wire [3:0]  mpeg2_new_backward_f_code_horizontal;
wire [3:0]  mpeg2_new_backward_f_code_vertical;
wire        mpeg2_new_motion_f_code_seen;
wire        mpeg2_new_intra_quant_matrix_default;

wire        mpeg2_new_slice_header_seen;
wire        mpeg2_new_macroblock_address_seen;
wire        mpeg2_new_first_i_macroblock_seen;
wire        mpeg2_new_first_luma_dc_seen;
wire        mpeg2_new_first_luma_block_complete;
wire        mpeg2_new_first_picture_420_parsed;
wire        mpeg2_new_second_picture_420_parsed;
wire        mpeg2_new_picture_420_complete;
wire [1:0]  mpeg2_new_active_frame_bank;
wire [1:0]  mpeg2_new_completed_frame_bank;
wire [7:0]  mpeg2_new_picture_count;
wire        mpeg2_new_reference_frame_valid;
wire [1:0]  mpeg2_new_reference_frame_bank;
wire [1:0]  mpeg2_new_previous_reference_frame_bank;
wire [7:0]  mpeg2_new_reference_promotion_count;
wire        mpeg2_new_p_macroblock_type_seen;
wire        mpeg2_new_p_forward_vector_valid;
wire signed [12:0] mpeg2_new_p_forward_vector_x;
wire signed [12:0] mpeg2_new_p_forward_vector_y;
wire        mpeg2_new_p_residual_required;
wire        mpeg2_new_p_residual_success;
wire        mpeg2_new_p_first_residual_sample_valid;
wire signed [15:0] mpeg2_new_p_first_residual_sample_value;
wire        mpeg2_new_p_residual_sample_valid;
wire [5:0]  mpeg2_new_p_residual_sample_index;
wire signed [15:0] mpeg2_new_p_residual_sample_value;
wire        mpeg2_new_b_motion_transport;
wire        mpeg2_new_slice_start;
wire        mpeg2_new_luma_macroblock_start;
wire        mpeg2_new_phase1_probe_error;
wire [3:0]  mpeg2_new_phase1_probe_error_source;
// kate - Commit 180 observability only.
wire [3:0]  mpeg2_new_p_probe_error_source;
wire [3:0]  mpeg2_new_p_progress_detail;
wire [2:0]  mpeg2_new_publication_error_detail;
wire [4:0]  mpeg2_new_p_wide_probe_error_detail;
wire        mpeg2_new_b_user_success;
wire [4:0]  mpeg2_new_slice_quantiser_scale_code;
wire [11:0] mpeg2_new_macroblock_address_increment;
wire        mpeg2_new_macroblock_quant;
wire [4:0]  mpeg2_new_macroblock_quantiser_scale_code;
wire [7:0]  mpeg2_new_slice_vertical_position;
wire [2:0]  mpeg2_new_slice_vertical_position_extension;
wire [3:0]  mpeg2_new_first_luma_dc_size;
wire signed [12:0] mpeg2_new_first_luma_dc_differential;
wire [10:0] mpeg2_new_first_luma_dc_coefficient;
wire [6:0]  mpeg2_new_first_luma_ac_nonzero_count;
wire [5:0]  mpeg2_new_first_luma_last_coeff_index;
wire signed [11:0] mpeg2_new_first_luma_last_ac_level;
wire [2:0]  mpeg2_new_qfs_block_index;
wire        mpeg2_new_qfs_block_start;
wire        mpeg2_new_qfs_write_en;
wire [5:0]  mpeg2_new_qfs_write_index;
wire signed [12:0] mpeg2_new_qfs_write_value;
wire        mpeg2_new_qfs_block_end;

wire        mpeg2_new_inverse_quant_complete;
wire        mpeg2_new_inverse_quant_error;
wire        mpeg2_new_inverse_quant_unsupported_matrix;
wire signed [11:0] mpeg2_new_first_luma_f00;
wire signed [11:0] mpeg2_new_first_luma_f77;
wire        mpeg2_new_iq_coeff_block_start;
wire        mpeg2_new_iq_coeff_valid;
wire [5:0]  mpeg2_new_iq_coeff_index;
wire signed [11:0] mpeg2_new_iq_coeff_value;
wire        mpeg2_new_iq_coeff_block_end;

wire        mpeg2_new_idct_complete;
wire        mpeg2_new_idct_error;
wire        mpeg2_new_idct_sample_valid;
wire [5:0]  mpeg2_new_idct_sample_index;
wire signed [15:0] mpeg2_new_idct_sample_value;
wire signed [15:0] mpeg2_new_first_luma_sample00;
wire signed [15:0] mpeg2_new_first_luma_sample77;

wire        mpeg2_new_recon_pixel_valid;
wire [1:0]  mpeg2_new_recon_pixel_component;
wire [11:0] mpeg2_new_recon_pixel_x;
wire [11:0] mpeg2_new_recon_pixel_y;
wire [7:0]  mpeg2_new_recon_pixel_value;
wire        mpeg2_new_recon_block_start;
wire        mpeg2_new_recon_block_complete;
wire        mpeg2_new_recon_macroblock_420_complete;
wire        mpeg2_new_recon_error;
wire [11:0] mpeg2_new_recon_block_origin_x;
wire [11:0] mpeg2_new_recon_block_origin_y;

wire        mpeg2_new_ddr_block_stored;
// Entry 546: writer capacity acknowledgement, distinct from DDR completion.
wire        mpeg2_new_ddr_block_accepted;
wire        mpeg2_new_ddr_capture_blocked;
wire        mpeg2_new_ddr_write_seen;
wire        mpeg2_new_ddr_store_error;

wire [7:0]  mpeg2_new_ddr_wr_burstcnt;
wire [28:0] mpeg2_new_ddr_wr_addr;
wire        mpeg2_new_ddr_wr_rd;
wire [63:0] mpeg2_new_ddr_wr_din;
wire [7:0]  mpeg2_new_ddr_wr_be;
wire        mpeg2_new_ddr_wr_we;
wire        mpeg2_new_ddr_writer_busy;

wire [7:0]  mpeg2_new_ddr_rd_burstcnt;
wire [28:0] mpeg2_new_ddr_rd_addr;
wire [28:0] mpeg2_new_ddr_rd_banked_addr;
wire        mpeg2_new_ddr_rd;
wire        mpeg2_new_ddr_reader_busy;
wire        mpeg2_new_ddr_reader_dout_ready;

wire [7:0]  dvd_overlay_writer_burstcnt;
wire [28:0] dvd_overlay_writer_addr;
wire        dvd_overlay_writer_rd;
wire [63:0] dvd_overlay_writer_din;
wire [7:0]  dvd_overlay_writer_be;
wire        dvd_overlay_writer_we;
wire        dvd_overlay_writer_busy;
wire [7:0]  dvd_overlay_reader_burstcnt;
wire [28:0] dvd_overlay_reader_addr;
wire        dvd_overlay_reader_rd;
wire        dvd_overlay_reader_busy;
wire        dvd_overlay_reader_dout_ready;
wire        dvd_overlay_engine_error;

wire [7:0]  audio_ui_writer_burstcnt;
wire [28:0] audio_ui_writer_addr;
wire        audio_ui_writer_rd;
wire [63:0] audio_ui_writer_din;
wire [7:0]  audio_ui_writer_be;
wire        audio_ui_writer_we;
wire        audio_ui_writer_busy;
wire        audio_ui_writer_accept;
wire        audio_ui_protocol_error;
wire        audio_ui_mode_active;
wire        audio_ui_loading_active;
wire        audio_ui_initial_loading_mpeg2 =
    audio_ui_loading_active && !audio_ui_mode_active;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] audio_ui_initial_loading_video_sync;

always @(posedge clk_video) begin
    if (reset_video)
        audio_ui_initial_loading_video_sync <= 3'b000;
    else
        audio_ui_initial_loading_video_sync <=
            {audio_ui_initial_loading_video_sync[1:0],
             audio_ui_initial_loading_mpeg2};
end

wire audio_ui_initial_loading_video =
    audio_ui_initial_loading_video_sync[2];
wire        audio_ui_display_bank;
wire        audio_ui_picture_publish;
wire [15:0] audio_ui_committed_frames;

wire [7:0]  mpeg2_new_pred_burstcnt;
wire [28:0] mpeg2_new_pred_addr;
wire        mpeg2_new_pred_rd;
wire        mpeg2_new_pred_busy;
wire        mpeg2_new_pred_dout_ready;
wire        mpeg2_new_pred_read_seen;
wire [7:0]  mpeg2_new_pred_sample_value;
wire        mpeg2_new_pred_sample_nonzero;
wire        mpeg2_new_pred_half_sample_seen;
wire        mpeg2_new_pred_reconstructed_seen;
wire [7:0]  mpeg2_new_pred_reconstructed_value;
wire        mpeg2_new_pred_persisted_seen;
wire        mpeg2_new_pred_row_persisted;
wire [3:0]  mpeg2_new_pred_progress_stage;
wire        mpeg2_new_pred_error;
wire [2:0]  mpeg2_new_pred_error_source;
wire [4:0]  mpeg2_new_pred_error_detail;

wire        mpeg2_new_p_store_select;
wire [7:0]  mpeg2_new_p_store_pixel_value;
wire [11:0] mpeg2_new_p_store_pixel_x;
wire [11:0] mpeg2_new_p_store_pixel_y;
wire        mpeg2_new_p_store_pixel_valid;
wire        mpeg2_new_p_store_block_start;
wire        mpeg2_new_p_store_block_complete;
wire        mpeg2_new_p_store_field_dct;
reg         mpeg2_new_b_decode_scratch_bank;

wire        mpeg2_new_ddr_cache_ready;
wire        mpeg2_new_ddr_read_seen;
wire        mpeg2_new_ddr_cache_error;
wire        mpeg2_new_ddr_bank_overlap_error;

wire [4:0] mpeg2_new_effective_quantiser_scale_code =
	mpeg2_new_macroblock_quant ?
		mpeg2_new_macroblock_quantiser_scale_code :
		mpeg2_new_slice_quantiser_scale_code;

wire mpeg2_new_phase1n_frame_geometry_supported =
	(mpeg2_new_horizontal_size != 14'd0) &&
	(mpeg2_new_vertical_size   != 14'd0) &&
	(mpeg2_new_horizontal_size <= 14'd720) &&
	(mpeg2_new_vertical_size   <= 14'd480);

mpeg2_h262_frontend mpeg2_h262_frontend
(
    .native_progressive_supported(mpeg2_new_native_progressive_supported),
    .native_film_supported(mpeg2_new_native_film_supported),
    .native_480i_supported(mpeg2_new_native_480i_supported),
    .picture_coding_extension_repeat_first_field(mpeg2_new_pce_repeat_first_field),
    .picture_coding_extension_progressive_frame(mpeg2_new_pce_progressive_frame),
	.clk                              (clk_mpeg2),
	.reset                            (reset_mpeg2),
	.stream_data                      (mpeg2_stream_data),
	.stream_valid                     (mpeg2_new_decode_stream_valid),
	.frontend_ready                   (mpeg2_new_frontend_ready),
	.phase1_supported                 (mpeg2_new_phase1_supported),
	.syntax_error                     (mpeg2_new_syntax_error),
	.syntax_error_source              (mpeg2_new_syntax_error_source),
	.sequence_seen                    (mpeg2_new_sequence_seen),
	.sequence_extension_seen          (mpeg2_new_sequence_extension_seen),
	.sequence_scalable_extension_seen (mpeg2_new_sequence_scalable_extension_seen),
	.picture_seen                     (mpeg2_new_picture_seen),
	.picture_coding_extension_seen    (mpeg2_new_picture_coding_extension_seen),
	.picture_coding_extension_valid   (mpeg2_new_picture_coding_extension_valid),
	.picture_coding_extension_top_field_first(mpeg2_new_picture_coding_extension_top_field_first),
	.slice_seen                       (mpeg2_new_slice_seen),
	.sequence_end_seen                (mpeg2_new_sequence_end_seen),
	.horizontal_size                  (mpeg2_new_horizontal_size),
	.vertical_size                    (mpeg2_new_vertical_size),
	.aspect_ratio_information         (mpeg2_new_aspect_ratio_information),
	.frame_rate_code                  (mpeg2_new_frame_rate_code),
	.profile_and_level_indication     (mpeg2_new_profile_and_level_indication),
	.progressive_sequence             (mpeg2_new_progressive_sequence),
	.chroma_format                    (mpeg2_new_chroma_format),
	.temporal_reference               (mpeg2_new_temporal_reference),
	.picture_coding_type              (mpeg2_new_picture_coding_type),
	.intra_dc_precision               (mpeg2_new_intra_dc_precision),
	.picture_structure                (mpeg2_new_picture_structure),
	.frame_pred_frame_dct             (mpeg2_new_frame_pred_frame_dct),
	.concealment_motion_vectors       (mpeg2_new_concealment_motion_vectors),
	.q_scale_type                     (mpeg2_new_q_scale_type),
	.intra_vlc_format                 (mpeg2_new_intra_vlc_format),
	.alternate_scan                   (mpeg2_new_alternate_scan),
	.progressive_frame                (mpeg2_new_progressive_frame),
	.chroma_420_type                  (mpeg2_new_chroma_420_type),
	.top_field_first                  (mpeg2_new_top_field_first),
	.repeat_first_field               (mpeg2_new_repeat_first_field),
	.forward_f_code_horizontal        (mpeg2_new_forward_f_code_horizontal),
	.forward_f_code_vertical          (mpeg2_new_forward_f_code_vertical),
	.backward_f_code_horizontal       (mpeg2_new_backward_f_code_horizontal),
	.backward_f_code_vertical         (mpeg2_new_backward_f_code_vertical),
	.motion_f_code_seen               (mpeg2_new_motion_f_code_seen),
	.intra_quant_matrix_default       (mpeg2_new_intra_quant_matrix_default)
);

mpeg2_h262_two_picture_probe mpeg2_h262_two_picture_probe
(
	.clk                         (clk_mpeg2),
	.reset                       (reset_mpeg2),
	.stream_data                 (mpeg2_stream_data),
	.stream_valid                (mpeg2_new_decode_stream_valid),
	.stream_ready                (mpeg2_new_decoder_stream_ready),
	.phase1_supported            (mpeg2_new_phase1_supported),
	.vertical_size               (mpeg2_new_vertical_size),
	.frame_pred_frame_dct        (mpeg2_new_frame_pred_frame_dct),
	.dct_type                    (mpeg2_new_dct_type),
	.intra_dc_precision          (mpeg2_new_intra_dc_precision),
	.intra_vlc_format            (mpeg2_new_intra_vlc_format),
	// Entry 599: release ST_WAIT_PIPELINE with one capacity grant per completed
	// capture, immediately when the alternate bank is free or after it drains.
	// This is a completion-qualified pulse, not an idle capacity level; DDR
	// persistence consumers continue to use block_stored separately.
	.pipeline_block_done         (mpeg2_new_ddr_block_accepted),
	.recon_block_complete        (mpeg2_new_recon_block_complete),
	.p_persistence_complete      (mpeg2_new_pred_persisted_seen),
	.p_row_persistence_complete  (mpeg2_new_pred_row_persisted),
	.slice_header_seen           (mpeg2_new_slice_header_seen),
	.macroblock_address_seen     (mpeg2_new_macroblock_address_seen),
	.first_i_macroblock_seen     (mpeg2_new_first_i_macroblock_seen),
	.first_luma_dc_seen          (mpeg2_new_first_luma_dc_seen),
	.first_luma_block_complete   (mpeg2_new_first_luma_block_complete),
	.first_picture_420_parsed    (mpeg2_new_first_picture_420_parsed),
	.second_picture_420_parsed   (mpeg2_new_second_picture_420_parsed),
	.picture_420_complete        (mpeg2_new_picture_420_complete),
	.active_frame_bank           (mpeg2_new_active_frame_bank),
	.completed_frame_bank        (mpeg2_new_completed_frame_bank),
	.picture_count               (mpeg2_new_picture_count),
	.reference_frame_valid       (mpeg2_new_reference_frame_valid),
	.reference_frame_bank        (mpeg2_new_reference_frame_bank),
	.previous_reference_frame_bank(mpeg2_new_previous_reference_frame_bank),
	.reference_promotion_count   (mpeg2_new_reference_promotion_count),
	.p_macroblock_type_seen      (mpeg2_new_p_macroblock_type_seen),
	.p_forward_vector_valid      (mpeg2_new_p_forward_vector_valid),
	.p_forward_vector_x          (mpeg2_new_p_forward_vector_x),
	.p_forward_vector_y          (mpeg2_new_p_forward_vector_y),
	.p_residual_required         (mpeg2_new_p_residual_required),
	.p_residual_success          (mpeg2_new_p_residual_success),
	.p_first_residual_sample_valid(mpeg2_new_p_first_residual_sample_valid),
	.p_first_residual_sample_value(mpeg2_new_p_first_residual_sample_value),
	.p_residual_sample_valid     (mpeg2_new_p_residual_sample_valid),
	.p_residual_sample_index     (mpeg2_new_p_residual_sample_index),
	.p_residual_sample_value     (mpeg2_new_p_residual_sample_value),
	.b_motion_transport          (mpeg2_new_b_motion_transport),
	.probe_error                 (mpeg2_new_phase1_probe_error),
	.probe_error_source          (mpeg2_new_phase1_probe_error_source),
	.p_probe_error_source        (mpeg2_new_p_probe_error_source),
	.p_progress_detail           (mpeg2_new_p_progress_detail),
	.publication_error_detail    (mpeg2_new_publication_error_detail),
	.p_wide_probe_error_detail   (mpeg2_new_p_wide_probe_error_detail),
	.b_user_success              (mpeg2_new_b_user_success),
	.quantiser_scale_code        (mpeg2_new_slice_quantiser_scale_code),
	.macroblock_address_increment(mpeg2_new_macroblock_address_increment),
	.macroblock_quant            (mpeg2_new_macroblock_quant),
	.macroblock_quantiser_scale_code(mpeg2_new_macroblock_quantiser_scale_code),
	.slice_vertical_position     (mpeg2_new_slice_vertical_position),
	.slice_vertical_position_extension(mpeg2_new_slice_vertical_position_extension),
	.first_luma_dc_size          (mpeg2_new_first_luma_dc_size),
	.first_luma_dc_differential  (mpeg2_new_first_luma_dc_differential),
	.first_luma_dc_coefficient   (mpeg2_new_first_luma_dc_coefficient),
	.first_luma_ac_nonzero_count (mpeg2_new_first_luma_ac_nonzero_count),
	.first_luma_last_coeff_index (mpeg2_new_first_luma_last_coeff_index),
	.first_luma_last_ac_level    (mpeg2_new_first_luma_last_ac_level),
	.slice_start                 (mpeg2_new_slice_start),
	.luma_macroblock_start       (mpeg2_new_luma_macroblock_start),
	.qfs_block_index             (mpeg2_new_qfs_block_index),
	.qfs_block_start             (mpeg2_new_qfs_block_start),
	.qfs_write_en                (mpeg2_new_qfs_write_en),
	.qfs_write_index             (mpeg2_new_qfs_write_index),
	.qfs_write_value             (mpeg2_new_qfs_write_value),
	.qfs_block_end               (mpeg2_new_qfs_block_end)
);

mpeg2_h262_inverse_quant mpeg2_h262_inverse_quant
(
    .stream_data(mpeg2_stream_data),
    .stream_valid(mpeg2_new_decode_stream_valid),
	.clk                         (clk_mpeg2),
	.reset                       (reset_mpeg2),
	.block_start                 (mpeg2_new_qfs_block_start),
	.coeff_write_en              (mpeg2_new_qfs_write_en),
	.coeff_write_index           (mpeg2_new_qfs_write_index),
	.coeff_write_value           (mpeg2_new_qfs_write_value),
	.block_end                   (mpeg2_new_qfs_block_end),
	.intra_quant_matrix_default  (mpeg2_new_intra_quant_matrix_default),
	.intra_dc_precision          (mpeg2_new_intra_dc_precision),
	.quantiser_scale_code        (mpeg2_new_effective_quantiser_scale_code),
	.q_scale_type                (mpeg2_new_q_scale_type),
	.alternate_scan              (mpeg2_new_alternate_scan),
	.block_complete              (mpeg2_new_inverse_quant_complete),
	.iq_error                    (mpeg2_new_inverse_quant_error),
	.unsupported_matrix          (mpeg2_new_inverse_quant_unsupported_matrix),
	.first_luma_f00              (mpeg2_new_first_luma_f00),
	.first_luma_f77              (mpeg2_new_first_luma_f77),
	.coeff_out_block_start       (mpeg2_new_iq_coeff_block_start),
	.coeff_out_valid             (mpeg2_new_iq_coeff_valid),
	.coeff_out_index             (mpeg2_new_iq_coeff_index),
	.coeff_out_value             (mpeg2_new_iq_coeff_value),
	.coeff_out_block_end         (mpeg2_new_iq_coeff_block_end)
);

mpeg2_h262_idct mpeg2_h262_idct
(
	.clk                         (clk_mpeg2),
	.reset                       (reset_mpeg2),
	.coeff_block_start           (mpeg2_new_iq_coeff_block_start),
	.coeff_valid                 (mpeg2_new_iq_coeff_valid),
	.coeff_index                 (mpeg2_new_iq_coeff_index),
	.coeff_value                 (mpeg2_new_iq_coeff_value),
	.coeff_block_end             (mpeg2_new_iq_coeff_block_end),
	.block_complete              (mpeg2_new_idct_complete),
	.idct_error                  (mpeg2_new_idct_error),
	.sample_valid                (mpeg2_new_idct_sample_valid),
	.sample_index                (mpeg2_new_idct_sample_index),
	.sample_value                (mpeg2_new_idct_sample_value),
	.first_luma_sample00         (mpeg2_new_first_luma_sample00),
	.first_luma_sample77         (mpeg2_new_first_luma_sample77)
);

mpeg2_h262_intra_recon mpeg2_h262_intra_recon
(
	.clk                                (clk_mpeg2),
	.reset                              (reset_mpeg2),
	.horizontal_size                    (mpeg2_new_horizontal_size),
	.vertical_size                      (mpeg2_new_vertical_size),
	.slice_vertical_position            (mpeg2_new_slice_vertical_position),
	.slice_vertical_position_extension  (mpeg2_new_slice_vertical_position_extension),
	.macroblock_address_increment       (mpeg2_new_macroblock_address_increment),
	.slice_start                        (mpeg2_new_slice_start),
	.macroblock_start                   (mpeg2_new_luma_macroblock_start),
	.block_index                        (mpeg2_new_qfs_block_index),
	.dct_type                           (mpeg2_new_dct_type),
	.sample_valid                       (mpeg2_new_idct_sample_valid),
	.sample_index                       (mpeg2_new_idct_sample_index),
	.sample_value                       (mpeg2_new_idct_sample_value),
	.idct_block_complete                (mpeg2_new_idct_complete),
	.pixel_valid                        (mpeg2_new_recon_pixel_valid),
	.pixel_component                    (mpeg2_new_recon_pixel_component),
	.pixel_x                            (mpeg2_new_recon_pixel_x),
	.pixel_y                            (mpeg2_new_recon_pixel_y),
	.pixel_value                        (mpeg2_new_recon_pixel_value),
	.block_start                        (mpeg2_new_recon_block_start),
	.block_complete                     (mpeg2_new_recon_block_complete),
	.macroblock_420_complete            (mpeg2_new_recon_macroblock_420_complete),
	.recon_error                        (mpeg2_new_recon_error),
	.block_origin_x                     (mpeg2_new_recon_block_origin_x),
	.block_origin_y                     (mpeg2_new_recon_block_origin_y)
);

wire mpeg2_new_luma_writer_word;
wire [2:0] mpeg2_new_luma_writer_region;
wire mpeg2_new_luma_writer_row_parity;
wire mpeg2_new_luma_writer_picture_start;
wire mpeg2_new_luma_writer_picture_complete;
wire [31:0] mpeg2_new_luma_writer_position_fingerprint;

mpeg2_h262_ddram_store mpeg2_h262_ddram_store
(
	.clk             (clk_mpeg2),
	.reset           (reset_mpeg2),
	.frame_bank      (mpeg2_new_active_frame_bank),
	.field_dct       (mpeg2_new_p_store_select ?
	                  mpeg2_new_p_store_field_dct :
	                  mpeg2_new_dct_type),
	.pixel_value     (mpeg2_new_p_store_select ?
	                  mpeg2_new_p_store_pixel_value :
	                  mpeg2_new_recon_pixel_value),
	.pixel_component (mpeg2_new_p_store_select ?
	                  2'd0 :
	                  mpeg2_new_recon_pixel_component),
	.pixel_x         (mpeg2_new_p_store_select ?
	                  mpeg2_new_p_store_pixel_x :
	                  mpeg2_new_recon_pixel_x),
	.pixel_y         (mpeg2_new_p_store_select ?
	                  mpeg2_new_p_store_pixel_y :
	                  mpeg2_new_recon_pixel_y),
	.pixel_valid     (mpeg2_new_p_store_select ?
	                  mpeg2_new_p_store_pixel_valid :
	                  mpeg2_new_recon_pixel_valid),
	.block_start     (mpeg2_new_p_store_select ?
	                  mpeg2_new_p_store_block_start :
	                  mpeg2_new_recon_block_start),
	.block_complete  (mpeg2_new_p_store_select ?
	                  mpeg2_new_p_store_block_complete :
	                  mpeg2_new_recon_block_complete),
	.block_stored    (mpeg2_new_ddr_block_stored),
	.block_accepted  (mpeg2_new_ddr_block_accepted),
	.capture_blocked_debug(mpeg2_new_ddr_capture_blocked),
	.write_seen      (mpeg2_new_ddr_write_seen),
	.store_error     (mpeg2_new_ddr_store_error),
	.ddram_busy      (mpeg2_new_ddr_writer_busy),
	.ddram_burstcnt  (mpeg2_new_ddr_wr_burstcnt),
	.ddram_addr      (mpeg2_new_ddr_wr_addr),
	.ddram_rd        (mpeg2_new_ddr_wr_rd),
	.ddram_din       (mpeg2_new_ddr_wr_din),
	.ddram_be        (mpeg2_new_ddr_wr_be),
	.ddram_we        (mpeg2_new_ddr_wr_we),
	.luma_word_debug (mpeg2_new_luma_writer_word),
	.luma_region_debug(mpeg2_new_luma_writer_region),
	.luma_row_parity_debug(mpeg2_new_luma_writer_row_parity),
	.luma_picture_start_debug(mpeg2_new_luma_writer_picture_start),
	.luma_picture_complete_debug(mpeg2_new_luma_writer_picture_complete),
	.luma_position_fingerprint_debug(
	                  mpeg2_new_luma_writer_position_fingerprint)
);

// kate - Phase 1T-o: the controlled pattern-only P macroblock has no explicit
// forward vector. Once its complete first-Y0 transform is available, the
// prediction client reconstructs the full 8x8 luma block from real reference
// rows plus the 64 live residual samples, emits it through the ordinary DDR
// block writer, and verifies all eight destination row words by readback.
wire mpeg2_new_phase1t_implicit_reconstruct_required =
    mpeg2_new_p_residual_required &&
    mpeg2_new_p_residual_success &&
    mpeg2_new_p_first_residual_sample_valid &&
    !mpeg2_new_p_forward_vector_valid;

mpeg2_h262_reference_read_probe mpeg2_h262_reference_read_probe
(
    .clk                       (clk_mpeg2),
    .reset                     (reset_mpeg2),
    // kate - Phase 1T-y: connect live coded horizontal geometry at top level.
    .horizontal_size           (mpeg2_new_horizontal_size),
    // kate - Phase 1U-c: connect live coded vertical geometry at top level.
    .vertical_size             (mpeg2_new_vertical_size),
    .p_vector_proof_seen       (mpeg2_new_p_macroblock_type_seen),
    .p_forward_vector_valid    (mpeg2_new_p_forward_vector_valid),
    .p_forward_vector_x        (mpeg2_new_p_forward_vector_x),
    .p_forward_vector_y        (mpeg2_new_p_forward_vector_y),
    .forward_f_code_horizontal (mpeg2_new_forward_f_code_horizontal),
    .forward_f_code_vertical   (mpeg2_new_forward_f_code_vertical),
    .p_implicit_reconstruct_request(mpeg2_new_phase1t_implicit_reconstruct_required),
    .p_residual_sample_valid   (mpeg2_new_p_residual_sample_valid),
    .p_residual_sample_index   (mpeg2_new_p_residual_sample_index),
    .p_residual_sample_value   (mpeg2_new_p_residual_sample_value),
    .b_motion_transport        (mpeg2_new_b_motion_transport),
    .reference_frame_valid     (mpeg2_new_reference_frame_valid),
    .reference_frame_bank      (mpeg2_new_reference_frame_bank),
    .previous_reference_frame_bank(mpeg2_new_previous_reference_frame_bank),
    .destination_frame_bank    (mpeg2_new_active_frame_bank),
    .b_scratch_frame_bank      (mpeg2_new_b_decode_scratch_bank),
    .p_store_block_stored      (mpeg2_new_ddr_block_stored),
    .ddram_busy                (mpeg2_new_pred_busy),
    .ddram_dout                (DDRAM_DOUT),
    .ddram_dout_ready          (mpeg2_new_pred_dout_ready),
    .ddram_burstcnt            (mpeg2_new_pred_burstcnt),
    .ddram_addr                (mpeg2_new_pred_addr),
    .ddram_rd                  (mpeg2_new_pred_rd),
    .p_store_select            (mpeg2_new_p_store_select),
    .p_store_pixel_value       (mpeg2_new_p_store_pixel_value),
    .p_store_pixel_x           (mpeg2_new_p_store_pixel_x),
    .p_store_pixel_y           (mpeg2_new_p_store_pixel_y),
    .p_store_pixel_valid       (mpeg2_new_p_store_pixel_valid),
    .p_store_block_start       (mpeg2_new_p_store_block_start),
    .p_store_block_complete    (mpeg2_new_p_store_block_complete),
    .p_store_field_dct         (mpeg2_new_p_store_field_dct),
    .read_seen                 (mpeg2_new_pred_read_seen),
    .sample_value              (mpeg2_new_pred_sample_value),
    .sample_nonzero            (mpeg2_new_pred_sample_nonzero),
    .half_sample_seen          (mpeg2_new_pred_half_sample_seen),
    .reconstructed_seen        (mpeg2_new_pred_reconstructed_seen),
    .reconstructed_value       (mpeg2_new_pred_reconstructed_value),
    .persisted_seen            (mpeg2_new_pred_persisted_seen),
    .row_persisted             (mpeg2_new_pred_row_persisted),
    .p_progress_stage          (mpeg2_new_pred_progress_stage),
    .probe_error               (mpeg2_new_pred_error),
    .probe_error_source        (mpeg2_new_pred_error_source),
    .probe_error_detail        (mpeg2_new_pred_error_detail)
);

wire [1:0] mpeg2_new_display_frame_bank;
wire      mpeg2_new_display_scratch;
wire      mpeg2_new_display_scratch_bank;
wire [2:0] mpeg2_new_framebuffer_swap_reset_count;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [1:0] mpeg2_new_film_mode_video_sync;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] mpeg2_new_native_field_sync;
always @(posedge clk_video) begin
    if(reset_video) mpeg2_new_film_mode_video_sync<=0;
    else mpeg2_new_film_mode_video_sync<={mpeg2_new_film_mode_video_sync[0],mpeg2_new_native_film_mode};
end
always @(posedge clk_mpeg2) begin
    if(reset_mpeg2) mpeg2_new_native_field_sync<=0;
    else mpeg2_new_native_field_sync<={mpeg2_new_native_field_sync[1:0],display_field};
end
reg       mpeg2_new_swap_window_video;
reg       mpeg2_new_cadence_window_video;
wire      mpeg2_new_b_presentation_complete;
// Entry 282: scheduler observability taps consumed only by the cadence
// profiler's unconditional hold-attribution counters.
wire      mpeg2_new_b_scratch_available;
wire      mpeg2_new_b_promotion_active;
wire      mpeg2_new_b_presentation_error;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] mpeg2_new_swap_window_sync;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] mpeg2_new_cadence_window_sync;

always @(posedge clk_video) begin
    if (reset_video)
        mpeg2_new_swap_window_video <= 1'b0;
    else
        mpeg2_new_swap_window_video <= mpeg2_new_film_mode_video_sync[1] ?
            display_field_swap_window : display_frame_window;

    if (reset_video)
        mpeg2_new_cadence_window_video <= 1'b0;
    else
        mpeg2_new_cadence_window_video <= display_field_window;
end

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2)
        mpeg2_new_swap_window_sync <= 3'b000;
    else
        mpeg2_new_swap_window_sync <=
            {mpeg2_new_swap_window_sync[1:0], mpeg2_new_swap_window_video};

    if (reset_mpeg2)
        mpeg2_new_cadence_window_sync <= 3'b000;
    else
        mpeg2_new_cadence_window_sync <=
            {mpeg2_new_cadence_window_sync[1:0],
             mpeg2_new_cadence_window_video};
end

wire mpeg2_new_swap_window_pulse =
    mpeg2_new_swap_window_sync[1] && !mpeg2_new_swap_window_sync[2];
wire mpeg2_new_cadence_window_pulse =
    mpeg2_new_cadence_window_sync[1] &&
    !mpeg2_new_cadence_window_sync[2];

wire mpeg2_new_frame_waiting =
    mpeg2_new_picture_420_complete &&
    mpeg2_new_first_picture_420_parsed &&
    (mpeg2_new_display_scratch ||
     (mpeg2_new_completed_frame_bank != mpeg2_new_display_frame_bank));

// kate - Commit 162 fixes the proven consecutive-P publication/presentation
// race without weakening Commit-142 DDR ownership protection.  After a P is
// published, accepted stream bytes are allowed to reach and classify the next
// picture header.  Only when that next picture is another P and its selected
// destination bank is still the displayed reference bank is input then parked.
// The hold releases as soon as presentation moves away from that bank.  A
// following B or I disarms the P-only gate and retains the existing B reorder
// and presentation path unchanged.
reg [31:0] mpeg2_new_p_ownership_picture_window;
reg        mpeg2_new_p_ownership_header_capture;
reg        mpeg2_new_p_ownership_header_second_byte;
reg        mpeg2_new_p_ownership_arm;
reg        mpeg2_new_p_destination_ownership_hold_reg;

wire [31:0] mpeg2_new_p_ownership_picture_window_next =
    {mpeg2_new_p_ownership_picture_window[23:0], mpeg2_stream_data};
wire mpeg2_new_p_ownership_picture_start_now =
    (mpeg2_new_p_ownership_picture_window_next == 32'h00000100);
wire mpeg2_new_picture_header_classified_now =
    mpeg2_new_decode_stream_valid &&
    mpeg2_new_p_ownership_header_capture &&
    mpeg2_new_p_ownership_header_second_byte;
wire [2:0] mpeg2_new_picture_header_type_now = mpeg2_stream_data[5:3];
wire mpeg2_new_b_picture_start_now =
    mpeg2_new_picture_header_classified_now &&
    (mpeg2_new_picture_header_type_now == 3'b011);
wire mpeg2_new_non_b_picture_start_now =
    mpeg2_new_picture_header_classified_now &&
    (mpeg2_new_picture_header_type_now != 3'b011);
wire mpeg2_new_i_picture_start_now =
    mpeg2_new_picture_header_classified_now &&
    (mpeg2_new_picture_header_type_now == 3'b001);
wire mpeg2_new_p_picture_start_now =
    mpeg2_new_picture_header_classified_now &&
    (mpeg2_new_picture_header_type_now == 3'b010);
wire mpeg2_new_sequence_end_now =
    mpeg2_new_decode_stream_valid &&
    (mpeg2_new_p_ownership_picture_window_next == 32'h000001b7);
wire mpeg2_new_p_destination_display_owned =
    !mpeg2_new_display_scratch &&
    (mpeg2_new_active_frame_bank == mpeg2_new_display_frame_bank);
wire mpeg2_new_p_publication_now =
    mpeg2_new_picture_420_complete &&
    (mpeg2_new_picture_coding_type == 3'b010);

assign mpeg2_new_p_destination_ownership_hold =
    mpeg2_new_p_destination_ownership_hold_reg;

wire mpeg2_new_b_reference_overlap_header;

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        mpeg2_new_p_ownership_picture_window      <= 32'd0;
        mpeg2_new_p_ownership_header_capture      <= 1'b0;
        mpeg2_new_p_ownership_header_second_byte  <= 1'b0;
        mpeg2_new_p_ownership_arm                 <= 1'b0;
        mpeg2_new_p_destination_ownership_hold_reg <= 1'b0;
    end
    else begin
        if (mpeg2_new_p_destination_ownership_hold_reg &&
            !mpeg2_new_p_destination_display_owned)
            mpeg2_new_p_destination_ownership_hold_reg <= 1'b0;

        if (mpeg2_new_p_publication_now)
            mpeg2_new_p_ownership_arm <= 1'b1;

        if (mpeg2_new_decode_stream_valid) begin
            mpeg2_new_p_ownership_picture_window <=
                mpeg2_new_p_ownership_picture_window_next;

            if (mpeg2_new_p_ownership_picture_start_now) begin
                mpeg2_new_p_ownership_header_capture     <= 1'b1;
                mpeg2_new_p_ownership_header_second_byte <= 1'b0;
            end
            else if (mpeg2_new_p_ownership_header_capture) begin
                if (!mpeg2_new_p_ownership_header_second_byte) begin
                    mpeg2_new_p_ownership_header_second_byte <= 1'b1;
                end
                else begin
                    mpeg2_new_p_ownership_header_capture     <= 1'b0;
                    mpeg2_new_p_ownership_header_second_byte <= 1'b0;

                    if (mpeg2_new_p_ownership_arm ||
                        mpeg2_new_b_reference_overlap_header) begin
                        mpeg2_new_p_ownership_arm <= 1'b0;
                        if ((mpeg2_stream_data[5:3] == 3'b010) &&
                            mpeg2_new_p_destination_display_owned)
                            mpeg2_new_p_destination_ownership_hold_reg <= 1'b1;
                    end
                end
            end
        end
    end
end

// Entry 206: every accepted picture header produces an explicit event, so two
// adjacent B headers cannot collapse into one coding-type level.  The scheduler
// alternates two scratch frames and owns the complete B...B->future-reference
// presentation transaction, including fail-open error retirement.
wire [31:0] mpeg2_new_b_scheduler_debug_state;
wire mpeg2_new_b_cadence_slot_debug;
wire mpeg2_new_b_candidate_presentable_debug;
wire mpeg2_new_startup_swaps_enabled;
wire mpeg2_new_startup_video_blank;
mpeg2_h262_native_startup mpeg2_h262_native_startup (
    .clk_mpeg2(clk_mpeg2), .reset_mpeg2(reset_mpeg2),
    .clk_video(clk_video), .reset_video(reset_video),
    .presentation_request(mpeg2_new_presentation_request),
    .first_picture_complete(mpeg2_new_first_picture_420_parsed),
    .candidate_presentable(mpeg2_new_b_candidate_presentable_debug),
    .sequence_end_seen(mpeg2_new_sequence_end_seen),
    .bypass_event(mpeg2_new_extracted_metadata_valid ||
        mpeg2_new_inband_pcm_valid ||
        dvd_overlay_record_valid ||
        audio_ui_picture_publish ||
        (mpeg2_new_picture_header_classified_now && !mpeg2_new_i_picture_start_now) ||
        mpeg2_new_syntax_error || mpeg2_new_phase1_probe_error),
    .frame_window(display_frame_window),
    .swap_window_active(mpeg2_new_swap_window_sync[2]),
    .swaps_enabled(mpeg2_new_startup_swaps_enabled),
    .video_blank(mpeg2_new_startup_video_blank)
);
mpeg2_h262_picture_timestamp mpeg2_h262_picture_timestamp
(
    .clk                     (clk_mpeg2),
    .reset                   (reset_mpeg2),
    .metadata_valid          (mpeg2_new_inband_valid),
    .metadata_pts            (mpeg2_new_inband_pts_90k),
    .picture_coding_extension_valid(mpeg2_new_picture_coding_extension_valid),
    .picture_top_field_first (mpeg2_new_picture_coding_extension_top_field_first),
    .picture_repeat_first_field(mpeg2_new_pce_repeat_first_field),
    .picture_progressive_frame(mpeg2_new_pce_progressive_frame),
    .display_repeat_first_field(mpeg2_new_display_repeat_first_field),
    .display_progressive_frame(mpeg2_new_display_progressive_frame),
    .display_descriptor_valid(mpeg2_new_display_descriptor_valid),
    .candidate_top_field_first(mpeg2_new_candidate_top_field_first),
    .picture_start           (mpeg2_new_picture_header_classified_now),
    .picture_is_b            (mpeg2_new_b_picture_start_now),
    .decode_scratch_bank     (mpeg2_new_b_decode_scratch_bank),
    .b_picture_complete      (mpeg2_new_b_user_success),
    .active_frame_bank       (mpeg2_new_active_frame_bank),
    .display_frame_bank      (mpeg2_new_display_frame_bank),
    .display_scratch         (mpeg2_new_display_scratch),
    .display_scratch_bank    (mpeg2_new_display_scratch_bank),
    .candidate_frame_valid   (mpeg2_new_candidate_frame_valid),
    .candidate_frame_scratch (mpeg2_new_candidate_frame_scratch),
    .candidate_scratch_bank  (mpeg2_new_candidate_scratch_bank),
    .candidate_frame_bank    (mpeg2_new_candidate_frame_bank),
    .display_pts             (mpeg2_new_display_pts),
    .display_pts_valid       (mpeg2_new_display_pts_valid),
    .display_top_field_first (mpeg2_new_display_top_field_first),
    .candidate_pts           (mpeg2_new_candidate_pts),
    .candidate_pts_valid     (mpeg2_new_candidate_pts_valid),
    .associated_count        (mpeg2_new_associated_count)
);

mpeg2_h262_pts_presentation_timeline mpeg2_h262_pts_presentation_timeline
(
    .clk              (clk_mpeg2),
    .reset            (reset_mpeg2),
    .tick_90k         (mpeg2_new_stc_tick_90k),
    .metadata_valid   (mpeg2_new_inband_valid),
    .metadata_pts     (mpeg2_new_inband_pts_90k),
    .candidate_valid  (mpeg2_new_candidate_pts_valid),
    .candidate_pts    (mpeg2_new_candidate_pts),
    .anchored         (mpeg2_new_pts_timeline_anchored),
    .stc_90k          (mpeg2_new_pts_timeline_stc),
    .candidate_active (mpeg2_new_timestamp_candidate_active),
    .candidate_due    (mpeg2_new_timestamp_candidate_due)
);

mpeg2_h262_b_presentation_scheduler mpeg2_h262_b_presentation_scheduler
(
    .native_film_mode(mpeg2_new_native_film_mode && mpeg2_new_native_active_mpeg2),
    .native_field(mpeg2_new_native_field_sync[2]),
    .display_picture_present(mpeg2_new_framebuffer_picture_present_sync[2]),
    .display_repeat_first_field(mpeg2_new_display_repeat_first_field),
    .candidate_top_field_first(mpeg2_new_candidate_top_field_first),
    .clk                         (clk_mpeg2),
    .reset                       (reset_mpeg2),
    .swap_window_pulse           (mpeg2_new_swap_window_pulse &&
                                 mpeg2_new_startup_swaps_enabled),
    .cadence_tick_pulse          (mpeg2_new_cadence_window_pulse),
    .frame_rate_code             (mpeg2_new_frame_rate_code),
    .timestamp_candidate_active  (mpeg2_new_timestamp_candidate_active),
    .timestamp_candidate_due     (mpeg2_new_timestamp_candidate_due),
    .native_ordinary_overlap_enable(mpeg2_new_native_active_mpeg2),
    .active_frame_bank           (mpeg2_new_active_frame_bank),
    .frame_waiting               (mpeg2_new_frame_waiting),
    .completed_frame_bank        (mpeg2_new_completed_frame_bank),
    .reference_frame_bank        (mpeg2_new_reference_frame_bank),
    .reference_promotion_count   (mpeg2_new_reference_promotion_count),
    .b_picture_start             (mpeg2_new_b_picture_start_now),
    .non_b_picture_start         (mpeg2_new_non_b_picture_start_now),
    .i_picture_start             (mpeg2_new_i_picture_start_now),
    .p_picture_start             (mpeg2_new_p_picture_start_now),
    .sequence_end                (mpeg2_new_sequence_end_now),
    .b_user_success              (mpeg2_new_b_user_success),
    .b_decode_error              (mpeg2_new_phase1_probe_error),
    .display_frame_bank          (mpeg2_new_display_frame_bank),
    .display_scratch             (mpeg2_new_display_scratch),
    .display_scratch_bank        (mpeg2_new_display_scratch_bank),
    .decode_scratch_bank         (mpeg2_new_b_decode_scratch_bank),
    .candidate_frame_valid       (mpeg2_new_candidate_frame_valid),
    .candidate_frame_scratch     (mpeg2_new_candidate_frame_scratch),
    .candidate_scratch_bank      (mpeg2_new_candidate_scratch_bank),
    .candidate_frame_bank        (mpeg2_new_candidate_frame_bank),
    .cadence_slot_debug          (mpeg2_new_b_cadence_slot_debug),
    .candidate_presentable_debug (mpeg2_new_b_candidate_presentable_debug),
    .framebuffer_swap_reset_count(mpeg2_new_framebuffer_swap_reset_count),
    .reference_overlap_header    (mpeg2_new_b_reference_overlap_header),
    .presentation_hold           (mpeg2_new_b_presentation_hold),
    .scratch_available           (mpeg2_new_b_scratch_available),
    .promotion_active            (mpeg2_new_b_promotion_active),
    .presentation_complete       (mpeg2_new_b_presentation_complete),
    .presentation_error          (mpeg2_new_b_presentation_error),
    .debug_state                 (mpeg2_new_b_scheduler_debug_state)
);
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] mpeg2_new_native_active_sync;

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2)
        mpeg2_new_native_active_sync <= 3'b000;
    else
        mpeg2_new_native_active_sync <=
            {mpeg2_new_native_active_sync[1:0], display_native_interlaced};
end

wire mpeg2_new_native_mode_change =
    mpeg2_new_native_active_sync[1] ^ mpeg2_new_native_active_sync[2];
assign mpeg2_new_native_active_mpeg2 = mpeg2_new_native_active_sync[2];
wire mpeg2_new_framebuffer_reset =
    reset_mpeg2 ||
    (mpeg2_new_framebuffer_swap_reset_count != 3'd0) ||
    mpeg2_new_native_mode_change;
wire mpeg2_new_framebuffer_generation_reset =
    (mpeg2_new_framebuffer_swap_reset_count != 3'd0) ||
    mpeg2_new_native_mode_change;
reg mpeg2_new_framebuffer_generation_reset_d;
reg [7:0] mpeg2_new_framebuffer_generation;

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        mpeg2_new_framebuffer_generation_reset_d <= 1'b0;
        mpeg2_new_framebuffer_generation <= 8'd0;
    end
    else begin
        mpeg2_new_framebuffer_generation_reset_d <=
            mpeg2_new_framebuffer_generation_reset;
        if (mpeg2_new_framebuffer_generation_reset &&
            !mpeg2_new_framebuffer_generation_reset_d)
            mpeg2_new_framebuffer_generation <=
                mpeg2_new_framebuffer_generation + 8'd1;
    end
end

wire mpeg2_new_framebuffer_picture_present_rd;
wire mpeg2_new_framebuffer_prefill_deadline_missed_rd;
// Entry 516: additional video-domain per-field evidence levels/toggles.
wire mpeg2_new_framebuffer_sequence_phase_error_rd;
// The DDR service evidence is generated on mem_clk, which is clk_mpeg2 itself,
// so it needs no synchronizer and stays fully timed.
wire mpeg2_new_framebuffer_first_field_fetch_toggle;
wire mpeg2_new_framebuffer_second_field_fetch_toggle;
// Entry 520: raw per-parity luma return event, generated on clk_mpeg2.
wire mpeg2_new_luma_return_valid;
wire mpeg2_new_luma_return_first_field;
wire [7:0] mpeg2_new_luma_return_byte;
wire mpeg2_new_luma_fingerprint_valid;
wire mpeg2_new_luma_fingerprint_first_field;
wire [31:0] mpeg2_new_luma_fingerprint_raw;
wire [31:0] mpeg2_new_luma_fingerprint_display;
wire mpeg2_new_luma_fingerprint_mismatch;
wire mpeg2_new_luma_provenance_valid;
wire mpeg2_new_luma_provenance_first_field;
wire mpeg2_new_luma_provenance_tag_mismatch;
wire mpeg2_new_luma_provenance_content_mismatch;
wire mpeg2_new_luma_provenance_expected_bank;
wire mpeg2_new_luma_provenance_tagged_bank;
wire [10:0] mpeg2_new_luma_provenance_expected_row;
wire [10:0] mpeg2_new_luma_provenance_tagged_row;
wire [7:0] mpeg2_new_luma_provenance_expected_generation;
wire [7:0] mpeg2_new_luma_provenance_tagged_generation;
wire [31:0] mpeg2_new_luma_provenance_raw_fingerprint;
wire [31:0] mpeg2_new_luma_provenance_display_fingerprint;
wire mpeg2_new_luma_write_read_valid;
wire mpeg2_new_luma_write_read_first_field;
wire mpeg2_new_luma_write_read_expected_valid;
wire [2:0] mpeg2_new_luma_write_read_region;
wire [31:0] mpeg2_new_luma_write_read_expected_fingerprint;
wire [31:0] mpeg2_new_luma_write_read_raw_fingerprint;
wire mpeg2_new_luma_write_read_mismatch;
wire mpeg2_new_ddr_writer_accept;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] mpeg2_new_framebuffer_picture_present_sync;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] mpeg2_new_framebuffer_prefill_missed_sync;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] mpeg2_new_framebuffer_phase_error_sync;

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        mpeg2_new_framebuffer_picture_present_sync <= 3'b000;
        mpeg2_new_framebuffer_prefill_missed_sync <= 3'b000;
        mpeg2_new_framebuffer_phase_error_sync <= 3'b000;
    end
    else begin
        mpeg2_new_framebuffer_picture_present_sync <=
            {mpeg2_new_framebuffer_picture_present_sync[1:0],
             mpeg2_new_framebuffer_picture_present_rd};
        mpeg2_new_framebuffer_prefill_missed_sync <=
            {mpeg2_new_framebuffer_prefill_missed_sync[1:0],
             mpeg2_new_framebuffer_prefill_deadline_missed_rd};
        mpeg2_new_framebuffer_phase_error_sync <=
            {mpeg2_new_framebuffer_phase_error_sync[1:0],
             mpeg2_new_framebuffer_sequence_phase_error_rd};
    end
end

wire mpeg2_new_framebuffer_picture_present =
    mpeg2_new_framebuffer_picture_present_sync[2];
wire mpeg2_new_framebuffer_prefill_deadline_missed =
    mpeg2_new_framebuffer_prefill_missed_sync[2];
wire mpeg2_new_framebuffer_sequence_phase_error =
    mpeg2_new_framebuffer_phase_error_sync[2];

localparam [28:0] MPEG2_NEW_DDR_FRAME_BANK_WORDS     = 29'h00010000;
localparam [28:0] MPEG2_NEW_DDR_FRAME_SCRATCH0_WORDS = 29'h00020000;
localparam [28:0] MPEG2_NEW_DDR_FRAME_SCRATCH1_WORDS = 29'h00030000;
localparam [28:0] MPEG2_NEW_DDR_FRAME_BANK2_WORDS    = 29'h00040000;
wire [28:0] mpeg2_new_decoder_display_frame_offset =
    mpeg2_new_display_scratch ?
        (mpeg2_new_display_scratch_bank ? MPEG2_NEW_DDR_FRAME_SCRATCH1_WORDS :
                                           MPEG2_NEW_DDR_FRAME_SCRATCH0_WORDS) :
    (mpeg2_new_display_frame_bank == 2'd1) ? MPEG2_NEW_DDR_FRAME_BANK_WORDS :
    (mpeg2_new_display_frame_bank == 2'd2) ? MPEG2_NEW_DDR_FRAME_BANK2_WORDS :
                                             29'd0;
wire [28:0] mpeg2_new_display_frame_offset = audio_ui_mode_active ?
    (audio_ui_display_bank ? MPEG2_NEW_DDR_FRAME_BANK_WORDS : 29'd0) :
    mpeg2_new_decoder_display_frame_offset;
assign mpeg2_new_ddr_rd_banked_addr =
    mpeg2_new_ddr_rd_addr + mpeg2_new_display_frame_offset;

// Entry 518: the framebuffer emits a plain row address and learns nothing
// about which of the five DDR regions the offset above steers it into.  A
// native frame readout spans two vertical periods and can straddle a display
// swap, so each parity may resolve into a different region while every
// framebuffer counter still reads correctly.  Sample the region in effect on
// each parity's fetch edge.  All of this is clk_mpeg2 logic and none of it
// enters the video domain.
wire [2:0] mpeg2_new_display_region = audio_ui_mode_active ?
    {2'b00,audio_ui_display_bank} : mpeg2_new_display_scratch ?
        (mpeg2_new_display_scratch_bank ? 3'd4 : 3'd3) :
        {1'b0, mpeg2_new_display_frame_bank};

// Entry 531: address bits [18:16] encode bank two and the scratch regions as
// 4, 2 and 3 respectively.  Keep that physical encoding for an exact compare
// against accepted writer transactions.
wire [2:0] mpeg2_new_display_physical_region = audio_ui_mode_active ?
    {2'b00,audio_ui_display_bank} : mpeg2_new_display_scratch ?
        (mpeg2_new_display_scratch_bank ? 3'd3 : 3'd2) :
    (mpeg2_new_display_frame_bank == 2'd2) ? 3'd4 :
        {1'b0,mpeg2_new_display_frame_bank};

wire [31:0] mpeg2_new_luma_writer_expected_even;
wire [31:0] mpeg2_new_luma_writer_expected_odd;
wire mpeg2_new_luma_writer_expected_valid;

mpeg2_h262_luma_write_fingerprint mpeg2_h262_luma_write_fingerprint
(
    .clk(clk_mpeg2),
    .reset(reset_mpeg2),
    .writer_accept(mpeg2_new_ddr_writer_accept),
    .luma_word(mpeg2_new_luma_writer_word),
    .luma_region(mpeg2_new_luma_writer_region),
    .luma_row_parity(mpeg2_new_luma_writer_row_parity),
    .luma_picture_start(mpeg2_new_luma_writer_picture_start),
    .luma_picture_complete(mpeg2_new_luma_writer_picture_complete),
    .luma_position_fingerprint(
        mpeg2_new_luma_writer_position_fingerprint),
    .display_region(mpeg2_new_display_physical_region),
    .expected_even_fingerprint(mpeg2_new_luma_writer_expected_even),
    .expected_odd_fingerprint(mpeg2_new_luma_writer_expected_odd),
    .expected_valid(mpeg2_new_luma_writer_expected_valid)
);

// Entry 548: raw fetch-address evidence, accumulated in the profiler.
wire mpeg2_new_luma_fetch_valid;
wire mpeg2_new_luma_fetch_first_field;
wire [8:0] mpeg2_new_luma_fetch_row;
// Entry 549: luma line-cache write evidence.
wire mpeg2_new_luma_cache_write_valid;
wire mpeg2_new_luma_cache_write_first_field;
wire [7:0] mpeg2_new_luma_cache_write_addr;

reg [2:0] mpeg2_new_first_field_region;
reg [2:0] mpeg2_new_second_field_region;
reg       mpeg2_new_first_field_fetch_d;
reg       mpeg2_new_second_field_fetch_d;

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        mpeg2_new_first_field_region  <= 3'd0;
        mpeg2_new_second_field_region <= 3'd0;
        mpeg2_new_first_field_fetch_d  <= 1'b0;
        mpeg2_new_second_field_fetch_d <= 1'b0;
    end
    else begin
        mpeg2_new_first_field_fetch_d  <=
            mpeg2_new_framebuffer_first_field_fetch_toggle;
        mpeg2_new_second_field_fetch_d <=
            mpeg2_new_framebuffer_second_field_fetch_toggle;
        if (mpeg2_new_framebuffer_first_field_fetch_toggle !=
            mpeg2_new_first_field_fetch_d)
            mpeg2_new_first_field_region <= mpeg2_new_display_region;
        if (mpeg2_new_framebuffer_second_field_fetch_toggle !=
            mpeg2_new_second_field_fetch_d)
            mpeg2_new_second_field_region <= mpeg2_new_display_region;
    end
end


mpeg2_h262_audio_ui mpeg2_h262_audio_ui
(
    .clk(clk_mpeg2),.reset(reset_mpeg2),
    .record_data(audio_ui_record_data),
    .record_start(audio_ui_record_start),
    .record_last(audio_ui_record_last),
    .record_valid(audio_ui_record_valid),
    .record_ready(audio_ui_record_ready),
    .protocol_error(audio_ui_protocol_error),
    .writer_burstcnt(audio_ui_writer_burstcnt),
    .writer_addr(audio_ui_writer_addr),
    .writer_rd(audio_ui_writer_rd),
    .writer_din(audio_ui_writer_din),
    .writer_be(audio_ui_writer_be),
    .writer_we(audio_ui_writer_we),
    .writer_busy(audio_ui_writer_busy),
    .publish_window(mpeg2_new_swap_window_pulse),
    .mode_active(audio_ui_mode_active),
    .loading_active(audio_ui_loading_active),
    .display_bank(audio_ui_display_bank),
    .picture_publish(audio_ui_picture_publish),
    .committed_frames(audio_ui_committed_frames)
);

mpeg2_luma_framebuffer mpeg2_luma_framebuffer
(
    .reset          (mpeg2_new_framebuffer_reset),
    .mem_clk        (clk_mpeg2),
    .picture_complete(audio_ui_picture_publish ||
        (mpeg2_new_first_picture_420_parsed &&
         mpeg2_new_display_descriptor_valid)),
    .horizontal_size(audio_ui_mode_active ? 12'd720 :
        mpeg2_new_horizontal_size),
    .vertical_size  (audio_ui_mode_active ? 12'd480 :
        mpeg2_new_vertical_size),
    // Use the fully synchronized presentation-mode level on the memory side.
    // The framebuffer carries this descriptor back through its existing
    // video-domain descriptor synchronizers with the published picture.
    .native_interlaced(audio_ui_mode_active ? 1'b0 :
        mpeg2_new_native_active_sync[2]),
    .top_field_first(audio_ui_mode_active ? 1'b0 :
        mpeg2_new_display_top_field_first),
    .progressive_chroma(audio_ui_mode_active ? 1'b1 :
        mpeg2_new_display_progressive_frame),
    .framebuffer_generation(mpeg2_new_framebuffer_generation),
    .write_read_expected_region(mpeg2_new_display_physical_region),
    .write_read_expected_valid(audio_ui_mode_active ? 1'b0 :
        mpeg2_new_luma_writer_expected_valid),
    .write_read_expected_even_fingerprint(
        mpeg2_new_luma_writer_expected_even),
    .write_read_expected_odd_fingerprint(
        mpeg2_new_luma_writer_expected_odd),
    .ddram_busy     (mpeg2_new_ddr_reader_busy),
    .ddram_dout     (DDRAM_DOUT),
    .ddram_dout_ready(mpeg2_new_ddr_reader_dout_ready),
    .ddram_burstcnt (mpeg2_new_ddr_rd_burstcnt),
    .ddram_addr     (mpeg2_new_ddr_rd_addr),
    .ddram_rd       (mpeg2_new_ddr_rd),
    .cache_ready    (mpeg2_new_ddr_cache_ready),
    .read_seen      (mpeg2_new_ddr_read_seen),
    .cache_error    (mpeg2_new_ddr_cache_error),
    .bank_overlap_error(mpeg2_new_ddr_bank_overlap_error),
    .picture_present_debug(mpeg2_new_framebuffer_picture_present_rd),
    .prefill_deadline_missed_debug(
        mpeg2_new_framebuffer_prefill_deadline_missed_rd),
    .sequence_phase_error_debug(
        mpeg2_new_framebuffer_sequence_phase_error_rd),
    .first_field_fetch_toggle_debug(
        mpeg2_new_framebuffer_first_field_fetch_toggle),
    .luma_cache_write_valid_debug(mpeg2_new_luma_cache_write_valid),
    .luma_cache_write_first_field_debug(
        mpeg2_new_luma_cache_write_first_field),
    .luma_cache_write_addr_debug(mpeg2_new_luma_cache_write_addr),
    .luma_fetch_valid_debug(mpeg2_new_luma_fetch_valid),
    .luma_fetch_first_field_debug(mpeg2_new_luma_fetch_first_field),
    .luma_fetch_row_debug(mpeg2_new_luma_fetch_row),
    .second_field_fetch_toggle_debug(
        mpeg2_new_framebuffer_second_field_fetch_toggle),
    .luma_return_valid_debug(mpeg2_new_luma_return_valid),
    .luma_return_first_field_debug(mpeg2_new_luma_return_first_field),
    .luma_return_byte_debug(mpeg2_new_luma_return_byte),
    .luma_fingerprint_valid_debug(mpeg2_new_luma_fingerprint_valid),
    .luma_fingerprint_first_field_debug(
        mpeg2_new_luma_fingerprint_first_field),
    .luma_fingerprint_raw_debug(mpeg2_new_luma_fingerprint_raw),
    .luma_fingerprint_display_debug(mpeg2_new_luma_fingerprint_display),
    .luma_fingerprint_mismatch_debug(mpeg2_new_luma_fingerprint_mismatch),
    .luma_provenance_valid_debug(mpeg2_new_luma_provenance_valid),
    .luma_provenance_first_field_debug(
        mpeg2_new_luma_provenance_first_field),
    .luma_provenance_tag_mismatch_debug(
        mpeg2_new_luma_provenance_tag_mismatch),
    .luma_provenance_content_mismatch_debug(
        mpeg2_new_luma_provenance_content_mismatch),
    .luma_provenance_expected_bank_debug(
        mpeg2_new_luma_provenance_expected_bank),
    .luma_provenance_tagged_bank_debug(
        mpeg2_new_luma_provenance_tagged_bank),
    .luma_provenance_expected_row_debug(
        mpeg2_new_luma_provenance_expected_row),
    .luma_provenance_tagged_row_debug(
        mpeg2_new_luma_provenance_tagged_row),
    .luma_provenance_expected_generation_debug(
        mpeg2_new_luma_provenance_expected_generation),
    .luma_provenance_tagged_generation_debug(
        mpeg2_new_luma_provenance_tagged_generation),
    .luma_provenance_raw_fingerprint_debug(
        mpeg2_new_luma_provenance_raw_fingerprint),
    .luma_provenance_display_fingerprint_debug(
        mpeg2_new_luma_provenance_display_fingerprint),
    .luma_write_read_valid_debug(mpeg2_new_luma_write_read_valid),
    .luma_write_read_first_field_debug(
        mpeg2_new_luma_write_read_first_field),
    .luma_write_read_expected_valid_debug(
        mpeg2_new_luma_write_read_expected_valid),
    .luma_write_read_region_debug(mpeg2_new_luma_write_read_region),
    .luma_write_read_expected_fingerprint_debug(
        mpeg2_new_luma_write_read_expected_fingerprint),
    .luma_write_read_raw_fingerprint_debug(
        mpeg2_new_luma_write_read_raw_fingerprint),
    .luma_write_read_mismatch_debug(mpeg2_new_luma_write_read_mismatch),
    .rd_clk         (clk_video),
    .h_pos          (display_h_pos),
    .v_pos          (display_v_pos),
    .pixel_ce       (display_pixel_ce),
    .pixel_en       (display_pixel_en),
    .h_sync         (display_h_sync),
    .v_sync         (display_v_sync),
    .video_r        (fb_video_r),
    .video_g        (fb_video_g),
    .video_b        (fb_video_b),
    .video_de       (fb_video_de),
    .video_hs       (fb_video_hs),
    .video_vs       (fb_video_vs)
);

mpeg2_h262_dvd_overlay mpeg2_h262_dvd_overlay
(
    .mem_clk          (clk_mpeg2),
    .mem_reset        (reset_mpeg2),
    .record_data      (dvd_overlay_record_data),
    .record_start     (dvd_overlay_record_start),
    .record_last      (dvd_overlay_record_last),
    .record_valid     (dvd_overlay_record_valid),
    .record_ready     (dvd_overlay_record_ready),
    .protocol_error   (dvd_overlay_engine_error),
    .writer_burstcnt  (dvd_overlay_writer_burstcnt),
    .writer_addr      (dvd_overlay_writer_addr),
    .writer_rd        (dvd_overlay_writer_rd),
    .writer_din       (dvd_overlay_writer_din),
    .writer_be        (dvd_overlay_writer_be),
    .writer_we        (dvd_overlay_writer_we),
    .writer_busy      (dvd_overlay_writer_busy),
    .reader_burstcnt  (dvd_overlay_reader_burstcnt),
    .reader_addr      (dvd_overlay_reader_addr),
    .reader_rd        (dvd_overlay_reader_rd),
    .reader_busy      (dvd_overlay_reader_busy),
    .reader_dout      (DDRAM_DOUT),
    .reader_dout_ready(dvd_overlay_reader_dout_ready),
    .video_clk        (clk_video),
    .video_reset      (reset_video),
    .pixel_ce         (display_pixel_ce),
    .h_pos            (display_h_pos),
    .v_pos            (display_v_pos),
    .native_active    (display_native_interlaced),
    .base_r           ((mpeg2_new_startup_video_blank ||
                        audio_ui_initial_loading_video) ?
                        8'd0 : fb_video_r),
    .base_g           ((mpeg2_new_startup_video_blank ||
                        audio_ui_initial_loading_video) ?
                        8'd0 : fb_video_g),
    .base_b           ((mpeg2_new_startup_video_blank ||
                        audio_ui_initial_loading_video) ?
                        8'd0 : fb_video_b),
    .base_de          (fb_video_de && !mpeg2_new_startup_video_blank &&
                       !audio_ui_initial_loading_video),
    .video_r          (dvd_overlay_video_r),
    .video_g          (dvd_overlay_video_g),
    .video_b          (dvd_overlay_video_b),
    .debug_words      (dvd_overlay_debug_words),
    .debug_commit_seen(dvd_overlay_debug_commit_seen)
);

mpeg2_h262_ddram_arbiter mpeg2_h262_ddram_arbiter
(
    .clk             (clk_mpeg2),
    .reset           (reset_mpeg2),
    .writer_burstcnt (mpeg2_new_ddr_wr_burstcnt),
    .writer_addr     (mpeg2_new_ddr_wr_addr),
    .writer_rd       (mpeg2_new_ddr_wr_rd),
    .writer_din      (mpeg2_new_ddr_wr_din),
    .writer_be       (mpeg2_new_ddr_wr_be),
    .writer_we       (mpeg2_new_ddr_wr_we),
    .writer_busy     (mpeg2_new_ddr_writer_busy),
    .ui_writer_burstcnt(audio_ui_writer_burstcnt),
    .ui_writer_addr  (audio_ui_writer_addr),
    .ui_writer_rd    (audio_ui_writer_rd),
    .ui_writer_din   (audio_ui_writer_din),
    .ui_writer_be    (audio_ui_writer_be),
    .ui_writer_we    (audio_ui_writer_we),
    .ui_writer_busy  (audio_ui_writer_busy),
    .reader_burstcnt (mpeg2_new_ddr_rd_burstcnt),
    .reader_addr     (mpeg2_new_ddr_rd_banked_addr),
    .reader_rd       (mpeg2_new_ddr_rd),
    .reader_busy     (mpeg2_new_ddr_reader_busy),
    .reader_dout_ready(mpeg2_new_ddr_reader_dout_ready),
    .prediction_burstcnt (mpeg2_new_pred_burstcnt),
    .prediction_addr     (mpeg2_new_pred_addr),
    .prediction_rd       (mpeg2_new_pred_rd),
    .prediction_busy     (mpeg2_new_pred_busy),
    .prediction_dout_ready(mpeg2_new_pred_dout_ready),
    .overlay_reader_burstcnt(dvd_overlay_reader_burstcnt),
    .overlay_reader_addr (dvd_overlay_reader_addr),
    .overlay_reader_rd   (dvd_overlay_reader_rd),
    .overlay_reader_busy (dvd_overlay_reader_busy),
    .overlay_reader_dout_ready(dvd_overlay_reader_dout_ready),
    .overlay_writer_burstcnt(dvd_overlay_writer_burstcnt),
    .overlay_writer_addr (dvd_overlay_writer_addr),
    .overlay_writer_rd   (dvd_overlay_writer_rd),
    .overlay_writer_din  (dvd_overlay_writer_din),
    .overlay_writer_be   (dvd_overlay_writer_be),
    .overlay_writer_we   (dvd_overlay_writer_we),
    .overlay_writer_busy (dvd_overlay_writer_busy),
    .ddram_busy      (DDRAM_BUSY),
    .ddram_dout_ready(DDRAM_DOUT_READY),
    .ddram_burstcnt  (DDRAM_BURSTCNT),
    .ddram_addr      (DDRAM_ADDR),
    .ddram_rd        (DDRAM_RD),
    .ddram_din       (DDRAM_DIN),
    .ddram_be        (DDRAM_BE),
    .ddram_we        (DDRAM_WE),
    .writer_accept_debug(mpeg2_new_ddr_writer_accept),
    .ui_writer_accept_debug(audio_ui_writer_accept)
);
assign CLK_VIDEO = clk_video;
assign CE_PIXEL  = display_pixel_ce;
assign VGA_F1 = display_field;
assign VGA_DE = presentation_base_de;
assign VGA_HS = presentation_base_hs;
assign VGA_VS = presentation_base_vs;
assign VGA_R = cadence_video_r;
assign VGA_G = cadence_video_g;
assign VGA_B = cadence_video_b;

assign presentation_base_r = dvd_overlay_video_r;
assign presentation_base_g = dvd_overlay_video_g;
assign presentation_base_b = dvd_overlay_video_b;
assign presentation_base_de = fb_video_de;
assign presentation_base_hs = fb_video_hs;
assign presentation_base_vs = fb_video_vs;

// Entry 245: development-only hardware cadence snapshot. Every input is an
// already registered top-level boundary. The profiler has no control output,
// and its overlay appears after either a quiet drain or the bounded terminal
// diagnostic timeout.
wire mpeg2_new_cadence_session_quiet =
    mpeg2_new_startup_swaps_enabled &&
    mpeg2_new_sequence_end_seen &&
    mpeg2_new_b_presentation_complete &&
    !mpeg2_new_b_scheduler_debug_state[26] &&
    mpeg2_stream_empty &&
    !mpeg2_new_decode_stream_valid &&
    !mpeg2_new_frame_waiting &&
    !mpeg2_new_b_presentation_hold &&
    !mpeg2_new_p_destination_ownership_hold &&
    !mpeg2_new_pred_rd &&
    !mpeg2_new_ddr_wr_we &&
    !audio_ui_writer_we &&
    !dvd_overlay_reader_rd &&
    !dvd_overlay_writer_we &&
    !audio_pcm_terminal_pending;

wire [15:0] mpeg2_new_cadence_error_flags = {
    display_record_router_error || audio_ui_protocol_error,
    dvd_overlay_extractor_error,
    dvd_overlay_engine_error,
    mpeg2_new_ddr_bank_overlap_error,
    mpeg2_new_inband_pcm_protocol_error,
    audio_pcm_underrun_sync[1],
    mpeg2_new_b_presentation_error,
    mpeg2_new_ddr_cache_error,
    mpeg2_new_ddr_store_error,
    mpeg2_new_recon_error,
    mpeg2_new_idct_error,
    mpeg2_new_inverse_quant_unsupported_matrix,
    mpeg2_new_inverse_quant_error,
    mpeg2_new_pred_error,
    mpeg2_new_phase1_probe_error,
    mpeg2_new_syntax_error
};

mpeg2_h262_hardware_cadence_profiler #(
    .PROFILE_START_STC_SECONDS(14'd0),
    .OVERLAY_DIAGNOSTICS(1'b1)
)
mpeg2_h262_hardware_cadence_profiler
(
    .clk_mpeg2                 (clk_mpeg2),
    .reset_mpeg2               (reset_mpeg2),
    .clk_video                 (clk_video),
    .reset_video               (reset_video),
    .pixel_ce                  (display_pixel_ce),
    .framebuffer_generation_reset(
        mpeg2_new_framebuffer_generation_reset),
    .framebuffer_picture_present(
        mpeg2_new_framebuffer_picture_present),
    .framebuffer_prefill_deadline_missed(
        mpeg2_new_framebuffer_prefill_deadline_missed),
    .framebuffer_sequence_phase_error(
        mpeg2_new_framebuffer_sequence_phase_error),
    .framebuffer_first_field_region(mpeg2_new_first_field_region),
    .framebuffer_second_field_region(mpeg2_new_second_field_region),
    .framebuffer_luma_fetch_valid(mpeg2_new_luma_fetch_valid),
    .framebuffer_luma_fetch_first_field(mpeg2_new_luma_fetch_first_field),
    .framebuffer_luma_fetch_row(mpeg2_new_luma_fetch_row),
    .framebuffer_display_region(mpeg2_new_display_region),
    .framebuffer_cache_write_valid(mpeg2_new_luma_cache_write_valid),
    .framebuffer_cache_write_first_field(
        mpeg2_new_luma_cache_write_first_field),
    .framebuffer_cache_write_addr(mpeg2_new_luma_cache_write_addr),
    .framebuffer_luma_return_valid(mpeg2_new_luma_return_valid),
    .framebuffer_luma_return_first_field(mpeg2_new_luma_return_first_field),
    .framebuffer_luma_return_byte(mpeg2_new_luma_return_byte),
    .framebuffer_luma_fingerprint_valid(mpeg2_new_luma_fingerprint_valid),
    .framebuffer_luma_fingerprint_first_field(
        mpeg2_new_luma_fingerprint_first_field),
    .framebuffer_luma_fingerprint_raw(mpeg2_new_luma_fingerprint_raw),
    .framebuffer_luma_fingerprint_display(mpeg2_new_luma_fingerprint_display),
    .framebuffer_luma_fingerprint_mismatch(
        mpeg2_new_luma_fingerprint_mismatch),
    .framebuffer_luma_provenance_valid(
        mpeg2_new_luma_provenance_valid),
    .framebuffer_luma_provenance_first_field(
        mpeg2_new_luma_provenance_first_field),
    .framebuffer_luma_provenance_tag_mismatch(
        mpeg2_new_luma_provenance_tag_mismatch),
    .framebuffer_luma_provenance_content_mismatch(
        mpeg2_new_luma_provenance_content_mismatch),
    .framebuffer_luma_provenance_expected_bank(
        mpeg2_new_luma_provenance_expected_bank),
    .framebuffer_luma_provenance_tagged_bank(
        mpeg2_new_luma_provenance_tagged_bank),
    .framebuffer_luma_provenance_expected_row(
        mpeg2_new_luma_provenance_expected_row),
    .framebuffer_luma_provenance_tagged_row(
        mpeg2_new_luma_provenance_tagged_row),
    .framebuffer_luma_provenance_expected_generation(
        mpeg2_new_luma_provenance_expected_generation),
    .framebuffer_luma_provenance_tagged_generation(
        mpeg2_new_luma_provenance_tagged_generation),
    .framebuffer_luma_provenance_raw_fingerprint(
        mpeg2_new_luma_provenance_raw_fingerprint),
    .framebuffer_luma_provenance_display_fingerprint(
        mpeg2_new_luma_provenance_display_fingerprint),
    .framebuffer_luma_write_read_valid(
        mpeg2_new_luma_write_read_valid),
    .framebuffer_luma_write_read_first_field(
        mpeg2_new_luma_write_read_first_field),
    .framebuffer_luma_write_read_expected_valid(
        mpeg2_new_luma_write_read_expected_valid),
    .framebuffer_luma_write_read_region(
        mpeg2_new_luma_write_read_region),
    .framebuffer_luma_write_read_expected_fingerprint(
        mpeg2_new_luma_write_read_expected_fingerprint),
    .framebuffer_luma_write_read_raw_fingerprint(
        mpeg2_new_luma_write_read_raw_fingerprint),
    .framebuffer_luma_write_read_mismatch(
        mpeg2_new_luma_write_read_mismatch),
    .framebuffer_first_field_fetch(
        mpeg2_new_framebuffer_first_field_fetch_toggle),
    .framebuffer_second_field_fetch(
        mpeg2_new_framebuffer_second_field_fetch_toggle),
    .fifo_pending              (!mpeg2_stream_empty),
    .native_decode_active      (mpeg2_new_presentation_request),
    .decoder_input_pending     (mpeg2_new_clean_video_pending),
    .writer_capacity_blocked   (mpeg2_new_ddr_capture_blocked),
    .decoder_ready             (mpeg2_new_decoder_stream_ready),
    .presentation_hold         (mpeg2_new_b_presentation_hold),
    .destination_hold          (mpeg2_new_p_destination_ownership_hold),
    .scratch_available         (mpeg2_new_b_scratch_available),
    .promotion_active          (mpeg2_new_b_promotion_active),
    .frame_waiting             (mpeg2_new_frame_waiting),
    .completed_frame_bank      (mpeg2_new_completed_frame_bank),
    .presentation_complete     (mpeg2_new_b_presentation_complete),
    .presentation_error        (mpeg2_new_b_presentation_error),
    .scheduler_debug_state     (mpeg2_new_b_scheduler_debug_state),
    .swap_window_pulse         (mpeg2_new_swap_window_pulse),
    .candidate_presentable     (mpeg2_new_b_candidate_presentable_debug),
    .timestamp_candidate_active(mpeg2_new_timestamp_candidate_active),
    .timestamp_candidate_due   (mpeg2_new_timestamp_candidate_due),
    .cadence_slot              (mpeg2_new_b_cadence_slot_debug),
    .decoder_byte_accepted     (mpeg2_new_decode_stream_valid),
    .stc_seconds               (mpeg2_new_stc_seconds),
    .associated_count          (mpeg2_new_associated_count),
    .display_pts               (mpeg2_new_display_pts),
    .pcm_sample_count          (mpeg2_new_inband_pcm_sample_count),
    .pcm_fifo_peak             (audio_pcm_fifo_peak),
    .transport_block_longest   (transport_block_longest),
    .transport_block_count     (transport_block_count),
    .audio_underrun_count      (audio_pcm_underrun_count),
    .audio_fifo_floor          (audio_pcm_fifo_floor),
    .overlay_debug_words       (dvd_overlay_debug_words),
    .overlay_debug_commit_seen (dvd_overlay_debug_commit_seen),
    .top_field_first           (mpeg2_new_top_field_first),
    .repeat_first_field        (mpeg2_new_repeat_first_field),
    .picture_coding_type       (mpeg2_new_picture_coding_type),
    .temporal_reference        (mpeg2_new_temporal_reference),
    .frame_rate_code           (mpeg2_new_frame_rate_code),
    .picture_count             (mpeg2_new_picture_count),
    .reference_picture_complete(mpeg2_new_picture_420_complete),
    .b_picture_complete        (mpeg2_new_b_user_success),
    .prediction_read           (mpeg2_new_pred_rd),
    .prediction_busy           (mpeg2_new_pred_busy),
    .prediction_data_ready     (mpeg2_new_pred_dout_ready),
    .writer_write              (mpeg2_new_ddr_wr_we),
    .writer_busy               (mpeg2_new_ddr_writer_busy),
    .display_frame_bank        (mpeg2_new_display_frame_bank),
    .display_scratch           (mpeg2_new_display_scratch),
    .display_scratch_bank      (mpeg2_new_display_scratch_bank),
    .sequence_end_seen         (mpeg2_new_sequence_end_seen),
    .session_quiet             (mpeg2_new_cadence_session_quiet),
    .terminal_defer            (audio_pcm_terminal_pending),
    .error_flags               (mpeg2_new_cadence_error_flags),
    .h_pos                     (display_h_pos),
    .v_pos                     (display_v_pos),
    .base_r                    (presentation_base_r),
    .base_g                    (presentation_base_g),
    .base_b                    (presentation_base_b),
    .base_de                   (presentation_base_de),
    .telemetry_visible         (status[125]),
    .video_r                   (cadence_video_r),
    .video_g                   (cadence_video_g),
    .video_b                   (cadence_video_b),
    .snapshot_ready            (cadence_snapshot_ready)
);

wire mpeg2_new_phase1s_all_i_user_success =
    mpeg2_new_first_picture_420_parsed &&
    mpeg2_new_second_picture_420_parsed &&
    (mpeg2_new_picture_count >= 8'd3) &&
    (mpeg2_new_completed_frame_bank == mpeg2_new_display_frame_bank);

wire mpeg2_new_phase1t_integer_read_required =
    mpeg2_new_p_forward_vector_valid &&
    (mpeg2_new_p_forward_vector_x == 13'sd4) &&
    (mpeg2_new_p_forward_vector_y == 13'sd0) &&
    (mpeg2_new_forward_f_code_horizontal == 4'd1) &&
    (mpeg2_new_forward_f_code_vertical   == 4'd1);

wire mpeg2_new_phase1t_halfpel_read_required =
    mpeg2_new_p_forward_vector_valid &&
    (mpeg2_new_p_forward_vector_x == 13'sd3) &&
    (mpeg2_new_p_forward_vector_y == 13'sd0) &&
    (mpeg2_new_forward_f_code_horizontal == 4'd2) &&
    (mpeg2_new_forward_f_code_vertical   == 4'd2);

wire mpeg2_new_phase1t_reference_read_required =
    mpeg2_new_phase1t_integer_read_required ||
    mpeg2_new_phase1t_halfpel_read_required;

wire mpeg2_new_phase1t_reference_read_ok =
    !mpeg2_new_phase1t_reference_read_required ||
    (mpeg2_new_pred_read_seen &&
     mpeg2_new_pred_sample_nonzero &&
     (!mpeg2_new_phase1t_halfpel_read_required ||
      mpeg2_new_pred_half_sample_seen));

// kate - Phase 1T-l requires the implicit pattern-only path to complete the
// real prediction + residual + clipping proof. No fixed expected pel value is
// invented; the prediction and residual are both live data from this stream.
wire mpeg2_new_phase1t_implicit_reconstruct_ok =
    !mpeg2_new_phase1t_implicit_reconstruct_required ||
    mpeg2_new_pred_reconstructed_seen;

wire mpeg2_new_phase1t_p_syntax_user_success =
    mpeg2_new_p_macroblock_type_seen &&
    mpeg2_new_first_picture_420_parsed &&
    mpeg2_new_second_picture_420_parsed &&
    (mpeg2_new_picture_count >= 8'd2) &&
    (mpeg2_new_completed_frame_bank == mpeg2_new_display_frame_bank) &&
    mpeg2_new_phase1t_reference_read_ok &&
    mpeg2_new_phase1t_implicit_reconstruct_ok;

wire unused_phase1t_reconstructed_value = &{1'b0, mpeg2_new_pred_reconstructed_value};

// Normal B acceptance requires the clean B decode/persistence result plus the
// proven Commit-139 scratch-then-future-P presentation transaction.
wire mpeg2_new_b_presentation_user_success =
    mpeg2_new_b_user_success &&
    mpeg2_new_b_presentation_complete &&
    !mpeg2_new_b_presentation_error;

wire mpeg2_new_normal_user_led =
    (mpeg2_new_phase1s_all_i_user_success ||
     mpeg2_new_phase1t_p_syntax_user_success ||
     mpeg2_new_b_presentation_user_success) &&

    mpeg2_new_recon_macroblock_420_complete &&
    mpeg2_new_phase1n_frame_geometry_supported &&
    !mpeg2_new_syntax_error &&
    !mpeg2_new_phase1_probe_error &&
    !mpeg2_new_pred_error &&
    !mpeg2_new_inverse_quant_error &&
    !mpeg2_new_inverse_quant_unsupported_matrix &&
    !mpeg2_new_idct_error &&
    !mpeg2_new_recon_error &&
    mpeg2_new_ddr_write_seen &&
    !mpeg2_new_ddr_store_error &&
    mpeg2_new_ddr_cache_ready &&
    mpeg2_new_ddr_read_seen &&
    !mpeg2_new_ddr_cache_error;

// kate - Commit 177 error-identification diagnostic.
//
// Commit-176 hardware read POWER ON / DISK OFF / USER OFF on all three P-final
// streams and all three ON on test_i_baseline.  Presentation is therefore clean
// and a decode/DDR error is latching instead, which is the opposite of the
// mechanism the static trace had favoured.  One bit cannot say which of the
// nine error flags fired, so the flags are priority-encoded and blinked out on
// LED_USER.  LED_DISK returns to its ioctl_download file-load duty in
// MediaPlayer.sv; LED_POWER keeps the presentation bit.
//
// LED_USER encoding:
//   steady ON        - no error latched and the stream is accepted
//   steady OFF       - no error latched but not accepted (acceptance
//                      prerequisites failed: picture_count,
//                      second_picture_420_parsed, p_macroblock_type_seen,
//                      reference_read_ok, implicit_reconstruct_ok)
//   N blinks, pause  - error flag N latched, per the table below
//
//   1 syntax          4 inverse_quant                   7 recon
//   2 phase1_probe    5 inverse_quant_unsupported_matrix 8 ddr_store
//   3 pred            6 idct                            9 ddr_cache
//  10 ddr_cache_bank_overlap
//
// No decode, presentation, ownership or acceptance behavior is altered; the
// acceptance term itself still drives the steady-ON state unchanged.
wire [3:0] mpeg2_new_diag_error_code_live =
    mpeg2_new_syntax_error                     ? 4'd1 :
    mpeg2_new_phase1_probe_error               ? 4'd2 :
    mpeg2_new_pred_error                       ? 4'd3 :
    mpeg2_new_inverse_quant_error              ? 4'd4 :
    mpeg2_new_inverse_quant_unsupported_matrix ? 4'd5 :
    mpeg2_new_idct_error                       ? 4'd6 :
    mpeg2_new_recon_error                      ? 4'd7 :
    mpeg2_new_ddr_store_error                  ? 4'd8 :
    mpeg2_new_ddr_cache_error                  ? 4'd9 :
    mpeg2_new_ddr_bank_overlap_error           ? 4'd10 : 4'd0;

// kate - Commit 178 sub-code diagnostic.
//
// Commit-177 hardware read 2 blinks (phase1_probe_error) on test_p_mba_escape
// and test_consecutive_chain, and steady OFF (no error latched, not accepted)
// on test_p_motion_residual.  Two distinct faults, and neither is named yet:
// probe_error ORs four sources, and the steady-OFF case does not say which
// acceptance term is false.  LED_POWER carried presentation_ok, which read ON
// on every stream and is therefore spent, so it is repurposed to blink the
// sub-code for whichever case USER is reporting.
//
// LED_POWER when USER blinks 2 (probe_error) - probe_error source.  Commit
// 179: the instantiated macrofunction is mpeg2_h262_two_picture_probe_p_chain
// (files.qip), whose probe_error is five terms, not the eight this table
// originally assumed from the uncompiled base two_picture_probe.sv:
//   1 bookkeeper_error (gated)  2 p_error_raw (gated)
//   3 b_error                   4 publication_error
//   5 reference_progress_error
//
// LED_POWER when USER is steady OFF - first false acceptance term:
//   1 p_macroblock_type_seen        2 first_picture_420_parsed
//   3 second_picture_420_parsed     4 picture_count < 2
//   5 completed != display          6 reference_read_ok
//   7 implicit_reconstruct_ok       8 recon_macroblock_420_complete
//   9 phase1n_frame_geometry_supported
//  10 ddr_write_seen               11 ddr_cache_ready
//  12 ddr_read_seen
//
// Otherwise LED_POWER is steady ON.  Observability only: no decode,
// presentation, ownership or acceptance behavior changes.
//
// Commit 199 extends the same hierarchy when USER blinks 3 (pred_error):
// POWER 1 plan adapter, 2 generalized P raster, 3 B raster/history,
// 4 legacy/base probe.  DISK then reports the selected raster engine's first
// internal assertion number; plan/base have no internal detail and report 0.
wire [3:0] mpeg2_new_diag_prereq_code =
    !mpeg2_new_p_macroblock_type_seen          ? 4'd1  :
    !mpeg2_new_first_picture_420_parsed        ? 4'd2  :
    !mpeg2_new_second_picture_420_parsed       ? 4'd3  :
    (mpeg2_new_picture_count < 8'd2)           ? 4'd4  :
    (mpeg2_new_completed_frame_bank !=
     mpeg2_new_display_frame_bank)             ? 4'd5  :
    !mpeg2_new_phase1t_reference_read_ok       ? 4'd6  :
    !mpeg2_new_phase1t_implicit_reconstruct_ok ? 4'd7  :
    !mpeg2_new_recon_macroblock_420_complete   ? 4'd8  :
    !mpeg2_new_phase1n_frame_geometry_supported ? 4'd9 :
    !mpeg2_new_ddr_write_seen                  ? 4'd10 :
    !mpeg2_new_ddr_cache_ready                 ? 4'd11 :
    !mpeg2_new_ddr_read_seen                   ? 4'd12 : 4'd0;

// kate - Commit 180 deepens the sub-code.  Commit-179 hardware read USER 2 /
// POWER 2 on all three P-final streams, i.e. phase1_probe_error sourced from
// p_error_raw, which is itself an eight-term OR in
// mpeg2_h262_p_diagnostic_controller.  When the five-way source is 2, POWER
// now carries that eight-way code instead; every other source value keeps the
// Commit-179 meaning.
//
// The compiled controller is mpeg2_h262_p_diagnostic_controller_rearm.sv
// (files.qip), whose probe_error is nine terms with legacy/wide replacing the
// base file's aligned term.  LED_POWER when USER blinks 2 and the five-way
// source is 2:
//   1 syntax_error      2 two_mb_error       3 four_mb_error
//   4 legacy_error      5 wide_error         6 progress_error
//   7 residual_error_raw 8 hold_error        9 raster_hold_error
// kate - Commit 183.  The observer error flags and their ownership claims are
// sticky/mutable state.  A live priority encoder can therefore relabel an old
// failure later in a multi-picture stream.  Snapshot the complete hierarchy on
// the first cycle that any parent error is visible, and retain it until reset.
// This changes only the LED report; every decode and acceptance signal remains
// connected exactly as before.
reg       mpeg2_new_diag_first_error_valid;
reg [3:0] mpeg2_new_diag_error_code_first;
reg [3:0] mpeg2_new_diag_phase1_source_first;
reg [3:0] mpeg2_new_diag_p_source_first;
reg [3:0] mpeg2_new_diag_progress_detail_first;
reg [2:0] mpeg2_new_diag_publication_detail_first;
reg [4:0] mpeg2_new_diag_p_wide_detail_first;
reg [2:0] mpeg2_new_diag_pred_source_first;
reg [4:0] mpeg2_new_diag_pred_detail_first;

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        mpeg2_new_diag_first_error_valid     <= 1'b0;
        mpeg2_new_diag_error_code_first      <= 4'd0;
        mpeg2_new_diag_phase1_source_first   <= 4'd0;
        mpeg2_new_diag_p_source_first        <= 4'd0;
        mpeg2_new_diag_progress_detail_first <= 4'd0;
        mpeg2_new_diag_publication_detail_first <= 3'd0;
        mpeg2_new_diag_p_wide_detail_first <= 5'd0;
        mpeg2_new_diag_pred_source_first     <= 3'd0;
        mpeg2_new_diag_pred_detail_first     <= 5'd0;
    end
    else if (!mpeg2_new_diag_first_error_valid &&
             (mpeg2_new_diag_error_code_live != 4'd0)) begin
        mpeg2_new_diag_first_error_valid     <= 1'b1;
        mpeg2_new_diag_error_code_first      <= mpeg2_new_diag_error_code_live;
        mpeg2_new_diag_phase1_source_first   <= mpeg2_new_phase1_probe_error_source;
        mpeg2_new_diag_p_source_first        <= mpeg2_new_p_probe_error_source;
        mpeg2_new_diag_progress_detail_first <= mpeg2_new_p_progress_detail;
        mpeg2_new_diag_publication_detail_first <= mpeg2_new_publication_error_detail;
        mpeg2_new_diag_p_wide_detail_first <= mpeg2_new_p_wide_probe_error_detail;
        mpeg2_new_diag_pred_source_first     <= mpeg2_new_pred_error_source;
        mpeg2_new_diag_pred_detail_first     <= mpeg2_new_pred_error_detail;
    end
end

wire [3:0] mpeg2_new_diag_error_code =
    mpeg2_new_diag_first_error_valid ? mpeg2_new_diag_error_code_first : 4'd0;

wire [3:0] mpeg2_new_diag_power_code_live =
    mpeg2_new_diag_first_error_valid ?
        ((mpeg2_new_diag_error_code_first == 4'd2) ?
            ((mpeg2_new_diag_phase1_source_first == 4'd2) ?
                 mpeg2_new_diag_p_source_first :
                 mpeg2_new_diag_phase1_source_first) :
         (mpeg2_new_diag_error_code_first == 4'd3) ?
            {1'b0, mpeg2_new_diag_pred_source_first} : 4'd0) :
        // Commit 192: prerequisites below describe the generalized P path.
        // Once the existing normal I/P/B acceptance result is true, none of
        // those P-only sub-codes is a failure and POWER must stay clear.
        (mpeg2_new_normal_user_led ? 4'd0 : mpeg2_new_diag_prereq_code);

// kate - Commit 180.  progress_error is a symptom, not a root cause: it is
// p_picture_expected && !p_macroblock_type_seen, and that signal is a deep
// conjunction.  When POWER reports 6, LED_DISK names the first false conjunct
// so one build covers both levels:
//   1 mb_seen_combined   2 residual_decision
//   3 residual required but not successful
//   4 hold_seen_combined 5 two_mb_wait      6 raster_wait
// LED_DISK is steady off in every other case; its ioctl_download file-load
// duty is displaced for the duration of this diagnostic.
// kate - Commit 185.  With no error latched and prerequisite 4 remaining,
// POWER proves that both pictures parsed but the P publication count did not
// advance.  DISK now reports the last generalized P raster stage reached:
//   1 admission/capture       2 execution started   3 reference read
//   4 reconstruction emitted 5 DDR store ack       6 verification readback
//   7 persistence asserted
// The prior Commit-180 progress-error detail remains available for its error
// case.  This changes observability only.
// Entry 210 adds publication-error detail when USER is 2 and POWER is 4:
//   1 B header before its P reference published
//   2 later I header before two P publications
//   3 I completion targets the retained reference bank
//   4 P persistence without a valid reference
//   5 P persistence targets the retained reference bank
// When publication detail 1 follows a generalized-P parser fault, DISK shows
// that parser's sticky first-fault code (state plus one, or 26..31) instead.
// Entry 223 uses an otherwise passing DISK window to report the deepest
// post-I50 hardware boundary:
//   1 third I header            2 third I publication
//   3 following P header        4 P raster metadata
//   5 first P row persistence   6 full P persistence
//   7 P reference publication   8 following B header
//   9 B persistence            10 B scratch selected
//  11 future reference presented
// USER and POWER retain all existing acceptance and error meanings.
wire [4:0] mpeg2_new_final_gop_progress_stage;
mpeg2_h262_final_gop_progress_probe mpeg2_h262_final_gop_progress_probe
(
    .clk                  (clk_mpeg2),
    .reset                (reset_mpeg2),
    .picture_header       (mpeg2_new_picture_header_classified_now),
    .picture_header_type  (mpeg2_new_picture_header_type_now),
    .picture_complete     (mpeg2_new_picture_420_complete),
    .picture_coding_type  (mpeg2_new_picture_coding_type),
    .sideband_valid       (mpeg2_new_p_residual_sample_valid),
    .sideband_index       (mpeg2_new_p_residual_sample_index),
    .row_persisted        (mpeg2_new_pred_row_persisted),
    .picture_persisted    (mpeg2_new_pred_persisted_seen),
    .b_success            (mpeg2_new_b_user_success),
    .display_scratch      (mpeg2_new_display_scratch),
    .presentation_complete(mpeg2_new_b_presentation_complete),
    .progress_stage       (mpeg2_new_final_gop_progress_stage)
);

wire [4:0] mpeg2_new_diag_disk_code_live =
    (mpeg2_new_diag_first_error_valid &&
     (mpeg2_new_diag_error_code_first == 4'd1)) ?
        mpeg2_new_syntax_error_source :
    (mpeg2_new_diag_first_error_valid &&
     (mpeg2_new_diag_error_code_first == 4'd3)) ?
        mpeg2_new_diag_pred_detail_first :
    (mpeg2_new_diag_first_error_valid &&
     (mpeg2_new_diag_error_code_first == 4'd2) &&
     (mpeg2_new_diag_phase1_source_first == 4'd4)) ?
        ((mpeg2_new_diag_publication_detail_first == 3'd1) &&
         (mpeg2_new_diag_p_wide_detail_first != 5'd0) ?
            mpeg2_new_diag_p_wide_detail_first :
            {2'b00, mpeg2_new_diag_publication_detail_first}) :
    (!mpeg2_new_diag_first_error_valid &&
     (mpeg2_new_diag_prereq_code == 4'd4)) ?
        {1'b0, mpeg2_new_pred_progress_stage} :
    (mpeg2_new_diag_first_error_valid &&
     (mpeg2_new_diag_error_code_first == 4'd2) &&
     (mpeg2_new_diag_phase1_source_first == 4'd2) &&
     (mpeg2_new_diag_p_source_first == 4'd6)) ?
        {1'b0, mpeg2_new_diag_progress_detail_first} :
    (mpeg2_new_normal_user_led &&
     (mpeg2_new_final_gop_progress_stage != 5'd0)) ?
        mpeg2_new_final_gop_progress_stage : 5'd0;

// Commit 189 snapshots only settled post-stream state.  sequence_end_seen is
// sticky; wait one decoder-clock second after it rises so parser, raster, DDR,
// publication and display scheduling have all drained before sampling any live
// prerequisite.  Reset the blink epoch at capture so every test begins at the
// same visible boundary.  The existing slot divider supplies the delay: four
// 250 ms slots are one second, avoiding a second wide counter/comparator.
reg        mpeg2_new_diag_snapshot_valid;
reg [3:0]  mpeg2_new_diag_error_code_snapshot;
reg [3:0]  mpeg2_new_diag_power_code_snapshot;
reg [4:0]  mpeg2_new_diag_disk_code_snapshot;
reg        mpeg2_new_diag_success_snapshot;

// 250 ms slots, divided into non-overlapping windows in a 32-second frame:
// USER 0..23, POWER 24..63, DISK 64..127.  Each numeric code uses alternating
// lit/dark slots local to its window, so simultaneous slot-zero flashes can no
// longer obscure the count.
localparam [23:0] MPEG2_NEW_DIAG_SLOT_CYCLES = 24'd13_500_000;
localparam [6:0]  MPEG2_NEW_DIAG_SLOT_LAST   = 7'd127;
localparam [6:0]  MPEG2_NEW_DIAG_POWER_FIRST = 7'd24;
localparam [6:0]  MPEG2_NEW_DIAG_DISK_FIRST  = 7'd64;

reg [23:0] mpeg2_new_diag_slot_div;
reg [6:0]  mpeg2_new_diag_slot;

wire mpeg2_new_diag_slot_tick =
    (mpeg2_new_diag_slot_div == MPEG2_NEW_DIAG_SLOT_CYCLES - 24'd1);

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        mpeg2_new_diag_snapshot_valid      <= 1'b0;
        mpeg2_new_diag_error_code_snapshot <= 4'd0;
        mpeg2_new_diag_power_code_snapshot <= 4'd0;
        mpeg2_new_diag_disk_code_snapshot  <= 5'd0;
        mpeg2_new_diag_success_snapshot    <= 1'b0;
        mpeg2_new_diag_slot_div <= 24'd0;
        mpeg2_new_diag_slot     <= 7'd0;
    end
    // Entry 219: fail-open masks decoder validity while draining, so a fatal
    // transaction intentionally discards any later sequence-end code.  The
    // sticky fatal result is already settled diagnostic evidence and must arm
    // the same one-second snapshot delay as a normally decoded sequence end.
    else if (!mpeg2_new_diag_snapshot_valid &&
             (mpeg2_new_sequence_end_seen ||
              mpeg2_new_transport_fatal_error)) begin
        if (mpeg2_new_diag_slot_tick && (mpeg2_new_diag_slot == 7'd3)) begin
            mpeg2_new_diag_snapshot_valid      <= 1'b1;
            mpeg2_new_diag_error_code_snapshot <= mpeg2_new_diag_error_code;
            mpeg2_new_diag_power_code_snapshot <= mpeg2_new_diag_power_code_live;
            mpeg2_new_diag_disk_code_snapshot  <= mpeg2_new_diag_disk_code_live;
            mpeg2_new_diag_success_snapshot    <= mpeg2_new_normal_user_led;
            mpeg2_new_diag_slot_div            <= 24'd0;
            mpeg2_new_diag_slot                <= 7'd0;
        end
        else if (mpeg2_new_diag_slot_tick) begin
            mpeg2_new_diag_slot_div <= 24'd0;
            mpeg2_new_diag_slot     <= mpeg2_new_diag_slot + 7'd1;
        end
        else begin
            mpeg2_new_diag_slot_div <= mpeg2_new_diag_slot_div + 24'd1;
        end
    end
    else if (mpeg2_new_diag_snapshot_valid && mpeg2_new_diag_slot_tick) begin
        mpeg2_new_diag_slot_div <= 24'd0;
        mpeg2_new_diag_slot     <= (mpeg2_new_diag_slot == MPEG2_NEW_DIAG_SLOT_LAST) ?
                                   7'd0 : mpeg2_new_diag_slot + 7'd1;
    end
    else if (mpeg2_new_diag_snapshot_valid) begin
        mpeg2_new_diag_slot_div <= mpeg2_new_diag_slot_div + 24'd1;
    end
end

wire [4:0] mpeg2_new_diag_user_slots =
    {mpeg2_new_diag_error_code_snapshot, 1'b0};
wire mpeg2_new_diag_user_window = mpeg2_new_diag_slot < MPEG2_NEW_DIAG_POWER_FIRST;
wire mpeg2_new_diag_user_blink =
    mpeg2_new_diag_snapshot_valid && mpeg2_new_diag_user_window &&
    (mpeg2_new_diag_slot < mpeg2_new_diag_user_slots) &&
    !mpeg2_new_diag_slot[0];

wire [6:0] mpeg2_new_diag_power_slot =
    mpeg2_new_diag_slot - MPEG2_NEW_DIAG_POWER_FIRST;
wire [4:0] mpeg2_new_diag_power_slots =
    {mpeg2_new_diag_power_code_snapshot, 1'b0};
wire mpeg2_new_diag_power_window =
    (mpeg2_new_diag_slot >= MPEG2_NEW_DIAG_POWER_FIRST) &&
    (mpeg2_new_diag_slot < MPEG2_NEW_DIAG_DISK_FIRST);
wire mpeg2_new_diag_power_blink =
    mpeg2_new_diag_snapshot_valid && mpeg2_new_diag_power_window &&
    (mpeg2_new_diag_power_slot < mpeg2_new_diag_power_slots) &&
    !mpeg2_new_diag_power_slot[0];

assign LED_USER = !mpeg2_new_diag_snapshot_valid ? 1'b0 :
                  (mpeg2_new_diag_error_code_snapshot == 4'd0) ?
                    (mpeg2_new_diag_user_window && mpeg2_new_diag_success_snapshot) :
                    mpeg2_new_diag_user_blink;

// LED_POWER is {enable, value}; sys_top drives the POWER LED from the value
// bit when enabled.  A zero sub-code lights the complete POWER window.
assign LED_POWER = {1'b1, !mpeg2_new_diag_snapshot_valid ? 1'b0 :
                          (mpeg2_new_diag_power_code_snapshot == 4'd0) ?
                            mpeg2_new_diag_power_window :
                            mpeg2_new_diag_power_blink};

// kate - Commit 180.  LED_DISK is {enable, value} on the same active-high
// convention (sys_top.v:157 gives LED[2] = led_disk[0] when enabled).  Steady
// OFF when there is no progress sub-code to report.
wire [6:0] mpeg2_new_diag_disk_slot =
    mpeg2_new_diag_slot - MPEG2_NEW_DIAG_DISK_FIRST;
wire [5:0] mpeg2_new_diag_disk_slots =
    {mpeg2_new_diag_disk_code_snapshot, 1'b0};
wire mpeg2_new_diag_disk_blink =
    mpeg2_new_diag_snapshot_valid &&
    (mpeg2_new_diag_slot >= MPEG2_NEW_DIAG_DISK_FIRST) &&
    (mpeg2_new_diag_disk_slot < mpeg2_new_diag_disk_slots) &&
    !mpeg2_new_diag_disk_slot[0];

assign LED_DISK = {1'b1, mpeg2_new_diag_disk_blink};

endmodule
