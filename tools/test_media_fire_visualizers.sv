`timescale 1ns/1ps
module test_media_fire_visualizers;
reg control_clk=0,clk=0;always #7 control_clk=~control_clk;always #5 clk=~clk;
reg [90:0] state_in=0;
reg [34:0] sub_command=0;wire sub_ack;
reg [23:0] rgb=24'h203040;
reg hs=0,vs=0,de=0;
wire [23:0] out;
wire ho,vo,deo;
reg enabled=1;reg [47:0] bounds=0;
wire [23:0] vrgb,wrgb;wire vh,vv,vd,ld,wh,wv,wd;
media_audio_viewport viewport(.clk(clk),.enabled(enabled),.bounds(bounds),.rgb(rgb),.hs(hs),.vs(vs),.de(de),
 .rgb_out(vrgb),.hs_out(vh),.vs_out(vv),.de_out(vd),.layout_de(ld));
reg [8:0] layout_pipe=0;always @(posedge clk)layout_pipe<={layout_pipe[7:0],ld};
reg audio_clk=0;always #22 audio_clk=~audio_clk;
reg [8:0] sample_phase=0;reg [31:0] random_state=32'h12345678;
reg sample_tick=0;reg signed [15:0] left_sample=0,right_sample=0;
integer sample_number=0,fire_mode=1,silent=0,switch_test=0;
always @(negedge audio_clk)begin
 sample_phase<=sample_phase+1'b1;sample_tick<=sample_phase==0;
 if(sample_phase==0)begin
  sample_number=sample_number+1;random_state=random_state*32'd1664525+32'd1013904223;
  left_sample<=silent!=0?16'sd0:16'($rtoi(11000*$sin(sample_number*0.09817477)+6500*$sin(sample_number*0.29452431)+4000*$sin(sample_number*0.83448555)))+$signed(random_state[31:18]);
  right_sample<=silent!=0?16'sd0:16'($rtoi(10000*$sin(sample_number*0.19634954)+6000*$sin(sample_number*0.51541754)+4000*$sin(sample_number*1.61988371)))+$signed(random_state[29:16]);
 end
end
wire [26:0] scope_reference;
media_waveform_visualizer reference_scope(.audio_clk(audio_clk),.video_clk(clk),.audio_active(enabled),.sample_tick(sample_tick),
 .sample_left(left_sample),.sample_right(right_sample),.rgb(vrgb),.hs(vh),.vs(vv),.de(vd),.layout_de(ld),
 .rgb_out(scope_reference[23:0]),.hs_out(scope_reference[26]),.vs_out(scope_reference[25]),.de_out(scope_reference[24]));
always @(negedge clk)if(fire_mode==0&&waveform.mode_pipe==0&&cycles>30&&{wh,wv,wd,wrgb}!==scope_reference)$fatal(1,"O-scope changed");
media_audio_visualizers waveform(.control_clk(control_clk),.select_visualizer(2'(fire_mode)),.audio_clk(audio_clk),.video_clk(clk),.audio_active(enabled),.sample_tick(sample_tick),
 .sample_left(left_sample),.sample_right(right_sample),.rgb(vrgb),.hs(vh),.vs(vv),.de(vd),.layout_de(ld),
 .rgb_out(wrgb),.hs_out(wh),.vs_out(wv),.de_out(wd));
media_player_overlay dut(.layout_de(layout_pipe[8]),.control_clk(control_clk),.video_clk(clk),.subtitle_command(sub_command),.subtitle_ack(sub_ack),.control_state(state_in),
 .rgb(wrgb),.hs(wh),.vs(wv),.de(wd),.rgb_out(out),.hs_out(ho),.vs_out(vo),.de_out(deo));
reg [26:0] expected[0:19];
integer cycles=0;
always @(posedge clk) begin
 expected[0]<={hs,vs,de,rgb};
 for(integer k=1;k<20;k=k+1) expected[k]<=expected[k-1];
 cycles<=cycles+1;
 #1;
 if(cycles>20 && {ho,vo,deo}!==expected[19][26:24]) $fatal(1,"timing pipeline mismatch");
end
integer view_x=0,view_y=0,view_w=720,view_h=480,music=1;
integer w=720,h=480,known=1,shown=1,paused=0,seeking=0;
integer fd,frame_no=0,pixels=0,pattern=0;
reg [34:0] position=35'd1340400000,total=35'd2629890000;
string path;
integer subtitles=0,subepoch=1;
string sub0="Hello, world!",sub1="Subtitle line two.";
task sub_send(input [1:0] op,input [15:0] payload);begin
 @(negedge control_clk);while(sub_ack!=sub_command[34])@(negedge control_clk);
 sub_command={~sub_command[34],subepoch[15:0],op,payload};
 @(negedge control_clk);while(sub_ack!=sub_command[34])@(negedge control_clk);
end endtask
initial begin
 if(!$value$plusargs("OUT=%s",path)) $fatal(1,"OUT");
 if($value$plusargs("W=%d",w)) begin end
 if($value$plusargs("H=%d",h)) begin end
 if($value$plusargs("KNOWN=%d",known)) begin end
 if($value$plusargs("SHOWN=%d",shown)) begin end
 if($value$plusargs("PAUSED=%d",paused)) begin end
 if($value$plusargs("SEEK=%d",seeking)) begin end
 if($value$plusargs("PATTERN=%d",pattern)) begin end
 if($value$plusargs("POSITION=%d",position)) begin end
 if($value$plusargs("TOTAL=%d",total)) begin end
 if($value$plusargs("SUBTITLES=%d",subtitles))begin end
 if($value$plusargs("SUBEPOCH=%d",subepoch))begin end
 if($value$plusargs("SUB0=%s",sub0))begin end
 if($value$plusargs("SUB1=%s",sub1))begin end
 if(sub0.len()>64 || sub1.len()>64)$fatal(1,"subtitle fixture too long");
 if($value$plusargs("X=%d",view_x))begin end
 if($value$plusargs("Y=%d",view_y))begin end
 if($value$plusargs("VW=%d",view_w))begin end
 if($value$plusargs("VH=%d",view_h))begin end
 if($value$plusargs("MUSIC=%d",music))begin end
 if($value$plusargs("FIRE=%d",fire_mode))begin end
 if($value$plusargs("SILENT=%d",silent))begin end
 if($value$plusargs("SWITCH=%d",switch_test))begin end
 enabled=music!=0;bounds={12'(view_x),12'(view_x+view_w-1),12'(view_y),12'(view_y+view_h-1)};
 state_in={16'd1,1'b1,shown[0],paused[0],seeking[0],known[0],total,position};
 if(subtitles!=0)begin
  for(integer i=0;i<128;i=i+1) sub_send(0,{i[7:0],(i<sub0.len()?sub0[i]:(i>=64 && i<64+sub1.len() && subtitles==2?sub1[i-64]:8'd0))});
  sub_send(1,{(subtitles==2?8'(sub1.len()):8'd0),(8'h80|8'(sub0.len()))});
 end
 fd=$fopen(path,"wb");$fwrite(fd,"P6\n%0d %0d\n255\n",w,h);
 repeat(12) @(negedge clk);
 for(frame_no=0;frame_no<5;frame_no=frame_no+1) begin
  for(integer y=0;y<h+20;y=y+1) begin
   for(integer x=0;x<w+40;x=x+1) begin
    vs=y<2;hs=x<8;de=y>=10 && y<h+10 && x>=20 && x<w+20;
    if(pattern!=0) begin
     rgb[23:16]=(x-20)&255;rgb[15:8]=(x+y-30)&255;rgb[7:0]=((x-20)*7+y-10)&255;
    end
    if(switch_test!=0&&y==20&&x==10)begin
     if(frame_no==1)fire_mode=switch_test==2?2:0;
     if(frame_no==3)fire_mode=1;
    end
    @(negedge clk);
    if(switch_test!=0&&y>=21&&frame_no==1&&waveform.frame_mode!=1)$fatal(1,"mode changed midframe");
    if(switch_test!=0&&y>=21&&frame_no==3&&waveform.frame_mode!=(switch_test==2?2:0))$fatal(1,"mode changed midframe");
    if(frame_no==4 && deo) begin
     $fwrite(fd,"%c%c%c",out[23:16],out[15:8],out[7:0]);pixels=pixels+1;
    end
   end
  end
 end
 $fclose(fd);
 if(pixels!=w*h) $fatal(1,"pixels %0d",pixels);
 if(dut.width!=12'(music!=0?view_w:w)||dut.height!=12'(music!=0?view_h:h)||waveform.fire.width!=dut.width||waveform.fire.height!=dut.height)$fatal(1,"viewport dimensions");
 $display("OVERLAY_RENDER_PASS pixels=%0d width=%0d height=%0d",pixels,dut.width,dut.height);$finish;
end
endmodule
