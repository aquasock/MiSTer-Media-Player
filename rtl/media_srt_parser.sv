// Bounded streaming SRT parser. Two 63-character display lines, no cue database.
// Header lines are searched for HH:MM:SS,mmm --> HH:MM:SS,mmm. Text is plain
// Printable ASCII plus normalized smart apostrophes; tags are removed and
// unsupported UTF-8 codepoints become '?'.
module media_srt_parser(
 input wire clk,reset,
 input wire [8:0] data,input wire valid,output wire ready,
 output reg cue_valid=0,input wire cue_ready,
 output reg [36:0] start_q=0,end_q=0,
 output reg [6:0] length0=0,length1=0,
 input wire [6:0] text_addr,output reg [7:0] text_q,
 output reg eof=0,warning=0
);
localparam COLLECT=0,READ=1,WAIT_READ=2,HEADER=3,TEXT=4,PUBLISH=5,HOLD=6,CONVERT=7;
reg [3:0] state=COLLECT;
(* ramstyle="M10K" *) reg [7:0] line[0:255];
(* ramstyle="M10K" *) reg [7:0] text[0:127];
reg [7:0] line_q;
reg [8:0] count=0,index=0;
reg reading_text=0,in_cue=0,ended=0,overflow=0;
reg [1:0] line_number=0;
reg [6:0] column=0;
reg tag=0;
reg [1:0] utf_left=0;
reg utf_smart=0,utf_replace=0;
reg [31:0] milliseconds=0,start_ms=0,end_ms=0;
reg [9:0] number=0;
reg [4:0] ti=0;
reg half=0;
wire digit=line_q>="0" && line_q<="9";
wire separator=ti==2 || ti==5 || ti==8 || ti==12 || ti==13 || ti==14 || ti==15 || ti==16;
assign ready=state==COLLECT && !eof;
always @(posedge clk) begin
 line_q<=line[index[7:0]];
 text_q<=text[text_addr];
 if(reset) begin
  state<=COLLECT;count<=0;index<=0;in_cue<=0;ended<=0;eof<=0;cue_valid<=0;
  length0<=0;length1<=0;line_number<=0;column<=0;warning<=0;tag<=0;utf_left<=0;utf_smart<=0;utf_replace<=0;overflow<=0;
  ti<=0;half<=0;number<=0;milliseconds<=0;start_ms<=0;end_ms<=0;start_q<=0;end_q<=0;reading_text<=0;
 end else case(state)
 COLLECT:if(valid && ready) begin
  if(data[8] || data[7:0]==10) begin
   ended<=data[8];index<=0;
   if(count==0) begin
    if(in_cue) state<=PUBLISH;
    else if(data[8]) eof<=1;
   end else if(in_cue) begin reading_text<=1;column<=0;state<=READ;end
   else begin
    reading_text<=0;ti<=0;half<=0;number<=0;milliseconds<=0;
    if(count>=29 && !overflow) state<=READ;
    else begin count<=0;overflow<=0;if(data[8]) eof<=1;end
   end
  end else if(data[7:0]!=13) begin
   if(count<256) begin line[count[7:0]]<=data[7:0];count<=count+1'b1;end
   else begin overflow<=1;warning<=1;end
  end
 end
 READ:state<=WAIT_READ;
 WAIT_READ:state<=reading_text?TEXT:HEADER;
 HEADER:begin
  // Reject a malformed candidate and resume searching at the next line.
  if((!separator && !digit) ||
     ((ti==2 || ti==5) && line_q!=":") || (ti==8 && line_q!=",") ||
     ((ti==12 || ti==16) && line_q!=" ") ||
     ((ti==13 || ti==14) && line_q!="-") || (ti==15 && line_q!=">") ||
     ((ti==5 || ti==8) && number>59)) begin
   state<=COLLECT;count<=0;overflow<=0;if(ended)eof<=1;
  end else begin
   if(!separator) number<=number*10+{6'd0,line_q[3:0]};
   if(ti==2 || ti==5) begin milliseconds<=milliseconds*60+{22'd0,number};number<=0;end
   if(ti==8) begin milliseconds<=(milliseconds*60+{22'd0,number})*1000;number<=0;end
   if(ti==11) begin
    if(!half) start_ms<=milliseconds+number*10+{28'd0,line_q[3:0]};
    else begin end_ms<=milliseconds+number*10+{28'd0,line_q[3:0]};state<=CONVERT;end
   end
   if(ti==16) begin half<=1;ti<=0;number<=0;milliseconds<=0;end
   else ti<=ti+1'b1;
   index<=index+1'b1;
   if(!(half && ti==11)) state<=READ;
  end
 end
 CONVERT:begin
  // Constant products only; no variable multiplier or timing division.
  start_q<={5'd0,start_ms}*37'd360;end_q<={5'd0,end_ms}*37'd360;
  count<=0;overflow<=0;length0<=0;length1<=0;line_number<=0;column<=0;tag<=0;utf_left<=0;utf_smart<=0;utf_replace<=0;
  if(end_ms>start_ms && !ended) in_cue<=1;else begin warning<=1;if(ended)eof<=1;end
  state<=COLLECT;
 end
 TEXT:begin
  if(line_q=="<")begin tag<=1;utf_left<=0;utf_smart<=0;utf_replace<=0;end
  else if(line_q==">")begin tag<=0;utf_left<=0;utf_smart<=0;utf_replace<=0;end
  else if(!tag) begin
   if(utf_left!=0 && line_q[7:6]==2'b10)begin
    utf_left<=utf_left-1'b1;
    // E2 80 98/99 (left/right single quotation marks). Replace the one
    // fallback cell allocated by the lead byte only after the full match.
    if(utf_left==1 && utf_smart && utf_replace && (line_q==8'h98 || line_q==8'h99))
     text[{line_number[0],(column[5:0]-6'd1)}]<=8'h27;
    utf_smart<=utf_smart && utf_left==2 && line_q==8'h80;
   end
   else begin
    utf_smart<=line_q==8'he2;utf_replace<=line_number<2 && column<63;
    utf_left<=line_q[7:5]==3'b110 ? 2'd1:line_q[7:4]==4'b1110 ? 2'd2:line_q[7:3]==5'b11110 ? 2'd3 : 2'd0;
    if(line_number<2 && column<63) begin
     text[{line_number[0],column[5:0]}]<=line_q==9?8'd32:(line_q==8'h91 || line_q==8'h92)?8'h27:(line_q>=32 && line_q<=126?line_q:8'd63);
     column<=column+1'b1;
     if(line_number==0)length0<=column+1'b1;else length1<=column+1'b1;
    end else warning<=1;
   end
  end
  if(index+1'b1==count) begin
   utf_left<=0;utf_smart<=0;utf_replace<=0;
   count<=0;overflow<=0;if(line_number<2)line_number<=line_number+1'b1;
   if(ended)state<=PUBLISH;else state<=COLLECT;
  end else begin index<=index+1'b1;state<=READ;end
 end
 PUBLISH:begin
  in_cue<=0;
  if(length0!=0 || length1!=0)begin cue_valid<=1;state<=HOLD;end
  else begin if(ended)eof<=1;state<=COLLECT;end
 end
 HOLD:if(cue_ready)begin cue_valid<=0;if(ended)eof<=1;state<=COLLECT;end
 default:state<=COLLECT;
 endcase
end
endmodule
