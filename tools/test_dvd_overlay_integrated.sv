`timescale 1ns/1ps

// Integrated regression for the physical schema-21 failure: a complete B9
// plane crosses the in-band extractor while the engine's DDR writer stalls.
module altsyncram #(
 parameter operation_mode="DUAL_PORT",parameter width_a=64,parameter widthad_a=6,
 parameter numwords_a=46,parameter width_b=64,parameter widthad_b=6,
 parameter numwords_b=46,parameter outdata_reg_b="UNREGISTERED",
 parameter address_reg_b="CLOCK1",parameter read_during_write_mode_mixed_ports="DONT_CARE",
 parameter ram_block_type="M10K",parameter intended_device_family="Cyclone V")
(
 input clock0,clock1,input [widthad_a-1:0] address_a,input [width_a-1:0] data_a,
 input wren_a,input [widthad_b-1:0] address_b,output reg [width_b-1:0] q_b,
 input aclr0,aclr1,addressstall_a,addressstall_b,byteena_a,byteena_b,
 input [width_b-1:0] data_b,input wren_b,output [width_a-1:0] q_a);
reg [63:0] memory [0:63];
always @(posedge clock0) if(wren_a) memory[address_a]<=data_a;
always @(posedge clock1) q_b<=memory[address_b];
assign q_a=0;
wire unused=&{1'b0,aclr0,aclr1,addressstall_a,addressstall_b,byteena_a,
              byteena_b,data_b,wren_b};
endmodule

module test_dvd_overlay_integrated;
reg mem_clk=0,video_clk=0,mem_reset=1,video_reset=1;
always #5 mem_clk=~mem_clk;
always #4 video_clk=~video_clk;

reg [7:0] input_data=0;
reg input_valid=0,input_end=0;
wire input_ready;
wire [7:0] clean_data,record_data;
wire clean_valid,record_start,record_last,record_valid,record_ready;
wire [32:0] pts_90k;
wire [1:0] picture_structure;
wire top_field_first,repeat_first_field,progressive_frame,metadata_valid;
wire [7:0] metadata_count;
wire [15:0] pcm_left,pcm_right;
wire pcm_stereo,pcm_rate_48k,pcm_non_audio,pcm_valid,pcm_end;
wire [13:0] pcm_sample_count;
wire pcm_protocol_error,extractor_error,engine_error;

wire [7:0] writer_burstcnt,reader_burstcnt;
wire [28:0] writer_addr,reader_addr;
wire writer_rd,writer_we,reader_rd;
wire [63:0] writer_din;
wire [7:0] writer_be;
reg [7:0] mem_cycle=0;
// Include multi-cycle stalls around complete-word publication.  This fills the
// extractor's retained queue and exercises record tails without relying on a
// combinational overlay_ready path.
wire writer_busy=(mem_cycle[3:0]>=4'd2&&mem_cycle[3:0]<=4'd6)||
                 (mem_cycle[4:0]>=5'd19&&mem_cycle[4:0]<=5'd23);
reg reader_busy=0;
reg [63:0] reader_dout=0;
reg reader_dout_ready=0;
reg pixel_ce=1,native_active=1,base_de=1;
reg [11:0] h_pos=0,v_pos=0;
reg [7:0] base_r=10,base_g=20,base_b=30;
wire [7:0] video_r,video_g,video_b;
wire [543:0] debug_words;
wire debug_commit_seen;

localparam [28:0] PLANE1=29'h06060000;
reg [63:0] ddr [0:10799];
reg read_active=0;
reg [28:0] service_addr=0;
integer service_words=0,write_count=0;

always @(posedge mem_clk) begin
    mem_cycle<=mem_cycle+1'b1;
    reader_dout_ready<=0;
    if(writer_we&&!writer_busy)begin
        if(writer_addr<PLANE1||writer_addr>=PLANE1+10800)
            $fatal(1,"bad write address %08x",writer_addr);
        ddr[writer_addr-PLANE1]<=writer_din;
        write_count<=write_count+1;
    end
    if(!read_active&&reader_rd&&!reader_busy)begin
        read_active<=1;service_addr<=reader_addr;service_words<=23;
    end
    else if(read_active)begin
        if(service_addr<PLANE1||service_addr>=PLANE1+10800)
            $fatal(1,"bad read address %08x",service_addr);
        reader_dout<=ddr[service_addr-PLANE1];
        reader_dout_ready<=1;
        service_addr<=service_addr+1;
        service_words<=service_words-1;
        if(service_words==1)read_active<=0;
    end
end

// Keep input valid across adjacent bytes so every ready-to-busy transition is
// exercised; each task returns only after its byte transfers.
task send_input(input [7:0] value);
begin
    @(negedge mem_clk);input_data=value;input_valid=1;
    while(!input_ready)@(negedge mem_clk);
end
endtask

task send_marker(input [15:0] length);
begin
    send_input(8'h00);send_input(8'h00);send_input(8'h01);send_input(8'hb9);
    send_input(length[15:8]);send_input(length[7:0]);
end
endtask

task send_style(input [7:0] command);
integer style_index;
reg [7:0] value;
begin
    send_marker(16'd42);send_input(command);
    for(style_index=0;style_index<41;style_index=style_index+1)begin
        value=0;
        if(style_index==0)value=8'd3;
        // Highlight palette index one is opaque magenta in transport RGBA.
        if(style_index==21)value=8'hff;
        if(style_index==23)value=8'hff;
        if(style_index==24)value=8'hff;
        if(style_index==38||style_index==40)value=8'd10;
        send_input(value);
    end
end
endtask

integer offset,chunk,index;
integer record_index;
initial begin
    repeat(5)@(posedge mem_clk);@(negedge mem_clk);mem_reset=0;
    repeat(5)@(posedge video_clk);@(negedge video_clk);video_reset=0;
    send_style(8'd1);
    offset=0;
    record_index=0;
    while(offset<86400)begin
        chunk=(86400-offset)>4096?4096:(86400-offset);
        send_marker(chunk+1);send_input(8'd2);
        for(index=0;index<chunk;index=index+1)
            send_input((record_index*37+index*13+8'h5a)&8'hff);
        offset=offset+chunk;
        record_index=record_index+1;
    end
    send_marker(16'd1);send_input(8'd3);
    @(negedge mem_clk);input_valid=0;

    repeat(400)@(posedge mem_clk);
    if(extractor_error||engine_error||pcm_protocol_error)
        $fatal(1,"protocol error extractor=%0d engine=%0d pcm=%0d",
               extractor_error,engine_error,pcm_protocol_error);
    if(write_count!=10800)$fatal(1,"write count %0d",write_count);
    if(ddr[0]!==64'hb5a89b8e8174675a)
        $fatal(1,"first plane word mismatch %016x",ddr[0]);
    if(ddr[10799]!==64'hd6c9bcafa295887b)
        $fatal(1,"last plane word mismatch %016x",ddr[10799]);
    repeat(20)@(posedge video_clk);
    // Nonuniform data is used here to prove every record-tail byte survives;
    // the engine-only regression retains the exact magenta compositing check.
    repeat(8)@(posedge mem_clk);
    if(!debug_commit_seen)$fatal(1,"commit not observed");
    if(debug_words[63:32]!=32'h00011601)
        $fatal(1,"record counts %08x",debug_words[63:32]);
    if(debug_words[95:64]!=32'h00000101)
        $fatal(1,"commit counts %08x",debug_words[95:64]);
    if(debug_words[127:96]!=32'd86465)
        $fatal(1,"record bytes %0d",debug_words[127:96]);
    if(debug_words[159:128]!=32'd86400)
        $fatal(1,"plane bytes %0d",debug_words[159:128]);
    if(debug_words[191:176]!=16'd10800)
        $fatal(1,"writer accepts %0d",debug_words[191:176]);
    if(debug_words[215:208]!=8'd1||debug_words[207:200]==8'd0)
        $fatal(1,"publication counts %08x",debug_words[223:192]);
    $display("dvd overlay integrated: two-entry extractor preserves all multi-record tails");
    $finish;
end

mpeg2_h262_inband_metadata extractor(
 .clk(mem_clk),.reset(mem_reset),.input_data(input_data),
 .input_valid(input_valid),.input_ready(input_ready),.input_end(input_end),
 .stream_data(clean_data),.stream_valid(clean_valid),.stream_ready(1'b1),
 .pts_90k(pts_90k),.picture_structure(picture_structure),
 .top_field_first(top_field_first),.repeat_first_field(repeat_first_field),
 .progressive_frame(progressive_frame),.metadata_valid(metadata_valid),
 .metadata_ready(1'b1),.metadata_count(metadata_count),.pcm_left(pcm_left),
 .pcm_right(pcm_right),.pcm_stereo(pcm_stereo),
 .pcm_rate_48k(pcm_rate_48k),.pcm_non_audio(pcm_non_audio),
 .pcm_valid(pcm_valid),.pcm_end(pcm_end),.pcm_ready(1'b1),
 .pcm_sample_count(pcm_sample_count),.pcm_protocol_error(pcm_protocol_error),
 .overlay_data(record_data),.overlay_start(record_start),
 .overlay_last(record_last),.overlay_valid(record_valid),
 .overlay_ready(record_ready),.overlay_protocol_error(extractor_error));

mpeg2_h262_dvd_overlay engine(
 .mem_clk(mem_clk),.mem_reset(mem_reset),.record_data(record_data),
 .record_start(record_start),.record_last(record_last),
 .record_valid(record_valid),.record_ready(record_ready),
 .protocol_error(engine_error),.writer_burstcnt(writer_burstcnt),
 .writer_addr(writer_addr),.writer_rd(writer_rd),.writer_din(writer_din),
 .writer_be(writer_be),.writer_we(writer_we),.writer_busy(writer_busy),
 .reader_burstcnt(reader_burstcnt),.reader_addr(reader_addr),
 .reader_rd(reader_rd),.reader_busy(reader_busy),
 .reader_dout(reader_dout),.reader_dout_ready(reader_dout_ready),
 .video_clk(video_clk),.video_reset(video_reset),.pixel_ce(pixel_ce),
 .h_pos(h_pos),.v_pos(v_pos),.native_active(native_active),
 .base_r(base_r),.base_g(base_g),.base_b(base_b),.base_de(base_de),
 .video_r(video_r),.video_g(video_g),.video_b(video_b),
 .debug_words(debug_words),.debug_commit_seen(debug_commit_seen));
endmodule
