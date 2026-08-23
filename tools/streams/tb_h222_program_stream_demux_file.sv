`timescale 1ns/1ps

module tb_h222_program_stream_demux_file;
reg clk=0,reset=1;
reg [7:0] input_data=0;
reg input_valid=0,input_end=0;
wire input_ready;
wire [7:0] video_data;
wire video_valid;
reg video_ready=1;
wire video_pts_valid;
wire [32:0] video_pts_90k;
wire program_stream_detected,program_end_seen,systems_error;
wire [3:0] systems_error_code;

integer input_file,expected_file,input_byte,expected_byte;
integer input_count=0,output_count=0,ready_divider=0;
integer pts_count=0,expected_pts_count=0;
reg [32:0] last_pts_90k=0,expected_last_pts_90k=0;
reg check_pts_count=0,check_last_pts=0;
reg [1023:0] input_path,expected_path;

always #5 clk=~clk;

mpeg2_h222_program_stream_demux dut
(
    .clk(clk),.reset(reset),
    .input_data(input_data),.input_valid(input_valid),
    .input_ready(input_ready),.input_end(input_end),
    .video_data(video_data),.video_valid(video_valid),
    .video_ready(video_ready),
    .video_pts_valid(video_pts_valid),.video_pts_90k(video_pts_90k),
    .program_stream_detected(program_stream_detected),
    .program_end_seen(program_end_seen),
    .systems_error(systems_error),
    .systems_error_code(systems_error_code)
);

always @(posedge clk) begin
    if(reset)begin
        ready_divider<=0;
        video_ready<=1;
    end
    else begin
        ready_divider<=ready_divider+1;
        video_ready<=(ready_divider[2:0]!=3'b111);
    end
    if(video_valid&&video_ready)begin
        expected_byte=$fgetc(expected_file);
        if(expected_byte<0)
            $fatal(1,"unexpected extra output byte %02x at %0d",
                   video_data,output_count);
        if(video_data!==expected_byte[7:0])
            $fatal(1,"output mismatch at %0d: %02x expected %02x",
                   output_count,video_data,expected_byte[7:0]);
        output_count<=output_count+1;
    end
    if(video_pts_valid)begin
        pts_count<=pts_count+1;
        last_pts_90k<=video_pts_90k;
    end
end

initial begin
    if(!$value$plusargs("INPUT=%s",input_path))
        $fatal(1,"missing +INPUT=<path>");
    if(!$value$plusargs("EXPECTED=%s",expected_path))
        $fatal(1,"missing +EXPECTED=<path>");
    check_pts_count=$value$plusargs("EXPECTED_PTS_COUNT=%d",expected_pts_count);
    check_last_pts=$value$plusargs("EXPECTED_LAST_PTS=%h",expected_last_pts_90k);
    input_file=$fopen(input_path,"rb");
    expected_file=$fopen(expected_path,"rb");
    if(!input_file||!expected_file)$fatal(1,"could not open input/expected files");

    repeat(4)@(negedge clk);reset=0;
    input_byte=$fgetc(input_file);
    while(input_byte>=0)begin
        @(negedge clk);input_data=input_byte[7:0];input_valid=1;
        while(!input_ready)@(negedge clk);
        input_count=input_count+1;
        @(negedge clk);input_valid=0;
        input_byte=$fgetc(input_file);
    end
    @(negedge clk);input_end=1;
    repeat(100)@(posedge clk);
    if(systems_error)
        $fatal(1,"systems error %0d after %0d input / %0d output bytes",
               systems_error_code,input_count,output_count);
    if(program_stream_detected&&!program_end_seen)
        $fatal(1,"Program Stream did not reach MPEG_program_end_code");
    expected_byte=$fgetc(expected_file);
    if(expected_byte>=0)
        $fatal(1,"output ended early after %0d bytes, next expected %02x",
               output_count,expected_byte[7:0]);
    if(check_pts_count&&(pts_count!=expected_pts_count))
        $fatal(1,"PTS association count %0d expected %0d",
               pts_count,expected_pts_count);
    if(check_last_pts&&(last_pts_90k!=expected_last_pts_90k))
        $fatal(1,"last PTS %h expected %h",last_pts_90k,expected_last_pts_90k);
    $display("H222_PROGRAM_STREAM_FILE_PASS input=%0d output=%0d ps=%0d end=%0d pts=%0d last=%h",
             input_count,output_count,program_stream_detected,program_end_seen,
             pts_count,last_pts_90k);
    $finish;
end
endmodule
