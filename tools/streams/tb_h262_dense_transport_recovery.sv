`timescale 1ns/1ps

// Entry 205 transport invariant.  A sticky B failure may reject the stream,
// but it must terminate live B ownership and keep the HPS byte path draining.
module tb_h262_b_transport_abort;
    reg clk=0,reset=1,stream_valid=0;
    reg [7:0] stream_data=0;
    integer accepted=0,stall_cycles=0,index;
    wire stream_ready,probe_error;

    always #5 clk=~clk;

    mpeg2_h262_two_picture_probe dut(
        .clk(clk),.reset(reset),.stream_data(stream_data),
        .stream_valid(stream_valid),.stream_ready(stream_ready),
        .phase1_supported(1'b1),.vertical_size(14'd480),
        .intra_dc_precision(2'd0),.intra_vlc_format(1'b0),
        .pipeline_block_done(1'b1),.recon_block_complete(1'b1),
        .p_persistence_complete(1'b0),
        .p_row_persistence_complete(1'b0),
        .probe_error(probe_error)
    );

    task automatic send_byte(input [7:0] value);
        begin
            @(negedge clk);
            while(!stream_ready) begin
                stream_valid<=0;
                stall_cycles=stall_cycles+1;
                if(stall_cycles>32)$fatal(1,"transport remained stalled");
                @(negedge clk);
            end
            stream_data<=value;
            stream_valid<=1;
            accepted=accepted+1;
            @(negedge clk);
            stream_valid<=0;
        end
    endtask

    initial begin
        repeat(5)@(posedge clk);
        reset<=0;

        // Minimal picture header whose second byte classifies a B picture.
        send_byte(8'h00);send_byte(8'h00);send_byte(8'h01);
        send_byte(8'h00);send_byte(8'h00);send_byte(8'h18);
        repeat(2)@(posedge clk);
        if(!dut.b_picture_inflight)$fatal(1,"B transaction did not arm");

        // Model the sticky parser/replay error seen in the second dense B.
        force dut.b_error=1'b1;
        repeat(2)@(posedge clk);
        if(dut.b_picture_inflight)$fatal(1,"failed B transaction retained ownership");
        if(!stream_ready)$fatal(1,"failed B transaction retained backpressure");
        if(!probe_error)$fatal(1,"B error was hidden from diagnostics");

        stall_cycles=0;
        for(index=0;index<4096;index=index+1)
            send_byte(8'h55);
        if(accepted!=4102)$fatal(1,"accepted %0d bytes",accepted);
        if(stall_cycles!=0)$fatal(1,"post-abort drain stalled %0d cycles",stall_cycles);
        release dut.b_error;

        $display("TRANSPORT_RECOVERY_RESULT accepted=%0d stalls=%0d inflight=%0d ready=%0d error=%0d",
                 accepted,stall_cycles,dut.b_picture_inflight,stream_ready,probe_error);
        $finish;
    end

    initial begin
        repeat(20000)@(posedge clk);
        $fatal(1,"transport recovery regression timed out");
    end
endmodule

// Full-corpus reproducer for the first failure which motivated Entry 205.
// It is kept separate from the fast transport invariant because transforming
// the first dense B picture is intentionally a long simulation.
module tb_h262_dense_second_b_error;
    localparam integer MAX_STREAM_BYTES=3145728;
    reg clk=0,reset=1,stream_valid=0;
    reg [7:0] stream_data=0;
    reg [7:0] stream_mem[0:MAX_STREAM_BYTES-1];
    reg [1023:0] hex_path;
    integer stream_len,stream_index=0;
    reg prior_error=0;

    wire candidate,seen,complete,hold,replay,sideband_valid,error;
    wire [5:0] sideband_index;
    wire signed [15:0] sideband_value;
    wire row_retired=sideband_valid&&(sideband_index==6'h3f)&&
        ((sideband_value==16'shA3FE)||(sideband_value==16'shA3FF));

    always #5 clk=~clk;

    mpeg2_h262_b_core_probe parser(
        .clk(clk),.reset(reset),.stream_data(stream_data),
        .stream_valid(stream_valid),.row_retired(row_retired),
        .b_candidate(candidate),.b_seen(seen),.b_complete_now(complete),
        .parse_hold(hold),.replay_active(replay),
        .sideband_valid(sideband_valid),.sideband_index(sideband_index),
        .sideband_value(sideband_value),.first_sample_valid(),
        .first_sample_value(),.probe_error(error)
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
        if(reset)begin stream_valid<=0;stream_data<=0;end
        else if(stream_index<stream_len)begin
            if(!hold)begin
                stream_data<=stream_mem[stream_index];
                stream_valid<=1;
                stream_index<=stream_index+1;
            end else stream_valid<=0;
        end else stream_valid<=0;
    end

    always @(posedge clk) begin
        if(error&&!prior_error)begin
            $display("DENSE_SECOND_B_ERROR offset=%0d state=%0d row=%0d col=%0d byte=%0d/%0d bit=%0d",
                     stream_index,parser.state,parser.slice_row_number,
                     parser.current_col,parser.parse_byte_index,
                     parser.parse_byte_limit,parser.parse_bit_index);
            if((stream_index<818000)||(stream_index>819500)||
               (parser.state!=6'd23)||(parser.slice_row_number!=6'd9))
                $fatal(1,"unexpected dense failure boundary");
            repeat(3)@(posedge clk);
            if(hold)$fatal(1,"B parser error retained parse_hold");
            $finish;
        end
        prior_error<=error;
    end

    initial begin
        repeat(120000000)@(posedge clk);
        $fatal(1,"dense second-B reproducer timed out at %0d",stream_index);
    end
endmodule
