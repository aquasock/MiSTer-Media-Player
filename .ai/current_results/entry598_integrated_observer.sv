`timescale 1ns/1ps

// Temporary cadence observer: real I pipeline, production publication shell,
// writer and scheduler; ideal source and modeled DDR readiness. No pixel oracle.
// This is not the physical HPS/DDR/scaler system or a fix validation.
// The authored field order is header metadata at this stage; reconstruction
// must produce the same full-frame Y/Cb/Cr planes for either TFF or BFF before
// native field presentation is allowed to consume those planes.
module tb_entry598_i_cadence;
    localparam integer MAX_STREAM_BYTES = 33554432;
    localparam integer FRAME_COUNT = 4;
    localparam integer LUMA_BYTES = 720*480;
    localparam integer CHROMA_BYTES = 360*240;
    localparam integer FRAME_BYTES = LUMA_BYTES + 2*CHROMA_BYTES;
    localparam integer ORACLE_BYTES = FRAME_COUNT*FRAME_BYTES;
    localparam integer MAX_CYCLES = 300000000;
    // Four 30000/1001 pictures have 8,008,000 decoder clocks available at
    // 60 MHz.  This is an implementation-throughput gate, not an H.262 limit.
    localparam integer REALTIME_2997_FOUR_FRAME_CYCLES = 8008000;

    reg clk=0,reset=1,stream_valid=0;
    reg [7:0] stream_data=0;
    reg [7:0] stream_mem[0:MAX_STREAM_BYTES-1];
    reg [1023:0] hex_path,pixel_path;
    integer stream_len,stream_index=0,total_cycles=0,quiet_cycles=0;
    integer reconstructed_picture=0,pixel_samples=0,pixel_differences=0;
    integer pixel_mismatches=0;
    integer max_pixel_delta=0,pixel_delta,pixel_index;
    reg phase1_seen=0,interlaced_seen=0,progressive_seen=0,field_order_seen=0;
    reg expected_tff=0;
    reg expect_progressive=0,expect_reject=0;

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
    wire writer_accepted,writer_error,writer_we,writer_stored;
    wire [28:0] writer_addr;
    integer use_writer=1,phase=1961195,busy_period=0,busy_length=0;
    integer first_swap=7967195;
    integer metric_fd,wait_cycles=0,bit_cycles=0,refill_cycles=0;
    integer capacity_cycles=0,hold_cycles=0,block_end_cycle=0;
    integer ack_latency_sum=0,ack_count=0,recon_latency_sum=0;
    integer header_cycle=0,first_ready_cycle=0,previous_ready=0;
    integer first_pending_cycle=0;
    reg was_presentable=0;
    reg [1023:0] metrics_path;
    wire capture_blocked;
    wire writer_busy=(busy_period>0) && ((total_cycles%busy_period)<busy_length);
    reg [31:0] window=0;
    wire [31:0] window_next={window[23:0],stream_data};
    reg header_capture=0,header_second=0;
    wire header_now=stream_valid&&header_capture&&header_second;
    wire i_start=header_now&&(stream_data[5:3]==1);
    wire end_now=stream_valid&&(window_next==32'h000001b7);
    wire waiting=picture_complete&&first_parsed&&(completed_bank!=display_bank);
    reg tick=0,swap=0;
    wire [31:0] scheduler_debug;
    wire presentable,cadence_slot;
    integer fd,completed=0,presented=0,pixels=0,words=0,stores=0,headers=0;
    integer first_present=0,last_present=0,previous_complete=0,gaps=0;
    integer generation[0:2];
    reg [1:0] previous_display=0;
    reg [1023:0] report_path;
    always #5 clk=~clk;

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
        .store_error(writer_error),.capture_blocked_debug(capture_blocked),.ddram_busy(writer_busy),.ddram_we(writer_we),
        .ddram_addr(writer_addr),.block_stored(writer_stored));
    mpeg2_h262_b_presentation_scheduler scheduler(
        .clk(clk),.reset(reset),.swap_window_pulse(swap),.cadence_tick_pulse(tick),
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
    initial begin
        if (!$value$plusargs("HEX=%s",hex_path)) $fatal(1,"missing HEX");
        if (!$value$plusargs("LEN=%d",stream_len)) $fatal(1,"missing LEN");
        if (!$value$plusargs("REPORT=%s",report_path)) $fatal(1,"missing REPORT");
        if ($value$plusargs("PHASE=%d",phase)) begin end
        if ($value$plusargs("FIRST_SWAP=%d",first_swap)) begin end
        if (!$value$plusargs("METRICS=%s",metrics_path)) $fatal(1,"missing METRICS");
        metric_fd=$fopen(metrics_path,"w");
        if (!metric_fd) $fatal(1,"cannot open metrics");
        $fdisplay(metric_fd,"picture,complete_cycle,header_to_complete,pipeline_wait,parsed_bits,refill_wait,capacity_blocked,presentation_hold,ack_latency_sum,ack_count,recon_latency_sum");
        if ($value$plusargs("WRITER=%d",use_writer)) begin end
        if ($value$plusargs("BUSY_PERIOD=%d",busy_period)) begin end
        if ($value$plusargs("BUSY_LENGTH=%d",busy_length)) begin end
        if (stream_len<1 || stream_len>MAX_STREAM_BYTES) $fatal(1,"invalid LEN");
        $readmemh(hex_path,stream_mem,0,stream_len-1);
        fd=$fopen(report_path,"w");
        if (!fd) $fatal(1,"cannot open report");
        $fdisplay(fd,"event,picture,cycle,interval,bank,debug");
        repeat(5) @(negedge clk);
        reset=0;
    end
    always @(negedge clk) begin
        if (!reset) begin
            total_cycles=total_cycles+1;
            tick=((total_cycles+2002000-phase+4)%1001000)==0;
            swap=((total_cycles%2002000)==phase) && total_cycles>=first_swap;
            if (stream_index<stream_len && parser_ready && !presentation_hold) begin
                stream_data<=stream_mem[stream_index];
                stream_valid<=1;stream_index<=stream_index+1;
            end else stream_valid<=0;
        end
    end
    always @(posedge clk) begin
        if (!reset) begin
            if (stream_valid) begin
                window<=window_next;
                if(window_next==32'h00000100)begin header_capture<=1;header_second<=0;end
                else if(header_capture)begin
                    if(!header_second)header_second<=1;
                    else begin header_capture<=0;header_second<=0;end
                end
            end
            if (header_now) begin
                header_cycle=total_cycles;
                headers=headers+1;
                if(!i_start)$fatal(1,"non-I header");
                $fdisplay(fd,"header,%0d,%0d,0,%0d,%08x",headers,total_cycles,active_bank,scheduler_debug);
            end
            if(syntax_error||probe_error||iq_error||unsupported_matrix||idct_error||recon_error||writer_error||presentation_error)
                $fatal(1,"pipeline error syntax=%0d probe=%0d iq=%0d matrix=%0d idct=%0d recon=%0d writer=%0d scheduler=%0d picture=%0d byte=%0d",
                  syntax_error,probe_error,iq_error,unsupported_matrix,idct_error,recon_error,writer_error,presentation_error,completed,stream_index);
            if (parser.bookkeeper.picture_probe.parse_active) begin
                if (parser.bookkeeper.picture_probe.parse_state==18) wait_cycles=wait_cycles+1;
                else if (!parser.bookkeeper.picture_probe.bit_valid) refill_cycles=refill_cycles+1;
                if (parser.bookkeeper.picture_probe.bit_consume) bit_cycles=bit_cycles+1;
            end
            if(capture_blocked) capacity_cycles=capacity_cycles+1;
            if(presentation_hold) hold_cycles=hold_cycles+1;
            if(qfs_block_end) block_end_cycle=total_cycles;
            if(recon_block_complete) recon_latency_sum=recon_latency_sum+total_cycles-block_end_cycle;
            if(writer_accepted) begin
                ack_latency_sum=ack_latency_sum+total_cycles-block_end_cycle;
                ack_count=ack_count+1;
            end
            if(recon_pixel_valid)pixels=pixels+1;
            if(writer_we&&!writer_busy)words=words+1;
            if(writer_stored)stores=stores+1;
            if(picture_complete)begin
                if(pixels!=518400)$fatal(1,"incomplete picture pixels=%0d",pixels);
                pixels=0;completed=completed+1;generation[completed_bank]=completed;
                $fdisplay(metric_fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                    completed,total_cycles,total_cycles-header_cycle,wait_cycles,bit_cycles,
                    refill_cycles,capacity_cycles,hold_cycles,ack_latency_sum,ack_count,recon_latency_sum);
                $fflush(metric_fd);
                wait_cycles=0;bit_cycles=0;refill_cycles=0;capacity_cycles=0;
                hold_cycles=0;ack_latency_sum=0;ack_count=0;recon_latency_sum=0;
                $fdisplay(fd,"complete,%0d,%0d,%0d,%0d,%08x",completed,total_cycles,total_cycles-previous_complete,completed_bank,scheduler_debug);
                previous_complete=total_cycles;
                first_pending_cycle=total_cycles;
                if(completed==1)begin
                    presented=1;first_present=total_cycles;last_present=total_cycles;
                end
                if(completed%32==0)$display("INTEGRATED_PROGRESS pictures=%0d cycles=%0d",completed,total_cycles);
            end
            if(presentable && !was_presentable) begin
                $fdisplay(fd,"ready,%0d,%0d,%0d,%0d,%08x",completed,total_cycles,total_cycles-first_pending_cycle,completed_bank,scheduler_debug);
                previous_ready=total_cycles;
            end
            was_presentable=presentable;
            if(swap && completed>1 && !presentable)
                $fdisplay(fd,"empty_window,%0d,%0d,0,%0d,%08x",presented+1,total_cycles,display_bank,scheduler_debug);
            #1;
            if(display_bank!=previous_display)begin
                if(generation[display_bank]!=presented+1)$fatal(1,"lost/duplicate identity expected=%0d actual=%0d",presented+1,generation[display_bank]);
                presented=presented+1;
                $fdisplay(fd,"present,%0d,%0d,%0d,%0d,%08x",presented,total_cycles,total_cycles-last_present,display_bank,scheduler_debug);
                if(presented>2 && total_cycles-last_present>3003000)begin
                    gaps=gaps+1;
                    $display("INTEGRATED_GAP picture=%0d cycles=%0d",presented,total_cycles-last_present);
                end
                last_present=total_cycles;previous_display=display_bank;
            end
            if(presented==449 && stream_index==stream_len && stores==449*8100)begin
                if(completed!=449||words!=449*64800||headers!=449)$fatal(1,"incomplete stream");
                $display("INTEGRATED_PASS writer=%0d phase=%0d displayed=%0d gaps=%0d elapsed_seconds=%f words=%0d stores=%0d",use_writer,phase,presented,gaps,(last_present-first_present)/60000000.0,words,stores);
                $fclose(fd);$fclose(metric_fd);$finish;
            end
            if(total_cycles>1200000000)$fatal(1,"timeout pictures=%0d presented=%0d byte=%0d stores=%0d",completed,presented,stream_index,stores);
        end
    end
endmodule
