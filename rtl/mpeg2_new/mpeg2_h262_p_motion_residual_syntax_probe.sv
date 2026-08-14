//============================================================================
// MiSTer Media Player - controlled H.262 P motion+residual raster observer
//
// Phase 1U-o recognizes one exact 128x96 progressive 4:2:0 P-picture shape:
// row 1 begins with an MC+Coded macroblock using forward (+32,0), CBP=63 and
// six +7/EOB non-intra blocks; column 1 is skipped; rows 2..6 retain the
// accepted per-row motion-dispatch syntax.  This remains a diagnostic observer,
// not a general P parser.
//============================================================================
module mpeg2_h262_p_motion_residual_syntax_probe
(
 input wire clk,input wire reset,input wire [7:0] stream_data,input wire stream_valid,
 output reg mixed_candidate,output reg mixed_seen,output wire mixed_complete_now,
 output reg first_slice_complete,output wire [47:0] shift_right_map,output wire probe_error
);
localparam [7:0] PICTURE_START_CODE=8'h00,SEQUENCE_HEADER_CODE=8'hB3,EXTENSION_START_CODE=8'hB5;
localparam [47:0] MIXED_MAP=48'h201008040201;
assign shift_right_map=MIXED_MAP; assign probe_error=1'b0;
reg [31:0] win; wire [31:0] wn={win[23:0],stream_data};
wire sc=(wn[31:8]==24'h000001); wire [7:0] code=wn[7:0];
wire slice=sc&&(code>=8'h01)&&(code<=8'hAF); wire boundary=sc&&((code==PICTURE_START_CODE)||(code==SEQUENCE_HEADER_CODE));
reg seqcap;reg [1:0] seqcnt;reg [23:0] seqsh;wire [23:0] seqn={seqsh[15:0],stream_data};reg geom;
reg pcap;reg pcnt;reg [15:0] psh;wire [15:0] pn={psh[7:0],stream_data};reg curp;
reg ecap;reg [2:0] ecnt;reg [39:0] esh;wire [39:0] en={esh[31:0],stream_data};reg controls;
reg capture;reg [3:0] row;reg [4:0] count;
function automatic [4:0] payload_len;input [3:0] r;begin payload_len=(r==1)?5'd18:5'd8;end endfunction
function automatic [7:0] expb;input [3:0] r;input [4:0] n;begin
 case(r)
 1:case(n)0:expb=8'h13;1:expb=8'h05;2:expb=8'hb9;3:expb=8'h80;4:expb=8'h52;5:expb=8'h02;6:expb=8'h90;7:expb=8'h14;8:expb=8'h80;9:expb=8'ha4;10:expb=8'h05;11:expb=8'h20;12:expb=8'h29;13:expb=8'h33;14:expb=8'hcf;15:expb=8'h3c;16:expb=8'hf3;17:expb=8'hce;default:expb=0;endcase
 2:case(n)0:expb=8'h12;1:expb=8'h79;2:expb=8'h05;3:expb=8'hbb;4:expb=8'h3c;5:expb=8'hf3;6:expb=8'hcf;7:expb=8'h38;default:expb=0;endcase
 3:case(n)0:expb=8'h12;1:expb=8'h79;2:expb=8'he4;3:expb=8'h16;4:expb=8'hec;5:expb=8'hf3;6:expb=8'hcf;7:expb=8'h38;default:expb=0;endcase
 4:case(n)0:expb=8'h12;1:expb=8'h79;2:expb=8'he7;3:expb=8'h90;4:expb=8'h5b;5:expb=8'hb3;6:expb=8'hcf;7:expb=8'h38;default:expb=0;endcase
 5:case(n)0:expb=8'h12;1:expb=8'h79;2:expb=8'he7;3:expb=8'h9e;4:expb=8'h41;5:expb=8'h6e;6:expb=8'hcf;7:expb=8'h38;default:expb=0;endcase
 6:case(n)0:expb=8'h12;1:expb=8'h79;2:expb=8'he7;3:expb=8'h9e;4:expb=8'h79;5:expb=8'h05;6:expb=8'hbb;7:expb=8'h38;default:expb=0;endcase
 default:expb=0;endcase end endfunction
wire count_ok=(count==(payload_len(row)+5'd3));
assign mixed_complete_now=stream_valid&&capture&&sc&&boundary&&(row==4'd6)&&count_ok&&mixed_candidate;
always @(posedge clk) begin
 if(reset)begin win<=0;seqcap<=0;seqcnt<=0;seqsh<=0;geom<=0;pcap<=0;pcnt<=0;psh<=0;curp<=0;ecap<=0;ecnt<=0;esh<=0;controls<=0;mixed_candidate<=0;mixed_seen<=0;first_slice_complete<=0;capture<=0;row<=0;count<=0;end
 else begin
  first_slice_complete<=0;
  if(stream_valid)begin
   win<=wn;
   if(seqcap)begin seqsh<=seqn;if(seqcnt==2)begin seqcap<=0;seqcnt<=0;geom<=(seqn[23:12]==12'd128)&&(seqn[11:0]==12'd96);end else seqcnt<=seqcnt+1'b1;end
   else if(sc&&code==SEQUENCE_HEADER_CODE)begin seqcap<=1;seqcnt<=0;seqsh<=0;end
   if(pcap)begin psh<=pn;if(pcnt)begin pcap<=0;pcnt<=0;curp<=(pn[5:3]==3'd2);mixed_candidate<=0;controls<=0;end else pcnt<=1;end
   else if(sc&&code==PICTURE_START_CODE)begin pcap<=1;pcnt<=0;psh<=0;end
   if(ecap)begin esh<=en;if(ecnt==4)begin ecap<=0;ecnt<=0;controls<=geom&&curp&&(en[39:36]==4'h8)&&(en[35:32]==4'd3)&&(en[31:28]==4'd3)&&(en[17:16]==2'b11)&&en[14]&&!en[13]&&!en[12]&&!en[10];end else ecnt<=ecnt+1'b1;end
   else if(curp&&sc&&code==EXTENSION_START_CODE)begin ecap<=1;ecnt<=0;esh<=0;end
   if(capture)begin
    if(sc)begin
     if(!count_ok)begin capture<=0;mixed_candidate<=0;end
     else if(row<6)begin
      if(code==({4'd0,row}+8'd1))begin if(row==1)first_slice_complete<=1;row<=row+1'b1;count<=0;end
      else begin capture<=0;mixed_candidate<=0;end
     end else begin capture<=0;if(boundary)begin mixed_seen<=1;end else mixed_candidate<=0;end
    end else begin
     if(count<payload_len(row) && stream_data!=expb(row,count))begin capture<=0;mixed_candidate<=0;end
     else if(count!=5'h1f)count<=count+1'b1;
    end
   end else if(controls&&slice&&code==8'h01&&!mixed_seen)begin mixed_candidate<=1;capture<=1;row<=1;count<=0;end
  end
 end
end
endmodule
