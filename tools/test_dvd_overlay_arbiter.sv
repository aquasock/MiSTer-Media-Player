`timescale 1ns/1ps
module test_dvd_overlay_arbiter;
reg clk=0,reset=1,ddram_busy=0,ddram_dout_ready=0;
always #5 clk=~clk;
reg [7:0] wb=1,rb=1,pb=1,orb=1,owb=1;
reg [28:0] wa=29'h10010,ra=29'h20,pa=29'h30,ora=29'h40,owa=29'h50050;
reg wrd=0,rreq=0,preq=0,orreq=0,owrd=0;
reg [63:0] wdin=64'h11,owdin=64'h22;
reg [7:0] wbe=8'hff,owbe=8'hff;
reg wwe=0,owwe=0;
wire wbusy,rbusy,pbusy,orbusy,owbusy,rrdy,prdy,orrdy;
wire [7:0] db;
wire [28:0] da;
wire drd,dwe,accept;
wire [63:0] ddin;
wire [7:0] dbe;

task response(input integer owner);
begin
    @(negedge clk);ddram_dout_ready=1;#1;
    if((owner==0&&!rrdy)||(owner==1&&!orrdy)||(owner==2&&!prdy))
        $fatal(1,"response owner %0d not selected",owner);
    if((owner!=0&&rrdy)||(owner!=1&&orrdy)||(owner!=2&&prdy))
        $fatal(1,"response leaked from owner %0d",owner);
    @(posedge clk);@(negedge clk);ddram_dout_ready=0;
end
endtask

initial begin
    repeat(3)@(posedge clk);@(negedge clk);reset=0;
    // Presentation read wins over every other simultaneous client.
    rreq=1;orreq=1;preq=1;wwe=1;owwe=1;#1;
    if(!drd||da!=ra||!orbusy||!pbusy||!wbusy||!owbusy)
        $fatal(1,"display priority/busy failure");
    @(posedge clk);@(negedge clk);rreq=0;orreq=0;preq=0;wwe=0;owwe=0;
    response(0);

    // Overlay owns both words of its explicit descriptor.
    orb=2;orreq=1;#1;if(!drd||da!=ora)$fatal(1,"overlay read grant failure");
    @(posedge clk);@(negedge clk);orreq=0;
    response(1);response(1);

    // Prediction retains its distinct response owner.
    preq=1;#1;if(!drd||da!=pa)$fatal(1,"prediction grant failure");
    @(posedge clk);@(negedge clk);preq=0;response(2);

    // Reconstruction write remains ahead of the low-priority plane writer.
    wwe=1;owwe=1;#1;
    if(!dwe||da!=wa||ddin!=wdin||!owbusy||!accept)
        $fatal(1,"video writer priority failure");
    @(posedge clk);@(negedge clk);wwe=0;#1;
    if(!dwe||da!=owa||ddin!=owdin)$fatal(1,"overlay writer grant failure");
    @(posedge clk);@(negedge clk);owwe=0;
    $display("dvd overlay arbiter: priority and response ownership pass");
    $finish;
end

mpeg2_h262_ddram_arbiter dut(
 .clk(clk),.reset(reset),.writer_burstcnt(wb),.writer_addr(wa),.writer_rd(wrd),
 .writer_din(wdin),.writer_be(wbe),.writer_we(wwe),.writer_busy(wbusy),
 .reader_burstcnt(rb),.reader_addr(ra),.reader_rd(rreq),.reader_busy(rbusy),
 .reader_dout_ready(rrdy),.prediction_burstcnt(pb),.prediction_addr(pa),
 .prediction_rd(preq),.prediction_busy(pbusy),.prediction_dout_ready(prdy),
 .overlay_reader_burstcnt(orb),.overlay_reader_addr(ora),
 .overlay_reader_rd(orreq),.overlay_reader_busy(orbusy),
 .overlay_reader_dout_ready(orrdy),.overlay_writer_burstcnt(owb),
 .overlay_writer_addr(owa),.overlay_writer_rd(owrd),.overlay_writer_din(owdin),
 .overlay_writer_be(owbe),.overlay_writer_we(owwe),.overlay_writer_busy(owbusy),
 .ddram_busy(ddram_busy),.ddram_dout_ready(ddram_dout_ready),
 .ddram_burstcnt(db),.ddram_addr(da),.ddram_rd(drd),.ddram_din(ddin),
 .ddram_be(dbe),.ddram_we(dwe),.writer_accept_debug(accept));
endmodule
