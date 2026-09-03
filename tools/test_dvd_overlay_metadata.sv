`timescale 1ns/1ps

module test_dvd_overlay_metadata;
reg clk=0,reset=1,input_valid=0,input_end=0;
reg [7:0] input_data=0;
wire input_ready;
wire [7:0] stream_data,overlay_data;
wire stream_valid,overlay_start,overlay_last,overlay_valid;
reg overlay_ready=0;
wire [32:0] pts;
wire [1:0] picture_structure;
wire top_field_first,repeat_first_field,progressive_frame,metadata_valid;
wire [7:0] metadata_count;
wire [15:0] pcm_left,pcm_right;
wire pcm_stereo,pcm_rate_48k,pcm_non_audio,pcm_valid,pcm_end;
wire [13:0] pcm_sample_count;
wire pcm_error,overlay_error;
reg [7:0] stream_seen [0:31];
reg [7:0] overlay_seen [0:7];
integer stream_count=0,overlay_count=0,cycles=0;
reg overlay_stalled=0;
reg [9:0] overlay_stalled_value=0;
reg sequence_end_seen=0;
reg [31:0] stream_window=0;

always #5 clk=~clk;
always @(posedge clk) begin
    cycles<=cycles+1;
    overlay_ready<=cycles[0];
    if(stream_valid)begin
        stream_seen[stream_count]=stream_data;
        stream_count=stream_count+1;
        stream_window={stream_window[23:0],stream_data};
        if({stream_window[23:0],stream_data}==32'h000001b7)
            sequence_end_seen=1;
    end
    if(overlay_stalled)begin
        if(!overlay_valid)$fatal(1,"overlay valid dropped during stall");
        if({overlay_start,overlay_last,overlay_data}!==overlay_stalled_value)
            $fatal(1,"overlay payload changed during stall");
        if(overlay_ready)overlay_stalled=0;
    end
    if(overlay_valid&&!overlay_ready&&!overlay_stalled)begin
        overlay_stalled=1;
        overlay_stalled_value={overlay_start,overlay_last,overlay_data};
    end
    if(overlay_valid&&overlay_ready)begin
        overlay_seen[overlay_count]=overlay_data;
        if(overlay_count==0 && !overlay_start)$fatal(1,"missing overlay start");
        if(overlay_count!=0 && overlay_start)$fatal(1,"late overlay start");
        if(overlay_count==2 && !overlay_last)$fatal(1,"missing overlay last");
        if(overlay_count!=2 && overlay_last)$fatal(1,"early overlay last");
        overlay_count=overlay_count+1;
    end
end

task send_byte(input [7:0] value);
begin
	@(negedge clk);
    input_data=value;input_valid=1;
    do @(posedge clk); while(!input_ready);
	@(negedge clk);
    input_valid=0;
end
endtask

mpeg2_h262_inband_metadata dut(
 .clk(clk),.reset(reset),.input_data(input_data),.input_valid(input_valid),
 .input_ready(input_ready),.input_end(input_end),.stream_data(stream_data),
 .stream_valid(stream_valid),.stream_ready(1'b1),.pts_90k(pts),
 .picture_structure(picture_structure),.top_field_first(top_field_first),
 .repeat_first_field(repeat_first_field),.progressive_frame(progressive_frame),
 .metadata_valid(metadata_valid),.metadata_ready(1'b1),
 .metadata_count(metadata_count),.pcm_left(pcm_left),.pcm_right(pcm_right),
 .pcm_stereo(pcm_stereo),.pcm_rate_48k(pcm_rate_48k),
 .pcm_non_audio(pcm_non_audio),.pcm_valid(pcm_valid),.pcm_end(pcm_end),
 .pcm_ready(1'b1),.pcm_sample_count(pcm_sample_count),
 .pcm_protocol_error(pcm_error),.overlay_data(overlay_data),
 .overlay_start(overlay_start),.overlay_last(overlay_last),
 .overlay_valid(overlay_valid),.overlay_ready(overlay_ready),
 .overlay_protocol_error(overlay_error));

initial begin
    repeat(3)@(posedge clk);@(negedge clk);reset=0;
    send_byte(8'haa);
    // The extra leading zero proves overlapping 00 00 00 01 B9 handling.
    send_byte(8'h00);send_byte(8'h00);send_byte(8'h00);
    send_byte(8'h01);send_byte(8'hb9);
    send_byte(8'h00);send_byte(8'h03);
    send_byte(8'h02);send_byte(8'hde);send_byte(8'had);
    send_byte(8'hbb);send_byte(8'hcc);
    send_byte(8'h00);send_byte(8'h00);send_byte(8'h01);send_byte(8'hb7);
    // A live indefinite DVD menu cannot assert input_end.  The helper's five
    // transport drain bytes must expose the complete sequence end first.
    send_byte(8'h00);send_byte(8'h00);send_byte(8'h00);
    send_byte(8'h00);send_byte(8'h00);
    repeat(10)@(posedge clk);
    if(input_end||!sequence_end_seen)
        $fatal(1,"sequence end did not leave lookahead during live session");
    input_end=1;
    repeat(20)@(posedge clk);
    if(overlay_error||pcm_error)$fatal(1,"unexpected protocol error");
    $display("overlay_count=%0d data=%02x %02x %02x stream_count=%0d",
             overlay_count,overlay_seen[0],overlay_seen[1],overlay_seen[2],
             stream_count);
    if(overlay_count!=3||overlay_seen[0]!=8'h02||
       overlay_seen[1]!=8'hde||overlay_seen[2]!=8'had)
        $fatal(1,"overlay payload mismatch");
    if(stream_count!=13||stream_seen[0]!=8'haa||stream_seen[1]!=8'h00||
       stream_seen[2]!=8'hbb||stream_seen[3]!=8'hcc||
       stream_seen[4]!=8'h00||stream_seen[5]!=8'h00||
       stream_seen[6]!=8'h01||stream_seen[7]!=8'hb7)
        $fatal(1,"clean stream mismatch count=%0d",stream_count);
    $display("dvd overlay metadata: bounded extraction, live sequence end and backpressure pass");
    $finish;
end
endmodule
