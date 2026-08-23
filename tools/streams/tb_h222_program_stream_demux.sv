`timescale 1ns/1ps

module tb_h222_program_stream_demux;
reg clk=0,reset=1;
reg [7:0] input_data=0;
reg input_valid=0,input_end=0;
wire input_ready;
wire [7:0] video_data;
wire video_valid;
reg video_ready=1;
wire program_stream_detected,program_end_seen,systems_error;
wire [3:0] systems_error_code;

reg throttle=0;
integer output_count=0;
reg [7:0] output_bytes [0:63];

always #5 clk=~clk;

mpeg2_h222_program_stream_demux dut
(
    .clk(clk),.reset(reset),
    .input_data(input_data),.input_valid(input_valid),
    .input_ready(input_ready),.input_end(input_end),
    .video_data(video_data),.video_valid(video_valid),
    .video_ready(video_ready),
    .program_stream_detected(program_stream_detected),
    .program_end_seen(program_end_seen),
    .systems_error(systems_error),
    .systems_error_code(systems_error_code)
);

always @(posedge clk) begin
    if(reset)
        video_ready<=1;
    else if(throttle)
        video_ready<=!video_ready;
    else
        video_ready<=1;
    if(video_valid&&video_ready)begin
        output_bytes[output_count]<=video_data;
        output_count<=output_count+1;
    end
end

task reset_case;
begin
    @(negedge clk);reset=1;input_valid=0;input_end=0;throttle=0;
    repeat(3)@(negedge clk);
    output_count=0;reset=0;
end
endtask

task send_byte;
input [7:0] value;
begin
    @(negedge clk);input_data=value;input_valid=1;
    while(!input_ready)@(negedge clk);
    @(negedge clk);input_valid=0;
end
endtask

task send_prefix;
input [7:0] code;
begin
    send_byte(8'h00);send_byte(8'h00);send_byte(8'h01);send_byte(code);
end
endtask

task send_pack;
input [2:0] stuffing;
integer i;
begin
    send_prefix(8'hba);
    send_byte(8'h44);send_byte(8'h00);send_byte(8'h04);
    send_byte(8'h00);send_byte(8'h04);send_byte(8'h01);
    send_byte(8'h00);send_byte(8'h01);send_byte(8'h03);
    send_byte({5'b11111,stuffing});
    for(i=0;i<stuffing;i=i+1)send_byte(8'hff);
end
endtask

task expect_byte;
input integer index;
input [7:0] value;
begin
    if(output_bytes[index]!==value)
        $fatal(1,"output[%0d]=%02x expected %02x",index,output_bytes[index],value);
end
endtask

initial begin
    // Exact raw elementary-stream replay and pass-through under backpressure.
    reset_case();throttle=1;
    send_byte(8'h00);send_byte(8'h00);send_byte(8'h01);send_byte(8'hb3);
    send_byte(8'h11);send_byte(8'h22);
    wait(output_count==6);repeat(2)@(posedge clk);
    if(program_stream_detected||program_end_seen||systems_error)
        $fatal(1,"raw stream misclassified ps=%0d end=%0d err=%0d",
               program_stream_detected,program_end_seen,systems_error);
    expect_byte(0,8'h00);expect_byte(1,8'h00);expect_byte(2,8'h01);
    expect_byte(3,8'hb3);expect_byte(4,8'h11);expect_byte(5,8'h22);

    // MPEG-2 pack stuffing, system header, audio skip, selected video payload,
    // non-selected video skip, a second selected PES, and normative end code.
    reset_case();throttle=1;
    send_pack(3'd2);
    send_prefix(8'hbb);send_byte(8'h00);send_byte(8'h03);
    send_byte(8'haa);send_byte(8'hbb);send_byte(8'hcc);
    send_prefix(8'hc0);send_byte(8'h00);send_byte(8'h04);
    send_byte(8'hde);send_byte(8'had);send_byte(8'hbe);send_byte(8'hef);
    send_prefix(8'he0);send_byte(8'h00);send_byte(8'h0e);
    send_byte(8'h84);send_byte(8'h80);send_byte(8'h05);
    send_byte(8'h21);send_byte(8'h00);send_byte(8'h01);
    send_byte(8'h00);send_byte(8'h01);
    send_byte(8'h00);send_byte(8'h00);send_byte(8'h01);
    send_byte(8'hb3);send_byte(8'h55);send_byte(8'h66);
    send_prefix(8'he1);send_byte(8'h00);send_byte(8'h06);
    send_byte(8'h00);send_byte(8'h11);send_byte(8'h22);
    send_byte(8'h33);send_byte(8'h44);send_byte(8'h55);
    send_prefix(8'he0);send_byte(8'h00);send_byte(8'h09);
    send_byte(8'h80);send_byte(8'h00);send_byte(8'h00);
    send_byte(8'h77);send_byte(8'h88);send_byte(8'h00);
    send_byte(8'h00);send_byte(8'h01);send_byte(8'hb7);
    send_prefix(8'hb9);
    wait(program_end_seen);wait(output_count==12);repeat(2)@(posedge clk);
    if(!program_stream_detected||systems_error)
        $fatal(1,"valid Program Stream rejected ps=%0d err=%0d/%0d",
               program_stream_detected,systems_error,systems_error_code);
    expect_byte(0,8'h00);expect_byte(1,8'h00);expect_byte(2,8'h01);
    expect_byte(3,8'hb3);expect_byte(4,8'h55);expect_byte(5,8'h66);
    expect_byte(6,8'h77);expect_byte(7,8'h88);expect_byte(8,8'h00);
    expect_byte(9,8'h00);expect_byte(10,8'h01);expect_byte(11,8'hb7);

    // Invalid MPEG-2 pack fixed bits.
    reset_case();
    send_prefix(8'hba);send_byte(8'h00);repeat(2)@(posedge clk);
    if(!systems_error||(systems_error_code!=4'd2))
        $fatal(1,"bad pack did not report code 2: %0d/%0d",
               systems_error,systems_error_code);

    // Program Stream video PES packets must have a bounded non-zero length.
    reset_case();send_pack(3'd0);
    send_prefix(8'he0);send_byte(8'h00);send_byte(8'h00);
    repeat(2)@(posedge clk);
    if(!systems_error||(systems_error_code!=4'd5))
        $fatal(1,"zero PES length did not report code 5: %0d/%0d",
               systems_error,systems_error_code);

    // End-of-input before MPEG_program_end_code is a distinct truncation.
    reset_case();send_pack(3'd0);
    @(negedge clk);input_end=1;
    repeat(2)@(posedge clk);
    if(!systems_error||(systems_error_code!=4'd10))
        $fatal(1,"truncation did not report code 10: %0d/%0d",
               systems_error,systems_error_code);

    $display("H222_PROGRAM_STREAM_DEMUX_PASS raw=6 ps_payload=12 errors=2/5/10");
    $finish;
end
endmodule
