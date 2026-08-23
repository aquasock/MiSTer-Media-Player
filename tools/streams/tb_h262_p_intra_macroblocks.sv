`timescale 1ns/1ps

module tb_h262_p_intra_macroblocks #(
    parameter integer CACHE_HIT_MODE=0
);
    localparam integer MAX_STREAM_BYTES=262144;
    integer expected_intra=1,expected_blocks=6;
    integer expected_cycles=773483;
    integer first_intra_row=8,last_intra_row=8,intra_col=20;

    reg clk=0,reset=1,stream_valid=0;
    reg [7:0] stream_data=0;
    reg [7:0] stream_mem[0:MAX_STREAM_BYTES-1];
    integer stream_len,stream_index,quiet_cycles,total_cycles=0;
    integer motion_events=0,intra_motion_events=0,picture_completions=0;
    integer replay_blocks=0,replay_samples=0,replay_total_samples=0;
    reg [1:0] replay_state=0;
    reg [1023:0] hex_path;
    reg replay_finished=0;

    wire candidate,seen,complete,row_complete,row_final,hold,parser_error;
    wire motion_valid,motion_intra;
    wire [10:0] motion_index;
    wire signed [12:0] motion_x,motion_y;
    wire [5:0] mb_width,mb_height;
    wire [10:0] mb_count;
    wire [10:0] block_read_address;
    wire [10:0] block_read_mb;
    wire [2:0] block_read_index;
    wire block_read_intra;
    wire [4:0] block_read_qscale;
    wire [11:0] residual_count;
    wire residual_present;
    wire [14:0] coeff_read_address;
    wire [5:0] coeff_read_index;
    wire signed [12:0] coeff_read_value;
    wire coeff_read_last;
    wire [15:0] coeff_count;
    wire qtype,alternate;

    wire decision,required,success,replay_active,first_valid;
    wire signed [15:0] first_value,replay_value;
    wire replay_valid,residual_error;
    wire [5:0] replay_index;
    wire row_produced=replay_valid&&(replay_index==6'h3f)&&
        ((replay_value==16'shA2FE)||(replay_value==16'shA2FF));
    wire engine_input_valid=motion_valid||replay_valid;
    wire [5:0] engine_input_index=motion_valid ?
        (motion_intra?6'h3b:6'h3e) : replay_index;
    wire signed [15:0] engine_input_value=motion_valid ?
        $signed({motion_x[7:0],motion_y[7:0]}) : replay_value;
    wire [7:0] engine_burstcnt,engine_store_value;
    wire [28:0] engine_addr;
    wire engine_rd,engine_store_select,engine_store_valid;
    wire engine_lookup_request;
    wire engine_store_start,engine_store_complete,engine_active;
    wire [11:0] engine_store_x,engine_store_y;
    wire engine_read_seen,engine_sample_nonzero,engine_half_seen;
    wire engine_reconstructed_seen,engine_persisted,engine_row_persisted,engine_error;
    wire [7:0] engine_sample,engine_reconstructed_value,engine_persisted_value;
    wire [3:0] engine_progress;
    wire [4:0] engine_error_source;
    wire engine_residual_write;
    wire [15:0] engine_residual_write_address;
    wire signed [15:0] engine_residual_write_data;
    wire [15:0] engine_residual_read_address;
    reg signed [15:0] engine_residual_read_data=0;
    reg signed [15:0] engine_residual_mem[0:65535];
    reg [63:0] engine_dout=0;
    reg engine_dout_ready=0,engine_block_stored=0,engine_lookup_ready=0;
    integer intra_store_samples=0;

    function automatic is_intra_mb;
        input [10:0] index;
        integer row,column;
        begin
            row=index/45;
            column=index%45;
            is_intra_mb=(row>=first_intra_row)&&(row<=last_intra_row)&&
                        (column==intra_col);
        end
    endfunction

    function automatic [10:0] expected_mb_for_block;
        input integer block_number;
        begin
            expected_mb_for_block=
                ((first_intra_row+(block_number/6))*45)+intra_col;
        end
    endfunction

    always #5 clk=~clk;

    always @(posedge clk) begin
        engine_lookup_ready<=engine_lookup_request;
        if(engine_residual_write)
            engine_residual_mem[engine_residual_write_address]
                <=engine_residual_write_data;
        engine_residual_read_data<=
            engine_residual_mem[engine_residual_read_address];
    end

    mpeg2_h262_p_wide_motion_syntax_probe parser(
        .clk(clk),.reset(reset),.stream_data(stream_data),
        .stream_valid(stream_valid),.intra_dc_precision(2'd0),
        .row_retired(engine_row_persisted),.row_produced(row_produced),
        .wide_candidate(candidate),.wide_seen(seen),
        .wide_complete_now(complete),.row_complete_now(row_complete),
        .row_final(row_final),.motion_event_valid(motion_valid),
        .motion_event_index(motion_index),.motion_event_x(motion_x),
        .motion_event_y(motion_y),.motion_event_intra(motion_intra),
        .picture_mb_width(mb_width),.picture_mb_height(mb_height),
        .picture_mb_count(mb_count),
        .residual_block_read_address(block_read_address),
        .residual_block_read_mb(block_read_mb),
        .residual_block_read_index(block_read_index),
        .residual_block_read_intra(block_read_intra),
        .residual_block_read_qscale(block_read_qscale),
        .residual_block_count(residual_count),
        .residual_present(residual_present),
        .residual_coeff_read_address(coeff_read_address),
        .residual_coeff_read_index(coeff_read_index),
        .residual_coeff_read_value(coeff_read_value),
        .residual_coeff_read_last(coeff_read_last),
        .residual_coeff_count(coeff_count),
        .q_scale_type(qtype),.alternate_scan(alternate),
        .parse_hold(hold),.probe_error(parser_error)
    );

    mpeg2_h262_p_residual_probe residual_pipeline(
        .clk(clk),.reset(reset),.stream_data(stream_data),
        .stream_valid(stream_valid),.p_picture_expected(1'b0),
        .general_mode(1'b0),.general_picture_complete(1'b0),
        .general_motion_x_plan(384'd0),.general_motion_y_plan(384'd0),
        .general_residual_block_plan(288'd0),
        .general_residual_block_count(5'd0),
        .general_coeff_index_plan(384'd0),
        .general_coeff_value_plan(832'd0),.general_coeff_last_plan(64'd0),
        .general_coeff_count(7'd0),.general_qscale_plan(80'd0),
        .general_q_scale_type(1'b0),.general_alternate_scan(1'b0),
        .wide_mode(candidate||seen),.wide_row_complete(row_complete),
        .wide_row_final(row_final),
        .wide_block_read_address(block_read_address),
        .wide_block_read_mb(block_read_mb),
        .wide_block_read_index(block_read_index),
        .wide_block_read_intra(block_read_intra),
        .wide_block_read_qscale(block_read_qscale),
        .wide_residual_block_count(residual_count),
        .wide_coeff_read_address(coeff_read_address),
        .wide_coeff_read_index(coeff_read_index),
        .wide_coeff_read_value(coeff_read_value),
        .wide_coeff_read_last(coeff_read_last),.wide_coeff_count(coeff_count),
        .wide_q_scale_type(qtype),
        .wide_alternate_scan(alternate),.wide_intra_dc_precision(2'd0),
        .decision_complete(decision),.residual_required(required),
        .residual_success(success),.mixed_replay_active(replay_active),
        .first_sample_valid(first_valid),.first_sample_value(first_value),
        .residual_sample_valid(replay_valid),.residual_sample_index(replay_index),
        .residual_sample_value(replay_value),.probe_error(residual_error)
    );

    mpeg2_h262_p_motion_residual_raster_engine raster_engine(
        .clk(clk),.reset(reset),.capture_enable(candidate||seen),
        .request(candidate||seen),.horizontal_size(14'd720),
        .vertical_size(14'd480),.shift_right_map(48'd0),
        .residual_valid(engine_input_valid),.residual_index(engine_input_index),
        .residual_value(engine_input_value),
        .motion_vector_x(motion_x),.motion_vector_y(motion_y),
        .residual_store_write(engine_residual_write),
        .residual_store_write_address(engine_residual_write_address),
        .residual_store_write_data(engine_residual_write_data),
        .residual_store_read_address(engine_residual_read_address),
        .residual_store_read_data(engine_residual_read_data),
        .reference_valid(1'b1),
        .reference_bank(2'd0),.destination_bank(2'd1),
        .store_block_stored(engine_block_stored),.ddram_busy(1'b0),
        .ddram_dout(engine_dout),.ddram_dout_ready(engine_dout_ready),
        .ddram_lookup_ready(engine_lookup_ready),
        .ddram_lookup_hit(CACHE_HIT_MODE!=0),
        .ddram_lookup_data({8{8'd50}}),
        .ddram_lookup_request(engine_lookup_request),
        .ddram_burstcnt(engine_burstcnt),.ddram_addr(engine_addr),
        .ddram_rd(engine_rd),.store_select(engine_store_select),
        .store_pixel_value(engine_store_value),.store_pixel_x(engine_store_x),
        .store_pixel_y(engine_store_y),.store_pixel_valid(engine_store_valid),
        .store_block_start(engine_store_start),
        .store_block_complete(engine_store_complete),.active(engine_active),
        .read_seen(engine_read_seen),.sample_value(engine_sample),
        .sample_nonzero(engine_sample_nonzero),.half_sample_seen(engine_half_seen),
        .reconstructed_seen(engine_reconstructed_seen),
        .reconstructed_value(engine_reconstructed_value),
        .persisted_seen(engine_persisted),.row_persisted(engine_row_persisted),
        .persisted_value(engine_persisted_value),
        .progress_stage(engine_progress),.error(engine_error),
        .error_source(engine_error_source)
    );

    initial begin
        if(!$value$plusargs("HEX=%s",hex_path)) $fatal(1,"missing +HEX");
        if(!$value$plusargs("LEN=%d",stream_len)) $fatal(1,"missing +LEN");
        if(!$value$plusargs("EXPECTED_INTRA=%d",expected_intra)) expected_intra=1;
        if(!$value$plusargs("EXPECTED_BLOCKS=%d",expected_blocks)) expected_blocks=6;
        if(!$value$plusargs("EXPECTED_CYCLES=%d",expected_cycles)) expected_cycles=773483;
        if(!$value$plusargs("FIRST_INTRA_ROW=%d",first_intra_row)) first_intra_row=8;
        if(!$value$plusargs("LAST_INTRA_ROW=%d",last_intra_row)) last_intra_row=8;
        if(!$value$plusargs("INTRA_COL=%d",intra_col)) intra_col=20;
        if(stream_len<=0||stream_len>MAX_STREAM_BYTES) $fatal(1,"invalid LEN");
        $readmemh(hex_path,stream_mem,0,stream_len-1);
        stream_index=0;quiet_cycles=0;
        repeat(5) @(posedge clk);
        reset<=0;
    end

    always @(negedge clk) begin
        if(reset) begin stream_valid<=0;stream_data<=0;end
        else if(stream_index<stream_len) begin
            if(!hold) begin
                stream_data<=stream_mem[stream_index];
                stream_valid<=1;
                stream_index<=stream_index+1;
            end else stream_valid<=0;
        end else begin
            stream_valid<=0;
            if(replay_finished&&engine_persisted&&!hold&&!replay_active)
                quiet_cycles<=quiet_cycles+1;
            else quiet_cycles<=0;
            if(quiet_cycles==100) begin
                $display("RESULT seen=%0d parser_error=%0d residual_error=%0d motion=%0d intra_motion=%0d blocks=%0d samples=%0d cycles=%0d",
                         seen,parser_error,residual_error,motion_events,
                         intra_motion_events,replay_blocks,replay_total_samples,
                         total_cycles);
                $display("RESIDUAL_DETAIL g_error=%0d transform=%0d",
                         residual_pipeline.g_error,residual_pipeline.terr);
                if(!seen||parser_error||residual_error||picture_completions!=1||
                   motion_events!=1350||intra_motion_events!=expected_intra||
                   replay_blocks!=expected_blocks||
                   replay_total_samples!=(expected_blocks*64)||!replay_finished||
                   !decision||!required||!success||engine_error||
                   !engine_read_seen||!engine_reconstructed_seen||
                   intra_store_samples!=(expected_blocks*64)||
                   // Entry 265 overlaps P row production and reconstruction;
                   // the exact end-to-end cycle count guards that boundary.
                   total_cycles!=expected_cycles)
                    $fatal(1,"P intra-macroblock regression failed");
                $finish;
            end
        end
    end

    always @(posedge clk) begin
        if(!reset)total_cycles<=total_cycles+1;
        engine_dout_ready<=0;
        engine_block_stored<=engine_store_complete;
        if(engine_rd) begin
            if(raster_engine.wait_store)
                $fatal(1,"P engine issued a post-write verification read");
            engine_dout_ready<=1;
            engine_dout<={8{8'd50}};
            if(is_intra_mb(raster_engine.mbi))
                $fatal(1,"intra macroblock issued a reference read");
        end
        if(engine_store_valid&&is_intra_mb(raster_engine.mbi)) begin
            intra_store_samples<=intra_store_samples+1;
            if(raster_engine.blk<4) begin
                if(engine_store_value<8'd95||engine_store_value>8'd97)
                    $fatal(1,"bad raster luma intra sample");
            end else if(engine_store_value<8'd127||engine_store_value>8'd129)
                $fatal(1,"bad raster chroma intra sample");
        end
        if(motion_valid) begin
            if(motion_index!=motion_events[10:0])
                $fatal(1,"motion order %0d != %0d",motion_index,motion_events);
            motion_events<=motion_events+1;
            if(motion_intra) begin
                intra_motion_events<=intra_motion_events+1;
                if(!is_intra_mb(motion_index)||motion_x!=0||motion_y!=0)
                    $fatal(1,"bad intra motion event");
            end
        end
        if(complete) begin
            picture_completions<=picture_completions+1;
            if(mb_width!=45||mb_height!=30||mb_count!=1350)
                $fatal(1,"bad completed P intra plans");
        end

        if(replay_valid) begin
            case(replay_state)
            0: begin
                if(replay_index==6'h3f&&
                   ((replay_value==16'shA2FE)||
                    (replay_value==16'shA2FF))) begin
                    if(replay_value==16'shA2FF)
                        replay_finished<=1;
                end else begin
                    if(replay_index!=6'h3c||
                       replay_value!=expected_mb_for_block(replay_blocks))
                        $fatal(1,"bad descriptor MB header");
                    replay_state<=1;
                end
            end
            1: begin
                if(replay_index!=6'h3d||!replay_value[3]||
                   replay_value[2:0]!=(replay_blocks%6))
                    $fatal(1,"bad intra descriptor block");
                replay_state<=2;
                replay_samples<=0;
            end
            2: begin
                replay_total_samples<=replay_total_samples+1;
                if(replay_index!=replay_samples[5:0])
                    $fatal(1,"bad sample order");
                if((replay_blocks%6)<4) begin
                    if(replay_value<16'sd95||replay_value>16'sd97)
                        $fatal(1,"bad luma intra sample %0d",replay_value);
                end else if(replay_value<16'sd127||replay_value>16'sd129)
                    $fatal(1,"bad chroma intra sample %0d",replay_value);
                if(replay_samples==63) begin
                    replay_blocks<=replay_blocks+1;
                    replay_samples<=replay_samples+1;
                    replay_state<=0;
                end else replay_samples<=replay_samples+1;
            end
            default:$fatal(1,"bad replay state");
            endcase
        end
    end

    initial begin
        repeat(30000000) @(posedge clk);
        $fatal(1,"P intra-macroblock regression timed out");
    end
endmodule
