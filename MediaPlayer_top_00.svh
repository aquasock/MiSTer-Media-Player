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
assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

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

// kate - Commit 180 displaces the LED_DISK file-load indicator again so it can
// blink the progress_error conjunct sub-code, exactly as Commit 176 did and
// Commit 177 reverted.  The assignment now lives with the rest of the blink
// machinery in MediaPlayer_top_07.svh; restore this line when the diagnostic
// is retired.
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

// The OSD alone selects display shape; sequence metadata never overrides it.
wire ar;
video_config_cdc #(.WIDTH(1)) aspect_config (
 .src_clk(clk_sys), .dst_clk(clk_video),
 .src_data(status[121]), .dst_data(ar)
);
assign VIDEO_ARX = ar ? 13'd16 : 13'd4;
assign VIDEO_ARY = ar ? 13'd9 : 13'd3;

`include "build_id.v"
localparam CONF_STR = {
	"MediaPlayer;;",
	"S0,M2VMPG,Open MPEG-2 Video;",
	"-;",
	"-;",
	"O[121],Aspect ratio,4:3,16:9;",
	"O[6],Refresh rate,59.94 Hz,50 Hz;",
	"O[5:4],Color matrix,Auto,BT.601,BT.709;",
	"O[3:1],Audio test,Off,44.1k Mono,44.1k Stereo,48k Mono,48k Stereo;",
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

// Mounted-file sector reads leave stock Main's menu polling responsive.
wire [0:0] media_img_mounted;
wire [63:0] media_img_size;
wire [31:0] media_sd_lba[1];
wire [5:0] media_sd_blocks[1];
wire [0:0] media_sd_rd,media_sd_ack;
wire [12:0] media_sd_addr;
wire [15:0] media_sd_data;
wire [15:0] media_sd_unused[1];
assign media_sd_unused[0]=16'd0;
wire media_sd_wr;
wire [8:0] media_stream_data,media_fifo_data;
wire [14:0] media_fifo_used;
wire [15:0] media_fifo_occupancy=mpeg2_stream_full ? 16'd32768 : {1'b0,media_fifo_used};
wire media_stream_valid,media_reader_idle;
wire media_prefill_mpeg,media_fatal_sys;
reg media_prefill=0;
reg [15:0] media_reservoir_min=16'hffff;
wire media_reader_cancel,media_fifo_reset,media_reader_start;
wire media_decoder_reset,media_quiesce,media_ddr_idle;
wire [63:0] media_byte_position;
wire [31:0] media_requests,media_completions,media_max_wait,media_generation;
wire [3:0] media_error;
reg media_mount_d=0,media_user_reset_d=0;
reg [63:0] media_file_size=0;
wire media_user_reset=status[0] | buttons[1];
wire media_new_file=(media_img_mounted[0] && !media_mount_d) ||
                   (media_user_reset && !media_user_reset_d);
wire media_paused_sys,media_seek_sys,media_seek_restart;
wire [34:0] media_target_sys,media_elapsed_sys,media_elapsed_q;
wire media_seek_done,media_seek_done_sys;
wire [36:0] media_control_mpeg;
wire media_paused=media_control_mpeg[36];
wire media_seeking=media_control_mpeg[35];
wire [34:0] media_target_q=media_control_mpeg[34:0];
wire media_search_restart,media_search_busy,media_probe_sys;
wire [40:0] media_start_offset,media_video_start;
wire [7:0] media_search_tag,media_search_echo;
wire [90:0] media_seek_config_mpeg;
wire [7:0] media_search_tag_mpeg=media_seek_config_mpeg[90:83];
wire media_probe_mpeg=media_seek_config_mpeg[82];
wire [40:0] media_start_offset_mpeg=media_seek_config_mpeg[81:41];
wire [40:0] media_video_start_mpeg=media_seek_config_mpeg[40:0];
wire media_movie_origin_valid;
wire [32:0] media_movie_origin;
wire media_point_found;
wire [32:0] media_point_pts;
wire [40:0] media_point_pack,media_point_sequence;
wire [159:0] media_probe_response_sys;
wire media_restart=media_new_file||media_search_restart;
video_config_cdc #(.WIDTH(91)) seek_file_config(
 .src_clk(clk_sys),.dst_clk(clk_mpeg2),
 .src_data({media_search_tag,media_probe_sys,media_start_offset,media_video_start}),
 .dst_data(media_seek_config_mpeg));
video_config_cdc #(.WIDTH(8)) seek_file_echo_config(
 .src_clk(clk_mpeg2),.dst_clk(clk_sys),.src_data(media_search_tag_mpeg),.dst_data(media_search_echo));
video_config_cdc #(.WIDTH(160)) seek_probe_config(
 .src_clk(clk_mpeg2),.dst_clk(clk_sys),
 .src_data({media_search_tag_mpeg,av_is_ps,media_movie_origin_valid,media_movie_origin,
            media_point_found,av_raw_end,media_point_pts,media_point_pack,media_point_sequence}),
 .dst_data(media_probe_response_sys));
media_seek_search media_seek_search(
 .clk(clk_sys),.reset(RESET),.new_file(media_new_file),.request(media_seek_restart),
 .program_stream(media_probe_response_sys[151]),.origin_valid(media_probe_response_sys[150]),
 .origin(media_probe_response_sys[149:117]),.target_q(media_target_sys),.file_size(media_file_size),
 .reader_start(media_reader_start),.reader_position(media_byte_position),
 .response_tag(media_probe_response_sys[159:152]),.point_found(media_probe_response_sys[116]),
 .probe_end(media_probe_response_sys[115]),.point_pts(media_probe_response_sys[114:82]),
 .point_pack(media_probe_response_sys[81:41]),.point_sequence(media_probe_response_sys[40:0]),
 .busy(media_search_busy),.probing(media_probe_sys),.restart(media_search_restart),
 .tag(media_search_tag),.start_offset(media_start_offset),.video_start(media_video_start));
(* preserve, altera_attribute="-name AUTO_SHIFT_REGISTER_RECOGNITION OFF; -name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] media_osd_sync=0;
always @(posedge clk_sys) media_osd_sync<={media_osd_sync[1:0],OSD_STATUS};
media_keyboard_control #(.RESTART_BOTH_DIRECTIONS(1)) media_keyboard_control(
 .clk(clk_sys),.reset(RESET),.new_file(media_new_file),.enabled(media_file_size!=0),
 .osd_open(media_osd_sync[2]),.key(ps2_key),.elapsed_q(media_elapsed_sys),
 .seek_done(media_seek_done_sys && !media_search_busy),.restart_complete(media_reader_start && !media_probe_sys),
 .paused(media_paused_sys),.seek_active(media_seek_sys),
 .seek_target_q(media_target_sys),.restart(media_seek_restart));
video_config_cdc #(.WIDTH(37)) playback_control_config(
 .src_clk(clk_sys),.dst_clk(clk_mpeg2),
 .src_data({media_paused_sys,media_seek_sys,media_target_sys}),.dst_data(media_control_mpeg));
video_config_cdc #(.WIDTH(36)) playback_position_config(
 .src_clk(clk_mpeg2),.dst_clk(clk_sys),
 .src_data({media_seek_done,media_elapsed_q}),.dst_data({media_seek_done_sys,media_elapsed_sys}));
always @(posedge clk_sys) begin
    media_mount_d<=media_img_mounted[0];media_user_reset_d<=media_user_reset;
    if(RESET) media_file_size<=0;
    else if(media_img_mounted[0]) media_file_size<=media_img_size;
end
media_session_control #(.ENABLE_START_READY(1)) media_session_control (
 .clk_sys(clk_sys),.clk_mpeg2(clk_mpeg2),.reset(RESET),.restart(media_restart),
 .reader_idle(media_reader_idle),.ddr_idle(media_ddr_idle),
 .start_ready(media_search_echo==media_search_tag),
 .reader_cancel(media_reader_cancel),.fifo_reset(media_fifo_reset),
 .reader_start(media_reader_start),.quiesce(media_quiesce),
 .decoder_reset(media_decoder_reset),.generation(media_generation)
);
media_file_reader media_file_reader (
 .clk(clk_sys),.reset(RESET),.start(media_reader_start && media_file_size!=0),
 .cancel(media_reader_cancel || media_fatal_sys),.suspend(1'b0),
 .file_size(media_file_size),.start_offset({23'd0,media_start_offset}),
 .sd_lba(media_sd_lba[0]),.sd_blk_cnt(media_sd_blocks[0]),.sd_rd(media_sd_rd[0]),
 .sd_ack(media_sd_ack[0]),.sd_buff_wr(media_sd_wr),
 .sd_buff_addr(media_sd_addr),.sd_buff_dout(media_sd_data),
 .stream_data(media_stream_data),.stream_valid(media_stream_valid),
 .stream_ready(!mpeg2_stream_full && !media_fifo_reset),.idle(media_reader_idle),
 .byte_position(media_byte_position),.requests(media_requests),
 .completions(media_completions),.max_wait(media_max_wait),.error(media_error)
);
always @(posedge clk_sys) begin
 if(media_fifo_reset) begin media_prefill<=0;media_reservoir_min<=16'hffff;end
 else begin
  if(media_fifo_used>=4096 || (media_stream_valid && media_stream_data[8])) media_prefill<=1;
  if(media_prefill && media_fifo_occupancy<media_reservoir_min)
   media_reservoir_min<=media_fifo_occupancy;
 end
end
video_config_cdc #(.WIDTH(1)) media_prefill_config (
 .src_clk(clk_sys),.dst_clk(clk_mpeg2),.src_data(media_prefill),.dst_data(media_prefill_mpeg));
video_config_cdc #(.WIDTH(1)) media_fatal_config (
 .src_clk(clk_mpeg2),.dst_clk(clk_sys),.src_data(mpeg2_new_transport_fatal_error),.dst_data(media_fatal_sys));
wire [255:0] media_telemetry;
video_config_cdc #(.WIDTH(256)) media_telemetry_config (
 .src_clk(clk_sys),.dst_clk(clk_mpeg2),
 .src_data({{26'd0,media_reader_cancel,media_reader_idle,media_error},
            {16'd0,media_reservoir_min},media_generation,media_byte_position,
            media_max_wait,media_completions,media_requests}),.dst_data(media_telemetry));
wire        mpeg2_stream_full;
wire        mpeg2_stream_empty;
wire [7:0]  mpeg2_fifo_data;
wire [7:0]  mpeg2_stream_data;
wire        mpeg2_new_system_input_ready;
wire        mpeg2_new_system_input_valid;
wire        mpeg2_stream_rd;
wire        mpeg2_stream_wr;
wire        mpeg2_new_decode_stream_valid;
wire        mpeg2_new_stream_ready;
wire        mpeg2_new_decoder_stream_ready;
wire        mpeg2_new_b_presentation_hold;
wire        mpeg2_new_p_destination_ownership_hold;

hps_io #(.CONF_STR(CONF_STR), .WIDE(1)) hps_io
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

    .img_mounted(media_img_mounted),.img_size(media_img_size),
    .sd_lba(media_sd_lba),.sd_blk_cnt(media_sd_blocks),
    .sd_rd(media_sd_rd),.sd_wr(1'b0),.sd_ack(media_sd_ack),
    .sd_buff_addr(media_sd_addr),.sd_buff_dout(media_sd_data),
    .sd_buff_din(media_sd_unused),.sd_buff_wr(media_sd_wr),
    .ioctl_wait(1'b0)

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
// User reset restarts a session through the DDR-drain handshake.
wire reset_request = RESET;

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

wire reset_mpeg2 = reset_mpeg2_base || media_decoder_reset;

// The first scheduled frame starts playback. Keep message suppression through
// subsequent bank swaps and EOF, clearing it only at reset or a fresh load.
wire media_new_file_mpeg;
video_config_cdc #(.WIDTH(1)) playback_hide_reset_config(
 .src_clk(clk_sys),.dst_clk(clk_mpeg2),.src_data(media_new_file_hold),.dst_data(media_new_file_mpeg));
reg media_new_file_hold=0;
always @(posedge clk_sys) begin
 if(RESET||media_new_file) media_new_file_hold<=1;
 else if(media_reader_start) media_new_file_hold<=0;
end
reg playback_started = 0;
always @(posedge clk_mpeg2) begin
    if (reset_mpeg2_base || media_new_file_mpeg) playback_started <= 0;
    else if (mpeg2_new_framebuffer_swap_reset_count != 0) playback_started <= 1;
end
video_config_cdc #(.WIDTH(1)) playback_osd_config (
 .src_clk(clk_mpeg2), .dst_clk(clk_sys),
 .src_data(playback_started), .dst_data(OSD_HIDE_MESSAGE)
);


// Entry 395: atomic Audio mode changes cross from clk_sys to clk_mpeg2 and
// CLK_AUDIO through dedicated DCFIFO mailboxes. Only the PCM data FIFO uses
// the stretched cross-domain clear; ordinary source/output state resets
// synchronously in its own clock domain. This retains the timing-closed control
// structure proven by the companion Audio implementation and keeps video file
// session resets completely independent from the Audio path.
wire [2:0] audio_test_mode = status[3:1];
reg  [2:0] audio_test_mode_prev;
reg  [4:0] audio_fifo_reset_stretch;

wire audio_mode_change_sys = (audio_test_mode != audio_test_mode_prev);

always @(posedge clk_sys or posedge reset_request) begin
	if (reset_request) begin
		audio_test_mode_prev   <= 3'd0;
		audio_fifo_reset_stretch <= 5'd0;
	end
	else begin
		audio_test_mode_prev <= audio_test_mode;
		if (audio_mode_change_sys)
			audio_fifo_reset_stretch <= 5'd31;
		else if (audio_fifo_reset_stretch != 5'd0)
			audio_fifo_reset_stretch <= audio_fifo_reset_stretch - 5'd1;
	end
end

wire audio_fifo_reset_request =
	reset_request || reset_mpeg2 || (audio_fifo_reset_stretch != 5'd0);

reg  [2:0] audio_mode_pending_data;
reg        audio_mode_pending_valid;
wire       audio_mode_src_full;
wire       audio_mode_src_empty;
wire [2:0] audio_mode_src_data;
wire       audio_mode_src_wr;
wire       audio_mode_src_rd;
wire       audio_restart_out_full;
wire       audio_restart_out_empty;
wire [2:0] audio_restart_out_data;
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
			if (audio_mode_change_sys) begin
				audio_mode_pending_data  <= audio_test_mode;
				audio_mode_pending_valid <= 1'b1;
			end
			else begin
				audio_mode_pending_valid <= 1'b0;
			end
		end
		else if (audio_mode_change_sys) begin
			audio_mode_pending_data <= audio_test_mode;
		end
	end
	else if (audio_mode_change_sys) begin
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
	.lpm_width            (3),
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
	.data    (audio_mode_pending_data),
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
reg [2:0] audio_mode_out;

always @(posedge CLK_AUDIO or posedge audio_fifo_reset_request) begin
	if (audio_fifo_reset_request)
		reset_audio_out_sync <= 3'b111;
	else
		reset_audio_out_sync <= {reset_audio_out_sync[1:0], 1'b0};
end

wire reset_audio_out_system = reset_audio_out_sync[2];

always @(posedge CLK_AUDIO) begin
    if (stc_audio_reset) audio_mode_out<=0;
    else if (!audio_restart_out_empty) audio_mode_out<=audio_restart_out_data;
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
wire               audio_pcm_fifo_full;
wire               audio_pcm_fifo_empty;
wire [33:0]        audio_pcm_fifo_data;
wire               audio_pcm_fifo_rd;
wire               audio_pcm_underrun;

assign audio_pcm_ready = !audio_pcm_fifo_full;

audio_pcm_test_source audio_pcm_test_source
(
	.clk      (clk_mpeg2),
	.reset    (reset_audio_src),
	.mode     (audio_mode_src),
	.ready    (audio_pcm_ready),
	.valid    (audio_pcm_valid),
	.left     (audio_pcm_left),
	.right    (audio_pcm_right),
	.stereo   (audio_pcm_stereo),
	.rate_48k (audio_pcm_rate_48k)
);

audio_pcm_fifo audio_pcm_fifo
(
	.reset    (audio_fifo_reset_request),
	.wr_clk   (clk_mpeg2),
	.wr_data  ({audio_pcm_rate_48k, audio_pcm_stereo, audio_pcm_left, audio_pcm_right}),
	.wr_en    (audio_pcm_valid && audio_pcm_ready),
	.wr_full  (audio_pcm_fifo_full),
	.rd_clk   (CLK_AUDIO),
	.rd_en    (audio_pcm_fifo_rd),
	.rd_data  (audio_pcm_fifo_data),
	.rd_empty (audio_pcm_fifo_empty)
);

wire [15:0] audio_test_output_l, audio_test_output_r;
audio_pcm_output_adapter audio_pcm_output_adapter
(
	.clk        (CLK_AUDIO),
	.reset      (reset_audio_out),
	.fifo_data  (audio_pcm_fifo_data),
	.fifo_empty (audio_pcm_fifo_empty),
	.fifo_rd    (audio_pcm_fifo_rd),
	.audio_l    (audio_test_output_l),
	.audio_r    (audio_test_output_r),
	.underrun   (audio_pcm_underrun)
);

// kate - Phase 1Ob: the streaming H.262 bitreader continues to own input
// backpressure while picture_data() advances across every slice of the first
// supported I-picture.  Slice boundaries remain inside the bitreader so no
// alignment or payload bytes are discarded.
// Before the first slice is selected, bytes flow continuously for start-code/header
// parsing.  During slice parsing the bitreader stalls this FIFO whenever its
// current payload byte has not been fully consumed, including IQ/IDCT waits.
assign mpeg2_stream_wr = media_stream_valid && !mpeg2_stream_full && !media_fifo_reset;
assign mpeg2_fifo_data=media_fifo_data[7:0];
wire media_eof_at_head=!mpeg2_stream_empty && media_fifo_data[8];
wire media_data_read;
reg media_eof_seen=0;
always @(posedge clk_mpeg2) begin
    if(reset_mpeg2) media_eof_seen<=0;
    else if(media_prefill_mpeg && media_eof_at_head) media_eof_seen<=1;
end
assign mpeg2_stream_rd=!reset_mpeg2 && media_prefill_mpeg && (media_eof_at_head || media_data_read);

// Phase 1V: the decoder owns syntax/persistence backpressure, while the top
// level additionally pauses between a persisted B and completion of its proven
// scratch->future-reference presentation transaction. This prevents a later
// P/B pair from overtaking the two-vblank display-order operation.
// kate - Commit 162 adds a second, P-only ownership pause after the following
// picture header has been consumed and classified.  It never blocks the header
// needed to distinguish a consecutive P from a following B.
assign mpeg2_new_stream_ready =
	!media_decoder_reset &&
	mpeg2_new_decoder_stream_ready &&
	!mpeg2_new_b_presentation_hold &&
	!mpeg2_new_p_destination_ownership_hold;

// EOF is an ordered FIFO token, never a gap between host sector requests.
wire mpeg2_new_system_input_end = media_eof_seen && !reset_mpeg2;

wire [7:0] mpeg2_ingress_data;
wire mpeg2_ingress_valid, mpeg2_ingress_ready, mpeg2_ingress_end;
wire mpeg2_demux_error;

wire mpeg2_new_transport_fatal_error =
    mpeg2_demux_error || mp2_error ||
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
	.fifo_empty       (mpeg2_stream_empty || media_eof_at_head || reset_mpeg2 || !media_prefill_mpeg),
	.decoder_ready    (mpeg2_new_system_input_ready),
	.fatal_error      (mpeg2_new_transport_fatal_error),
	.fifo_read        (media_data_read),
	.decoder_valid    (mpeg2_new_system_input_valid)
);

// Container parsing consumes the same ordered bytes from the new transport.
wire [7:0] av_video_byte, av_audio_byte;
wire av_video_valid,av_video_ready,av_ingress_end,av_is_ps;
wire [32:0] av_video_pts,av_audio_pts;
wire [7:0] av_raw_video,av_raw_audio;
wire av_raw_valid,av_raw_pts_valid,av_raw_audio_valid,av_raw_end,av_raw_error;
wire [32:0] av_raw_pts;
wire [40:0] av_file_position,av_pack_position;
wire av_discard_video=media_probe_mpeg || av_file_position<media_video_start_mpeg;
wire av_filter_ready;
wire av_raw_ready=av_discard_video || av_filter_ready;
reg av_gate_pts_valid=0;
reg [32:0] av_gate_pts=0;
always @(posedge clk_mpeg2) begin
 if(reset_mpeg2) av_gate_pts_valid<=0;
 else if(av_raw_valid && av_raw_ready) begin
  if(!av_discard_video) av_gate_pts_valid<=0;
  else if(av_raw_pts_valid) begin av_gate_pts_valid<=1;av_gate_pts<=av_raw_pts;end
 end
end
media_seek_video_filter media_seek_video_filter(
 .clk(clk_mpeg2),.reset(reset_mpeg2),.resync_start(media_video_start_mpeg!=0),
 .input_data({(av_raw_pts_valid || av_gate_pts_valid),
              (av_raw_pts_valid ? av_raw_pts : av_gate_pts),av_raw_video}),
 .input_valid(av_raw_valid && !av_discard_video),.input_end(av_raw_end && !media_probe_mpeg),
 .input_ready(av_filter_ready),.output_data({av_video_pts_valid,av_video_pts,av_video_byte}),
 .output_valid(av_video_valid),.output_end(av_ingress_end),.output_ready(av_video_ready));
assign av_audio_byte=av_raw_audio;
assign av_audio_valid=av_raw_audio_valid && !media_probe_mpeg;
assign mpeg2_demux_error=av_raw_error && !media_probe_mpeg;
media_seek_point media_seek_point(
 .clk(clk_mpeg2),.clear(reset_mpeg2_base || media_new_file_mpeg),.reset(reset_mpeg2),
 .data(av_raw_video),.valid(av_is_ps && av_raw_valid && av_raw_ready),
 .pts_valid(av_raw_pts_valid),.pts(av_raw_pts),
 .file_position(av_file_position),.pack_position(av_pack_position),
 .origin_valid(media_movie_origin_valid),.origin(media_movie_origin),
 .found(media_point_found),.point_pts(media_point_pts),
 .point_pack(media_point_pack),.point_sequence(media_point_sequence));
wire av_video_pts_valid,av_audio_pts_valid,av_audio_valid,av_audio_ready;
mpeg2_program_stream_ingress #(.ENABLE_AUDIO(1),.APPEND_RAW_END(1),.ENABLE_FILE_POSITION(1)) mpeg2_program_stream_ingress (
    .clk(clk_mpeg2), .reset(reset_mpeg2),
    .input_data(mpeg2_fifo_data), .input_valid(mpeg2_new_system_input_valid),
    .input_ready(mpeg2_new_system_input_ready), .input_end(mpeg2_new_system_input_end),
    .force_program_stream(media_start_offset_mpeg!=0),.start_file_position(media_start_offset_mpeg),
    .video_file_position(av_file_position),.video_pack_position(av_pack_position),
    .output_data(av_raw_video), .output_valid(av_raw_valid),
    .output_ready(av_raw_ready), .output_end(av_raw_end),
    .video_pts(av_raw_pts),.video_pts_valid(av_raw_pts_valid),
    .audio_data(av_raw_audio),.audio_valid(av_raw_audio_valid),.audio_ready(media_probe_mpeg || av_audio_ready),
    .audio_pts(av_audio_pts),.audio_pts_valid(av_audio_pts_valid),.is_program_stream(av_is_ps),
    .demux_error(av_raw_error)
);

`include "MediaPlayer_av.svh"

mpeg2_h262_inband_metadata mpeg2_h262_inband_metadata
(
	.clk                (clk_mpeg2),
	.reset              (reset_mpeg2),
	.input_data         (mpeg2_ingress_data),
	.input_valid        (mpeg2_ingress_valid),
	.input_ready        (mpeg2_ingress_ready),
	.input_end          (mpeg2_ingress_end),
	.stream_data        (mpeg2_stream_data),
	.stream_valid       (mpeg2_new_decode_stream_valid),
	.stream_ready       (mpeg2_new_stream_ready),
	.pts_90k            (mpeg2_new_inband_pts_90k),
	.picture_structure  (mpeg2_new_inband_picture_structure),
	.top_field_first    (mpeg2_new_inband_top_field_first),
	.repeat_first_field (mpeg2_new_inband_repeat_first_field),
	.progressive_frame  (mpeg2_new_inband_progressive_frame),
	.metadata_valid     (mpeg2_new_inband_valid),
	.metadata_count     (mpeg2_new_inband_count)
);

mpeg2_stream_fifo mpeg2_stream_fifo
(
	// kate - DCFIFO owns reset-release synchronization for wr_clk and rd_clk.
	.reset    (media_fifo_reset),

	.wr_clk   (clk_sys),
	.wr_data  (media_stream_data),
	.wr_en    (mpeg2_stream_wr),
	.wr_full  (mpeg2_stream_full),
    .wr_used(media_fifo_used),

	.rd_clk   (clk_mpeg2),
	.rd_en    (mpeg2_stream_rd),
	.rd_data  (media_fifo_data),
	.rd_empty (mpeg2_stream_empty)
);

// AUDIO_FORK_POINT[DDR_CLIENT]: advisory v0.5.0 handoff, not a permanent ABI.
// If audio eventually needs external buffering, integrate it as an explicit
// additional DDR client at mpeg2_h262_ddram_arbiter in MediaPlayer_top_06.svh
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
// MediaPlayer_top_04.svh and the actual framebuffer swap in _06.svh.  Export a
// clean video-present/timebase event to a higher-level A/V controller; let that
// controller use timestamps/buffer occupancy/drop-repeat policy rather than
// directly stalling either codec's internal parser for normal synchronization.
wire [11:0] display_h_pos;
wire [11:0] display_v_pos;
wire        display_pixel_en;
wire        display_h_sync;
wire        display_v_sync;

wire [7:0]  fb_video_r;
wire [7:0]  fb_video_g;
wire [7:0]  fb_video_b;
wire        fb_video_de;
wire        fb_video_hs;
wire        fb_video_vs;
wire [7:0]  cadence_video_r;
wire [7:0]  cadence_video_g;
wire [7:0]  cadence_video_b;
wire        cadence_snapshot_ready;

// ---------------------------------------------------------------------------
// Entry 389: presentation time base.
//
// The 90 kHz System Time Clock of H.222.0 is anchored to CLK_AUDIO (24.576
// MHz), the same domain sys/audio_out.sv clocks samples out on, so externally
// decoded audio will be consumed drift-free by construction once the PCM sink
// exists.  Nothing consumes the clock yet: presentation remains free-running
// and this cycle only proves the clock runs at the right rate on hardware.
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
	.run           (!(media_paused_audio || media_seeking_audio)),
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
