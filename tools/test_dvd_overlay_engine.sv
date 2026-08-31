`timescale 1ns/1ps

// Minimal dual-clock model for the one M10K used by the DUT.
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

module test_dvd_overlay_engine;
reg mem_clk=0,video_clk=0,mem_reset=1,video_reset=1;
always #5 mem_clk=~mem_clk;
always #4 video_clk=~video_clk;

reg [7:0] record_data=0;
reg record_start=0,record_last=0,record_valid=0;
wire record_ready,protocol_error;
wire [7:0] writer_burstcnt,reader_burstcnt;
wire [28:0] writer_addr,reader_addr;
wire writer_rd,writer_we,reader_rd;
wire [63:0] writer_din;
wire [7:0] writer_be;
reg writer_busy=0,reader_busy=0;
reg [63:0] reader_dout=0;
reg reader_dout_ready=0;
reg pixel_ce=1,native_active=1,base_de=1;
reg [11:0] h_pos=0,v_pos=0;
reg [7:0] base_r=10,base_g=20,base_b=30;
wire [7:0] video_r,video_g,video_b;

localparam [28:0] PLANE1=29'h06060000;
reg [63:0] ddr [0:10799];
reg read_active=0;
reg [28:0] service_addr=0;
integer service_words=0,write_count=0;

always @(posedge mem_clk) begin
    reader_dout_ready<=0;
    if(writer_we&&!writer_busy)begin
        if(writer_addr<PLANE1||writer_addr>=PLANE1+10800)$fatal(1,"bad write address");
        ddr[writer_addr-PLANE1]<=writer_din;
        write_count<=write_count+1;
    end
    if(!read_active&&reader_rd&&!reader_busy)begin
        read_active<=1;service_addr<=reader_addr;service_words<=23;
    end
    else if(read_active)begin
        if(service_addr<PLANE1||service_addr>=PLANE1+10800)$fatal(1,"bad read address");
        reader_dout<=ddr[service_addr-PLANE1];
        reader_dout_ready<=1;
        service_addr<=service_addr+1;
        service_words<=service_words-1;
        if(service_words==1)read_active<=0;
    end
end

task send_byte(input [7:0] value,input first,input last);
begin
    @(negedge mem_clk);record_data=value;record_start=first;
    record_last=last;record_valid=1;
    do @(posedge mem_clk); while(!record_ready);
    @(negedge mem_clk);record_valid=0;record_start=0;record_last=0;
end
endtask

task send_style(input [7:0] command,input menu,input red_highlight);
integer index;
reg [7:0] value;
begin
    send_byte(command,1,0);
    for(index=0;index<41;index=index+1)begin
        value=0;
        if(index==0)value=menu?8'd3:8'd1;
        // Normal color index one: RGBA 200,100,50,255.
        if(index==5)value=200;
        if(index==6)value=100;
        if(index==7)value=50;
        if(index==8)value=255;
        // Highlight color index one, optionally opaque red.
        if(red_highlight&&index==21)value=250;
        if(red_highlight&&index==24)value=255;
        // Inclusive highlight rectangle (0,0)-(10,10).
        if(index==38||index==40)value=10;
        send_byte(value,0,index==40);
    end
end
endtask

integer offset,chunk,index;
initial begin
    repeat(5)@(posedge mem_clk);@(negedge mem_clk);mem_reset=0;
    repeat(5)@(posedge video_clk);@(negedge video_clk);video_reset=0;
    send_style(8'd1,0,0);
    offset=0;
    while(offset<86400)begin
        chunk=(86400-offset)>4096?4096:(86400-offset);
        send_byte(8'd2,1,0);
        for(index=0;index<chunk;index=index+1)
            send_byte(8'h55,0,index==chunk-1);
        offset=offset+chunk;
    end
    send_byte(8'd3,1,1);
    repeat(300)@(posedge mem_clk);
    if(protocol_error)$fatal(1,"overlay protocol error");
    if(write_count!=10800)$fatal(1,"write count %0d",write_count);
    if(ddr[0]!==64'h5555555555555555||ddr[10799]!==64'h5555555555555555)
        $fatal(1,"plane content mismatch");
    repeat(12)@(posedge video_clk);
    if(video_r!=200||video_g!=100||video_b!=50)
        $fatal(1,"normal composite mismatch %0d %0d %0d",video_r,video_g,video_b);

    send_style(8'd4,1,1);
    repeat(20)@(posedge video_clk);
    if(video_r!=250||video_g!=0||video_b!=0)
        $fatal(1,"highlight composite mismatch %0d %0d %0d",video_r,video_g,video_b);
    send_byte(8'd0,1,1);
    repeat(20)@(posedge video_clk);
    if(video_r!=base_r||video_g!=base_g||video_b!=base_b)
        $fatal(1,"clear mismatch %0d %0d %0d",video_r,video_g,video_b);
    $display("dvd overlay engine: plane write/read, normal/highlight blend and clear pass");
    $finish;
end

mpeg2_h262_dvd_overlay dut(
 .mem_clk(mem_clk),.mem_reset(mem_reset),.record_data(record_data),
 .record_start(record_start),.record_last(record_last),.record_valid(record_valid),
 .record_ready(record_ready),.protocol_error(protocol_error),
 .writer_burstcnt(writer_burstcnt),.writer_addr(writer_addr),.writer_rd(writer_rd),
 .writer_din(writer_din),.writer_be(writer_be),.writer_we(writer_we),
 .writer_busy(writer_busy),.reader_burstcnt(reader_burstcnt),
 .reader_addr(reader_addr),.reader_rd(reader_rd),.reader_busy(reader_busy),
 .reader_dout(reader_dout),.reader_dout_ready(reader_dout_ready),
 .video_clk(video_clk),.video_reset(video_reset),.pixel_ce(pixel_ce),
 .h_pos(h_pos),.v_pos(v_pos),.native_active(native_active),
 .base_r(base_r),.base_g(base_g),.base_b(base_b),.base_de(base_de),
 .video_r(video_r),.video_g(video_g),.video_b(video_b));
endmodule
