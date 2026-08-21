`timescale 1ns/1ps

`ifndef H262_PREDICTION_DESCRIPTOR_DEPTH
`define H262_PREDICTION_DESCRIPTOR_DEPTH 4
`endif

`ifndef H262_SOAK_MAX_STREAM_BYTES
`define H262_SOAK_MAX_STREAM_BYTES 4194304
`endif

// Entry 221: complete 72-picture I/P/B progression through the compiled
// generalized P/B raster wrapper, active tagged DDR writer, request arbiter,
// memory service, publication shell, and presentation scheduler.  The 128x96
// source keeps the real pixel and accepted-write work inexpensive while preserving the
// same 3-I/22-P/47-B repeated-GOP transaction sequence as the 720x480 stream.
module tb_h262_live_raster_soak #(
    parameter integer MIXED_PIXEL_MODE=0,
    parameter integer MEMORY_READ_LATENCY=1,
    parameter integer SWAP_WINDOW_CYCLES=10000,
    parameter integer STALL_TRACE_CYCLES=0,
    parameter integer POST_INPUT_TRACE_CYCLES=0
);
    localparam integer EXPECTED_DESCRIPTOR_DEPTH=
        `H262_PREDICTION_DESCRIPTOR_DEPTH;
    // A 720x480 photographic clip at the encoder's default quality does not
    // fit the 1 MiB budget the 128x96 corpus needed, and shrinking the encode
    // to fit changes the content under test.  Size the load buffer for the
    // real stream instead and leave the override available.
    localparam integer MAX_STREAM_BYTES=`H262_SOAK_MAX_STREAM_BYTES;
    localparam integer MAX_MEMORY_READ_LATENCY=256;
    localparam [28:0] DDR_BASE=29'h06000000;
    localparam integer DDR_WORDS=327680;

    reg clk=0,reset=1,stream_valid=0;
    reg [7:0] stream_data=0;
    reg [7:0] stream_mem[0:MAX_STREAM_BYTES-1];
    reg [7:0] pixel_oracle[0:442367];
    reg [63:0] ddr_mem[0:DDR_WORDS-1];
    reg [1023:0] hex_path,pixel_path,prediction_trace_path,row_trace_path;
    reg [1023:0] b_block_trace_path;
    reg [1023:0] picture_trace_path;
    integer stream_len,stream_index=0,quiet_cycles=0;
    integer i,p_rows=0,b_rows=0,p_pictures=0,b_pictures=0;
    integer published_references=0,display_swaps=0;
    integer queued_run_admissions=0,generation_promotions=0;
    integer b_queue_current_starts=0,b_queue_prefetch_starts=0;
    integer b_queue_handoffs=0,b_queue_bank0_starts=0;
    integer b_queue_bank1_starts=0;
    integer b_paired_tap_lookups=0,b_single_tap_advances=0;
    integer b_vertical_tap_pairs=0;
    integer b_quad_tap_lookups=0;
    integer reference_writes=0,scratch0_writes=0,scratch1_writes=0;
    integer bank2_reference_writes=0;
    integer memory_reads=0,total_cycles=0;
    integer stream_stall_cycles=0,last_stream_index=0;
    integer progress_interval=0;
    reg [1023:0] motion_trace_path;
    integer motion_trace_fd=0,motion_trace_cycle=0,motion_repeat_count=0;
    reg [10:0] motion_index_d=0;
    reg motion_valid_d=0;
    integer post_input_cycles=0;
    integer prediction_no_progress_cycles=0;
    integer prediction_trace_fd=0;
    integer row_trace_fd=0,row_trace_cycle=0;
    integer b_block_trace_fd=0,b_block_trace_cycle=0;
    integer picture_trace_fd=0,picture_trace_cycle=0;
    integer picture_trace_next_id=0,picture_trace_ready_id=0;
    integer picture_trace_hold_total=0;
    reg p_row_waiting_d=0,b_row_waiting_d=0;
    reg b_block_fetch_complete_d=0;
    integer prediction_trace_demands=0,prediction_trace_hits=0;
    integer prediction_trace_misses=0,prediction_trace_block_starts=0;
    integer prediction_trace_block_ends=0;
    integer profile_input_decoder=0,profile_input_presentation=0;
    integer profile_input_destination=0;
    integer profile_input_i=0,profile_input_p=0,profile_input_b=0;
    integer profile_decoder_base_parser=0,profile_decoder_p_hold=0;
    integer profile_decoder_b_parse=0,profile_decoder_b_persist=0;
    integer profile_p_four_parse=0,profile_p_legacy_parse=0;
    integer profile_p_wide_parse=0,profile_p_raster_hold=0;
    integer profile_p_old_hold=0,profile_p_hold_other=0;
    integer profile_p_wide_parse_active=0,profile_p_wide_replay=0;
    integer profile_p_wide_raster=0,profile_p_wide_wait_other=0;
    integer profile_b_parse_active=0,profile_b_replay_active=0;
    integer profile_b_replay_twrite=0,profile_b_replay_coeff_wait=0;
    integer profile_b_replay_coeff_writes=0;
    integer profile_b_row_waiting=0,profile_b_parse_other=0;
    integer profile_b_row_raster=0,profile_b_row_other=0;
    integer profile_p_transform=0,profile_b_transform=0;
    integer profile_p_raster=0,profile_b_raster=0;
    integer profile_p_lookup=0,profile_b_lookup=0;
    integer profile_p_ddr_request=0,profile_b_ddr_request=0;
    integer profile_p_ddr_response=0,profile_b_ddr_response=0;
    integer profile_p_emit=0,profile_b_emit=0;
    integer profile_p_store=0,profile_b_store=0;
    integer profile_writer=0,profile_presentation=0;
    integer profile_b_miss_prelaunch=0;
    integer profile_prefetch_lookups=0,profile_prefetch_requests=0;
    integer profile_prefetch_avoided=0,profile_prefetch_induced=0;
    reg profile_prefetch_valid0=0,profile_prefetch_valid1=0;
    reg profile_prefetch_valid2=0,profile_prefetch_valid3=0;
    reg [28:0] profile_prefetch_tag0=0,profile_prefetch_tag1=0;
    reg [28:0] profile_prefetch_tag2=0,profile_prefetch_tag3=0;
    reg [1:0] profile_prefetch_replace=0;
    integer profile_sidecar_misses=0,profile_sidecar_fills=0;
    integer profile_sidecar_hits=0,profile_sidecar_bank0_hits=0;
    integer profile_sidecar_bank1_hits=0;
    reg profile_sidecar_valid0=0,profile_sidecar_valid1=0;
    reg [28:0] profile_sidecar_tag0=0,profile_sidecar_tag1=0;
    integer profile_partition_lookups=0;
    integer profile_partition8_hits=0,profile_partition8_misses=0;
    integer profile_partition16_hits=0,profile_partition16_misses=0;
    reg [7:0] profile_partition8_valid=0;
    reg [15:0] profile_partition16_valid=0;
    reg [28:0] profile_partition8_tag[0:7];
    reg [28:0] profile_partition16_tag[0:15];
    reg [1:0] profile_partition8_replace[0:1];
    reg [1:0] profile_partition16_replace[0:3];
    integer profile_partition_set8,profile_partition_set16;
    integer profile_partition_base8,profile_partition_base16;
    integer profile_partition_way;
    reg profile_partition_hit8,profile_partition_hit16;
    integer profile_victim_lookups=0,profile_victim_primary_hits=0;
    integer profile_victim_hits=0,profile_victim_full_misses=0;
    reg [3:0] profile_victim_primary_valid=0;
    reg [7:0] profile_victim_second_valid=0;
    reg [28:0] profile_victim_primary_tag[0:3];
    reg [28:0] profile_victim_second_tag[0:7];
    reg [1:0] profile_victim_primary_replace=0;
    reg [1:0] profile_victim_second_replace[0:1];
    integer profile_victim_way,profile_victim_bank;
    integer profile_victim_base,profile_victim_slot;
    reg profile_victim_primary_hit,profile_victim_second_hit;
    reg profile_victim_evicted_valid;
    reg [28:0] profile_victim_evicted_tag;
    integer pixel_samples=0,pixel_mismatches=0,max_pixel_delta=0;
    integer pixel_index,pixel_delta,pixel_row,pixel_word,pixel_lane;
    reg first_pixel_mismatch=0;

    function automatic [18:0] reference_frame_offset;
        input [1:0] bank;
        begin
            reference_frame_offset=(bank==2'd1)?19'h10000:
                                   (bank==2'd2)?19'h40000:19'h00000;
        end
    endfunction

    wire frontend_ready,phase1_supported;
    wire [13:0] horizontal_size,vertical_size;
    wire [1:0] intra_dc_precision;
    wire intra_vlc_format;
    wire [2:0] picture_coding_type;
    wire [9:0] temporal_reference;
    wire sequence_end_seen;

    wire decoder_ready,picture_complete;
    wire [1:0] active_bank,completed_bank,reference_bank,previous_reference_bank;
    wire reference_valid;
    wire [7:0] picture_count,reference_promotion_count;
    wire sideband_valid;
    wire [5:0] sideband_index;
    wire signed [15:0] sideband_value;
    wire probe_error,b_success;
    wire [3:0] probe_error_source,p_probe_error_source,p_progress_detail;
    wire [2:0] publication_error_detail;
    wire [4:0] p_wide_probe_error_detail;

    wire [7:0] pred_burstcnt,pred_store_value,pred_sample,pred_recon_value;
    wire [28:0] pred_addr;
    wire pred_rd,pred_store_select,pred_store_valid,pred_store_start;
    wire pred_store_complete,pred_active,pred_read_seen,pred_sample_nonzero;
    wire pred_half_seen,pred_reconstructed_seen,pred_persisted;
    wire pred_row_persisted,pred_error;
    wire [11:0] pred_store_x,pred_store_y;
    wire [3:0] pred_progress;
    wire [2:0] pred_error_source;
    wire [4:0] pred_error_detail;
    assign pred_active=prediction.mixed_active||prediction.b_active;

    // Decode the compact component/scratch tags exactly as the active DDR
    // writer does, then address the software-decoded display-order oracle by
    // temporal_reference.  The one-GOP mixed stream gives every picture a
    // unique temporal reference from 0 through 23.
    wire pixel_scratch_tag=(pred_store_x[11:10]==2'b11);
    wire pixel_wide_bs0=pixel_scratch_tag&&pred_store_y[11]&&
        (pred_store_y[10:9]!=2'b11);
    wire pixel_wide_bs1=pixel_scratch_tag&&!pred_store_y[11]&&
        (pred_store_y[10:9]!=2'b00);
    wire pixel_wide_bs=pixel_wide_bs0||pixel_wide_bs1;
    wire [1:0] pixel_legacy_component=(pred_store_x[9:8]==2'b00)?2'd0:
        (pred_store_x[9:8]==2'b01)?2'd1:
        (pred_store_x[9:8]==2'b10)?2'd2:2'd3;
    wire [1:0] pixel_wide_component=pixel_wide_bs0?
        pred_store_y[10:9]:(pred_store_y[10:9]-2'b01);
    wire [1:0] pixel_component=pixel_scratch_tag?
        (pixel_wide_bs?pixel_wide_component:pixel_legacy_component):
        (pred_store_x[11:10]==2'b01)?2'd1:
        (pred_store_x[11:10]==2'b10)?2'd2:2'd0;
    wire [11:0] pixel_x=pixel_wide_bs?{2'b00,pred_store_x[9:0]}:
        pixel_scratch_tag?{4'b0000,pred_store_x[7:0]}:
        (pred_store_x[11:10]!=2'b00)?{2'b00,pred_store_x[9:0]}:
        pred_store_x;
    wire [11:0] pixel_y=pixel_wide_bs?{3'b000,pred_store_y[8:0]}:
        pred_store_y;

    wire writer_stored,writer_seen,writer_error,writer_busy;
    wire [7:0] writer_burstcnt,writer_be;
    wire [28:0] writer_addr;
    wire writer_rd,writer_we;
    wire [63:0] writer_din;

    wire [7:0] memory_burstcnt;
    wire [28:0] memory_addr;
    wire memory_rd,memory_we;
    wire [63:0] memory_din;
    wire [7:0] memory_be;
    reg [63:0] memory_dout=0;
    reg memory_dout_ready=0;
    reg [MAX_MEMORY_READ_LATENCY-1:0] read_valid_pipe=0;
    reg [18:0] read_index_pipe[0:MAX_MEMORY_READ_LATENCY-1];
    integer read_pipe_pointer=0;
    wire read_pending=|read_valid_pipe;
    wire pred_busy,pred_dout_ready;

    wire prediction_trace_b=prediction.b_engine_select;
    wire [10:0] prediction_trace_mbi=prediction_trace_b?
        prediction.b_probe.mbi:prediction.mixed_probe.mbi;
    wire [2:0] prediction_trace_blk=prediction_trace_b?
        prediction.b_probe.blk:prediction.mixed_probe.blk;
    wire [5:0] prediction_trace_ei=prediction_trace_b?
        prediction.b_probe.ei:prediction.mixed_probe.ei;
    wire [1:0] prediction_trace_tap=prediction_trace_b?
        prediction.b_probe.tap_index:prediction.mixed_probe.tap_index;
    wire [1:0] prediction_trace_direction=prediction_trace_b?
        prediction.b_probe.pred_direction:2'd1;
    wire prediction_trace_block_start=prediction_trace_b?
        (prediction.b_probe.pixel_setup&&(prediction.b_probe.ei==0)):
        (prediction.mixed_probe.pixel_setup&&(prediction.mixed_probe.ei==0));
    wire prediction_trace_capture=
        prediction.reference_cache.request_accept;
    wire prediction_trace_capture_hit=
        prediction.reference_cache.ordered_request_hit;
    wire prediction_trace_lookup_hit=
        prediction.reference_cache.lookup_request&&
        prediction.reference_cache.cache_lookup_hit;

    wire [1:0] display_frame_bank;
    wire display_scratch,display_scratch_bank;
    wire decode_scratch_bank,presentation_hold,presentation_complete;
    wire presentation_error;
    wire reference_overlap_header;
    wire [2:0] framebuffer_swap_reset_count;
    reg swap_window_pulse=0;
    integer swap_counter=0;

    reg [31:0] picture_window=0;
    wire [31:0] picture_window_next={picture_window[23:0],stream_data};
    reg picture_header_capture=0,picture_header_second_byte=0;
    reg [7:0] picture_trace_header_first=0;
    reg b_picture_start=0,non_b_picture_start=0,p_picture_start=0,sequence_end=0;
    reg reference_ownership_arm=0,destination_ownership_hold=0;

    reg pred_persisted_d=0;
    reg queued_run_active_d=0,promotion_pending_d=0;
    reg pred_read_observed=0,pred_reconstructed_observed=0;
    reg [1:0] display_frame_bank_d=0;
    reg display_scratch_d=0,display_scratch_bank_d=0;
    reg [7:0] reference_identity[0:2];
    reg [7:0] scratch_identity[0:1];
    reg [7:0] picture_trace_reference_id[0:2];
    reg [7:0] picture_trace_scratch_id[0:1];
    reg [2:0] picture_trace_reference_type[0:2];
    reg [2:0] picture_trace_scratch_type[0:1];
    reg [9:0] picture_trace_reference_tr[0:2];
    reg [9:0] picture_trace_scratch_tr[0:1];
    reg [9:0] last_reference_temporal=0;
    wire [7:0] displayed_identity=display_scratch ?
        scratch_identity[display_scratch_bank] : reference_identity[display_frame_bank];

    wire destination_display_owned=!display_scratch&&
        (active_bank==display_frame_bank);
    wire frame_waiting=picture_complete&&
        (display_scratch||(completed_bank!=display_frame_bank));
    wire stream_ready=decoder_ready&&!presentation_hold&&
        !destination_ownership_hold;

    always #5 clk=~clk;


    mpeg2_h262_frontend frontend(
        .clk(clk),.reset(reset),.stream_data(stream_data),
        .stream_valid(stream_valid),.frontend_ready(frontend_ready),
        .phase1_supported(phase1_supported),.horizontal_size(horizontal_size),
        .vertical_size(vertical_size),.intra_dc_precision(intra_dc_precision),
        .intra_vlc_format(intra_vlc_format),
        .picture_coding_type(picture_coding_type),
        .temporal_reference(temporal_reference),
        .sequence_end_seen(sequence_end_seen));

    mpeg2_h262_two_picture_probe publication(
        .clk(clk),.reset(reset),.stream_data(stream_data),
        .stream_valid(stream_valid),.stream_ready(decoder_ready),
        .phase1_supported(phase1_supported),.vertical_size(vertical_size),
        .intra_dc_precision(intra_dc_precision),
        .intra_vlc_format(intra_vlc_format),
        .pipeline_block_done(1'b1),.recon_block_complete(1'b1),
        .p_persistence_complete(pred_persisted),
        .p_row_persistence_complete(pred_row_persisted),
        .picture_420_complete(picture_complete),
        .active_frame_bank(active_bank),.completed_frame_bank(completed_bank),
        .picture_count(picture_count),.reference_frame_valid(reference_valid),
        .reference_frame_bank(reference_bank),
        .previous_reference_frame_bank(previous_reference_bank),
        .reference_promotion_count(reference_promotion_count),
        .p_residual_sample_valid(sideband_valid),
        .p_residual_sample_index(sideband_index),
        .p_residual_sample_value(sideband_value),
        .probe_error(probe_error),.probe_error_source(probe_error_source),
        .p_probe_error_source(p_probe_error_source),
        .p_progress_detail(p_progress_detail),
        .publication_error_detail(publication_error_detail),
        .p_wide_probe_error_detail(p_wide_probe_error_detail),
        .b_user_success(b_success));

    mpeg2_h262_reference_read_probe prediction(
        .clk(clk),.reset(reset),.horizontal_size(horizontal_size),
        .vertical_size(vertical_size),.p_vector_proof_seen(1'b1),
        .p_forward_vector_valid(publication.p_forward_vector_valid),
        .p_forward_vector_x(publication.p_forward_vector_x),
        .p_forward_vector_y(publication.p_forward_vector_y),
        .forward_f_code_horizontal(frontend.forward_f_code_horizontal),
        .forward_f_code_vertical(frontend.forward_f_code_vertical),
        .p_implicit_reconstruct_request(1'b0),
        .p_residual_sample_valid(sideband_valid),
        .p_residual_sample_index(sideband_index),
        .p_residual_sample_value(sideband_value),
        .reference_frame_valid(reference_valid),
        .reference_frame_bank(reference_bank),
        .previous_reference_frame_bank(previous_reference_bank),
        .destination_frame_bank(active_bank),
        .b_scratch_frame_bank(decode_scratch_bank),
        .p_store_block_stored(writer_stored),.ddram_busy(pred_busy),
        .ddram_dout(memory_dout),.ddram_dout_ready(pred_dout_ready),
        .ddram_burstcnt(pred_burstcnt),.ddram_addr(pred_addr),
        .ddram_rd(pred_rd),.p_store_select(pred_store_select),
        .p_store_pixel_value(pred_store_value),
        .p_store_pixel_x(pred_store_x),.p_store_pixel_y(pred_store_y),
        .p_store_pixel_valid(pred_store_valid),
        .p_store_block_start(pred_store_start),
        .p_store_block_complete(pred_store_complete),.read_seen(pred_read_seen),
        .sample_value(pred_sample),.sample_nonzero(pred_sample_nonzero),
        .half_sample_seen(pred_half_seen),
        .reconstructed_seen(pred_reconstructed_seen),
        .reconstructed_value(pred_recon_value),.persisted_seen(pred_persisted),
        .row_persisted(pred_row_persisted),.p_progress_stage(pred_progress),
        .probe_error(pred_error),.probe_error_source(pred_error_source),
        .probe_error_detail(pred_error_detail));

    // This is the active writer selected by files.qip.  P chroma tags and B
    // scratch-bank/component tags are intentionally presented exactly as the
    // compiled top level presents them.
    mpeg2_h262_ddram_store writer(
        .clk(clk),.reset(reset),.frame_bank(active_bank),
        .pixel_value(pred_store_value),.pixel_component(2'd0),
        .pixel_x(pred_store_x),.pixel_y(pred_store_y),
        .pixel_valid(pred_store_valid),.block_start(pred_store_start),
        .block_complete(pred_store_complete),.block_stored(writer_stored),
        .write_seen(writer_seen),.store_error(writer_error),
        .ddram_busy(writer_busy),.ddram_burstcnt(writer_burstcnt),
        .ddram_addr(writer_addr),.ddram_rd(writer_rd),
        .ddram_din(writer_din),.ddram_be(writer_be),.ddram_we(writer_we));

    mpeg2_h262_ddram_arbiter arbiter(
        .clk(clk),.reset(reset),.writer_burstcnt(writer_burstcnt),
        .writer_addr(writer_addr),.writer_rd(writer_rd),
        .writer_din(writer_din),.writer_be(writer_be),.writer_we(writer_we),
        .writer_busy(writer_busy),.reader_burstcnt(8'd0),.reader_addr(29'd0),
        .reader_rd(1'b0),.prediction_burstcnt(pred_burstcnt),
        .prediction_addr(pred_addr),.prediction_rd(pred_rd),
        .prediction_busy(pred_busy),.prediction_dout_ready(pred_dout_ready),
        .ddram_busy(1'b0),.ddram_dout_ready(memory_dout_ready),
        .ddram_burstcnt(memory_burstcnt),.ddram_addr(memory_addr),
        .ddram_rd(memory_rd),.ddram_din(memory_din),.ddram_be(memory_be),
        .ddram_we(memory_we));

    mpeg2_h262_b_presentation_scheduler scheduler(
        .clk(clk),.reset(reset),.swap_window_pulse(swap_window_pulse),
        .frame_rate_code(4'h3),
        .frame_waiting(frame_waiting),.completed_frame_bank(completed_bank),
        .reference_frame_bank(reference_bank),.b_picture_start(b_picture_start),
        .reference_promotion_count(reference_promotion_count),
        .non_b_picture_start(non_b_picture_start),
        .p_picture_start(p_picture_start),.sequence_end(sequence_end),
        .b_user_success(b_success),.b_decode_error(probe_error||pred_error),
        .display_frame_bank(display_frame_bank),.display_scratch(display_scratch),
        .display_scratch_bank(display_scratch_bank),
        .decode_scratch_bank(decode_scratch_bank),
        .framebuffer_swap_reset_count(framebuffer_swap_reset_count),
        .reference_overlap_header(reference_overlap_header),
        .presentation_hold(presentation_hold),
        .presentation_complete(presentation_complete),
        .presentation_error(presentation_error));

    initial begin
        reference_identity[0]=0;
        reference_identity[1]=0;
        reference_identity[2]=0;
        scratch_identity[0]=0;
        scratch_identity[1]=0;
        picture_trace_reference_id[0]=0;
        picture_trace_reference_id[1]=0;
        picture_trace_reference_id[2]=0;
        picture_trace_scratch_id[0]=0;
        picture_trace_scratch_id[1]=0;
        picture_trace_reference_type[0]=0;
        picture_trace_reference_type[1]=0;
        picture_trace_reference_type[2]=0;
        picture_trace_scratch_type[0]=0;
        picture_trace_scratch_type[1]=0;
        picture_trace_reference_tr[0]=0;
        picture_trace_reference_tr[1]=0;
        picture_trace_reference_tr[2]=0;
        picture_trace_scratch_tr[0]=0;
        picture_trace_scratch_tr[1]=0;
        for(i=0;i<DDR_WORDS;i=i+1)ddr_mem[i]=0;
        if(!$value$plusargs("HEX=%s",hex_path))$fatal(1,"missing +HEX");
        if(!$value$plusargs("LEN=%d",stream_len))$fatal(1,"missing +LEN");
        // A 720x480 replay runs for tens of minutes with no output until it
        // either completes or fails.  +PROGRESS=<cycles> makes that visible
        // without changing any functional timing.
        void'($value$plusargs("PROGRESS=%d",progress_interval));
        if($value$plusargs("ROW_EVENT=%s",row_event_path))begin
            row_event_fd=$fopen(row_event_path,"w");
            if(row_event_fd==0)$fatal(1,"cannot open row event trace");
            $fdisplay(row_event_fd,"cycle,hdr,event,src,outstanding,waiting,state");
        end
        if($value$plusargs("PATH1=%s",path1_path))begin
            path1_fd=$fopen(path1_path,"w");
            if(path1_fd==0)$fatal(1,"cannot open path1 trace");
            $fdisplay(path1_fd,"cycle,hdr,final_queued,retired,produced,outstanding,waiting,blocked,state");
        end
        // Entry 294 keyed its duplicate detector on the residual sideband
        // index, which is a fixed class code (3e non-intra / 3b intra) and is
        // therefore constant across any run of skipped macroblocks.  This
        // trace records the 11-bit macroblock index instead, which is the only
        // field that can distinguish a repeated record from a legitimate skip
        // run.  Observation only: no RTL signal is driven from here.
        if($value$plusargs("MOTION_TRACE=%s",motion_trace_path))begin
            motion_trace_fd=$fopen(motion_trace_path,"w");
            if(motion_trace_fd==0)$fatal(1,"cannot open motion trace");
            $fdisplay(motion_trace_fd,"cycle,index,intra,x,y,repeat");
        end
        if($value$plusargs("PRED_TRACE=%s",prediction_trace_path))begin
            prediction_trace_fd=$fopen(prediction_trace_path,"w");
            if(prediction_trace_fd==0)
                $fatal(1,"cannot open prediction trace");
            $fdisplay(prediction_trace_fd,
                "cycle,event,engine,temporal_reference,mbi,blk,ei,tap,direction,address");
        end
        if($value$plusargs("ROW_TRACE=%s",row_trace_path))begin
            row_trace_fd=$fopen(row_trace_path,"w");
            if(row_trace_fd==0)
                $fatal(1,"cannot open row trace");
            $fdisplay(row_trace_fd,
                "cycle,engine,event,temporal_reference");
        end
        if($value$plusargs("B_BLOCK_TRACE=%s",b_block_trace_path))begin
            b_block_trace_fd=$fopen(b_block_trace_path,"w");
            if(b_block_trace_fd==0)
                $fatal(1,"cannot open B block trace");
            $fdisplay(b_block_trace_fd,
                "cycle,event,temporal_reference,mbi,blk,direction,fmvx,fmvy,bmvx,bmvy");
        end
        if($value$plusargs("PICTURE_TRACE=%s",picture_trace_path))begin
            picture_trace_fd=$fopen(picture_trace_path,"w");
            if(picture_trace_fd==0)
                $fatal(1,"cannot open picture trace");
            $fdisplay(picture_trace_fd,
                "cycle,event,id,type,temporal_reference,bank,hold_total");
        end
        if(MIXED_PIXEL_MODE)begin
            if(!$value$plusargs("PIXELS=%s",pixel_path))
                $fatal(1,"missing +PIXELS");
            $readmemh(pixel_path,pixel_oracle,0,442367);
        end
        if((stream_len<=0)||(stream_len>MAX_STREAM_BYTES))
            $fatal(1,"invalid LEN %0d",stream_len);
        $readmemh(hex_path,stream_mem,0,stream_len-1);
        repeat(5)@(posedge clk);
        reset<=0;
    end

    // Entry 263: expose only row-buffer ownership boundaries.  READY marks
    // the instant parsing/transform production has filled the current row;
    // RETIRE marks reconstruction and persistence releasing that row.  The
    // sidecar analyzer can replay these intervals through a two-bank schedule
    // without changing functional timing or adding production logic.
    always @(posedge clk) begin
        if(reset)begin
            row_trace_cycle<=0;
            p_row_waiting_d<=0;
            b_row_waiting_d<=0;
        end else begin
            row_trace_cycle<=row_trace_cycle+1;
            if(row_trace_fd!=0)begin
                if(publication.p_controller.wide_general_probe.row_waiting&&
                   !p_row_waiting_d)
                    $fdisplay(row_trace_fd,"%0d,P,READY,%0d",
                        row_trace_cycle,temporal_reference);
                if(publication.p_controller.wide_general_probe.row_retired&&
                   publication.p_controller.wide_general_probe.row_waiting)
                    $fdisplay(row_trace_fd,"%0d,P,RETIRE,%0d",
                        row_trace_cycle,temporal_reference);
                if(publication.b_controller.row_waiting&&!b_row_waiting_d)
                    $fdisplay(row_trace_fd,"%0d,B,READY,%0d",
                        row_trace_cycle,temporal_reference);
                if(publication.b_controller.row_retired&&
                   publication.b_controller.row_waiting)
                    $fdisplay(row_trace_fd,"%0d,B,RETIRE,%0d",
                        row_trace_cycle,temporal_reference);
            end
            p_row_waiting_d<=
                publication.p_controller.wide_general_probe.row_waiting;
            b_row_waiting_d<=publication.b_controller.row_waiting;
        end
    end

    // Entry 272: simulation-only B block ownership boundaries. START names
    // either the current launch or its actual prefetched successor, FETCHED
    // tracks the selected consumer bank, and RETIRE is the writer persistence
    // barrier that permits the released bank to be reused.
    always @(posedge clk) begin
        if(reset)begin
            b_block_trace_cycle<=0;
            b_block_fetch_complete_d<=0;
        end else begin
            b_block_trace_cycle<=b_block_trace_cycle+1;
            if(prediction.b_probe.block_fetch_active0&&
               prediction.b_probe.block_fetch_active1)
                $fatal(1,"both B footprint producers active at cycle %0d",
                       b_block_trace_cycle);
            if(prediction.b_probe.block_fetch_start)begin
                if(prediction.b_probe.block_fetch_start_prefetch)
                    b_queue_prefetch_starts<=b_queue_prefetch_starts+1;
                else
                    b_queue_current_starts<=b_queue_current_starts+1;
                if(prediction.b_probe.block_fetch_start_bank)
                    b_queue_bank1_starts<=b_queue_bank1_starts+1;
                else
                    b_queue_bank0_starts<=b_queue_bank0_starts+1;
            end
            if(prediction.b_probe.wait_store&&writer_stored&&
               (prediction.b_probe.blk<5)&&
               prediction.b_probe.block_prefetch_valid)
                b_queue_handoffs<=b_queue_handoffs+1;
            if(prediction.b_probe.lookup_pair)
                b_paired_tap_lookups<=b_paired_tap_lookups+1;
            if(prediction.b_probe.lookup_vertical_pair)
                b_vertical_tap_pairs<=b_vertical_tap_pairs+1;
            if(prediction.b_probe.lookup_quad)
                b_quad_tap_lookups<=b_quad_tap_lookups+1;
            if(prediction.b_probe.lookup_wait&&
               prediction.b_probe.block_lookup_ready&&
               prediction.b_probe.block_lookup_valid&&
               !prediction.b_probe.tap_last&&
               !prediction.b_probe.lookup_pair&&
               !prediction.b_probe.lookup_quad)
                b_single_tap_advances<=b_single_tap_advances+1;
            if(b_block_trace_fd!=0)begin
                if(prediction.b_probe.block_fetch_start)
                    $fdisplay(b_block_trace_fd,
                        "%0d,START,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                        b_block_trace_cycle,temporal_reference,
                        prediction.b_probe.mbi,
                        prediction.b_probe.blk+
                            prediction.b_probe.block_fetch_start_prefetch,
                        prediction.b_probe.exec_direction,
                        $signed(prediction.b_probe.block_fetch_start_prefetch?
                            prediction.b_probe.successor_fmvx:
                            prediction.b_probe.exec_fmvx),
                        $signed(prediction.b_probe.block_fetch_start_prefetch?
                            prediction.b_probe.successor_fmvy:
                            prediction.b_probe.exec_fmvy),
                        $signed(prediction.b_probe.block_fetch_start_prefetch?
                            prediction.b_probe.successor_bmvx:
                            prediction.b_probe.exec_bmvx),
                        $signed(prediction.b_probe.block_fetch_start_prefetch?
                            prediction.b_probe.successor_bmvy:
                            prediction.b_probe.exec_bmvy));
                if(prediction.b_probe.block_fetch_complete&&
                   !b_block_fetch_complete_d)
                    $fdisplay(b_block_trace_fd,
                        "%0d,FETCHED,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                        b_block_trace_cycle,temporal_reference,
                        prediction.b_probe.mbi,prediction.b_probe.blk,
                        prediction.b_probe.exec_direction,
                        $signed(prediction.b_probe.exec_fmvx),
                        $signed(prediction.b_probe.exec_fmvy),
                        $signed(prediction.b_probe.exec_bmvx),
                        $signed(prediction.b_probe.exec_bmvy));
                if(prediction.b_probe.wait_store&&writer_stored&&
                   (prediction.b_probe.exec_direction!=0))
                    $fdisplay(b_block_trace_fd,
                        "%0d,RETIRE,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                        b_block_trace_cycle,temporal_reference,
                        prediction.b_probe.mbi,prediction.b_probe.blk,
                        prediction.b_probe.exec_direction,
                        $signed(prediction.b_probe.exec_fmvx),
                        $signed(prediction.b_probe.exec_fmvy),
                        $signed(prediction.b_probe.exec_bmvx),
                        $signed(prediction.b_probe.exec_bmvy));
            end
            b_block_fetch_complete_d<=
                prediction.b_probe.block_fetch_complete;
        end
    end

    always @(negedge clk) begin
        if(reset)begin
            stream_valid<=0;
            stream_data<=0;
        end
        else if(stream_index<stream_len)begin
            if(stream_ready)begin
                stream_data<=stream_mem[stream_index];
                stream_valid<=1;
                stream_index<=stream_index+1;
            end
            else stream_valid<=0;
        end
        else stream_valid<=0;
    end

    always @(posedge clk) begin
        if(reset||!prediction.reference_cache.active)begin
            profile_prefetch_valid0<=0;profile_prefetch_valid1<=0;
            profile_prefetch_valid2<=0;profile_prefetch_valid3<=0;
            profile_prefetch_replace<=0;
            profile_sidecar_valid0<=0;profile_sidecar_valid1<=0;
            profile_partition8_valid<=0;
            profile_partition16_valid<=0;
            profile_partition8_replace[0]<=0;
            profile_partition8_replace[1]<=0;
            profile_partition16_replace[0]<=0;
            profile_partition16_replace[1]<=0;
            profile_partition16_replace[2]<=0;
            profile_partition16_replace[3]<=0;
            profile_victim_primary_valid<=0;
            profile_victim_second_valid<=0;
            profile_victim_primary_replace<=0;
            profile_victim_second_replace[0]<=0;
            profile_victim_second_replace[1]<=0;
        end else if(prediction.reference_cache.lookup_request)begin
            profile_prefetch_lookups<=profile_prefetch_lookups+1;
            if((profile_prefetch_valid0&&
                profile_prefetch_tag0==prediction.reference_cache.request_addr)||
               (profile_prefetch_valid1&&
                profile_prefetch_tag1==prediction.reference_cache.request_addr)||
               (profile_prefetch_valid2&&
                profile_prefetch_tag2==prediction.reference_cache.request_addr)||
               (profile_prefetch_valid3&&
                profile_prefetch_tag3==prediction.reference_cache.request_addr))begin
                if(!prediction.reference_cache.cache_lookup_hit)
                    profile_prefetch_avoided<=profile_prefetch_avoided+1;
            end else begin
                profile_prefetch_requests<=profile_prefetch_requests+1;
                if(prediction.reference_cache.cache_lookup_hit)
                    profile_prefetch_induced<=profile_prefetch_induced+1;
                case(profile_prefetch_replace)
                    2'd0:begin
                        profile_prefetch_valid0<=1;profile_prefetch_valid1<=1;
                        profile_prefetch_tag0<=prediction.reference_cache.request_addr;
                        profile_prefetch_tag1<=prediction.reference_cache.request_addr+1'b1;
                        profile_prefetch_replace<=2'd2;
                    end
                    2'd1:begin
                        profile_prefetch_valid1<=1;profile_prefetch_valid2<=1;
                        profile_prefetch_tag1<=prediction.reference_cache.request_addr;
                        profile_prefetch_tag2<=prediction.reference_cache.request_addr+1'b1;
                        profile_prefetch_replace<=2'd3;
                    end
                    2'd2:begin
                        profile_prefetch_valid2<=1;profile_prefetch_valid3<=1;
                        profile_prefetch_tag2<=prediction.reference_cache.request_addr;
                        profile_prefetch_tag3<=prediction.reference_cache.request_addr+1'b1;
                        profile_prefetch_replace<=2'd0;
                    end
                    default:begin
                        profile_prefetch_valid3<=1;profile_prefetch_valid0<=1;
                        profile_prefetch_tag3<=prediction.reference_cache.request_addr;
                        profile_prefetch_tag0<=prediction.reference_cache.request_addr+1'b1;
                        profile_prefetch_replace<=2'd1;
                    end
                endcase
            end

            // A safer alternative keeps the proven four-entry cache exactly
            // as-is and stores only the speculative following word in one
            // side entry per reference bank.  Model the physical transaction
            // stream here: a side hit consumes its saved word without starting
            // another burst; a miss starts a two-word burst and replaces only
            // that bank's side entry.  This deliberately does not credit an
            // impossible chained prefetch after a side hit.
            if(!prediction.reference_cache.cache_lookup_hit)begin
                profile_sidecar_misses<=profile_sidecar_misses+1;
                if(prediction.reference_cache.request_addr[16])begin
                    if(profile_sidecar_valid1&&
                       profile_sidecar_tag1==prediction.reference_cache.request_addr)begin
                        profile_sidecar_hits<=profile_sidecar_hits+1;
                        profile_sidecar_bank1_hits<=profile_sidecar_bank1_hits+1;
                        profile_sidecar_valid1<=0;
                    end else begin
                        profile_sidecar_fills<=profile_sidecar_fills+1;
                        profile_sidecar_valid1<=1;
                        profile_sidecar_tag1<=prediction.reference_cache.request_addr+1'b1;
                    end
                end else begin
                    if(profile_sidecar_valid0&&
                       profile_sidecar_tag0==prediction.reference_cache.request_addr)begin
                        profile_sidecar_hits<=profile_sidecar_hits+1;
                        profile_sidecar_bank0_hits<=profile_sidecar_bank0_hits+1;
                        profile_sidecar_valid0<=0;
                    end else begin
                        profile_sidecar_fills<=profile_sidecar_fills+1;
                        profile_sidecar_valid0<=1;
                        profile_sidecar_tag0<=prediction.reference_cache.request_addr+1'b1;
                    end
                end
            end

            // Entry 248 proposal model.  Both candidates retain four parallel
            // tag comparisons: the first partitions only by reference bank;
            // the second also separates the low address bit that distributes
            // adjacent vertical-row working sets.  They never affect live RTL.
            profile_partition_lookups<=profile_partition_lookups+1;
            profile_partition_set8=prediction.reference_cache.request_addr[16];
            profile_partition_set16={prediction.reference_cache.request_addr[16],
                                     prediction.reference_cache.request_addr[1]};
            profile_partition_base8=profile_partition_set8*4;
            profile_partition_base16=profile_partition_set16*4;
            profile_partition_hit8=0;
            profile_partition_hit16=0;
            for(profile_partition_way=0;profile_partition_way<4;
                profile_partition_way=profile_partition_way+1)begin
                if(profile_partition8_valid[profile_partition_base8+
                                            profile_partition_way]&&
                   profile_partition8_tag[profile_partition_base8+
                                          profile_partition_way]==
                       prediction.reference_cache.request_addr)
                    profile_partition_hit8=1;
                if(profile_partition16_valid[profile_partition_base16+
                                             profile_partition_way]&&
                   profile_partition16_tag[profile_partition_base16+
                                           profile_partition_way]==
                       prediction.reference_cache.request_addr)
                    profile_partition_hit16=1;
            end
            if(profile_partition_hit8)
                profile_partition8_hits<=profile_partition8_hits+1;
            else begin
                profile_partition8_misses<=profile_partition8_misses+1;
                profile_partition8_valid[profile_partition_base8+
                    profile_partition8_replace[profile_partition_set8]]<=1;
                profile_partition8_tag[profile_partition_base8+
                    profile_partition8_replace[profile_partition_set8]]<=
                        prediction.reference_cache.request_addr;
                profile_partition8_replace[profile_partition_set8]<=
                    profile_partition8_replace[profile_partition_set8]+1'b1;
            end
            if(profile_partition_hit16)
                profile_partition16_hits<=profile_partition16_hits+1;
            else begin
                profile_partition16_misses<=profile_partition16_misses+1;
                profile_partition16_valid[profile_partition_base16+
                    profile_partition16_replace[profile_partition_set16]]<=1;
                profile_partition16_tag[profile_partition_base16+
                    profile_partition16_replace[profile_partition_set16]]<=
                        prediction.reference_cache.request_addr;
                profile_partition16_replace[profile_partition_set16]<=
                    profile_partition16_replace[profile_partition_set16]+1'b1;
            end

            // Entry 249 proposal model: the current four-word primary stays
            // on the fast path.  Only a primary miss probes four victim tags
            // selected by reference bank.  Victim hits swap with the next
            // primary replacement slot; full misses preserve that evicted
            // primary word in the victim stage.
            profile_victim_lookups<=profile_victim_lookups+1;
            profile_victim_primary_hit=0;
            profile_victim_second_hit=0;
            profile_victim_bank=prediction.reference_cache.request_addr[16];
            profile_victim_base=profile_victim_bank*4;
            profile_victim_slot=profile_victim_base;
            for(profile_victim_way=0;profile_victim_way<4;
                profile_victim_way=profile_victim_way+1)begin
                if(profile_victim_primary_valid[profile_victim_way]&&
                   profile_victim_primary_tag[profile_victim_way]==
                       prediction.reference_cache.request_addr)
                    profile_victim_primary_hit=1;
                if(profile_victim_second_valid[profile_victim_base+
                                               profile_victim_way]&&
                   profile_victim_second_tag[profile_victim_base+
                                             profile_victim_way]==
                       prediction.reference_cache.request_addr)begin
                    profile_victim_second_hit=1;
                    profile_victim_slot=profile_victim_base+
                                        profile_victim_way;
                end
            end
            if(profile_victim_primary_hit)
                profile_victim_primary_hits<=profile_victim_primary_hits+1;
            else begin
                profile_victim_evicted_valid=
                    profile_victim_primary_valid[profile_victim_primary_replace];
                profile_victim_evicted_tag=
                    profile_victim_primary_tag[profile_victim_primary_replace];
                profile_victim_primary_valid[profile_victim_primary_replace]<=1;
                profile_victim_primary_tag[profile_victim_primary_replace]<=
                    prediction.reference_cache.request_addr;
                profile_victim_primary_replace<=
                    profile_victim_primary_replace+1'b1;
                if(profile_victim_second_hit)begin
                    profile_victim_hits<=profile_victim_hits+1;
                    if(profile_victim_evicted_valid)begin
                        profile_victim_second_valid[profile_victim_slot]<=1;
                        profile_victim_second_tag[profile_victim_slot]<=
                            profile_victim_evicted_tag;
                    end else
                        profile_victim_second_valid[profile_victim_slot]<=0;
                end else begin
                    profile_victim_full_misses<=profile_victim_full_misses+1;
                    if(profile_victim_evicted_valid)begin
                        profile_victim_bank=profile_victim_evicted_tag[16];
                        profile_victim_slot=profile_victim_bank*4+
                            profile_victim_second_replace[profile_victim_bank];
                        profile_victim_second_valid[profile_victim_slot]<=1;
                        profile_victim_second_tag[profile_victim_slot]<=
                            profile_victim_evicted_tag;
                        profile_victim_second_replace[profile_victim_bank]<=
                            profile_victim_second_replace[profile_victim_bank]+1'b1;
                    end
                end
            end
        end
        if(!reset)begin
            total_cycles<=total_cycles+1;
            if((progress_interval!=0)&&
               ((total_cycles%progress_interval)==0))begin
                $display("SOAK_PROGRESS cycles=%0d byte=%0d/%0d p_pictures=%0d b_pictures=%0d published=%0d swaps=%0d motion_repeats=%0d",
                         total_cycles,stream_index,stream_len,
                         p_pictures,b_pictures,published_references,
                         display_swaps,motion_repeat_count);
                $display("ROWCOUNT produced=%0d retired=%0d mix_pers=%0d mix_pers_sel=%0d",
                         prod_count,ret_count,mixpers_count,mixsel_pers_count);
                $fflush;
            end
            if(prediction_trace_fd!=0)begin
                if(prediction_trace_block_start)begin
                    $fdisplay(prediction_trace_fd,
                        "%0d,S,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%08h",
                        total_cycles,prediction_trace_b,temporal_reference,
                        prediction_trace_mbi,prediction_trace_blk,
                        prediction_trace_ei,prediction_trace_tap,
                        prediction_trace_direction,
                        prediction.reference_cache.request_addr);
                    prediction_trace_block_starts=
                        prediction_trace_block_starts+1;
                end
                if(prediction_trace_capture)begin
                    $fdisplay(prediction_trace_fd,
                        "%0d,%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%08h",
                        total_cycles,
                        prediction_trace_capture_hit?"H":"M",
                        prediction_trace_b,temporal_reference,
                        prediction_trace_mbi,prediction_trace_blk,
                        prediction_trace_ei,prediction_trace_tap,
                        prediction_trace_direction,
                        prediction.reference_cache.request_addr);
                    prediction_trace_demands=prediction_trace_demands+1;
                    if(prediction_trace_capture_hit)
                        prediction_trace_hits=prediction_trace_hits+1;
                    else
                        prediction_trace_misses=prediction_trace_misses+1;
                end
                // Record a direct hit when its address is presented rather
                // than one cycle later when the registered lookup is
                // consumed; the live address may already have advanced then.
                if(prediction_trace_lookup_hit)begin
                    $fdisplay(prediction_trace_fd,
                        "%0d,H,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%08h",
                        total_cycles,prediction_trace_b,temporal_reference,
                        prediction_trace_mbi,prediction_trace_blk,
                        prediction_trace_ei,prediction_trace_tap,
                        prediction_trace_direction,
                        prediction.reference_cache.request_addr);
                    prediction_trace_demands=prediction_trace_demands+1;
                    prediction_trace_hits=prediction_trace_hits+1;
                end
                if(pred_store_complete)begin
                    $fdisplay(prediction_trace_fd,
                        "%0d,E,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%08h",
                        total_cycles,prediction_trace_b,temporal_reference,
                        prediction_trace_mbi,prediction_trace_blk,
                        prediction_trace_ei,prediction_trace_tap,
                        prediction_trace_direction,
                        prediction.reference_cache.request_addr);
                    prediction_trace_block_ends=
                        prediction_trace_block_ends+1;
                end
            end
            if(!pred_active||pred_store_valid||memory_rd||memory_dout_ready||
               writer_stored)
                prediction_no_progress_cycles<=0;
            else
                prediction_no_progress_cycles<=
                    prediction_no_progress_cycles+1;
            if(prediction_no_progress_cycles==10000)
                $fatal(1,"prediction liveness failed engine=%0d/%0d/%0d tap=%0d ei=%0d cache=%0d/%0d addr=%h arb=%0d/%0d/%0d mem=%0d/%0d/%0d pblock=%0d/%0d/%0d/%0d base=%0d fetch=%0d/%0d/%0d/%0d valid=%h",
                       prediction.mixed_probe.req,
                       prediction.mixed_probe.waitresp,
                       prediction.mixed_probe.lookup_wait,
                       prediction.mixed_probe.tap_index,
                       prediction.mixed_probe.ei,
                       prediction.reference_cache.request_active,
                       prediction.reference_cache.response_pending,
                       prediction.reference_cache.request_addr_reg,
                       arbiter.read_outstanding,
                       arbiter.read_owner_prediction,
                       arbiter.read_words_remaining,
                       read_pending,memory_rd,memory_dout_ready,
                       prediction.mixed_probe.block_lookup_row,
                       prediction.mixed_probe.block_lookup_column,
                       prediction.mixed_probe.block_lookup_ready,
                       prediction.mixed_probe.block_lookup_valid,
                       prediction.mixed_probe.block_base_byte,
                       prediction.mixed_probe.block_fetch_active,
                       prediction.mixed_probe.block_fetch_complete,
                       prediction.mixed_probe.block_fetch_issued,
                       prediction.mixed_probe.block_fetch_returned,
                       prediction.mixed_probe.block_fetcher.word_valid);
            // Simulation-only attribution. Input stalls use mutually
            // exclusive priority; engine-stage counters intentionally
            // overlap so each active pipeline exposes its actual occupancy.
            if(stream_index<stream_len)begin
                if(!decoder_ready)begin
                    profile_input_decoder<=profile_input_decoder+1;
                    case(picture_coding_type)
                        3'b001:profile_input_i<=profile_input_i+1;
                        3'b010:profile_input_p<=profile_input_p+1;
                        3'b011:profile_input_b<=profile_input_b+1;
                        default:;
                    endcase
                    // Entry 259: mirror the publication shell's mutually
                    // exclusive ready equation, then split each row-bounded
                    // P/B hold by its live owner. These counters are
                    // simulation-only and do not alter the decoder contract.
                    if(publication.p_hold_effective)begin
                        profile_decoder_p_hold<=profile_decoder_p_hold+1;
                        if(publication.p_controller.four_mb_parse_hold)
                            profile_p_four_parse<=profile_p_four_parse+1;
                        else if(publication.p_controller.legacy_parse_hold)
                            profile_p_legacy_parse<=profile_p_legacy_parse+1;
                        else if(publication.p_controller.wide_parse_hold)begin
                            profile_p_wide_parse<=profile_p_wide_parse+1;
                            if(publication.p_controller.wide_general_probe.parse_active)
                                profile_p_wide_parse_active<=profile_p_wide_parse_active+1;
                            else if(publication.p_controller.wide_general_probe.row_waiting)begin
                                if(prediction.mixed_active)
                                    profile_p_wide_raster<=profile_p_wide_raster+1;
                                else if(publication.p_controller.mixed_replay_active)
                                    profile_p_wide_replay<=profile_p_wide_replay+1;
                                else
                                    profile_p_wide_wait_other<=profile_p_wide_wait_other+1;
                            end
                            else
                                profile_p_wide_wait_other<=profile_p_wide_wait_other+1;
                        end
                        else if(publication.p_controller.raster_hold_active)
                            profile_p_raster_hold<=profile_p_raster_hold+1;
                        else if(publication.p_controller.old_stream_hold)
                            profile_p_old_hold<=profile_p_old_hold+1;
                        else
                            profile_p_hold_other<=profile_p_hold_other+1;
                    end
                    else if(publication.b_parse_hold)begin
                        profile_decoder_b_parse<=profile_decoder_b_parse+1;
                        if(publication.b_controller.parse_active)
                            profile_b_parse_active<=profile_b_parse_active+1;
                        else if(publication.b_controller.replay_active)
                            profile_b_replay_active<=profile_b_replay_active+1;
                        else if(publication.b_controller.row_waiting)begin
                            profile_b_row_waiting<=profile_b_row_waiting+1;
                            if(prediction.b_active)
                                profile_b_row_raster<=profile_b_row_raster+1;
                            else
                                profile_b_row_other<=profile_b_row_other+1;
                        end
                        else
                            profile_b_parse_other<=profile_b_parse_other+1;
                    end
                    else if(publication.b_persistence_wait)
                        profile_decoder_b_persist<=profile_decoder_b_persist+1;
                    else
                        profile_decoder_base_parser<=profile_decoder_base_parser+1;
                end
                else if(presentation_hold)
                    profile_input_presentation<=profile_input_presentation+1;
                else if(destination_ownership_hold)
                    profile_input_destination<=profile_input_destination+1;
            end
            if(sideband_valid)
                profile_p_transform<=profile_p_transform+1;
            if(publication.b_controller.replay_active&&
               (publication.b_controller.rstate==4'd4))
                profile_b_replay_twrite<=profile_b_replay_twrite+1;
            if(publication.b_controller.replay_active&&
               (publication.b_controller.rstate==4'd5))
                profile_b_replay_coeff_wait<=profile_b_replay_coeff_wait+1;
            if(publication.b_controller.t_we)
                profile_b_replay_coeff_writes<=profile_b_replay_coeff_writes+1;
            if(publication.b_controller.t_valid)
                profile_b_transform<=profile_b_transform+1;
            if(prediction.mixed_active)profile_p_raster<=profile_p_raster+1;
            if(prediction.b_active)profile_b_raster<=profile_b_raster+1;
            if(prediction.mixed_probe.lookup_wait)profile_p_lookup<=profile_p_lookup+1;
            if(prediction.b_probe.lookup_wait)profile_b_lookup<=profile_b_lookup+1;
            if(prediction.mixed_probe.req)profile_p_ddr_request<=profile_p_ddr_request+1;
            if(prediction.b_probe.req)profile_b_ddr_request<=profile_b_ddr_request+1;
            if(prediction.mixed_probe.waitresp)profile_p_ddr_response<=profile_p_ddr_response+1;
            if(prediction.b_probe.waitresp)profile_b_ddr_response<=profile_b_ddr_response+1;
            if(prediction.mixed_probe.emit)profile_p_emit<=profile_p_emit+1;
            if(prediction.b_probe.emit)profile_b_emit<=profile_b_emit+1;
            if(prediction.mixed_probe.wait_store)profile_p_store<=profile_p_store+1;
            if(prediction.b_probe.wait_store)profile_b_store<=profile_b_store+1;
            if(prediction.b_probe.miss_response_prelaunch)
                profile_b_miss_prelaunch<=profile_b_miss_prelaunch+1;
            if(memory_we)
                profile_writer<=profile_writer+1;
            if(presentation_hold)profile_presentation<=profile_presentation+1;
        end
        if(MIXED_PIXEL_MODE&&pred_store_valid)begin
            if(temporal_reference>=24||pixel_component>=3||
               (pixel_component==0&&(pixel_x>=128||pixel_y>=96))||
               (pixel_component!=0&&(pixel_x>=64||pixel_y>=48)))
                $fatal(1,"mixed pixel coordinate/tag error tr=%0d c=%0d x=%0d y=%0d raw=%h/%h refs=%0d/%0d active=%0d p_ref=%0d b_mbi=%0d b_col=%0d b_blk=%0d b_ei=%0d bank=%0d prefetch=%0d",
                       temporal_reference,pixel_component,pixel_x,pixel_y,
                       pred_store_x,pred_store_y,previous_reference_bank,
                       reference_bank,active_bank,
                       prediction.mixed_probe.reference_bank_latched,
                       prediction.b_probe.mbi,
                       prediction.b_probe.col,prediction.b_probe.blk,
                       prediction.b_probe.ei,
                       prediction.b_probe.block_consumer_bank,
                       prediction.b_probe.block_prefetch_valid);
            pixel_index=temporal_reference*18432;
            if(pixel_component==0)
                pixel_index=pixel_index+pixel_y*128+pixel_x;
            else if(pixel_component==1)
                pixel_index=pixel_index+12288+pixel_y*64+pixel_x;
            else
                pixel_index=pixel_index+15360+pixel_y*64+pixel_x;
            pixel_delta=$signed({1'b0,pred_store_value})-
                $signed({1'b0,pixel_oracle[pixel_index]});
            if(pixel_delta<0)pixel_delta=-pixel_delta;
            pixel_samples=pixel_samples+1;
            if(pixel_delta>max_pixel_delta)max_pixel_delta=pixel_delta;
            if(pixel_delta>2)begin
                pixel_mismatches=pixel_mismatches+1;
                if(!first_pixel_mismatch)begin
                    first_pixel_mismatch=1;
                    $display("MIXED_PIXEL_FIRST tr=%0d c=%0d x=%0d y=%0d rtl=%0d oracle=%0d delta=%0d",
                             temporal_reference,pixel_component,pixel_x,pixel_y,
                             pred_store_value,pixel_oracle[pixel_index],pixel_delta);
                end
            end
        end
        if((MEMORY_READ_LATENCY<1)||
           (MEMORY_READ_LATENCY>MAX_MEMORY_READ_LATENCY))
            $fatal(1,"unsupported memory latency %0d",MEMORY_READ_LATENCY);
        memory_dout_ready<=read_valid_pipe[read_pipe_pointer];
        if(read_valid_pipe[read_pipe_pointer])
            memory_dout<=ddr_mem[
                read_index_pipe[read_pipe_pointer]];
        read_valid_pipe[read_pipe_pointer]<=memory_rd;
        if(memory_rd)begin
            memory_reads<=memory_reads+1;
            if((memory_addr<DDR_BASE)||((memory_addr-DDR_BASE)>=DDR_WORDS))
                $fatal(1,"DDR read outside frame regions: %h",memory_addr);
            read_index_pipe[read_pipe_pointer]<=memory_addr-DDR_BASE;
        end
        if((read_pipe_pointer+1)>=MEMORY_READ_LATENCY)
            read_pipe_pointer<=0;
        else
            read_pipe_pointer<=read_pipe_pointer+1;
        if(memory_we)begin
            if((memory_addr<DDR_BASE)||((memory_addr-DDR_BASE)>=DDR_WORDS))
                $fatal(1,"DDR write outside frame regions: %h",memory_addr);
            ddr_mem[memory_addr-DDR_BASE]<=memory_din;
            case(memory_addr[18:16])
                3'd0,3'd1:reference_writes<=reference_writes+1;
                3'd2:scratch0_writes<=scratch0_writes+1;
                3'd3:scratch1_writes<=scratch1_writes+1;
                3'd4:begin
                    reference_writes<=reference_writes+1;
                    bank2_reference_writes<=bank2_reference_writes+1;
                end
            endcase
        end
        // The live prediction boundary does not instantiate the independent
        // intra framebuffer writer.  Seed an accepted I picture into the same
        // fixed-stride DDR layout so the following P/B samples are checked
        // against real reference content instead of the historical zero fill.
        if(MIXED_PIXEL_MODE&&picture_complete&&
           picture_coding_type==3'b001)begin
            for(pixel_row=0;pixel_row<96;pixel_row=pixel_row+1)
                for(pixel_word=0;pixel_word<16;pixel_word=pixel_word+1)
                    for(pixel_lane=0;pixel_lane<8;pixel_lane=pixel_lane+1)
                        ddr_mem[reference_frame_offset(completed_bank)+
                                pixel_row*90+pixel_word]
                            [pixel_lane*8 +: 8]=
                            pixel_oracle[pixel_row*128+
                                         pixel_word*8+pixel_lane];
            for(pixel_row=0;pixel_row<48;pixel_row=pixel_row+1)
                for(pixel_word=0;pixel_word<8;pixel_word=pixel_word+1)
                    for(pixel_lane=0;pixel_lane<8;pixel_lane=pixel_lane+1)begin
                        ddr_mem[reference_frame_offset(completed_bank)+
                                18'h0a8c0+pixel_row*45+pixel_word]
                            [pixel_lane*8 +: 8]=
                            pixel_oracle[12288+pixel_row*64+
                                         pixel_word*8+pixel_lane];
                        ddr_mem[reference_frame_offset(completed_bank)+
                                18'h0d2f0+pixel_row*45+pixel_word]
                            [pixel_lane*8 +: 8]=
                            pixel_oracle[15360+pixel_row*64+
                                         pixel_word*8+pixel_lane];
                    end
        end
    end

    always @(posedge clk) begin
        swap_window_pulse<=0;
        b_picture_start<=0;
        non_b_picture_start<=0;
        p_picture_start<=0;
        sequence_end<=0;
        pred_persisted_d<=pred_persisted;
        if(reset)begin
            picture_trace_cycle<=0;
            picture_trace_hold_total<=0;
        end else begin
            picture_trace_cycle<=picture_trace_cycle+1;
            if(presentation_hold)
                picture_trace_hold_total<=picture_trace_hold_total+1;
        end
        if(pred_read_seen)pred_read_observed<=1;
        if(pred_reconstructed_seen)pred_reconstructed_observed<=1;
        if(swap_counter==(SWAP_WINDOW_CYCLES-1))begin
            swap_counter<=0;
            swap_window_pulse<=1;
        end
        else swap_counter<=swap_counter+1;

        if(stream_index!=last_stream_index)begin
            last_stream_index<=stream_index;
            stream_stall_cycles<=0;
        end else if(stream_index<stream_len)
            stream_stall_cycles<=stream_stall_cycles+1;
        if((STALL_TRACE_CYCLES!=0)&&
           (stream_stall_cycles==STALL_TRACE_CYCLES))
            $fatal(1,"stream stall byte=%0d ready=%0d/%0d/%0d current=%0d/%0d/%0d/%0d scratch=%0d%0d next=%0d future=%0d/%0d overlap=%0d queued=%0d/%0d/%0d/%0d qs=%0d%0d qfuture=%0d/%0d qoverlap=%0d promotion=%0d display=%0d/%0d frame=%0d pending=%0d/%0d",
                   stream_index,decoder_ready,presentation_hold,
                   destination_ownership_hold,scheduler.reorder_active,
                   scheduler.run_closed,scheduler.decode_inflight,
                   scheduler.run_picture_count,scheduler.scratch0_pending,
                   scheduler.scratch1_pending,
                   scheduler.next_present_scratch_bank,
                   scheduler.future_frame_pending,
                   scheduler.future_reference_pending,
                   scheduler.overlap_decode_open,
                   scheduler.queued_run_active,
                   scheduler.queued_run_closed,
                   scheduler.queued_decode_inflight,
                   scheduler.queued_run_picture_count,
                   scheduler.queued_scratch0_pending,
                   scheduler.queued_scratch1_pending,
                   scheduler.queued_future_frame_pending,
                   scheduler.queued_future_reference_pending,
                   scheduler.queued_overlap_decode_open,
                   scheduler.promotion_pending,display_scratch,
                   display_scratch_bank,frame_waiting,
                   scheduler.pending_frame_valid,
                   scheduler.overlap_frame_pending);

        queued_run_active_d<=scheduler.queued_run_active;
        promotion_pending_d<=scheduler.promotion_pending;
        if(!queued_run_active_d&&scheduler.queued_run_active)
            queued_run_admissions<=queued_run_admissions+1;
        if(promotion_pending_d&&!scheduler.promotion_pending&&
           scheduler.reorder_active)
            generation_promotions<=generation_promotions+1;

        if(stream_valid)begin
            picture_window<=picture_window_next;
            if(picture_window_next==32'h00000100)begin
                picture_header_capture<=1;
                picture_header_second_byte<=0;
            end
            else if(picture_header_capture)begin
                if(!picture_header_second_byte)begin
                    picture_header_second_byte<=1;
                    picture_trace_header_first<=stream_data;
                end else begin
                    picture_header_capture<=0;
                    picture_header_second_byte<=0;
                    if(picture_trace_fd!=0)
                        $fdisplay(picture_trace_fd,
                            "%0d,START,%0d,%0d,%0d,-1,%0d",
                            picture_trace_cycle,picture_trace_next_id,
                            stream_data[5:3],
                            {picture_trace_header_first,stream_data[7:6]},
                            picture_trace_hold_total);
                    picture_trace_next_id<=picture_trace_next_id+1;
                    if(stream_data[5:3]==3'b011)b_picture_start<=1;
                    else begin
                        non_b_picture_start<=1;
                        if(stream_data[5:3]==3'b010)p_picture_start<=1;
                    end
                    if(reference_ownership_arm||reference_overlap_header)begin
                        reference_ownership_arm<=0;
                        if((stream_data[5:3]==3'b010)&&destination_display_owned)
                            destination_ownership_hold<=1;
                    end
                end
            end
            if(picture_window_next==32'h000001b7)sequence_end<=1;
        end

        if(destination_ownership_hold&&!destination_display_owned)
            destination_ownership_hold<=0;
        if(picture_complete&&(picture_coding_type==3'b010))
            reference_ownership_arm<=1;

        if(pred_row_persisted)begin
            if(publication.b_picture_inflight)b_rows<=b_rows+1;
            else p_rows<=p_rows+1;
        end
        if(pred_persisted&&!pred_persisted_d)begin
            if(publication.b_picture_inflight)begin
                b_pictures<=b_pictures+1;
                scratch_identity[decode_scratch_bank]<=b_pictures+1;
                picture_trace_scratch_id[decode_scratch_bank]<=
                    picture_trace_ready_id;
                picture_trace_scratch_type[decode_scratch_bank]<=3;
                picture_trace_scratch_tr[decode_scratch_bank]<=
                    temporal_reference;
                if(picture_trace_fd!=0)
                    $fdisplay(picture_trace_fd,
                        "%0d,READY,%0d,3,%0d,%0d,%0d",
                        picture_trace_cycle,picture_trace_ready_id,
                        temporal_reference,2+decode_scratch_bank,
                        picture_trace_hold_total);
                picture_trace_ready_id<=picture_trace_ready_id+1;
            end
            else begin
                p_pictures<=p_pictures+1;
                last_reference_temporal<=temporal_reference;
            end
        end
        if(picture_complete)begin
            published_references<=published_references+1;
            reference_identity[completed_bank]<=published_references+1;
            picture_trace_reference_id[completed_bank]<=
                picture_trace_ready_id;
            picture_trace_reference_type[completed_bank]<=picture_coding_type;
            picture_trace_reference_tr[completed_bank]<=temporal_reference;
            if(picture_trace_fd!=0)
                $fdisplay(picture_trace_fd,
                    "%0d,READY,%0d,%0d,%0d,%0d,%0d",
                    picture_trace_cycle,picture_trace_ready_id,
                    picture_coding_type,temporal_reference,completed_bank,
                    picture_trace_hold_total);
            picture_trace_ready_id<=picture_trace_ready_id+1;
        end

        if((display_frame_bank!=display_frame_bank_d)||
           (display_scratch!=display_scratch_d)||
           (display_scratch&&
            (display_scratch_bank!=display_scratch_bank_d)))begin
            display_swaps<=display_swaps+1;
            if(picture_trace_fd!=0)begin
                if(display_scratch)
                    $fdisplay(picture_trace_fd,
                        "%0d,DISPLAY,%0d,%0d,%0d,%0d,%0d",
                        picture_trace_cycle,
                        picture_trace_scratch_id[display_scratch_bank],
                        picture_trace_scratch_type[display_scratch_bank],
                        picture_trace_scratch_tr[display_scratch_bank],
                        2+display_scratch_bank,picture_trace_hold_total);
                else
                    $fdisplay(picture_trace_fd,
                        "%0d,DISPLAY,%0d,%0d,%0d,%0d,%0d",
                        picture_trace_cycle,
                        picture_trace_reference_id[display_frame_bank],
                        picture_trace_reference_type[display_frame_bank],
                        picture_trace_reference_tr[display_frame_bank],
                        display_frame_bank,picture_trace_hold_total);
            end
        end
        display_frame_bank_d<=display_frame_bank;
        display_scratch_d<=display_scratch;
        display_scratch_bank_d<=display_scratch_bank;

        if(probe_error||pred_error||writer_error||presentation_error) begin
            // Error source 10 is the row-execution watchdog: the engine
            // started a row and never observed persistence.  The fatal above
            // reports the surrounding shell but not the engine's own position,
            // which is what identifies the stalled stage.
            $display("RASTER_STALL stage=%0d started=%0d active=%0d persisted=%0d row_persisted=%0d timeout=%0d mbi=%0d col=%0d blk=%0d ei=%0d mrow=%0d desc_slot=%0d desc_latched=%0d motion_end=%0d motion_count=%0d pending=%0d request=%0d ready_res=%0d ref_valid=%0d geom=%0d exec_bank=%0d cap_bank=%0d cap_row=%0d cap_desc=%0d desc_active=%0d sample_expected=%0d",
                prediction.mixed_probe.progress_stage,
                prediction.mixed_probe.started,
                prediction.mixed_probe.active,
                prediction.mixed_probe.persisted_seen,
                prediction.mixed_probe.row_persisted,
                prediction.mixed_probe.timeout,
                prediction.mixed_probe.mbi,
                prediction.mixed_probe.col,
                prediction.mixed_probe.blk,
                prediction.mixed_probe.ei,
                prediction.mixed_probe.mrow,
                prediction.mixed_probe.exec_desc_slot,
                prediction.mixed_probe.exec_desc_count_latched,
                prediction.mixed_probe.exec_motion_end,
                prediction.mixed_probe.motion_count,
                prediction.mixed_probe.pending,
                prediction.mixed_probe.request,
                prediction.mixed_probe.ready_res,
                prediction.mixed_probe.reference_valid,
                prediction.mixed_probe.geometry_ok,
                prediction.mixed_probe.execute_bank,
                prediction.mixed_probe.capture_bank,
                prediction.mixed_probe.capture_row,
                prediction.mixed_probe.capture_desc_count,
                prediction.mixed_probe.desc_active,
                prediction.mixed_probe.sample_expected);
            $fatal(1,"live raster error byte=%0d shell=%0d/%0d/%0d pred=%0d/%0d writer=%0d presentation=%0d sched=%0d/%0d/%0d/%0d scratch=%0d/%0d queued=%0d/%0d/%0d promote=%0d future=%0d/%0d pending=%0d/%0d display=%0d/%0d p_headers=%0d p_publications=%0d p_rows=%0d p_pictures=%0d engine=%0d/%0d/%0d tap=%0d ei=%0d cache=%0d/%0d addr=%h arb=%0d/%0d/%0d mem=%0d/%0d/%0d",
                   stream_index,probe_error_source,p_probe_error_source,
                   publication_error_detail,pred_error_source,pred_error_detail,
                   writer_error,presentation_error,scheduler.reorder_active,
                   scheduler.run_closed,scheduler.decode_inflight,
                   scheduler.run_picture_count,scheduler.scratch0_pending,
                   scheduler.scratch1_pending,scheduler.queued_run_active,
                   scheduler.queued_run_closed,
                   scheduler.queued_decode_inflight,
                   scheduler.promotion_pending,scheduler.future_frame_pending,
                   scheduler.future_frame_bank,scheduler.pending_frame_valid,
                   scheduler.pending_frame_bank,display_scratch,
                   display_frame_bank,publication.p_header_count,
                   publication.p_publication_count,p_rows,p_pictures,
                   prediction.mixed_probe.req,prediction.mixed_probe.waitresp,
                   prediction.mixed_probe.lookup_wait,
                   prediction.mixed_probe.tap_index,prediction.mixed_probe.ei,
                   prediction.reference_cache.request_active,
                   prediction.reference_cache.response_pending,
                   prediction.reference_cache.request_addr_reg,
                   arbiter.read_outstanding,
                   arbiter.read_owner_prediction,
                   arbiter.read_words_remaining,
                   read_pending,memory_rd,memory_dout_ready);
        end

        if((stream_index==stream_len)&&sequence_end_seen&&!pred_active&&
           !presentation_hold&&!destination_ownership_hold&&!writer.writing&&
           !arbiter.read_outstanding&&!read_pending)
            quiet_cycles<=quiet_cycles+1;
        else quiet_cycles<=0;

        // Entry 283: the STALL_TRACE_CYCLES watchdog above is gated by
        // stream_index<stream_len, so it cannot see a decoder that accepted
        // every byte and then failed to quiesce.  Watch that case separately.
        if((stream_index==stream_len)&&(quiet_cycles==0))
            post_input_cycles<=post_input_cycles+1;
        else if(quiet_cycles!=0)
            post_input_cycles<=0;
        if((POST_INPUT_TRACE_CYCLES!=0)&&
           (post_input_cycles==POST_INPUT_TRACE_CYCLES))
            $fatal(1,"post-input stall seq_end=%0d pred_active=%0d phold=%0d dhold=%0d writing=%0d rd_outstanding=%0d rd_pending=%0d pictures=%0d published=%0d swaps=%0d b_pics=%0d p_pics=%0d reorder=%0d run_closed=%0d inflight=%0d runcount=%0d scratch=%0d%0d next=%0d future=%0d/%0d overlap=%0d queued=%0d/%0d/%0d/%0d promotion=%0d display=%0d/%0d/%0d frame_waiting=%0d err=%0d/%0d/%0d/%0d",
                   sequence_end_seen,pred_active,presentation_hold,
                   destination_ownership_hold,writer.writing,
                   arbiter.read_outstanding,read_pending,
                   picture_count,published_references,display_swaps,
                   b_pictures,p_pictures,
                   scheduler.reorder_active,scheduler.run_closed,
                   scheduler.decode_inflight,scheduler.run_picture_count,
                   scheduler.scratch0_pending,scheduler.scratch1_pending,
                   scheduler.next_present_scratch_bank,
                   scheduler.future_frame_pending,
                   scheduler.future_reference_pending,
                   scheduler.overlap_decode_open,
                   scheduler.queued_run_active,scheduler.queued_run_closed,
                   scheduler.queued_decode_inflight,
                   scheduler.queued_run_picture_count,
                   scheduler.promotion_pending,
                   scheduler.display_scratch,scheduler.display_scratch_bank,
                   scheduler.display_frame_bank,frame_waiting,
                   probe_error,writer_error,pred_error,presentation_error);

        if(quiet_cycles==30000)begin
            $display("LIVE_RASTER_RESULT bytes=%0d p_rows=%0d p=%0d b_rows=%0d b=%0d published=%0d pictures=%0d promotions=%0d display_identity=%0d swaps=%0d last_p_temporal=%0d ref_writes=%0d bank2_ref_writes=%0d scratch0_writes=%0d scratch1_writes=%0d ddr_reads=%0d cache=%0d/%0d/%0d cycles=%0d read=%0d recon=%0d presentation=%0d queued=%0d promoted=%0d error=%0d/%0d/%0d/%0d",
                     stream_index,p_rows,p_pictures,b_rows,b_pictures,
                     published_references,picture_count,reference_promotion_count,
                     displayed_identity,display_swaps,last_reference_temporal,
                     reference_writes,bank2_reference_writes,
                     scratch0_writes,scratch1_writes,
                     memory_reads,prediction.reference_cache.cache_hit_count,
                     prediction.reference_cache.cache_miss_count,
                     prediction.reference_cache.uncached_count,total_cycles,
                     pred_read_observed,pred_reconstructed_observed,
                     presentation_complete,queued_run_admissions,
                     generation_promotions,probe_error,pred_error,writer_error,
                     presentation_error);
            $display("LIVE_RASTER_PROFILE input=%0d/%0d/%0d input_type=%0d/%0d/%0d transform=%0d/%0d raster=%0d/%0d lookup=%0d/%0d ddr_request=%0d/%0d ddr_response=%0d/%0d emit=%0d/%0d store=%0d/%0d writer=%0d presentation=%0d b_miss_prelaunch=%0d",
                     profile_input_decoder,profile_input_presentation,
                     profile_input_destination,
                     profile_input_i,profile_input_p,profile_input_b,
                     profile_p_transform,profile_b_transform,
                     profile_p_raster,profile_b_raster,
                     profile_p_lookup,profile_b_lookup,
                     profile_p_ddr_request,profile_b_ddr_request,
                     profile_p_ddr_response,profile_b_ddr_response,
                     profile_p_emit,profile_b_emit,
                     profile_p_store,profile_b_store,
                     profile_writer,profile_presentation,
                     profile_b_miss_prelaunch);
            $display("LIVE_RASTER_BACKPRESSURE decoder=%0d base_parser=%0d p_hold=%0d b_parse=%0d b_persist=%0d p_owner=%0d/%0d/%0d/%0d/%0d/%0d b_owner=%0d/%0d/%0d/%0d",
                     profile_input_decoder,profile_decoder_base_parser,
                     profile_decoder_p_hold,profile_decoder_b_parse,
                     profile_decoder_b_persist,profile_p_four_parse,
                     profile_p_legacy_parse,profile_p_wide_parse,
                     profile_p_raster_hold,profile_p_old_hold,
                     profile_p_hold_other,profile_b_parse_active,
                     profile_b_replay_active,profile_b_row_waiting,
                     profile_b_parse_other);
            $display("LIVE_RASTER_ROW_STAGES p=%0d/%0d/%0d/%0d b=%0d/%0d",
                     profile_p_wide_parse_active,profile_p_wide_replay,
                     profile_p_wide_raster,profile_p_wide_wait_other,
                     profile_b_row_raster,profile_b_row_other);
            $display("LIVE_RASTER_B_REPLAY twrite=%0d coeff_wait=%0d coeff_writes=%0d",
                     profile_b_replay_twrite,profile_b_replay_coeff_wait,
                     profile_b_replay_coeff_writes);
            $display("LIVE_RASTER_PREFETCH lookups=%0d requests=%0d avoided=%0d induced=%0d",
                     profile_prefetch_lookups,profile_prefetch_requests,
                     profile_prefetch_avoided,profile_prefetch_induced);
            $display("LIVE_RASTER_SIDECAR misses=%0d fills=%0d hits=%0d bank0=%0d bank1=%0d",
                     profile_sidecar_misses,profile_sidecar_fills,
                     profile_sidecar_hits,profile_sidecar_bank0_hits,
                     profile_sidecar_bank1_hits);
            $display("LIVE_RASTER_PARTITION lookups=%0d bank4=%0d/%0d bankrow4=%0d/%0d",
                     profile_partition_lookups,
                     profile_partition8_hits,profile_partition8_misses,
                     profile_partition16_hits,profile_partition16_misses);
            $display("LIVE_RASTER_VICTIM lookups=%0d primary_hits=%0d victim_hits=%0d full_misses=%0d probe_cycles=%0d",
                     profile_victim_lookups,profile_victim_primary_hits,
                     profile_victim_hits,profile_victim_full_misses,
                     profile_victim_hits+profile_victim_full_misses);
            $display("LIVE_RASTER_B_QUEUE current=%0d prefetch=%0d handoffs=%0d banks=%0d/%0d",
                     b_queue_current_starts,b_queue_prefetch_starts,
                     b_queue_handoffs,b_queue_bank0_starts,
                     b_queue_bank1_starts);
            $display("LIVE_RASTER_B_TAPS paired=%0d single_advance=%0d vertical=%0d quad=%0d",
                     b_paired_tap_lookups,b_single_tap_advances,
                     b_vertical_tap_pairs,b_quad_tap_lookups);
            $display("LIVE_RASTER_ASSERT publication=%0d/%0d/%0d/%0d writer=%0d read=%0d recon=%0d complete=%0d errors=%0d/%0d/%0d/%0d",
                     publication.p_header_count,
                     publication.p_publication_count,
                     publication.b_header_count,
                     publication.b_persist_count,writer_seen,
                     pred_read_observed,pred_reconstructed_observed,
                     presentation_complete,probe_error,pred_error,
                     writer_error,presentation_error);
            if(MIXED_PIXEL_MODE)begin
                $display("MIXED_PIXEL_RESULT samples=%0d mismatches=%0d max_delta=%0d",
                         pixel_samples,pixel_mismatches,max_pixel_delta);
                if(stream_index!=stream_len||p_rows!=48||p_pictures!=8||
                   b_rows!=90||b_pictures!=15||published_references!=9||
                   picture_count!=9||reference_promotion_count!=9||
                   publication.p_header_count!=8||
                   publication.p_publication_count!=8||
                   publication.b_header_count!=15||
                   publication.b_persist_count!=15||
                   displayed_identity!=9||last_reference_temporal!=10'd23||
                   reference_writes!=18432||bank2_reference_writes!=6912||
                   scratch0_writes!=18432||
                   scratch1_writes!=16128||
                   // Entry 255 launches the exact successor while an older
                   // word is pending.  Potential hits therefore remain
                   // ordered downstream reads rather than overtaking it.
                   prediction.reference_cache.cache_hit_count!=0||
                   ((EXPECTED_DESCRIPTOR_DEPTH==2)&&
                    (prediction.reference_cache.cache_miss_count!=32'd69556))||
                   prediction.reference_cache.uncached_count!=0||
                   (memory_reads!=prediction.reference_cache.cache_miss_count)||
                   b_queue_current_starts!=720||
                   b_queue_prefetch_starts!=3600||
                   b_queue_handoffs!=3600||
                   b_queue_bank0_starts!=2160||
                   b_queue_bank1_starts!=2160||
                   b_paired_tap_lookups!=44197||
                   b_single_tap_advances!=5017||
                   b_vertical_tap_pairs!=22327||
                   b_quad_tap_lookups!=4241||
                   profile_b_replay_twrite!=26591||
                   profile_b_replay_coeff_writes!=26591||
                   profile_b_replay_coeff_wait!=0||
                   ((EXPECTED_DESCRIPTOR_DEPTH==2)&&
                    (MEMORY_READ_LATENCY==1)&&(total_cycles!=1239996))||
                   ((EXPECTED_DESCRIPTOR_DEPTH==4)&&
                    (MEMORY_READ_LATENCY==1)&&(total_cycles!=1239996))||
                   pixel_samples!=423936||pixel_mismatches!=0||
                   !writer_seen||!pred_read_observed||
                   !pred_reconstructed_observed||!presentation_complete||
                   probe_error||pred_error||writer_error||presentation_error)
                    $fatal(1,"mixed raster pixel regression failed");
                if(prediction_trace_fd!=0)begin
                    if(prediction_trace_hits!=
                           prediction.reference_cache.cache_hit_count||
                       prediction_trace_misses!=
                           prediction.reference_cache.cache_miss_count||
                       prediction_trace_block_starts!=6624||
                       prediction_trace_block_ends!=6624)
                        $fatal(1,"prediction trace accounting failed demands=%0d hits=%0d misses=%0d blocks=%0d/%0d",
                               prediction_trace_demands,
                               prediction_trace_hits,
                               prediction_trace_misses,
                               prediction_trace_block_starts,
                               prediction_trace_block_ends);
                    $fdisplay(prediction_trace_fd,
                        "%0d,Z,0,0,0,0,0,0,0,00000000",
                        total_cycles);
                    $fclose(prediction_trace_fd);
                end
                $finish;
            end
            else if(stream_index!=stream_len||p_rows!=132||p_pictures!=22||
               b_rows!=282||b_pictures!=47||published_references!=25||
               picture_count!=25||reference_promotion_count!=25||
               publication.p_header_count!=22||publication.p_publication_count!=22||
               publication.b_header_count!=47||publication.b_persist_count!=47||
               displayed_identity!=25||last_reference_temporal!=10'd23||
               reference_writes!=50688||bank2_reference_writes!=16128||
               scratch0_writes!=55296||
               scratch1_writes!=52992||
               prediction.reference_cache.cache_hit_count!=0||
               ((EXPECTED_DESCRIPTOR_DEPTH==2)&&
                (prediction.reference_cache.cache_miss_count!=32'd372696))||
               prediction.reference_cache.uncached_count!=0||
               (memory_reads!=prediction.reference_cache.cache_miss_count)||
               b_queue_current_starts!=2256||
               b_queue_prefetch_starts!=11280||
               b_queue_handoffs!=11280||
               b_queue_bank0_starts!=6768||
               b_queue_bank1_starts!=6768||
               b_paired_tap_lookups!=550069||
               b_single_tap_advances!=62827||
               b_vertical_tap_pairs!=425781||
               b_quad_tap_lookups!=102888||
               profile_b_replay_twrite!=262671||
               profile_b_replay_coeff_writes!=262671||
               profile_b_replay_coeff_wait!=0||
               ((EXPECTED_DESCRIPTOR_DEPTH==2)&&
                (MEMORY_READ_LATENCY==1)&&(total_cycles!=6589996))||
               ((EXPECTED_DESCRIPTOR_DEPTH==4)&&
                (MEMORY_READ_LATENCY==1)&&(total_cycles!=6589996))||
               !writer_seen||!pred_read_observed||!pred_reconstructed_observed||
               !presentation_complete||probe_error||pred_error||writer_error||
               presentation_error)
                $fatal(1,"live raster soak failed");
            else begin
                if(prediction_trace_fd!=0)begin
                    if(prediction_trace_hits!=
                           prediction.reference_cache.cache_hit_count||
                       prediction_trace_misses!=
                           prediction.reference_cache.cache_miss_count||
                       prediction_trace_block_starts!=19872||
                       prediction_trace_block_ends!=19872)
                        $fatal(1,"prediction trace accounting failed demands=%0d hits=%0d misses=%0d blocks=%0d/%0d",
                               prediction_trace_demands,
                               prediction_trace_hits,
                               prediction_trace_misses,
                               prediction_trace_block_starts,
                               prediction_trace_block_ends);
                    $fdisplay(prediction_trace_fd,
                        "%0d,Z,0,0,0,0,0,0,0,00000000",
                        total_cycles);
                    $fclose(prediction_trace_fd);
                end
                $finish;
            end
        end
    end

    initial begin
        repeat(200000000)@(posedge clk);
        $fatal(1,"live raster soak timed out at byte %0d",stream_index);
    end

    wire unused=&{1'b0,frontend_ready,sideband_value,pred_sample,
                  pred_sample_nonzero,pred_half_seen,pred_recon_value,
                  pred_progress,p_wide_probe_error_detail,memory_burstcnt,
                  memory_din,memory_be,framebuffer_swap_reset_count};

    // Producer-side motion emission trace.  A repeat is an emission on the
    // cycle immediately after another emission carrying the same macroblock
    // index; consecutive skipped macroblocks advance the index and are not
    // repeats.
    always @(posedge clk) begin
        if(reset)begin
            motion_trace_cycle<=0;
            motion_valid_d<=0;
            motion_index_d<=0;
        end else begin
            motion_trace_cycle<=motion_trace_cycle+1;
            motion_valid_d<=publication.p_controller.wide_motion_valid;
            if(publication.p_controller.wide_motion_valid)
                motion_index_d<=publication.p_controller.wide_motion_index;
            if(publication.p_controller.wide_motion_valid)begin
                if(motion_valid_d&&
                   (publication.p_controller.wide_motion_index==motion_index_d))
                    motion_repeat_count<=motion_repeat_count+1;
                if(motion_trace_fd!=0)
                    $fdisplay(motion_trace_fd,"%0d,%0d,%0d,%0d,%0d,%0d",
                        motion_trace_cycle,
                        publication.p_controller.wide_motion_index,
                        publication.p_controller.wide_motion_intra,
                        publication.p_controller.wide_motion_x,
                        publication.p_controller.wide_motion_y,
                        (motion_valid_d&&
                         (publication.p_controller.wide_motion_index==
                          motion_index_d))?1:0);
            end
        end
    end

    // Entry 296 follow-up: the raster engine only rearms for a new picture on
    // new_picture_metadata, which requires the FIRST sideband event of the
    // picture to be a motion record (index 3e/3b).  Log the opening events of
    // every P picture so a picture that opens with a non-motion event is
    // visible directly rather than inferred.
    integer sb_pic=0,sb_left=0;
    integer p_header_count_d=0;
    always @(posedge clk) begin
        if(reset)begin
            p_header_count_d<=0;
            sb_left<=0;
            sb_pic<=0;
        end else begin
            p_header_count_d<=publication.p_header_count;
            if(publication.p_header_count!=p_header_count_d)begin
                sb_pic<=publication.p_header_count;
                sb_left<=4;
            end
            if((sb_left!=0)&&publication.p_controller.wide_sideband_valid)begin
                sb_left<=sb_left-1;
                $display("PIC_FIRST_SIDEBAND pic=%0d idx=%h val=%h motion=%0d desc_active=%0d persisted=%0d active=%0d",
                    sb_pic,
                    publication.p_controller.wide_sideband_index,
                    publication.p_controller.wide_sideband_value,
                    publication.p_controller.wide_motion_valid,
                    prediction.mixed_probe.desc_active,
                    prediction.mixed_probe.persisted_seen,
                    prediction.mixed_probe.active);
                $fflush;
            end
        end
    end

    // Entry 297 next step: both engines' produce and retire events on one
    // timebase.  row_produced is the P parser's own row-final marker; row_retired
    // is the b_select-muxed persistence, so each retire is attributed to the
    // engine that actually sourced it.
    integer prod_count=0,ret_count=0,mixpers_count=0,mixsel_pers_count=0;
    integer path1_fd=0;
    reg [1023:0] path1_path;
    reg [1023:0] row_event_path;
    integer row_event_fd=0,row_event_cycle=0;
    always @(posedge clk) begin
        if(reset)row_event_cycle<=0;
        else begin
            row_event_cycle<=row_event_cycle+1;
            if(publication.p_controller.wide_general_probe.row_produced)
                prod_count<=prod_count+1;
            if(publication.p_controller.wide_general_probe.row_retired)
                ret_count<=ret_count+1;
            if(prediction.mix_row_persisted)mixpers_count<=mixpers_count+1;
            if(prediction.mix_row_persisted&&prediction.mixed_select)
                mixsel_pers_count<=mixsel_pers_count+1;
            if((path1_fd!=0)&&
               publication.p_controller.wide_general_probe.final_row_queued)
                $fdisplay(path1_fd,"%0d,%0d,1,%0d,%0d,%0d,%0d,%0d,%0d",
                    row_event_cycle,publication.p_header_count,
                    publication.p_controller.wide_general_probe.row_retired,
                    publication.p_controller.wide_general_probe.row_produced,
                    publication.p_controller.wide_general_probe.outstanding_rows,
                    publication.p_controller.wide_general_probe.row_waiting,
                    publication.p_controller.wide_general_probe.bank_blocked,
                    publication.p_controller.wide_general_probe.parser_state);
            if(row_event_fd!=0)begin
                if(publication.p_controller.wide_general_probe.row_produced)
                    $fdisplay(row_event_fd,"%0d,%0d,PRODUCE,P,%0d,%0d,%0d",
                        row_event_cycle,publication.p_header_count,
                        publication.p_controller.wide_general_probe.outstanding_rows,
                        publication.p_controller.wide_general_probe.row_waiting,
                        publication.p_controller.wide_general_probe.parser_state);
                if(publication.p_controller.wide_general_probe.row_retired)
                    $fdisplay(row_event_fd,"%0d,%0d,RETIRE,%0s,%0d,%0d,%0d",
                        row_event_cycle,publication.p_header_count,
                        prediction.b_select?"B":"P",
                        publication.p_controller.wide_general_probe.outstanding_rows,
                        publication.p_controller.wide_general_probe.row_waiting,
                        publication.p_controller.wide_general_probe.parser_state);
            end
        end
    end

endmodule
