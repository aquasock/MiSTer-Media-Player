// Convert a slowly changing CD source-sample count to the UI's 360000 Hz
// timeline. One shared serial division services elapsed and total counts.
module media_music_time(
 input wire clk,reset,
 input wire[35:0] position,total,
 output reg[34:0] elapsed_q=0,total_q=0
);
 reg which=0;reg[5:0] count=0;
 reg[35:0] quotient=0;reg[15:0] remainder=0;
 wire[16:0] trial={remainder,quotient[35]};
 wire[16:0] difference=trial-17'd44100;
 wire[39:0] scaled={19'd0,quotient[20:0]}*40'd360000;
 always @(posedge clk)begin
  if(reset)begin which<=0;count<=0;quotient<=0;remainder<=0;elapsed_q<=0;total_q<=0;end
  else if(count==0)begin quotient<=which?total:position;remainder<=0;count<=36;end
  else if(count==37)begin
   if(which)total_q<=(|scaled[39:35])?{35{1'b1}}:scaled[34:0];
   else elapsed_q<=(|scaled[39:35])?{35{1'b1}}:scaled[34:0];
   which<=!which;count<=0;
  end else begin
   remainder<=difference[16]?trial[15:0]:difference[15:0];
   quotient<={quotient[34:0],!difference[16]};
   count<=count==1?6'd37:count-1'b1;
  end
 end
endmodule
