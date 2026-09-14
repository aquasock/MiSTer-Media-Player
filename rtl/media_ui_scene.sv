// Scene assembler. Only this producer writes the compositor's inactive page.
// A future cue producer may update the retained auxiliary provider (slots 4-7)
// and publish its epoch. No subtitle parser, transport or cue selection exists.
module media_ui_scene(
 input wire clk,input wire [90:0] state_in,input wire [11:0] width,height,
 input wire pending,acknowledged,
 output reg text_we=0,output reg [8:0] text_addr=0,output reg [7:0] text_data=0,
 output reg object_we=0,output reg [3:0] object_addr=0,output reg [55:0] object_data=0,
 output reg commit=0,output reg [15:0] commit_epoch=0,
 output reg [1:0] commit_groups=0,output reg [3:0] commit_scale=4,
 input wire aux_text_we,input wire [7:0] aux_text_addr,aux_text_data,
 input wire aux_object_we,input wire [1:0] aux_object_addr,input wire [55:0] aux_object_data,
 input wire aux_commit,input wire [15:0] aux_epoch,input wire aux_visible
);
(* ramstyle="M10K" *) reg [7:0] auxiliary_text[0:255];
reg [55:0] auxiliary_objects[0:3];
reg [15:0] auxiliary_epoch=0;
reg auxiliary_visible=0,auxiliary_editing=0;
reg [15:0] auxiliary_revision=0,revision=0;
reg [7:0] aux_read;
reg [90:0] snapshot=0;
reg [11:0] w=0,h=0;
reg [3:0] scale=4;
reg [7:0] state=0,resume_state=0;
reg [2:0] field=0;
reg [5:0] ch=0;
reg [6:0] hours=0,minutes=0,seconds=0;
reg [11:0] tx=0,ty=0,tw=0,th=0,track_x0=0,track_x1=0,fill_x0=0,fill_x1=0;
reg [11:0] track_y0=0,track_y1=0,fill_y0=0,fill_y1=0;
reg [11:0] fraction=0;
reg [47:0] product=0,multiplicand=0;
reg [11:0] multiplier=0;
reg [3:0] multiply_count=0;
reg div_start=0;
reg [47:0] numerator=0;
reg [34:0] denominator=1;
wire div_busy,div_done;
wire [47:0] quotient;
wire [34:0] remainder;
media_ui_divider divider(.clk(clk),.start(div_start),.numerator(numerator),.denominator(denominator),
 .busy(div_busy),.done(div_done),.quotient(quotient),.remainder(remainder));
task divide;
 input [47:0] n;input [34:0] d;input [7:0] next_state;
 begin numerator<=n;denominator<=d;div_start<=1;resume_state<=next_state;state<=250;end
endtask
wire known=snapshot[70];
wire [34:0] duration=snapshot[69:35],position=snapshot[34:0];
wire [34:0] remaining=position<duration?duration-position:35'd0;
wire [5:0] length=field==0?17:field==1?15:field==2?19:snapshot[71]?7:snapshot[72]?6:0;
wire [5:0] label_length=field==0?9:field==1?7:11;
function [7:0] label_glyph;
 input [2:0] f;input [5:0] index;
 reg [87:0] label;
 begin
  case(f)
   0:label={"Elapsed: ",16'd0};1:label={"Total: ",32'd0};
   2:label="Remaining: ";default:label={"Seeking",32'd0};
  endcase
  label_glyph=label[87-index*8 -:8];
 end
endfunction
function [7:0] time_glyph;
 input [5:0] index;
 begin
  if(index==2 || index==5) time_glyph=":";
  else if(field!=0 && !known) time_glyph="-";
  else case(index)
   0:time_glyph=48+hours/10;1:time_glyph=48+hours%10;
   3:time_glyph=48+minutes/10;4:time_glyph=48+minutes%10;
   6:time_glyph=48+seconds/10;default:time_glyph=48+seconds%10;
  endcase
 end
endfunction
integer ai;
initial for(ai=0;ai<4;ai=ai+1) auxiliary_objects[ai]=0;
always @(posedge clk) begin
 if(aux_text_we || aux_object_we) auxiliary_editing<=1;
 if(aux_commit) auxiliary_editing<=0;
 if(aux_text_we) auxiliary_text[aux_text_addr]<=aux_text_data;
 if(aux_object_we) auxiliary_objects[aux_object_addr]<=aux_object_data;
 if(aux_commit) begin auxiliary_epoch<=aux_epoch;auxiliary_visible<=aux_visible;end
 // A provider change during assembly cancels publication; the next complete
 // scene copies its retained content. Producers finish writes before commit.
 if(aux_text_we || aux_object_we || aux_commit) auxiliary_revision<=auxiliary_revision+1'b1;
 aux_read<=auxiliary_text[{field[1:0],ch}];
 text_we<=0;object_we<=0;commit<=0;div_start<=0;
 case(state)
  0:if(!pending && !auxiliary_editing && width!=0 && height!=0) begin
   snapshot<=state_in;w<=width;h<=height;revision<=auxiliary_revision;
   scale<=height>=1000?9:height>=700?6:4;field<=0;state<=1;
  end
  1:begin
   if(field==0) divide({13'd0,position},35'd360000,2);
   else if(field==1) divide({13'd0,duration}+48'd359999,35'd360000,2);
   else if(field==2) divide({13'd0,remaining}+48'd359999,35'd360000,2);
   else begin ch<=0;state<=5;end
  end
  2:divide(quotient>359999?48'd359999:quotient,35'd3600,3);
  3:begin hours<=quotient[6:0];divide({13'd0,remainder},35'd60,4);end
  4:begin minutes<=quotient[6:0];seconds<=remainder[6:0];ch<=0;state<=5;end
  5:begin
   text_we<=1;text_addr<={field,ch};
   if(ch>=length) text_data<=0;
   else if(field==3) begin
    if(snapshot[71]) text_data<=label_glyph(3,ch);
    else case(ch) 0:text_data<="P";1:text_data<="a";2:text_data<="u";3:text_data<="s";4:text_data<="e";default:text_data<="d";endcase
   end else if(ch<label_length) text_data<=label_glyph(field,ch);
   else text_data<=time_glyph(ch-label_length);
   if(ch==63) state<=6;else ch<=ch+1'b1;
  end
  6:divide(w*(field==0?48'd141:field==1?48'd360:field==2?48'd579:48'd360),35'd720,7);
  7:begin
   tw<=(length*6*scale+3)/4;th<=(7*scale+3)/4;
   tx<=quotient[11:0]-(length*6*scale)/8;
   divide(h*(field==3?48'd403:48'd422),35'd480,8);
  end
  8:begin ty<=quotient[11:0];state<=9;end
  9:begin
   object_we<=1;object_addr<={1'b0,field};
   object_data<={length!=0,1'b0,2'd3,4'd0,(tx+tw),(ty+th),ty,tx};
   if(field==3) begin field<=4;ch<=0;state<=10;end
   else begin field<=field+1'b1;state<=1;end
  end
  10:state<=11; // synchronous retained-provider character read
  11:begin
   text_we<=1;text_addr<={field,ch};text_data<=aux_read;
   if(ch==63) state<=12;else begin ch<=ch+1'b1;state<=10;end
  end
  12:begin
   object_we<=1;object_addr<={1'b0,field};object_data<=auxiliary_objects[field[1:0]];
   if(field==7) state<=20;else begin field<=field+1'b1;ch<=0;state<=10;end
  end
  20:divide(w*48'd32,35'd720,21);
  21:begin track_x0<=quotient[11:0];divide(w*48'd688,35'd720,22);end
  22:begin track_x1<=quotient[11:0];divide(w*48'd34,35'd720,23);end
  23:begin fill_x0<=quotient[11:0];divide(w*48'd686,35'd720,24);end
  24:begin fill_x1<=quotient[11:0];divide(h*48'd438,35'd480,25);end
  25:begin track_y0<=quotient[11:0];divide(h*48'd452,35'd480,26);end
  26:begin track_y1<=quotient[11:0];divide(h*48'd441,35'd480,27);end
  27:begin fill_y0<=quotient[11:0];divide(h*48'd449,35'd480,28);end
  28:begin
   fill_y1<=quotient[11:0];
   if(known && duration!=0) begin
    product<=0;multiplicand<={13'd0,(position<duration?position:duration)};
    multiplier<=fill_x1-fill_x0;multiply_count<=12;state<=36;
   end
   else begin fraction<=fill_x1-fill_x0;state<=30;end
  end
  36:begin
   if(multiplier[0]) product<=product+multiplicand;
   multiplicand<=multiplicand<<1;multiplier<=multiplier>>1;
   multiply_count<=multiply_count-1'b1;
   if(multiply_count==1) state<=37;
  end
  37:divide(product,duration,29);
  29:begin fraction<=quotient[11:0];state<=30;end
  30:begin object_we<=1;object_addr<=8;
   object_data<={1'b1,1'b0,2'd2,4'd0,track_y1,track_x1,track_y0,track_x0};state<=31;end
  31:begin object_we<=1;object_addr<=9;
   object_data<={1'b1,1'b0,(known?2'd3:2'd2),!known,3'd0,fill_y1,(fill_x0+fraction),fill_y0,fill_x0};state<=32;end
  32:begin object_we<=1;object_addr<=10;object_data<=0;state<=33;end
  33:begin object_we<=1;object_addr<=11;object_data<=0;state<=34;end
  34:begin
   if(snapshot[90:75]==state_in[90:75] && revision==auxiliary_revision) begin
    commit<=1;commit_epoch<=snapshot[90:75];commit_scale<=scale;
    commit_groups<={auxiliary_visible && auxiliary_epoch==snapshot[90:75],snapshot[73]};state<=35;
   end else state<=0;
  end
  35:if(acknowledged) state<=0;
  250:if(div_done) state<=resume_state;
  default:state<=0;
 endcase
end
endmodule
