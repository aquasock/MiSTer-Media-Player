`timescale 1ns/1ps
// Entry 371: replay a real annotated elementary stream through the extractor
// and require the emitted bytes to equal the unannotated source exactly.
// Replays an annotated elementary stream and its unannotated source through
// mpeg2_h262_inband_metadata, requiring the emitted bytes to equal the source
// exactly.  Paths and lengths arrive as plusargs so any stream can be used:
//
//   tools/streams/inject_inband_metadata.py in.m2v out.m2v
//   (convert both to one-byte-per-line hex, then)
//   ./tb +ann=out.hex +src=in.hex +ann_n=<bytes> +src_n=<bytes> +records=<n>
module tb_h262_inband_metadata_file;
    integer ANN_N, SRC_N, WANT_RECORDS;
    reg [1023:0] ann_path, src_path;
    reg [7:0] ann [0:800000];
    reg [7:0] src [0:800000];

    reg clk=0, reset=1, input_valid=0, input_end=0, stream_ready=1;
    reg [7:0] input_data=0;
    wire input_ready, stream_valid, metadata_valid;
    wire [7:0] stream_data, metadata_count;
    wire [32:0] pts_90k;
    wire [1:0] picture_structure;
    wire tff, rff, pf;
    always #5 clk=~clk;

    mpeg2_h262_inband_metadata dut(.clk(clk),.reset(reset),
        .input_data(input_data),.input_valid(input_valid),.input_ready(input_ready),
        .input_end(input_end),.stream_data(stream_data),.stream_valid(stream_valid),
        .stream_ready(stream_ready),.pts_90k(pts_90k),
        .picture_structure(picture_structure),.top_field_first(tff),
        .repeat_first_field(rff),.progressive_frame(pf),
        .metadata_valid(metadata_valid),.metadata_ready(1'b1),
        .metadata_count(metadata_count));

    integer out_n=0; integer recs=0; reg [32:0] last_pts=0;
    always @(posedge clk) if(!reset && stream_valid && stream_ready) begin
        if (out_n < SRC_N && stream_data !== src[out_n])
            $fatal(1,"byte %0d: got %h expected %h",out_n,stream_data,src[out_n]);
        out_n=out_n+1;
    end
    always @(posedge clk) if(!reset && metadata_valid) begin
        recs=recs+1; last_pts=pts_90k;
    end

    integer i;
    initial begin
        if(!$value$plusargs("ann=%s",ann_path)) $fatal(1,"+ann= required");
        if(!$value$plusargs("src=%s",src_path)) $fatal(1,"+src= required");
        if(!$value$plusargs("ann_n=%d",ANN_N))  $fatal(1,"+ann_n= required");
        if(!$value$plusargs("src_n=%d",SRC_N))  $fatal(1,"+src_n= required");
        if(!$value$plusargs("records=%d",WANT_RECORDS)) WANT_RECORDS=0;
        $readmemh(ann_path,ann);
        $readmemh(src_path,src);
        repeat(3) @(posedge clk); reset=0;
        for(i=0;i<ANN_N;i=i+1) begin
            @(negedge clk); input_data=ann[i]; input_valid=1;
            @(posedge clk); while(!input_ready) @(posedge clk);
            @(negedge clk); input_valid=0;
            if (i % 977 == 0) begin stream_ready=0; repeat(2) @(posedge clk); stream_ready=1; end
        end
        @(negedge clk); input_end=1; repeat(60) @(posedge clk); input_end=0;
        if (out_n !== SRC_N) $fatal(1,"emitted %0d bytes, source is %0d",out_n,SRC_N);
        if (recs !== WANT_RECORDS)
            $fatal(1,"extracted %0d records, expected %0d",recs,WANT_RECORDS);
        $display("H262_INBAND_FILE_PASS bytes=%0d records=%0d last_pts=%h low11=%h",
                 out_n,recs,last_pts,last_pts[10:0]);
        $finish;
    end
endmodule
