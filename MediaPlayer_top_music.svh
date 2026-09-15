// Mounted-file sector reads leave stock Main's menu polling responsive.
wire [1:0] media_img_mounted;
wire [63:0] media_img_size;
wire [31:0] media_sd_lba[2];
wire [5:0] media_sd_blocks[2];
wire [1:0] media_sd_rd,media_sd_ack,media_host_rd,media_reader_wr;
wire [12:0] media_sd_addr;
wire [15:0] media_sd_data;
wire [15:0] media_sd_unused[2];
assign media_sd_unused[0]=16'd0;
assign media_sd_unused[1]=16'd0;
wire media_sd_wr;
wire [8:0] media_stream_data,media_fifo_data;
wire [14:0] media_fifo_used;
wire [15:0] media_fifo_occupancy=mpeg2_stream_full ? 16'd32768 : {1'b0,media_fifo_used};
wire media_stream_valid,media_reader_idle;
wire media_prefill_mpeg,media_fatal_sys,media_reader_error_mpeg;
reg media_prefill=0;
wire media_reader_cancel,media_fifo_reset,media_reader_start;
wire media_decoder_reset,media_quiesce,media_ddr_idle;
wire [63:0] media_byte_position;
wire [31:0] media_generation;
wire [3:0] media_error;
reg media_mount_d=0,media_user_reset_d=0;
reg [63:0] media_file_size=0;
wire media_user_reset=status[0] | buttons[1];
wire media_eof_close,media_video_eof_close;
wire media_music_hint,media_music_hint_mpeg;
reg media_music_mode=0;
wire media_movie_ddr_idle,media_music_idle;
wire media_music_input_ready,media_music_metadata;
wire [35:0] media_music_total,media_music_total_sys;
wire [3:0] media_music_decode_error;
wire [37:0] media_music_status_sys;
wire [34:0] media_music_elapsed,media_music_duration,media_track_elapsed,media_track_duration,media_track_origin;
wire media_track_times_valid;
wire media_album_duration_known;
wire [28:0] music_mem_addr,movie_mem_addr;
wire [63:0] music_mem_data,movie_mem_data;
wire [7:0] music_mem_be,movie_mem_be,movie_mem_burst;
wire music_mem_read,music_mem_write,movie_mem_read,movie_mem_write;
wire music_play_request=media_music_hint && media_file_size!=0;
assign PLAYER_MUSIC=music_play_request;
assign PLAYER_VISUALIZER=status[123:122];
assign PLAYER_MUSIC_PAUSED=media_paused_sys;
assign PLAYER_PCM_RESET=reset_mpeg2 || !media_music_mode;
assign media_ddr_idle=media_music_mode?media_music_idle:media_movie_ddr_idle;
assign media_eof_close=media_video_eof_close || (music_play_request && !media_fifo_reset &&
 (media_music_status_sys[37] || media_music_status_sys[36] || media_music_error_sys));
wire media_music_error_sys;
video_config_cdc #(.WIDTH(1)) music_hint_cdc(.src_clk(clk_sys),.dst_clk(clk_mpeg2),.src_data(media_music_hint),.dst_data(media_music_hint_mpeg));
video_config_cdc #(.WIDTH(1)) music_error_cdc(.src_clk(clk_mpeg2),.dst_clk(clk_sys),.src_data(|media_music_decode_error),.dst_data(media_music_error_sys));
video_config_cdc #(.WIDTH(36)) music_total_cdc(.src_clk(clk_mpeg2),.dst_clk(clk_sys),.src_data(media_music_total),.dst_data(media_music_total_sys));
video_config_cdc #(.WIDTH(38)) music_position_cdc(.src_clk(CLK_AUDIO_CD),.dst_clk(clk_sys),
 .src_data({PLAYER_MUSIC_FINISHED,PLAYER_MUSIC_ERROR,PLAYER_MUSIC_POSITION}),.dst_data(media_music_status_sys));
media_music_time music_time(.clk(clk_sys),.reset(RESET||media_new_file),
 .track_changed(album_track_changed),.track_start(album_track_start),
 .position(album_position),.total(media_music_total_sys),
 .track_position(album_position>=album_track_start?album_position-album_track_start:36'd0),
 .track_total(album_track_end>=album_track_start?album_track_end-album_track_start:36'd0),
 .elapsed_q(media_music_elapsed),.total_q(media_music_duration),
 .track_elapsed_q(media_track_elapsed),.track_total_q(media_track_duration),
 .track_start_q(media_track_origin),.track_times_valid(media_track_times_valid));
// The bus mode changes only while both previous clients have drained and
// the session is holding decoder reset. It stays fixed for all live requests.
always @(posedge clk_mpeg2)begin
 if(reset_mpeg2_base)media_music_mode<=0;
 else if(media_decoder_reset && media_music_idle && media_movie_ddr_idle)media_music_mode<=media_music_hint_mpeg;
end

// Album cue/seek indexing observes only bytes accepted into the music stream.
wire album_restart,album_busy,album_resume,album_available,album_seek_available,album_landed_sys;
wire [40:0] album_offset;
wire album_track_valid,album_track_changed;
wire [35:0] album_track_start,album_track_end;
wire [35:0] album_start,album_target,album_total;
wire [15:0] album_min,album_max;
wire [7:0] album_tag,album_echo;
wire [148:0] album_config;
wire [36:0] album_absolute_position={1'b0,album_target}+{1'b0,media_music_status_sys[35:0]};
wire [35:0] album_position=album_absolute_position[36]?{36{1'b1}}:album_absolute_position[35:0];
flac_album_control album_control(.clk(clk_sys),.reset(RESET),.new_file(media_new_file),
 .enabled(music_play_request&&!media_duration_busy),.osd_open(media_osd_sync[2]),.key(ps2_key),
 .byte_valid(media_stream_valid&&!media_stream_data[8]&&!media_duration_busy&&!mpeg2_stream_full&&!media_fifo_reset),
 .byte_data(media_stream_data[7:0]),.position(album_position),.file_size(media_file_size),
 .reader_start(media_reader_start),.landed(album_landed_sys),
 .seek_request(media_seek_restart&&music_play_request),.seek_target_q(media_target_sys),
 .restart(album_restart),.busy(album_busy),.resume_frame(album_resume),.start_offset(album_offset),
 .current_track_valid(album_track_valid),.track_changed(album_track_changed),.current_track_number(),
 .current_track_start(album_track_start),.current_track_end(album_track_end),
 .start_sample(album_start),.target_sample(album_target),.total_samples(album_total),.min_block(album_min),.max_block(album_max),.tag(album_tag),.available(album_available),.seek_available(album_seek_available));
video_config_cdc #(.WIDTH(149)) album_config_cdc(.src_clk(clk_sys),.dst_clk(clk_mpeg2),
 .src_data({album_tag,album_resume,album_total,album_min,album_max,album_start,album_target}),.dst_data(album_config));
video_config_cdc #(.WIDTH(8)) album_echo_cdc(.src_clk(clk_mpeg2),.dst_clk(clk_sys),.src_data(album_config[148:141]),.dst_data(album_echo));
wire music_raw_valid,music_raw_eof,music_raw_ready;
wire [31:0] music_raw_pcm;
wire music_landed;
flac_pcm_landing album_landing(.clk(clk_mpeg2),.reset(reset_mpeg2),
 .start_sample(album_config[71:36]),.target_sample(album_config[35:0]),
 .input_valid(music_raw_valid),.input_eof(music_raw_eof),.input_pcm(music_raw_pcm),.input_ready(music_raw_ready),
 .output_valid(PLAYER_PCM_VALID),.output_eof(PLAYER_PCM_DATA[32]),.output_pcm(PLAYER_PCM_DATA[31:0]),
 .output_ready(PLAYER_PCM_READY),.landed(music_landed));
video_config_cdc #(.WIDTH(1)) album_landed_cdc(.src_clk(clk_mpeg2),.dst_clk(clk_sys),.src_data(music_landed),.dst_data(album_landed_sys));

