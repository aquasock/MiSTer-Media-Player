// Observer only. First fault after a seek survives pause and decoder restart.
// Audio flags are observed after their existing CDC; ordering is local to clk.
module media_seek_diagnostics #(
 parameter integer STALL_CYCLES=120000000
)(
 input wire clk,clear,seeking,paused,progress,
 input wire [11:0] state_flags,
 input wire [15:0] errors,
 input wire [31:0] subcodes,scheduler,
 input wire [34:0] elapsed_q,target_q,
 input wire [32:0] display_pts,
 input wire [17:0] picture,
 input wire [20:0] video_level,
 input wire [10:0] audio_level,
 input wire [12:0] pcm_level,
 input wire [15:0] reservoir_min,
 output reg valid=0,
 output reg [447:0] snapshot=0
);
reg seeking_q=0,armed=0;
reg [31:0] cycles=0;
reg [26:0] stalled=0;
reg [15:0] seeks=0,entry_errors=0;
wire entering=seeking&&!seeking_q;
wire timeout=seeking&&!progress&&stalled>=STALL_CYCLES-1;
wire capture=!valid&&(armed||entering)&&((|errors)||timeout);
wire [3:0] reason=(|errors)?(entering?4'd2:4'd1):4'd3;
wire [31:0] words[0:12];
assign words[0]=32'h4d4d5331;
assign words[1]=32'h010eea60; // version 1, fourteen words, 60000 kHz
assign words[2]={reason,state_flags,errors};
assign words[3]=subcodes;
assign words[4]=elapsed_q[31:0];
assign words[5]=target_q[31:0];
assign words[6]={7'd0,picture,display_pts[32],target_q[34:32],elapsed_q[34:32]};
assign words[7]=display_pts[31:0];
assign words[8]={video_level,audio_level};
assign words[9]={3'd0,reservoir_min,pcm_level};
assign words[10]=scheduler;
assign words[11]=entering?32'd0:cycles;
assign words[12]={entering?seeks+16'd1:seeks,entering?errors:entry_errors};
integer i;
reg [31:0] checksum;
always @* begin
 checksum=0;
 for(integer n=0;n<13;n=n+1) checksum=checksum^words[n];
end
always @(posedge clk) begin
 if(clear) begin
  valid<=0;snapshot<=0;seeking_q<=0;armed<=0;cycles<=0;stalled<=0;seeks<=0;entry_errors<=0;
 end else begin
  seeking_q<=seeking;
  if(entering) begin armed<=1;seeks<=seeks+16'd1;entry_errors<=errors;cycles<=0;stalled<=0;end
  else begin
   if(armed&&cycles!=32'hffffffff) cycles<=cycles+32'd1;
   if(!seeking||progress) stalled<=0;
   else if(stalled<STALL_CYCLES) stalled<=stalled+27'd1;
  end
  if(capture) begin
   valid<=1;
   for(i=0;i<13;i=i+1) snapshot[i*32+:32]<=words[i];
   snapshot[416+:32]<=checksum;
  end
 end
end
endmodule

// Four-pixel cells, same framing as the cadence overlay, separate magic/origin.
module media_seek_overlay(
 input wire clk,reset,valid,de,
 input wire [447:0] snapshot,
 input wire [11:0] h,v,
 output wire enable,pixel
);
wire [11:0] row=(v-12'd280)>>2;
reg [31:0] word;
reg [42:0] shift=0;
always @* begin
 word=0;
 if(row<14) word=snapshot[row[3:0]*32+:32];
end
always @(posedge clk) begin
 if(reset) shift<=0;
 else if(h==0) shift<={4'b1010,row[5:0],word,^word};
 else if(h>=192 && h<364 && h[1:0]==3) shift<={shift[41:0],1'b0};
end
assign enable=valid&&de&&h>=192&&h<364&&v>=280&&v<336;
assign pixel=shift[42];
endmodule
