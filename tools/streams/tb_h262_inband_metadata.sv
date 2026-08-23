`timescale 1ns/1ps
// Entry 369: proves the in-band metadata extractor by replaying byte streams
// and comparing the emitted bytes against an independently built expectation,
// rather than by inspecting internal state.
module tb_h262_inband_metadata;

    reg        clk = 0;
    reg        reset = 1;
    reg  [7:0] input_data = 0;
    reg        input_valid = 0;
    wire       input_ready;
    reg        input_end = 0;
    wire [7:0] stream_data;
    wire       stream_valid;
    reg        stream_ready = 1;
    wire [32:0] pts_90k;
    wire [1:0]  picture_structure;
    wire        top_field_first, repeat_first_field, progressive_frame;
    wire        metadata_valid;
    wire [7:0]  metadata_count;

    always #5 clk = ~clk;

    mpeg2_h262_inband_metadata dut(
        .clk(clk),.reset(reset),
        .input_data(input_data),.input_valid(input_valid),
        .input_ready(input_ready),.input_end(input_end),
        .stream_data(stream_data),.stream_valid(stream_valid),
        .stream_ready(stream_ready),
        .pts_90k(pts_90k),.picture_structure(picture_structure),
        .top_field_first(top_field_first),.repeat_first_field(repeat_first_field),
        .progressive_frame(progressive_frame),
        .metadata_valid(metadata_valid),.metadata_count(metadata_count));

    // captured output
    reg [7:0] got [0:1023];
    integer   got_n = 0;
    always @(posedge clk) if (!reset && stream_valid && stream_ready) begin
        got[got_n] = stream_data; got_n = got_n + 1;
    end

    integer meta_seen = 0;
    reg [32:0] last_pts;
    always @(posedge clk) if (!reset && metadata_valid) begin
        meta_seen = meta_seen + 1; last_pts = pts_90k;
    end

    task send(input [7:0] b);
        begin
            @(negedge clk); input_data = b; input_valid = 1;
            @(posedge clk); while (!input_ready) @(posedge clk);
            @(negedge clk); input_valid = 0;
        end
    endtask

    task finish_stream;
        begin
            @(negedge clk); input_end = 1;
            repeat (40) @(posedge clk);
            @(negedge clk); input_end = 0;
        end
    endtask

    integer i;
    reg [7:0] expect_a [0:63];
    integer   expect_n;

    initial begin
        repeat(3) @(posedge clk); reset = 0; @(posedge clk);

        // ---- 1. raw ES with no records passes through byte-identical ----
        // includes a real start code and an overlapping 00 00 00 01 run
        expect_n = 0;
        expect_a[0]=8'h00; expect_a[1]=8'h00; expect_a[2]=8'h01; expect_a[3]=8'hB3;
        expect_a[4]=8'h12; expect_a[5]=8'h00; expect_a[6]=8'h00; expect_a[7]=8'h00;
        expect_a[8]=8'h01; expect_a[9]=8'hB8; expect_a[10]=8'hAA; expect_a[11]=8'h00;
        expect_a[12]=8'h00; expect_a[13]=8'h01; expect_a[14]=8'hB7;
        expect_n = 15;
        for (i=0;i<expect_n;i=i+1) send(expect_a[i]);
        finish_stream();
        if (got_n !== expect_n)
            $fatal(1,"raw passthrough length %0d expected %0d",got_n,expect_n);
        for (i=0;i<expect_n;i=i+1)
            if (got[i] !== expect_a[i])
                $fatal(1,"raw passthrough byte %0d got %h expected %h",i,got[i],expect_a[i]);
        if (meta_seen !== 0) $fatal(1,"record detected in a raw stream");

        // ---- 2. a record is stripped and decoded, surrounding bytes intact ----
        got_n = 0;
        send(8'hAA); send(8'hBB);
        send(8'h00); send(8'h00); send(8'h01); send(8'hB0);   // marker
        send(8'h00); send(8'h03); send(8'hBF); send(8'h79);   // pts 0x77EF2 << 7
        send(8'h28);                                          // ps=01, tff=0, rff=1, pf=0
        send(8'hCC); send(8'hDD);
        finish_stream();
        if (meta_seen !== 1) $fatal(1,"expected exactly one record, saw %0d",meta_seen);
        if (got_n !== 4) $fatal(1,"record not stripped: %0d bytes emitted",got_n);
        if (got[0]!==8'hAA||got[1]!==8'hBB||got[2]!==8'hCC||got[3]!==8'hDD)
            $fatal(1,"bytes around the record were altered");
        if (last_pts !== 33'h00077EF2)
            $fatal(1,"pts decoded as %h expected 00077ef2",last_pts);
        if (picture_structure!==2'b01||top_field_first!==1'b0||
            repeat_first_field!==1'b1||progressive_frame!==1'b0)
            $fatal(1,"flags decoded wrong ps=%b tff=%b rff=%b pf=%b",
                   picture_structure,top_field_first,repeat_first_field,progressive_frame);

        // ---- 3. a near-miss marker (00 00 01 B1) must pass through whole ----
        got_n = 0; meta_seen = 0;
        send(8'h00); send(8'h00); send(8'h01); send(8'hB1); send(8'h55);
        finish_stream();
        if (meta_seen !== 0) $fatal(1,"reserved code B1 was mistaken for a record");
        if (got_n !== 5) $fatal(1,"near-miss lost bytes: %0d of 5",got_n);
        if (got[0]!==8'h00||got[1]!==8'h00||got[2]!==8'h01||got[3]!==8'hB1||got[4]!==8'h55)
            $fatal(1,"near-miss corrupted the stream");

        // ---- 4. overlapping prefix: 00 00 00 01 B0 is a real record ----
        got_n = 0; meta_seen = 0;
        send(8'h00);
        send(8'h00); send(8'h00); send(8'h01); send(8'hB0);
        send(8'h00); send(8'h00); send(8'h00); send(8'h00); send(8'h00);
        finish_stream();
        if (meta_seen !== 1) $fatal(1,"overlapping prefix record missed");
        if (got_n !== 1 || got[0] !== 8'h00)
            $fatal(1,"overlapping prefix emitted %0d bytes, expected the single leading 00",got_n);

        // ---- 5. backpressure must not corrupt or drop ----
        got_n = 0; meta_seen = 0; stream_ready = 0;
        fork
            begin
                send(8'h11); send(8'h22); send(8'h33); send(8'h44);
                send(8'h55); send(8'h66);
            end
            begin repeat(12) @(posedge clk); stream_ready = 1; end
        join
        finish_stream();
        if (got_n !== 6) $fatal(1,"backpressure lost bytes: %0d of 6",got_n);
        if (got[0]!==8'h11||got[5]!==8'h66)
            $fatal(1,"backpressure reordered the stream");

        $display("H262_INBAND_METADATA_PASS raw=15 record=1 nearmiss=1 overlap=1 backpressure=1 pts=%h count=%0d",
                 last_pts, metadata_count);
        $finish;
    end
endmodule
