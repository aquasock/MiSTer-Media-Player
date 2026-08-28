`timescale 1ns/1ps
module tb_h262_quant_matrix_iq;
localparam CASES=384;
reg clk=0,reset=1,stream_valid=0;
reg [7:0] stream_data=0;
reg start=0,we=0,finish=0;
reg [5:0] widx=0;
reg signed [12:0] wvalue=0;
reg [11:0] control;
wire intra=control[7],qt=control[6],alt=control[5];
wire [1:0] dc=control[9:8];
wire [4:0] qs=control[4:0];
reg [11:0] controls[0:CASES-1],expected[0:CASES*64-1];
reg [12:0] levels[0:CASES*64-1];
reg [7:0] headers[0:419];
string directory;
integer c,j,mode,prior_mode=-1,pi=0,ii=0,pchecks=0,ichecks=0;
wire pdone,perror,icomplete,ierror,iunsupported,ivalid;
wire [5:0] iindex;
wire signed [11:0] ivalue;
always #5 clk=~clk;
mpeg2_h262_p_non_intra_transform p (
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),
 .qfs_block_index(2'd1),.qfs_block_start(start),.qfs_write_en(we),
 .qfs_write_index(widx),.qfs_write_value(wvalue),.qfs_block_end(finish),
 .quantiser_scale_code(qs),.q_scale_type(qt),.alternate_scan(alt),
 .intra_block(intra),.intra_dc_precision(dc),.block_done(pdone),
 .first_sample_valid(),.first_sample_value(),.residual_sample_valid(),
 .residual_sample_block_index(),.residual_sample_index(),.residual_sample_value(),.probe_error(perror));
mpeg2_h262_inverse_quant i (
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),
 .block_start(start&&intra),.coeff_write_en(we&&intra),
 .coeff_write_index(widx),.coeff_write_value(wvalue),.block_end(finish&&intra),
 .intra_quant_matrix_default(mode==0),.intra_dc_precision(dc),
 .quantiser_scale_code(qs),.q_scale_type(qt),.alternate_scan(alt),
 .block_complete(icomplete),.iq_error(ierror),.unsupported_matrix(iunsupported),
 .first_luma_f00(),.first_luma_f77(),.coeff_out_block_start(),
 .coeff_out_valid(ivalid),.coeff_out_index(iindex),.coeff_out_value(ivalue),.coeff_out_block_end());
always @(posedge clk) if(!reset) begin
 if(perror||ierror||iunsupported)$fatal(1,"IQ error case=%0d p=%b i=%b unsupported=%b",c,perror,ierror,iunsupported);
 if(p.idct_coeff_valid) begin
  if(p.idct_coeff_index!=pi || p.idct_coeff_value!==expected[c*64+pi])
   $fatal(1,"P/B IQ mismatch case=%0d index=%0d actual=%0d expected=%0d",c,pi,p.idct_coeff_value,$signed(expected[c*64+pi]));
  pi=pi+1;pchecks=pchecks+1;
 end
 if(ivalid) begin
  if(!intra||iindex!=ii||ivalue!==expected[c*64+ii])
   $fatal(1,"I IQ mismatch case=%0d index=%0d actual=%0d expected=%0d",c,ii,ivalue,$signed(expected[c*64+ii]));
  ii=ii+1;ichecks=ichecks+1;
 end
end
initial begin
 if(!$value$plusargs("DIR=%s",directory))$fatal(1,"missing DIR");
 $readmemh({directory,"/controls.hex"},controls);
 $readmemh({directory,"/levels.hex"},levels);
 $readmemh({directory,"/expected.hex"},expected);
 $readmemh({directory,"/headers.hex"},headers);
 repeat(4)@(negedge clk);reset=0;
 for(c=0;c<CASES;c=c+1)begin
  control=controls[c];mode=control[11:10];pi=0;ii=0;
  if(mode!=prior_mode)begin
   for(j=0;j<(mode==0?12:140);j=j+1)begin
    @(negedge clk);stream_data=headers[mode*140+j];stream_valid=1;
   end
   @(negedge clk);stream_valid=0;repeat(3)@(negedge clk);prior_mode=mode;
  end
  @(negedge clk);start=1;
  @(negedge clk);start=0;
  for(j=0;j<64;j=j+1)begin
   we=1;widx=j;wvalue=levels[c*64+j];@(negedge clk);
  end
  we=0;finish=1;@(negedge clk);finish=0;
  wait(pdone);repeat(4)@(negedge clk);
  if(pi!=64||(intra && ii!=64))$fatal(1,"missing coefficients case=%0d p=%0d i=%0d",c,pi,ii);
 end
 $display("MATRIX_IQ_PASS cases=%0d P_B_coefficients=%0d I_coefficients=%0d",CASES,pchecks,ichecks);
 $finish;
end
initial begin #100000000;$fatal(1,"IQ timeout");end
endmodule
