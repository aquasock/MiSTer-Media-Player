module test_mp2_decoder;
reg clk=0; always #5 clk=~clk;
reg reset=1,iv=0,ie=0,ready=0, ipt=0;
reg [7:0] data; wire ir,pv,error,idle; wire signed [15:0] l,r;
wire [32:0] pts; wire pts_valid; wire [31:0] frames;
reg [32:0] pts_origin=90000;
integer seek_frame=0,start_sync=0;
wire [32:0] seek_target=pts_origin+seek_frame*2160;
mp2_decoder #(.ENABLE_SEEK_SKIP(1),.ENABLE_START_SYNC(1)) dut(.clk(clk),.reset(reset),.input_data(data),.input_valid(iv),.input_ready(ir),.input_end(ie),
.input_pts(pts_origin),.input_pts_valid(ipt),.pcm_valid(pv),.pcm_ready(ready),.pcm_left(l),.pcm_right(r),
.pcm_pts(pts),.pcm_pts_valid(pts_valid),.error(error),.frames_decoded(frames),.idle(idle),.seek(seek_frame!=0),.seek_target(seek_target),.resync_start(start_sync!=0));
integer fd,ofd,index=0,size,n=0,cycles=0,rc,session,expect_error=0;
reg hold_input=0,held_pcm=0;reg [31:0] held_sample;
reg [7:0] bytes [0:1048575]; reg [1023:0] path; reg [31:0] rng=32'habcde123;
always @(posedge clk) begin
 cycles<=cycles+1;
 if(cycles>60000000) $fatal(1,"timeout state %d",dut.state);
 if(!reset&&error) begin
  if(expect_error) begin $display("EXPECTED MP2 ERROR PASS");$finish;end
  else $fatal(1,"decoder error state %d pos %d",dut.state,dut.bit_pos);
 end
 if(!reset&&held_pcm&&(!pv||{l,r}!==held_sample)) $fatal(1,"stalled PCM changed");
 held_pcm<=!reset&&pv&&!ready;held_sample<={l,r};
 if(pv&&ready) begin
  $fwrite(ofd,"%d %d\n",l,r);
  if(n%1152==0 && (!pts_valid||pts!=((pts_origin+frames*33'd2160)&33'h1ffffffff))) $fatal(1,"PTS mismatch");
  n<=n+1;
 end
end
initial begin
 if(!$value$plusargs("input=%s",path)) $fatal;
 fd=$fopen(path,"rb"); size=$fread(bytes,fd); $fclose(fd);
 if(!$value$plusargs("output=%s",path)) path="/tmp/mp2-decoder-rtl.txt";
 ofd=$fopen(path,"w");
 rc=$value$plusargs("expect_error=%d",expect_error);
 rc=$value$plusargs("seek_frame=%d",seek_frame);
 rc=$value$plusargs("start_sync=%d",start_sync);
 rc=$value$plusargs("pts_origin=%h",pts_origin);
 for(session=0;session<2;session=session+1) begin
 reset=1;iv=0;ie=0;hold_input=0;index=0;n=0;cycles=0;
 repeat(5) @(negedge clk); reset=0;
 while(index<size) begin
  @(negedge clk); rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
  if(!hold_input) begin iv=rng[5]||rng[6];ipt=index==0;data=bytes[index];end
  ready=rng[0]||rng[1];
  @(posedge clk);hold_input=iv&&!ir;if(iv&&ir) index=index+1;
 end
 @(negedge clk); iv=0; ie=1; ready=1;
 wait(idle);
 @(negedge clk); $display("decoded frames %0d samples %0d cycles %0d",frames,n,cycles); if(expect_error) $fatal(1,"malformed input accepted");
 end
 $fclose(ofd); $finish;
end
endmodule
