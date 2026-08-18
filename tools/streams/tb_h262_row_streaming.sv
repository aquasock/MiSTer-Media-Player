`timescale 1ns/1ps

// Entry 204 P-row capacity regression.  The parser is allowed to reuse its
// descriptor/coefficient addresses only after the serialized transform emits
// the current row terminator.  This deliberately checks a picture whose
// cumulative coefficient traffic exceeds the old 32,768-event picture store.
module tb_h262_row_streaming;
    localparam integer MAX_STREAM_BYTES=3145728;

    reg clk=0,reset=1,stream_valid=0,row_retired=0,stop_feeding=0;
    reg [7:0] stream_data=0;
    reg [7:0] stream_mem[0:MAX_STREAM_BYTES-1];
    reg [1023:0] hex_path;
    integer stream_len,stream_index=0,quiet_cycles=0;
    integer motion_events=0,row_ready_count=0,row_retired_count=0;
    integer total_blocks=0,total_coeffs=0,max_row_blocks=0,max_row_coeffs=0;
    integer replay_blocks=0,replay_samples=0;
    reg [1:0] replay_state=0;
    reg final_row_ready=0,final_terminator=0,picture_complete_seen=0;

    wire candidate,seen,picture_complete,row_complete,row_final,hold,parser_error;
    wire motion_valid,motion_intra;
    wire [10:0] motion_index;
    wire signed [7:0] motion_x,motion_y;
    wire [5:0] mb_width,mb_height;
    wire [10:0] mb_count;
    wire [10:0] block_read_address,block_read_mb;
    wire [2:0] block_read_index;
    wire block_read_intra;
    wire [4:0] block_read_qscale;
    wire [11:0] block_count;
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

    always #5 clk=~clk;

    mpeg2_h262_p_wide_motion_syntax_probe parser(
        .clk(clk),.reset(reset),.stream_data(stream_data),
        .stream_valid(stream_valid),.intra_dc_precision(2'd0),
        .row_retired(row_retired),
        .wide_candidate(candidate),.wide_seen(seen),
        .wide_complete_now(picture_complete),
        .row_complete_now(row_complete),.row_final(row_final),
        .motion_event_valid(motion_valid),.motion_event_index(motion_index),
        .motion_event_x(motion_x),.motion_event_y(motion_y),
        .motion_event_intra(motion_intra),
        .picture_mb_width(mb_width),.picture_mb_height(mb_height),
        .picture_mb_count(mb_count),
        .residual_block_read_address(block_read_address),
        .residual_block_read_mb(block_read_mb),
        .residual_block_read_index(block_read_index),
        .residual_block_read_intra(block_read_intra),
        .residual_block_read_qscale(block_read_qscale),
        .residual_block_count(block_count),.residual_present(residual_present),
        .residual_coeff_read_address(coeff_read_address),
        .residual_coeff_read_index(coeff_read_index),
        .residual_coeff_read_value(coeff_read_value),
        .residual_coeff_read_last(coeff_read_last),
        .residual_coeff_count(coeff_count),.q_scale_type(qtype),
        .alternate_scan(alternate),.parse_hold(hold),.probe_error(parser_error)
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
        .wide_residual_block_count(block_count),
        .wide_coeff_read_address(coeff_read_address),
        .wide_coeff_read_index(coeff_read_index),
        .wide_coeff_read_value(coeff_read_value),
        .wide_coeff_read_last(coeff_read_last),.wide_coeff_count(coeff_count),
        .wide_q_scale_type(qtype),.wide_alternate_scan(alternate),
        .wide_intra_dc_precision(2'd0),
        .decision_complete(decision),.residual_required(required),
        .residual_success(success),.mixed_replay_active(replay_active),
        .first_sample_valid(first_valid),.first_sample_value(first_value),
        .residual_sample_valid(replay_valid),.residual_sample_index(replay_index),
        .residual_sample_value(replay_value),.probe_error(residual_error)
    );

    initial begin
        if(!$value$plusargs("HEX=%s",hex_path)) $fatal(1,"missing +HEX");
        if(!$value$plusargs("LEN=%d",stream_len)) $fatal(1,"missing +LEN");
        if((stream_len<=0)||(stream_len>MAX_STREAM_BYTES))
            $fatal(1,"invalid LEN %0d",stream_len);
        $readmemh(hex_path,stream_mem,0,stream_len-1);
        repeat(5) @(posedge clk);
        reset<=0;
    end

    always @(negedge clk) begin
        if(reset) begin
            stream_valid<=0;
            stream_data<=0;
        end else if(!stop_feeding&&(stream_index<stream_len)) begin
            if(!hold) begin
                stream_data<=stream_mem[stream_index];
                stream_valid<=1;
                stream_index<=stream_index+1;
            end else stream_valid<=0;
        end else begin
            stream_valid<=0;
            if(picture_complete_seen&&!replay_active&&!hold)
                quiet_cycles<=quiet_cycles+1;
            else
                quiet_cycles<=0;
            if(quiet_cycles==100) begin
                $display("ROW_RESULT rows=%0d blocks=%0d coeffs=%0d max_blocks=%0d max_coeffs=%0d motion=%0d replay_blocks=%0d samples=%0d",
                         row_ready_count,total_blocks,total_coeffs,
                         max_row_blocks,max_row_coeffs,motion_events,
                         replay_blocks,replay_samples);
                if(!seen||parser_error||residual_error||!picture_complete_seen||
                   !final_row_ready||!final_terminator||row_ready_count!=30||
                   row_retired_count!=30||motion_events!=1350||mb_count!=1350||
                   total_blocks<=1526||total_coeffs<=32768||
                   max_row_blocks>=2048||max_row_coeffs>=32768||
                   replay_blocks!=total_blocks||replay_samples!=(total_blocks*64)||
                   !decision||!required||!success)
                    $fatal(1,"P row-streaming regression failed");
                $finish;
            end
        end
    end

    always @(posedge clk) begin
        row_retired<=0;

        if(motion_valid) begin
            if(motion_index!=motion_events[10:0])
                $fatal(1,"motion order %0d != %0d",motion_index,motion_events);
            motion_events<=motion_events+1;
        end

        if(row_complete) begin
            row_ready_count<=row_ready_count+1;
            total_blocks<=total_blocks+block_count;
            total_coeffs<=total_coeffs+coeff_count;
            if(block_count>max_row_blocks) max_row_blocks<=block_count;
            if(coeff_count>max_row_coeffs) max_row_coeffs<=coeff_count;
            if(row_final) final_row_ready<=1;
            if((row_ready_count==29)!=row_final)
                $fatal(1,"bad row-final marker at row %0d",row_ready_count);
        end

        if(picture_complete) begin
            picture_complete_seen<=1;
            stop_feeding<=1;
        end

        if(replay_valid) begin
            case(replay_state)
            0: begin
                if((replay_index==6'h3f)&&
                   ((replay_value==16'shA2FE)||(replay_value==16'shA2FF))) begin
                    row_retired<=1;
                    row_retired_count<=row_retired_count+1;
                    if(replay_value==16'shA2FF) final_terminator<=1;
                end else begin
                    if(replay_index!=6'h3c) $fatal(1,"missing descriptor MB");
                    replay_state<=1;
                end
            end
            1: begin
                if(replay_index!=6'h3d) $fatal(1,"missing descriptor block");
                replay_state<=2;
            end
            2: begin
                if(replay_index!=(replay_samples%64))
                    $fatal(1,"sample order error");
                replay_samples<=replay_samples+1;
                if((replay_samples%64)==63) begin
                    replay_blocks<=replay_blocks+1;
                    replay_state<=0;
                end
            end
            default:$fatal(1,"bad replay state");
            endcase
        end
    end

    initial begin
        repeat(50000000) @(posedge clk);
        $fatal(1,"P row-streaming regression timed out");
    end
endmodule

module tb_h262_b_row_streaming;
    localparam integer MAX_STREAM_BYTES=3145728;
    reg clk=0,reset=1,stream_valid=0,stop_feeding=0;
    reg [7:0] stream_data=0;
    reg [7:0] stream_mem[0:MAX_STREAM_BYTES-1];
    reg [1023:0] hex_path;
    integer stream_len,stream_index=0,quiet_cycles=0;
    integer rows=0,total_blocks=0,total_coeffs=0;
    integer max_row_blocks=0,max_row_coeffs=0;
    integer motion_events=0,replay_blocks=0,replay_samples=0;
    reg [6:0] samples_remaining=0;

    wire candidate,seen,complete,hold,replay_active,sideband_valid;
    wire [5:0] sideband_index;
    wire signed [15:0] sideband_value;
    wire first_valid,error;
    wire signed [15:0] first_value;
    wire row_retired=sideband_valid&&(sideband_index==6'h3f)&&
        ((sideband_value==16'shA3FE)||(sideband_value==16'shA3FF));

    always #5 clk=~clk;

    mpeg2_h262_b_core_probe parser(
        .clk(clk),.reset(reset),.stream_data(stream_data),
        .stream_valid(stream_valid),.row_retired(row_retired),
        .b_candidate(candidate),.b_seen(seen),.b_complete_now(complete),
        .parse_hold(hold),.replay_active(replay_active),
        .sideband_valid(sideband_valid),.sideband_index(sideband_index),
        .sideband_value(sideband_value),.first_sample_valid(first_valid),
        .first_sample_value(first_value),.probe_error(error)
    );

    initial begin
        if(!$value$plusargs("HEX=%s",hex_path)) $fatal(1,"missing +HEX");
        if(!$value$plusargs("LEN=%d",stream_len)) $fatal(1,"missing +LEN");
        if((stream_len<=0)||(stream_len>MAX_STREAM_BYTES))
            $fatal(1,"invalid LEN %0d",stream_len);
        $readmemh(hex_path,stream_mem,0,stream_len-1);
        repeat(5) @(posedge clk);
        reset<=0;
    end

    always @(negedge clk) begin
        if(reset) begin stream_valid<=0;stream_data<=0;end
        else if(!stop_feeding&&(stream_index<stream_len)) begin
            if(!hold) begin
                stream_data<=stream_mem[stream_index];stream_valid<=1;
                stream_index<=stream_index+1;
            end else stream_valid<=0;
        end else begin
            stream_valid<=0;
            if(stop_feeding&&!replay_active&&!hold)quiet_cycles<=quiet_cycles+1;
            else quiet_cycles<=0;
            if(quiet_cycles==100) begin
                $display("B_ROW_RESULT rows=%0d blocks=%0d coeffs=%0d max_blocks=%0d max_coeffs=%0d motion=%0d replay_blocks=%0d samples=%0d",
                         rows,total_blocks,total_coeffs,max_row_blocks,
                         max_row_coeffs,motion_events,replay_blocks,replay_samples);
                if(!seen||error||rows!=30||motion_events!=1350||
                   total_blocks<=1314||total_coeffs<=32768||
                   max_row_blocks>=2048||max_row_coeffs>=32768||
                   replay_blocks!=total_blocks||replay_samples!=(total_blocks*64))
                    $fatal(1,"B row-streaming regression failed");
                $finish;
            end
        end
    end

    always @(posedge clk) begin
        if(complete) stop_feeding<=1;
        if(sideband_valid) begin
            if(samples_remaining!=0) begin
                if(sideband_index!=(7'd64-samples_remaining))
                    $fatal(1,"B sample order error");
                replay_samples<=replay_samples+1;
                samples_remaining<=samples_remaining-1'b1;
            end else if((sideband_index==6'h3f)&&
                        (sideband_value[15:14]==2'b11)) begin
                replay_blocks<=replay_blocks+1;
                samples_remaining<=7'd64;
            end else if((sideband_index==6'h38)||
                        (sideband_index==6'h39)||
                        (sideband_index==6'h3a)) begin
                motion_events<=motion_events+1;
            end else if(row_retired) begin
                rows<=rows+1;
                total_blocks<=total_blocks+parser.residual_count;
                total_coeffs<=total_coeffs+parser.residual_coeff_count;
                if(parser.residual_count>max_row_blocks)
                    max_row_blocks<=parser.residual_count;
                if(parser.residual_coeff_count>max_row_coeffs)
                    max_row_coeffs<=parser.residual_coeff_count;
                if((rows==29)!=(sideband_value==16'shA3FF))
                    $fatal(1,"bad B row-final marker at row %0d",rows);
            end
        end
    end

    initial begin
        repeat(50000000) @(posedge clk);
        $fatal(1,"B row-streaming regression timed out");
    end
endmodule
