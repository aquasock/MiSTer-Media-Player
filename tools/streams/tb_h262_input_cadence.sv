`timescale 1ns/1ps
// Real decoder/writer/scheduler and production ingress wrappers. No HDMI pixel
// raster, physical DDR service or measured host trace is modeled here.
// The FIFO primitives below model bounded showahead storage and synchronized
// pointer visibility, not Intel metastability or exact vendor flag latency.
// Production startup is instantiated by default. Legacy raw-window suppression
// and capacity overrides remain explicit experiment controls, not hardware proof.
module tb_h262_input_cadence;
    localparam integer MAX_STREAM_BYTES=16777216;
    reg clk=0,clk_host=0,clk_video=0,reset=1;
    reg global_reset=1;
    integer warm_reload=0,lifetime_cycles=0,production_startup=1;
    wire stream_valid;
    wire [7:0] stream_data;
    reg [7:0] stream_mem[0:MAX_STREAM_BYTES-1];
    reg [1023:0] hex_path;
    integer stream_len,stream_index=0,total_cycles=0,expected_pictures=449;
    integer sessions=1,session_number=0;
    reg session_done=0;
    wire parser_ready,frontend_ready,phase1_supported,syntax_error;
    wire [13:0] horizontal_size,vertical_size;
    wire [3:0] frame_rate_code;
    wire [1:0] chroma_format,intra_dc_precision,picture_structure;
    wire [2:0] picture_coding_type;
    wire progressive_sequence,progressive_frame,chroma_420_type;
    wire top_field_first,repeat_first_field,frame_pred_frame_dct;
    wire concealment_motion_vectors,intra_vlc_format,q_scale_type,alternate_scan;
    wire intra_quant_matrix_default;

    wire slice_start,macroblock_start;
    wire [2:0] qfs_block_index;
    wire qfs_block_start,qfs_write_en,qfs_block_end;
    wire [5:0] qfs_write_index;
    wire signed [12:0] qfs_write_value;
    wire [4:0] slice_quantiser_scale_code;
    wire macroblock_quant;
    wire [4:0] macroblock_quantiser_scale_code;
    wire [11:0] macroblock_address_increment;
    wire [7:0] slice_vertical_position;
    wire [2:0] slice_vertical_position_extension;
    wire picture_complete,probe_error;
    wire [7:0] picture_count;

    wire iq_complete,iq_error,unsupported_matrix;
    wire iq_coeff_start,iq_coeff_valid,iq_coeff_end;
    wire [5:0] iq_coeff_index;
    wire signed [11:0] iq_coeff_value;
    wire idct_complete,idct_error,idct_sample_valid;
    wire [5:0] idct_sample_index;
    wire signed [15:0] idct_sample_value;
    wire recon_pixel_valid,recon_block_start,recon_block_complete;
    wire recon_macroblock_complete,recon_error;
    wire [1:0] recon_pixel_component;
    wire [11:0] recon_pixel_x,recon_pixel_y;
    wire [7:0] recon_pixel_value;

    wire [4:0] effective_quantiser_scale_code = macroblock_quant ?
        macroblock_quantiser_scale_code : slice_quantiser_scale_code;

    wire [1:0] active_bank,completed_bank,reference_bank,display_bank;
    wire [7:0] reference_count;
    wire first_parsed,presentation_hold,presentation_error,display_scratch;
    wire writer_accepted,writer_error,writer_we,writer_stored,writer_capture_blocked;
    wire profiler_snapshot_ready;
    integer snapshot_fd,snapshot_index;
    wire [28:0] writer_addr;
    integer use_writer=1,phase=194681,busy_period=0,busy_length=0;
    integer direct=0,startup_windows=0,skipped_windows=0;
    integer host_stride=8,resume_cycles=0,host_index=0,host_cooldown=0;
    integer host_tick=0,resume_events=0;
    reg host_was_full=0,host_write=0;
    reg [15:0] host_data=0;
    wire hps_full,hps_empty,hps_read,extracted_ready,ingress_ready,ingress_valid;
    wire [7:0] hps_data,extracted_data,queue_data;
    wire extracted_valid,queue_valid,queue_pending;
    wire [32:0] extracted_pts;
    wire metadata_valid,metadata_ready,output_metadata_valid,pcm_valid,pcm_error;
    wire decoder_accept=parser_ready&&!presentation_hold;
    reg [2:0] download_active_sync=0;
    always @(posedge clk)begin
        if(reset)download_active_sync<=0;
        else download_active_sync<={download_active_sync[1:0],(host_index<stream_len)||host_write};
    end
    wire source_done=!download_active_sync[2]&&hps_empty;
    integer input_wait=0,critical_wait=0,transform_overlap=0,header_wait=0;
    integer interval_input=0,interval_critical=0,interval_overlap=0;
    integer peak_clean=0,peak_hps=0;
    wire parse_active=parser.bookkeeper.picture_probe.parse_active;
    wire pipeline_wait=(parser.bookkeeper.picture_probe.parse_state==18);
    wire input_empty=direct ? (stream_index>=stream_len) : !queue_pending;
    reg [63:0] pixel_hash=64'hcbf29ce484222325;
    reg [63:0] completed_hash[0:2];
    reg [63:0] pixel_token;

    wire writer_busy=(busy_period>0) && ((total_cycles%busy_period)<busy_length);
    reg [31:0] window=0;
    wire [31:0] window_next={window[23:0],stream_data};
    reg header_capture=0,header_second=0;
    wire header_now=stream_valid&&header_capture&&header_second;
    wire i_start=header_now&&(stream_data[5:3]==1);
    wire end_now=stream_valid&&(window_next==32'h000001b7);
    wire waiting=picture_complete&&first_parsed&&(completed_bank!=display_bank);
    reg tick=0,swap=0;
    reg video_frame_window=0,swap_video=0;
    reg [2:0] swap_sync=0;
    wire startup_enabled,video_blank;
    wire scheduler_swap=production_startup ? (swap_sync[1]&&!swap_sync[2]&&startup_enabled) : swap;
    reg end_seen=0,visible_recorded=0;
    mpeg2_h262_native_startup startup(
        .clk_mpeg2(clk),.reset_mpeg2(reset),.clk_video(clk_video),.reset_video(global_reset),
        .native_request(phase1_supported&&!progressive_sequence),.frame_rate_code(frame_rate_code),
        .first_picture_complete(first_parsed),.candidate_presentable(presentable),
        .sequence_end_seen(end_seen),.bypass_event(metadata_valid||pcm_valid),
        .frame_window(video_frame_window),.swaps_enabled(startup_enabled),.video_blank(video_blank));
    always #5.555 clk_video=~clk_video; // 54 MHz versus 60 MHz decoder (scaled)
    always @(posedge clk_video) begin
        if(global_reset)swap_video<=0;else swap_video<=video_frame_window;
    end
    always @(posedge clk) begin
        if(reset)begin swap_sync<=0;end_seen<=0;end
        else begin swap_sync<={swap_sync[1:0],swap_video};if(end_now)end_seen<=1;end
    end
    wire [31:0] scheduler_debug;
    wire presentable,cadence_slot;
    integer hold_cycles=0,writer_wait=0,parser_busy=0;
    integer fd,completed=0,presented=0,pixels=0,words=0,stores=0,headers=0;
    integer first_present=0,last_present=0,previous_complete=0,gaps=0;
    integer generation[0:2];
    reg [1:0] previous_display=0;
    reg [1023:0] report_path;
    always #5 clk=~clk;
    // Production clock ratio: 60 MHz decoder to 20 MHz HPS ingress clock.
    always #15 clk_host=~clk_host;
    assign stream_valid=direct ? (stream_index<stream_len&&decoder_accept) : queue_valid;
    assign stream_data=direct ? stream_mem[stream_index] : queue_data;
    mpeg2_stream_fifo ingress_fifo(.reset(warm_reload ? global_reset : reset),.wr_clk(clk_host),
        .wr_data(host_data),.wr_en(host_write),.wr_full(hps_full),
        .rd_clk(clk),.rd_en(hps_read),.rd_data(hps_data),.rd_empty(hps_empty));
    mpeg2_h262_stream_transport_gate gate(.clk(clk),.reset(reset),
        .fifo_empty(hps_empty),.decoder_ready(ingress_ready),.fatal_error(1'b0),
        .fifo_read(hps_read),.decoder_valid(ingress_valid));
    mpeg2_h262_inband_metadata extractor(.clk(clk),.reset(reset),
        .input_data(hps_data),.input_valid(ingress_valid),.input_ready(ingress_ready),
        .input_end(source_done&&!direct),.stream_data(extracted_data),
        .stream_valid(extracted_valid),.stream_ready(extracted_ready),
        .pts_90k(extracted_pts),.metadata_valid(metadata_valid),.metadata_ready(metadata_ready),
        .pcm_valid(pcm_valid),.pcm_protocol_error(pcm_error),.pcm_ready(1'b1));
    mpeg2_h262_clean_video_queue queue(.clk(clk),.reset(reset),
        .input_data(extracted_data),.input_valid(extracted_valid),.input_ready(extracted_ready),
        .input_metadata_pts(extracted_pts),.input_metadata_valid(metadata_valid),
        .input_metadata_ready(metadata_ready),.output_data(queue_data),.output_valid(queue_valid),
        .output_ready(decoder_accept&&!direct),.output_pending_debug(queue_pending),
        .output_metadata_valid(output_metadata_valid));
    // The host sends 16-bit words, stops on backpressure, then waits the
    // configured resume delay once the full flag clears. This is a scenario,
    // not a measured Main_MiSTer transport implementation.
    always @(negedge clk_host) begin
        if(reset) begin
            host_write=0;host_index=0;host_tick=0;host_cooldown=0;
            host_was_full=0;resume_events=0;
        end else begin
            host_write=0;host_tick=host_tick+1;
            if(hps_full)host_was_full=1;
            if(host_was_full&&!hps_full&&host_cooldown==0)begin
                host_was_full=0;host_cooldown=(resume_cycles+2)/3;
                resume_events=resume_events+1;
            end
            if(host_cooldown>0)host_cooldown=host_cooldown-1;
            else if(!direct&&!hps_full&&host_index<stream_len&&(host_tick%host_stride)==0)begin
                host_data={stream_mem[host_index+1],stream_mem[host_index]};
                host_write=1;host_index=host_index+2;
            end
        end
    end

    mpeg2_h262_frontend frontend(
        .clk(clk),.reset(reset),.stream_data(stream_data),
        .stream_valid(stream_valid),.frontend_ready(frontend_ready),
        .phase1_supported(phase1_supported),
        .syntax_error(syntax_error),.horizontal_size(horizontal_size),
        .vertical_size(vertical_size),.frame_rate_code(frame_rate_code),
        .progressive_sequence(progressive_sequence),.chroma_format(chroma_format),
        .picture_coding_type(picture_coding_type),
        .intra_dc_precision(intra_dc_precision),
        .picture_structure(picture_structure),
        .frame_pred_frame_dct(frame_pred_frame_dct),
        .concealment_motion_vectors(concealment_motion_vectors),
        .q_scale_type(q_scale_type),.intra_vlc_format(intra_vlc_format),
        .alternate_scan(alternate_scan),.progressive_frame(progressive_frame),
        .chroma_420_type(chroma_420_type),.top_field_first(top_field_first),
        .repeat_first_field(repeat_first_field),
        .intra_quant_matrix_default(intra_quant_matrix_default));

    mpeg2_h262_two_picture_probe parser(
        .clk(clk),.reset(reset),.stream_data(stream_data),
        .stream_valid(stream_valid),.stream_ready(parser_ready),
        .phase1_supported(phase1_supported),.vertical_size(vertical_size),
        .intra_dc_precision(intra_dc_precision),
        .intra_vlc_format(intra_vlc_format),
        .pipeline_block_done(use_writer ? writer_accepted : recon_block_complete),
        .recon_block_complete(recon_block_complete),
        .p_persistence_complete(1'b0),.p_row_persistence_complete(1'b0),
        .picture_420_complete(picture_complete),.picture_count(picture_count),
        .first_picture_420_parsed(first_parsed),.active_frame_bank(active_bank),
        .completed_frame_bank(completed_bank),.reference_frame_bank(reference_bank),
        .reference_promotion_count(reference_count),
        .probe_error(probe_error),
        .quantiser_scale_code(slice_quantiser_scale_code),
        .macroblock_address_increment(macroblock_address_increment),
        .macroblock_quant(macroblock_quant),
        .macroblock_quantiser_scale_code(macroblock_quantiser_scale_code),
        .slice_vertical_position(slice_vertical_position),
        .slice_vertical_position_extension(slice_vertical_position_extension),
        .slice_start(slice_start),.luma_macroblock_start(macroblock_start),
        .qfs_block_index(qfs_block_index),.qfs_block_start(qfs_block_start),
        .qfs_write_en(qfs_write_en),.qfs_write_index(qfs_write_index),
        .qfs_write_value(qfs_write_value),.qfs_block_end(qfs_block_end));

    mpeg2_h262_inverse_quant inverse_quant(
        .clk(clk),.reset(reset),.block_start(qfs_block_start),
        .coeff_write_en(qfs_write_en),.coeff_write_index(qfs_write_index),
        .coeff_write_value(qfs_write_value),.block_end(qfs_block_end),
        .intra_quant_matrix_default(intra_quant_matrix_default),
        .intra_dc_precision(intra_dc_precision),
        .quantiser_scale_code(effective_quantiser_scale_code),
        .q_scale_type(q_scale_type),.alternate_scan(alternate_scan),
        .block_complete(iq_complete),.iq_error(iq_error),
        .unsupported_matrix(unsupported_matrix),
        .coeff_out_block_start(iq_coeff_start),
        .coeff_out_valid(iq_coeff_valid),.coeff_out_index(iq_coeff_index),
        .coeff_out_value(iq_coeff_value),.coeff_out_block_end(iq_coeff_end));

    mpeg2_h262_idct idct(
        .clk(clk),.reset(reset),.coeff_block_start(iq_coeff_start),
        .coeff_valid(iq_coeff_valid),.coeff_index(iq_coeff_index),
        .coeff_value(iq_coeff_value),.coeff_block_end(iq_coeff_end),
        .block_complete(idct_complete),.idct_error(idct_error),
        .sample_valid(idct_sample_valid),.sample_index(idct_sample_index),
        .sample_value(idct_sample_value));

    mpeg2_h262_intra_recon recon(
        .clk(clk),.reset(reset),.horizontal_size(horizontal_size),
        .vertical_size(vertical_size),
        .slice_vertical_position(slice_vertical_position),
        .slice_vertical_position_extension(slice_vertical_position_extension),
        .macroblock_address_increment(macroblock_address_increment),
        .slice_start(slice_start),.macroblock_start(macroblock_start),
        .block_index(qfs_block_index),.sample_valid(idct_sample_valid),
        .sample_index(idct_sample_index),.sample_value(idct_sample_value),
        .idct_block_complete(idct_complete),.pixel_valid(recon_pixel_valid),
        .pixel_component(recon_pixel_component),.pixel_x(recon_pixel_x),
        .pixel_y(recon_pixel_y),.pixel_value(recon_pixel_value),
        .block_start(recon_block_start),.block_complete(recon_block_complete),
        .macroblock_420_complete(recon_macroblock_complete),
        .recon_error(recon_error));



    mpeg2_h262_ddram_store writer(
        .clk(clk),.reset(reset),.frame_bank(active_bank),.pixel_value(recon_pixel_value),
        .pixel_component(recon_pixel_component),.pixel_x(recon_pixel_x),.pixel_y(recon_pixel_y),
        .pixel_valid(recon_pixel_valid),.block_start(recon_block_start),
        .block_complete(recon_block_complete),.block_accepted(writer_accepted),
        .capture_blocked_debug(writer_capture_blocked),
        .store_error(writer_error),.ddram_busy(writer_busy),.ddram_we(writer_we),
        .ddram_addr(writer_addr),.block_stored(writer_stored));
    mpeg2_h262_b_presentation_scheduler scheduler(
        .clk(clk),.reset(reset),.swap_window_pulse(scheduler_swap),.cadence_tick_pulse(tick),
        .frame_rate_code(frame_rate_code),.timestamp_candidate_active(1'b0),
        .timestamp_candidate_due(1'b0),.native_ordinary_overlap_enable(1'b1),
        .active_frame_bank(active_bank),.frame_waiting(waiting),
        .completed_frame_bank(completed_bank),.reference_frame_bank(reference_bank),
        .reference_promotion_count(reference_count),.b_picture_start(1'b0),
        .non_b_picture_start(i_start),.i_picture_start(i_start),.p_picture_start(1'b0),
        .sequence_end(end_now),.b_user_success(1'b0),.b_decode_error(probe_error),
        .display_frame_bank(display_bank),.display_scratch(display_scratch),
        .presentation_hold(presentation_hold),.presentation_error(presentation_error),
        .debug_state(scheduler_debug),.candidate_presentable_debug(presentable),
        .cadence_slot_debug(cadence_slot));
    mpeg2_h262_hardware_cadence_profiler profiler(
        .clk_mpeg2(clk),.reset_mpeg2(reset),.clk_video(clk),.reset_video(reset),.pixel_ce(1'b1),
        .native_active(1'b1),.native_decode_active(1'b1),
        .decoder_input_pending(!input_empty),.writer_capacity_blocked(writer_capture_blocked),
        .fifo_pending(!hps_empty),.decoder_ready(parser_ready),
        .presentation_hold(presentation_hold),.destination_hold(1'b0),
        .scratch_available(1'b1),.promotion_active(1'b0),.frame_waiting(waiting),
        .completed_frame_bank(completed_bank),.presentation_complete(1'b1),
        .presentation_error(presentation_error),.scheduler_debug_state(scheduler_debug),
        .swap_window_pulse(production_startup ? (swap_sync[1]&&!swap_sync[2]) : swap),.candidate_presentable(presentable),
        .timestamp_candidate_active(1'b0),.timestamp_candidate_due(1'b0),.cadence_slot(cadence_slot),
        .decoder_byte_accepted(stream_valid),.picture_coding_type(picture_coding_type),
        .temporal_reference(10'd0),.frame_rate_code(frame_rate_code),.picture_count(picture_count),
        .reference_picture_complete(picture_complete),.b_picture_complete(1'b0),
        .prediction_read(1'b0),.prediction_busy(1'b0),.prediction_data_ready(1'b0),
        .writer_write(writer_we),.writer_busy(writer_busy),.display_frame_bank(display_bank),
        .display_scratch(1'b0),.display_scratch_bank(1'b0),
        .sequence_end_seen(stream_index==stream_len),.session_quiet(session_done),
        .terminal_defer(1'b0),.stc_seconds(14'd0),.associated_count(8'd0),.display_pts(33'd0),
        .pcm_sample_count(14'd0),.pcm_fifo_peak(7'd0),.top_field_first(1'b1),
        .repeat_first_field(1'b0),.error_flags(16'd0),.h_pos(12'd0),.v_pos(12'd0),
        .base_r(8'd0),.base_g(8'd0),.base_b(8'd0),.base_de(1'b0),
        .snapshot_ready(profiler_snapshot_ready));
    initial begin
        if (!$value$plusargs("HEX=%s",hex_path)) $fatal(1,"missing HEX");
        if (!$value$plusargs("LEN=%d",stream_len)) $fatal(1,"missing LEN");
        if (!$value$plusargs("REPORT=%s",report_path)) $fatal(1,"missing REPORT");
        if (!$value$plusargs("PICTURES=%d",expected_pictures)) $fatal(1,"missing PICTURES");
        if ($value$plusargs("PHASE=%d",phase)) begin end
        if ($value$plusargs("DIRECT=%d",direct)) begin end
        if ($value$plusargs("PRODUCTION_STARTUP=%d",production_startup)) begin end
        if ($value$plusargs("WARM_RELOAD=%d",warm_reload)) begin end
        if ($value$plusargs("HOST_STRIDE=%d",host_stride)) begin end
        if ($value$plusargs("RESUME_CYCLES=%d",resume_cycles)) begin end
        if ($value$plusargs("STARTUP_WINDOWS=%d",startup_windows)) begin end
        if ($value$plusargs("SESSIONS=%d",sessions)) begin end
        if ($value$plusargs("BUSY_PERIOD=%d",busy_period)) begin end
        if ($value$plusargs("BUSY_LENGTH=%d",busy_length)) begin end
        if (stream_len<1 || stream_len>MAX_STREAM_BYTES || stream_len%2 || host_stride<1 ||
            resume_cycles<0 || startup_windows<0 || sessions<1 || expected_pictures<1)
            $fatal(1,"invalid parameters; ingress requires even byte length");
        $readmemh(hex_path,stream_mem,0,stream_len-1);
        fd=$fopen(report_path,"w");
        if (!fd) $fatal(1,"cannot open report");
        $fdisplay(fd,"event,picture,cycle,interval,bank,detail");
        for(session_number=1;session_number<=sessions;session_number=session_number+1)begin
            reset=1;repeat(10)@(negedge clk_host);@(negedge clk);reset=0;global_reset=0;
            $fdisplay(fd,"session,%0d,0,0,0,0",session_number);
            wait(session_done);repeat(2000)@(negedge clk);
            if(!profiler_snapshot_ready)$fatal(1,"snapshot did not settle");
            if(profiler.deadline_gap_count!=gaps || profiler.display_picture_count_full!=expected_pictures ||
               profiler.display_swap_count_full!=expected_pictures-1)
                $fatal(1,"profiler count disagreement gaps=%0d/%0d",gaps,profiler.deadline_gap_count);
            for(snapshot_index=0;snapshot_index<3 && snapshot_index<gaps;snapshot_index=snapshot_index+1)
                $display("INPUT_DEADLINE session=%0d picture=%0d ready_delay=%0d input_wait=%0d writer_blocked=%0d",
                    session_number,profiler.deadline_records[snapshot_index*8][31:16],
                    profiler.deadline_records[snapshot_index*8+6],profiler.deadline_records[snapshot_index*8+4],
                    profiler.deadline_records[snapshot_index*8+5]);
            $display("INPUT_SESSION_PASS session=%0d",session_number);
        end
        $fclose(fd);$finish;
    end
    always @(negedge clk) begin
        if(global_reset)lifetime_cycles=0;else lifetime_cycles=lifetime_cycles+1;
        // Full-pair window level starts before the decoder-domain edge, as in top.
        video_frame_window=((lifetime_cycles+2002000-phase+5)%2002000)<100;
        if(reset)begin total_cycles=0;tick=0;swap=0;skipped_windows=0;end
        else begin
            total_cycles=total_cycles+1;
            tick=(((production_startup ? lifetime_cycles : total_cycles)+2002000-phase+4)%1001000)==0;
            swap=(total_cycles%2002000)==phase;
            if(swap&&completed>0&&skipped_windows<startup_windows)begin
                swap=0;skipped_windows=skipped_windows+1;
            end
        end
    end
    always @(posedge clk) begin
        if(reset)begin
            stream_index<=0;window<=0;header_capture<=0;header_second<=0;
            hold_cycles=0;writer_wait=0;parser_busy=0;completed=0;presented=0;pixels=0;
            words=0;stores=0;headers=0;first_present=0;last_present=0;previous_complete=0;
            gaps=0;previous_display=0;session_done=0;visible_recorded=0;input_wait=0;critical_wait=0;
            transform_overlap=0;header_wait=0;interval_input=0;interval_critical=0;interval_overlap=0;
            peak_clean=0;peak_hps=0;pixel_hash=64'hcbf29ce484222325;
            for(integer bank=0;bank<3;bank=bank+1)begin generation[bank]=0;completed_hash[bank]=0;end
        end else if(!session_done) begin
            if(production_startup&&!video_blank&&!visible_recorded)begin
                visible_recorded=1;
                if(display_bank!=0 || completed<1)$fatal(1,"initial visible bank wrong");
                $fdisplay(fd,"visible,1,%0d,0,%0d,0",total_cycles,display_bank);
            end
            if(queue.video_fifo.count>peak_clean)peak_clean=queue.video_fifo.count;
            if(ingress_fifo.stream_fifo.occupancy>peak_hps)peak_hps=ingress_fifo.stream_fifo.occupancy;
            if(input_empty&&parser_ready&&!presentation_hold&&stream_index<stream_len)begin
                input_wait=input_wait+1;interval_input=interval_input+1;
                if(parse_active&&!pipeline_wait)begin critical_wait=critical_wait+1;interval_critical=interval_critical+1;end
                else if(parse_active&&pipeline_wait)begin transform_overlap=transform_overlap+1;interval_overlap=interval_overlap+1;end
                else header_wait=header_wait+1;
            end
            if(pcm_valid||metadata_valid||output_metadata_valid||pcm_error)$fatal(1,"unexpected metadata in elementary stream");
            if (stream_valid) begin
                if(stream_index>=stream_len || stream_data!==stream_mem[stream_index])
                    $fatal(1,"byte order mismatch offset=%0d",stream_index);
                stream_index<=stream_index+1;
                window<=window_next;
                if(window_next==32'h00000100)begin header_capture<=1;header_second<=0;end
                else if(header_capture)begin
                    if(!header_second)header_second<=1;
                    else begin header_capture<=0;header_second<=0;end
                end
            end
            if (header_now) begin
                headers=headers+1;
                if(!i_start)$fatal(1,"non-I header");
                $fdisplay(fd,"header,%0d,%0d,0,%0d,%08x",headers,total_cycles,active_bank,scheduler_debug);
            end
            if(syntax_error||probe_error||iq_error||unsupported_matrix||idct_error||recon_error||writer_error||presentation_error)
                $fatal(1,"pipeline error syntax=%0d probe=%0d iq=%0d matrix=%0d idct=%0d recon=%0d writer=%0d scheduler=%0d picture=%0d byte=%0d",
                  syntax_error,probe_error,iq_error,unsupported_matrix,idct_error,recon_error,writer_error,presentation_error,completed,stream_index);
            if(presentation_hold)hold_cycles=hold_cycles+1;
            if(writer_we&&writer_busy)writer_wait=writer_wait+1;
            if(!parser_ready)parser_busy=parser_busy+1;
            if(recon_pixel_valid)begin
                pixels=pixels+1;
                pixel_token={30'd0,recon_pixel_component,recon_pixel_x,recon_pixel_y,recon_pixel_value};
                pixel_hash=(pixel_hash^pixel_token)*64'h100000001b3;
            end
            if(writer_we&&!writer_busy)words=words+1;
            if(writer_stored)stores=stores+1;
            if(picture_complete)begin
                if(pixels!=518400)$fatal(1,"incomplete picture pixels=%0d",pixels);
                pixels=0;completed=completed+1;generation[completed_bank]=completed;
                completed_hash[completed_bank]=pixel_hash;
                $fdisplay(fd,"pixels,%0d,%0d,518400,%0d,%016x",completed,total_cycles,completed_bank,pixel_hash);
                pixel_hash=64'hcbf29ce484222325;
                $fdisplay(fd,"complete,%0d,%0d,%0d,%0d,%08x",completed,total_cycles,total_cycles-previous_complete,completed_bank,scheduler_debug);
                previous_complete=total_cycles;
                if(completed==1)begin
                    presented=1;first_present=total_cycles;last_present=total_cycles;
                end
                if(completed%32==0)$display("INTEGRATED_PROGRESS pictures=%0d cycles=%0d",completed,total_cycles);
                $fflush(fd);
            end
            if(scheduler_swap && completed>1 && !presentable)begin
                $fdisplay(fd,"empty_window,%0d,%0d,%0d,%0d,%0d",presented+1,total_cycles,interval_input,interval_critical,interval_overlap);
            end
            // Observe registered display state on the following clock; intervals remain exact.
            if(display_bank!=previous_display)begin
                if(production_startup&&!visible_recorded)$fatal(1,"swap before initial visibility");
                if(generation[display_bank]!=presented+1)$fatal(1,"lost/duplicate identity expected=%0d actual=%0d",presented+1,generation[display_bank]);
                presented=presented+1;
                $fdisplay(fd,"present,%0d,%0d,%0d,%0d,%08x",presented,total_cycles,total_cycles-last_present,display_bank,scheduler_debug);
                if(presented>2 && total_cycles-last_present>3003000)begin
                    gaps=gaps+1;
                    $display("INTEGRATED_GAP picture=%0d cycles=%0d",presented,total_cycles-last_present);
                end
                last_present=total_cycles;previous_display=display_bank;
                interval_input=0;interval_critical=0;interval_overlap=0;
            end
            if((!production_startup||visible_recorded) && presented==expected_pictures && stream_index==stream_len && stores==expected_pictures*8100)begin
                if(completed!=expected_pictures||words!=expected_pictures*64800||headers!=expected_pictures)
                    $fatal(1,"incomplete stream");
                if(input_wait!=critical_wait+transform_overlap+header_wait)$fatal(1,"input partition mismatch");
                $display("INPUT_PASS session=%0d pictures=%0d gaps=%0d cycles=%0d first=%0d last=%0d words=%0d stores=%0d",
                    session_number,presented,gaps,total_cycles,first_present,last_present,words,stores);
                $display("INPUT_COUNTERS session=%0d input_wait=%0d critical_wait=%0d transform_overlap=%0d header_wait=%0d hold=%0d writer_wait=%0d peak_clean=%0d peak_hps=%0d resumes=%0d",
                    session_number,input_wait,critical_wait,transform_overlap,header_wait,hold_cycles,writer_wait,peak_clean,peak_hps,resume_events);
                session_done=1;$fflush(fd);
            end
            if(total_cycles>2000000000)$fatal(1,"timeout pictures=%0d presented=%0d byte=%0d stores=%0d",completed,presented,stream_index,stores);
        end
    end
endmodule

// Same-clock showahead queue. The capacity override is deliberately confined
// to this simulation primitive; production defaults to 64 KiB.
module scfifo #(
    parameter integer lpm_numwords=16,lpm_width=8,lpm_widthu=4,
    parameter lpm_showahead="ON",lpm_type="scfifo",
    parameter overflow_checking="ON",underflow_checking="ON",use_eab="ON"
)(input wire aclr,clock,input wire [lpm_width-1:0] data,
  input wire wrreq,rdreq,output wire full,empty,output wire [lpm_width-1:0] q);
    localparam integer MAX_DEPTH=(lpm_width==8) ? 65536 : lpm_numwords;
    reg [lpm_width-1:0] memory[0:MAX_DEPTH-1];
    integer capacity=lpm_numwords,write_pointer=0,read_pointer=0,count=0;
    initial begin
        if(lpm_width==8 && $value$plusargs("CLEAN_BYTES=%d",capacity))begin end
        if(capacity<2 || capacity>MAX_DEPTH || (capacity&(capacity-1)))$fatal(1,"bad clean capacity");
    end
    assign full=count==capacity;
    assign empty=count==0;
    assign q=memory[read_pointer];
    always @(posedge clock or posedge aclr)begin
        if(aclr)begin write_pointer<=0;read_pointer<=0;count<=0;end
        else begin
            if(wrreq&&full)$fatal(1,"clean overflow");
            if(rdreq&&empty)$fatal(1,"clean underflow");
            if(wrreq)begin memory[write_pointer]<=data;write_pointer<=(write_pointer+1)&(capacity-1);end
            if(rdreq)read_pointer<=(read_pointer+1)&(capacity-1);
            case({wrreq,rdreq})
                2'b10:count<=count+1;
                2'b01:count<=count-1;
                default:begin end
            endcase
        end
    end
endmodule

// Behavioral mixed-width FIFO: low byte first, separate clock domains,
// delayed pointer visibility and conservative full/empty flags. Binary pointer
// synchronization is a simulation contract, NOT synthesizable CDC guidance.
module dcfifo_mixed_widths #(
    parameter integer lpm_numwords=16384,lpm_width=16,lpm_width_r=8,
    parameter integer lpm_widthu=14,lpm_widthu_r=15,
    parameter integer rdsync_delaypipe=4,wrsync_delaypipe=4,
    parameter lpm_showahead="ON",lpm_type="dcfifo_mixed_widths",
    parameter overflow_checking="ON",underflow_checking="ON",use_eab="ON",
    parameter write_aclr_synch="ON",read_aclr_synch="ON"
)(input wire aclr,wrclk,rdclk,input wire [15:0] data,input wire wrreq,rdreq,
  output wire wrfull,rdempty,output wire [7:0] q);
    reg [7:0] memory[0:131071];
    integer capacity=lpm_numwords*2,write_count=0,read_count=0;
    integer write_sync[0:rdsync_delaypipe-1],read_sync[0:wrsync_delaypipe-1];
    wire [31:0] occupancy=write_count-read_count;
    initial begin
        if($value$plusargs("HPS_BYTES=%d",capacity))begin end
        if(capacity<2||capacity>131072||(capacity&(capacity-1)))$fatal(1,"bad HPS capacity");
        if(lpm_width!=16||lpm_width_r!=8)$fatal(1,"unsupported mixed width");
    end
    assign wrfull=(write_count-read_sync[wrsync_delaypipe-1])>=capacity-1;
    assign rdempty=read_count==write_sync[rdsync_delaypipe-1];
    assign q=memory[read_count&(capacity-1)];
    always @(posedge wrclk or posedge aclr)begin
        if(aclr)begin
            write_count<=0;
            for(integer i=0;i<wrsync_delaypipe;i=i+1)read_sync[i]<=0;
        end else begin
            read_sync[0]<=read_count;
            for(integer i=1;i<wrsync_delaypipe;i=i+1)read_sync[i]<=read_sync[i-1];
            if(wrreq)begin
                if(wrfull)$fatal(1,"HPS overflow");
                memory[write_count&(capacity-1)]<=data[7:0];
                memory[(write_count+1)&(capacity-1)]<=data[15:8];
                write_count<=write_count+2;
            end
        end
    end
    always @(posedge rdclk or posedge aclr)begin
        if(aclr)begin
            read_count<=0;
            for(integer i=0;i<rdsync_delaypipe;i=i+1)write_sync[i]<=0;
        end else begin
            write_sync[0]<=write_count;
            for(integer i=1;i<rdsync_delaypipe;i=i+1)write_sync[i]<=write_sync[i-1];
            if(rdreq)begin
                if(rdempty)$fatal(1,"HPS underflow");
                read_count<=read_count+1;
            end
        end
    end
endmodule
