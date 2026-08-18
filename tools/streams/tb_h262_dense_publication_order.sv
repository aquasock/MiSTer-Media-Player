`timescale 1ns/1ps

// Entry 210 complete dense I/P/B publication regression.  The combined P/B
// sideband is retired exactly as the hardware raster engines retire it: every
// row terminator receives one row-persistence pulse and each final-row
// terminator receives the corresponding picture-persistence pulse.
module tb_h262_dense_publication_order;
    localparam integer MAX_STREAM_BYTES=3145728;

    reg clk=0,reset=1,stream_valid=0;
    reg [7:0] stream_data=0;
    reg [7:0] stream_mem[0:MAX_STREAM_BYTES-1];
    reg [1023:0] hex_path;
    integer stream_len,stream_index=0,quiet_cycles=0;
    integer last_stream_index=0,transport_stall_cycles=0;
    integer p_rows=0,b_rows=0,p_pictures=0,b_pictures=0;
    integer published_references=0;
    reg row_persistence=0,picture_persistence=0;
    reg [5:0] previous_wide_parser_state=0;
    reg previous_wide_error=0;

    wire stream_ready,picture_complete;
    wire [7:0] picture_count,reference_promotion_count;
    wire reference_valid,reference_bank,active_bank,completed_bank;
    wire sideband_valid;
    wire [5:0] sideband_index;
    wire signed [15:0] sideband_value;
    wire probe_error,b_success;
    wire [3:0] probe_error_source,p_probe_error_source,p_progress_detail;
    wire [2:0] publication_error_detail;

    wire p_row_terminator=sideband_valid&&(sideband_index==6'h3f)&&
        ((sideband_value==16'shA2FE)||(sideband_value==16'shA2FF));
    wire b_row_terminator=sideband_valid&&(sideband_index==6'h3f)&&
        ((sideband_value==16'shA3FE)||(sideband_value==16'shA3FF));
    wire p_final=p_row_terminator&&(sideband_value==16'shA2FF);
    wire b_final=b_row_terminator&&(sideband_value==16'shA3FF);

    always #5 clk=~clk;

    mpeg2_h262_two_picture_probe dut(
        .clk(clk),.reset(reset),.stream_data(stream_data),
        .stream_valid(stream_valid),.stream_ready(stream_ready),
        .phase1_supported(1'b1),.vertical_size(14'd480),
        .intra_dc_precision(2'd0),.intra_vlc_format(1'b0),
        .pipeline_block_done(1'b1),.recon_block_complete(1'b1),
        .p_persistence_complete(picture_persistence),
        .p_row_persistence_complete(row_persistence),
        .picture_420_complete(picture_complete),
        .active_frame_bank(active_bank),.completed_frame_bank(completed_bank),
        .picture_count(picture_count),.reference_frame_valid(reference_valid),
        .reference_frame_bank(reference_bank),
        .reference_promotion_count(reference_promotion_count),
        .p_residual_sample_valid(sideband_valid),
        .p_residual_sample_index(sideband_index),
        .p_residual_sample_value(sideband_value),
        .probe_error(probe_error),.probe_error_source(probe_error_source),
        .p_probe_error_source(p_probe_error_source),
        .p_progress_detail(p_progress_detail),
        .publication_error_detail(publication_error_detail),
        .b_user_success(b_success)
    );

    initial begin
        if(!$value$plusargs("HEX=%s",hex_path))$fatal(1,"missing +HEX");
        if(!$value$plusargs("LEN=%d",stream_len))$fatal(1,"missing +LEN");
        if((stream_len<=0)||(stream_len>MAX_STREAM_BYTES))
            $fatal(1,"invalid LEN %0d",stream_len);
        $readmemh(hex_path,stream_mem,0,stream_len-1);
        repeat(5)@(posedge clk);
        reset<=0;
    end

    always @(negedge clk) begin
        if(reset)begin
            stream_valid<=0;
            stream_data<=0;
        end else if(stream_index<stream_len)begin
            if(stream_ready)begin
                stream_data<=stream_mem[stream_index];
                stream_valid<=1;
                stream_index<=stream_index+1;
            end else stream_valid<=0;
        end else stream_valid<=0;
    end

    always @(posedge clk) begin
        row_persistence<=0;
        picture_persistence<=0;
        previous_wide_parser_state<=
            dut.p_controller.wide_general_probe.parser_state;
        previous_wide_error<=dut.p_controller.wide_error;

        if((dut.p_controller.wide_general_probe.parser_state==6'd22)&&
           (previous_wide_parser_state!=6'd22))
            $display("WIDE_R_ERROR byte=%0d previous_state=%0d parse_byte=%0d/%0d bit=%0d row=%0d col=%0d covered=%0d row_bytes=%0d boundary_final=%0d slice_capture=%0d parser_started=%0d qfs=%0d run=%0d target=%0d coeffs=%0d blocks=%0d intra=%0d",
                     stream_index,previous_wide_parser_state,
                     dut.p_controller.wide_general_probe.parse_byte_index,
                     dut.p_controller.wide_general_probe.parse_byte_limit,
                     dut.p_controller.wide_general_probe.parse_bit_index,
                     dut.p_controller.wide_general_probe.slice_row_number,
                     dut.p_controller.wide_general_probe.current_col,
                     dut.p_controller.wide_general_probe.row_covered_count,
                     dut.p_controller.wide_general_probe.row_byte_count,
                     dut.p_controller.wide_general_probe.boundary_final,
                     dut.p_controller.wide_general_probe.slice_capture,
                     dut.p_controller.wide_general_probe.slice_parser_started,
                     dut.p_controller.wide_general_probe.qfs_index,
                     dut.p_controller.wide_general_probe.coeff_run_pending,
                     dut.p_controller.wide_general_probe.normal_target_index,
                     dut.p_controller.wide_general_probe.residual_coeff_count,
                     dut.p_controller.wide_general_probe.residual_block_count,
                     dut.p_controller.wide_general_probe.current_is_intra);

        if(dut.p_controller.wide_error&&!previous_wide_error)
            $display("WIDE_ERROR byte=%0d previous_state=%0d state=%0d parse_byte=%0d/%0d bit=%0d row=%0d col=%0d covered=%0d row_bytes=%0d boundary_final=%0d slice_capture=%0d parser_started=%0d",
                     stream_index,previous_wide_parser_state,
                     dut.p_controller.wide_general_probe.parser_state,
                     dut.p_controller.wide_general_probe.parse_byte_index,
                     dut.p_controller.wide_general_probe.parse_byte_limit,
                     dut.p_controller.wide_general_probe.parse_bit_index,
                     dut.p_controller.wide_general_probe.slice_row_number,
                     dut.p_controller.wide_general_probe.current_col,
                     dut.p_controller.wide_general_probe.row_covered_count,
                     dut.p_controller.wide_general_probe.row_byte_count,
                     dut.p_controller.wide_general_probe.boundary_final,
                     dut.p_controller.wide_general_probe.slice_capture,
                     dut.p_controller.wide_general_probe.slice_parser_started);

        if(p_row_terminator)begin
            row_persistence<=1;
            p_rows<=p_rows+1;
            if(p_final)begin
                picture_persistence<=1;
                p_pictures<=p_pictures+1;
                $display("P_FINAL byte=%0d p=%0d inflight=%0d headers=%0d publications=%0d",
                         stream_index,p_pictures+1,dut.b_picture_inflight,
                         dut.p_header_count,dut.p_publication_count);
            end
        end else if(b_row_terminator)begin
            row_persistence<=1;
            b_rows<=b_rows+1;
            if(b_final)begin
                picture_persistence<=1;
                b_pictures<=b_pictures+1;
                $display("B_FINAL byte=%0d b=%0d inflight=%0d headers=%0d persisted=%0d",
                         stream_index,b_pictures+1,dut.b_picture_inflight,
                         dut.b_header_count,dut.b_persist_count);
            end
        end

        if(dut.b_header_now)
            $display("B_HEADER byte=%0d inflight=%0d p_headers=%0d p_publications=%0d b_headers=%0d b_persist=%0d",
                     stream_index,dut.b_picture_inflight,
                     dut.p_header_count,dut.p_publication_count,
                     dut.b_header_count,dut.b_persist_count);
        if(dut.p_persisted_now)
            $display("P_PUBLISH_EDGE byte=%0d headers=%0d publications=%0d",
                     stream_index,dut.p_header_count,dut.p_publication_count);
        if(dut.b_persisted_now)
            $display("B_PERSIST_EDGE byte=%0d headers=%0d persisted=%0d",
                     stream_index,dut.b_header_count,dut.b_persist_count);

        if(picture_complete)published_references<=published_references+1;

        if(stream_index!=last_stream_index)begin
            last_stream_index<=stream_index;
            transport_stall_cycles<=0;
        end else if(stream_index<stream_len)begin
            transport_stall_cycles<=transport_stall_cycles+1;
            if(transport_stall_cycles==2000000)
                $fatal(1,"dense publication transport stalled byte=%0d inflight=%0d p_hold=%0d b_hold=%0d b_wait=%0d p_headers=%0d p_publications=%0d b_headers=%0d b_persist=%0d p_rows=%0d p=%0d b_rows=%0d b=%0d wide_candidate=%0d wide_seen=%0d wide_error=%0d proof_done=%0d current_p=%0d picture_capture=%0d slice_capture=%0d parse_active=%0d row_waiting=%0d wide_parse_hold=%0d b_candidate=%0d b_seen=%0d",
                       stream_index,dut.b_picture_inflight,
                       dut.p_hold_effective,dut.b_parse_hold,
                       dut.b_persistence_wait,dut.p_header_count,
                       dut.p_publication_count,dut.b_header_count,
                       dut.b_persist_count,p_rows,p_pictures,b_rows,b_pictures,
                       dut.p_controller.wide_candidate,
                       dut.p_controller.wide_seen,
                       dut.p_controller.wide_error,
                       dut.p_controller.wide_general_probe.proof_done,
                       dut.p_controller.wide_general_probe.current_picture_is_p,
                       dut.p_controller.wide_general_probe.picture_capture,
                       dut.p_controller.wide_general_probe.slice_capture,
                       dut.p_controller.wide_general_probe.parse_active,
                       dut.p_controller.wide_general_probe.row_waiting,
                       dut.p_controller.wide_parse_hold,
                       dut.b_candidate,dut.b_seen);
        end

        // The compact testbench ties the legacy I reconstruction handshakes
        // high, so its controlled bookkeeper observer can reject the dense I
        // before mixed-GOP ownership exists.  The compiled shell gates that
        // observer after the first B header; enforce every error from that
        // point forward, which includes all publication-order checks.
        if(probe_error&&dut.b_picture_observed)
            $fatal(1,"publication sequence error source=%0d detail=%0d byte=%0d p_headers=%0d p_publications=%0d b_headers=%0d b_persist=%0d active=%0d completed=%0d reference_valid=%0d reference=%0d pictures=%0d promotions=%0d",
                   probe_error_source,publication_error_detail,stream_index,
                   dut.p_header_count,dut.p_publication_count,
                   dut.b_header_count,dut.b_persist_count,
                   active_bank,completed_bank,reference_valid,reference_bank,
                   picture_count,reference_promotion_count);

        if((stream_index==stream_len)&&stream_ready&&!sideband_valid)
            quiet_cycles<=quiet_cycles+1;
        else quiet_cycles<=0;

        if(quiet_cycles==100)begin
            $display("DENSE_PUBLICATION_RESULT bytes=%0d p_rows=%0d p=%0d b_rows=%0d b=%0d published=%0d pictures=%0d promotions=%0d b_success=%0d",
                     stream_index,p_rows,p_pictures,b_rows,b_pictures,
                     published_references,picture_count,
                     reference_promotion_count,b_success);
            if(probe_error||publication_error_detail!=0||
               stream_index!=stream_len||p_rows!=120||p_pictures!=4||
               b_rows!=210||b_pictures!=7||published_references!=5||
               picture_count!=5||reference_promotion_count!=5||
               dut.p_header_count!=3||dut.p_publication_count!=3||!b_success)
                $fatal(1,"dense publication-order regression failed");
            $finish;
        end
    end

    initial begin
        repeat(200000000)@(posedge clk);
        $fatal(1,"dense publication-order regression timed out at byte %0d",stream_index);
    end

    wire unused=&{1'b0,p_probe_error_source,p_progress_detail};
endmodule
