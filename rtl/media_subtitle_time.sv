// Absolute subtitle timeline: max(0, (video_time - offset) * speed / 100).
// Positive offset delays subtitles. before_start hides even cues beginning at
// zero until a positive delay expires. Serial arithmetic never accumulates drift.
module media_subtitle_time(
 input wire clk,reset,
 input wire[34:0] elapsed_q,
 input wire[6:0] offset_code,speed_code,
 output reg[36:0] subtitle_q=0,
 output reg before_start=0,restart=1
);
 // Menu indices are circular around defaults: 0 -> zero offset / 1.00x.
 wire signed[7:0] offset_steps=offset_code<=50?$signed({1'b0,offset_code}):
                              offset_code<=100?$signed({1'b0,offset_code})-8'sd101:8'sd0;
 wire[7:0] speed_percent=speed_code<=50?{1'b0,speed_code}+8'd100:
                         speed_code<=100?{1'b0,speed_code}-8'd1:8'd100;
 wire signed[36:0] offset_q=37'(offset_steps)*37'sd36000;
 wire signed[36:0] shifted_q=$signed({2'd0,elapsed_q})-offset_q;
 reg[6:0] saved_offset=0,saved_speed=0;
 reg[1:0] state=0;
 reg[5:0] count=0;
 reg[43:0] work=0,addend=0;
 reg[7:0] multiplier=0;
 reg[6:0] remainder=0;
 reg negative=0;
 wire[7:0] trial={remainder,work[43]};
 wire[7:0] difference=trial-8'd100;
 always @(posedge clk)begin
  if(reset)begin
   state<=0;subtitle_q<=0;before_start<=0;restart<=1;
   saved_offset<=offset_code;saved_speed<=speed_code;
  end else if(offset_code!=saved_offset||speed_code!=saved_speed)begin
   saved_offset<=offset_code;saved_speed<=speed_code;state<=0;restart<=1;
  end else case(state)
   0:begin
    negative<=shifted_q[36];addend<=shifted_q[36]?44'd0:{8'd0,shifted_q[35:0]};
    work<=0;multiplier<=speed_percent;count<=8;state<=1;
   end
   1:begin
    if(multiplier[0])work<=work+addend;
    multiplier<=multiplier>>1;addend<=addend<<1;
    if(count==1)begin count<=44;remainder<=0;state<=2;end
    else count<=count-1'b1;
   end
   2:begin
    remainder<=difference[7]?trial[6:0]:difference[6:0];
    work<={work[42:0],!difference[7]};
    if(count==1)state<=3;else count<=count-1'b1;
   end
   3:begin subtitle_q<=work[36:0];before_start<=negative;restart<=0;state<=0;end
  endcase
 end
endmodule
