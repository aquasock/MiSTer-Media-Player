// Read-only, post-volume stereo scope. Four output samples are averaged per
// history point (23.2 ms across 256 points at 44.1 kHz). No audio backpressure.
module media_waveform_visualizer(
 input wire audio_clk,video_clk,audio_active,sample_tick,
 input wire signed [15:0] sample_left,sample_right,
 input wire [23:0] rgb,input wire hs,vs,de,
 output reg [23:0] rgb_out=0,output reg hs_out=0,vs_out=0,de_out=0
);
 reg was_active=0,epoch=0;
 reg [1:0] phase=0;
 reg [7:0] sequence_id=0,envelope=0;
 reg signed [17:0] sum_l=0,sum_r=0;
 reg [15:0] pair=0;
 wire signed [17:0] total_l=sum_l+{{2{sample_left[15]}},sample_left};
 wire signed [17:0] total_r=sum_r+{{2{sample_right[15]}},sample_right};
 wire [15:0] abs_l=sample_left[15] ? -sample_left : sample_left;
 wire [15:0] abs_r=sample_right[15] ? -sample_right : sample_right;
 wire [7:0] peak=(abs_l>abs_r) ? abs_l[15:8] : abs_r[15:8];
 reg [3:0] decay=0;
 always @(posedge audio_clk) begin
  was_active<=audio_active;
  if(!audio_active)begin
   if(was_active)epoch<=~epoch;
   phase<=0;sum_l<=0;sum_r<=0;pair<=0;sequence_id<=0;envelope<=0;decay<=0;
  end else if(sample_tick)begin
   decay<=decay+1'b1;
   if(peak>envelope)envelope<=peak;
   else if(decay==0&&envelope!=0)envelope<=envelope-1'b1;
   phase<=phase+1'b1;
   if(phase==3)begin
    pair<={total_l[17:10],total_r[17:10]};sequence_id<=sequence_id+1'b1;
    sum_l<=0;sum_r<=0;
   end else begin sum_l<=total_l;sum_r<=total_r;end
  end
 end
 wire [33:0] snapshot;
 video_config_cdc #(.WIDTH(34)) visualizer_config(.src_clk(audio_clk),.dst_clk(video_clk),
  .src_data({epoch,audio_active,sequence_id,pair,envelope}),.dst_data(snapshot));
 wire active=snapshot[32];
 reg seen_epoch=0;reg [7:0] seen_sequence=0,head=0;
 reg [8:0] count=0;
 (* ramstyle="M10K" *) reg [31:0] history[0:255];
 reg [15:0] previous_pair=0;
 (* ramstyle="M10K" *) reg [31:0] frame_history[0:255];
 reg [31:0] history_q=0,copy_q=0;
 reg copying=0;
 reg [8:0] copy_index=0,frame_count=0;
 reg [7:0] copy_head=0;
 reg [11:0] x=0,y=0,width=0,height=0;
 reg de_d=0,vs_d=0;
 // Compute a fractional history step once per resolution change. This
 // small serial divider never sits in the per-pixel arithmetic path.
 reg [11:0] divided_width=0;
 reg [15:0] quotient=0,position_x=0;
 reg [12:0] remainder=0;
 reg [4:0] divide_count=0;
 reg [7:0] step_x=1;
 wire [13:0] trial={remainder,quotient[15]};
 always @(posedge video_clk)begin
  if(width>=256 && width!=divided_width)begin
   divided_width<=width;quotient<=16'hffff;remainder<=0;divide_count<=16;
  end else if(divide_count!=0)begin
   if(trial>={2'b0,divided_width})begin
    remainder<=13'(trial-{2'b0,divided_width});quotient<={quotient[14:0],1'b1};
   end else begin remainder<=trial[12:0];quotient<={quotient[14:0],1'b0};end
   divide_count<=divide_count-1'b1;
   if(divide_count==1)step_x<={quotient[6:0],trial>={2'b0,divided_width}};
  end
  if(de)position_x<=position_x+{8'b0,step_x};else position_x<=0;
 end
 wire [7:0] column=position_x[15:8];
 wire [7:0] copy_address=copy_head+8'd1+copy_index[7:0];
 wire valid_history=frame_count==256 || {1'b0,column} >= 9'd256-frame_count;
 always @(posedge video_clk)begin
  if(!active || seen_epoch!=snapshot[33])begin
   count<=0;frame_count<=0;copying<=0;head<=0;previous_pair<=0;seen_sequence<=snapshot[31:24];seen_epoch<=snapshot[33];
  end else if(!copying&&!(vs&&!vs_d)&&seen_sequence!=snapshot[31:24])begin
   history[head+8'd1]<={previous_pair,snapshot[23:8]};previous_pair<=snapshot[23:8];head<=head+1'b1;
   seen_sequence<=snapshot[31:24];if(count<256)count<=count+1'b1;
  end
  // Copy during vertical blank. Briefly hold history writes (never audio)
  // so no point can be overwritten while the display snapshot is constructed.
  if(active&&seen_epoch==snapshot[33])begin
   if(vs&&!vs_d)begin copying<=1;copy_index<=0;copy_head<=head;frame_count<=count;end
   else if(copying)begin
    if(copy_index!=0)frame_history[copy_index[7:0]-8'd1]<=copy_q;
    if(copy_index==256)copying<=0;else copy_index<=copy_index+1'b1;
   end
  end
  copy_q<=history[copy_address];
  history_q<=frame_history[column];
  de_d<=de;vs_d<=vs;
  if(de)begin
   x<=x+1'b1;
  end else x<=0;
  if(de_d&&!de)begin width<=x;y<=y+1'b1;end
  if(vs&&!vs_d)begin height<=y;y<=0;end
 end
 // Seven stages, including synchronous history read. The same delay is applied
 // to bypass pixels and all syncs; geometry uses the measured HDMI raster.
 reg [23:0] pixels[0:5];
 reg [5:0] hpipe=0,vpipe=0,dpipe=0,enable_pipe=0;
 reg [11:0] ypos[0:4];
 reg [7:0] fraction_q=0;
 reg signed [7:0] previous_l=0,previous_r=0,interpolated_l=0,interpolated_r=0;
 reg signed [17:0] blend_l=0,blend_r=0;
 wire signed [8:0] difference_l=$signed({history_q[15],history_q[15:8]})-$signed({history_q[31],history_q[31:24]});
 wire signed [8:0] difference_r=$signed({history_q[7],history_q[7:0]})-$signed({history_q[23],history_q[23:16]});
 reg signed [20:0] product_l=0,product_r=0;
 reg signed [13:0] curve_l=0,curve_r=0;
 reg [13:0] distance_l=0,distance_r=0;
 wire signed [12:0] amplitude=$signed({1'b0,height>>3});
 wire signed [13:0] center_l=$signed({2'b0,(height>>2)+(height>>3)});
 wire signed [13:0] center_r=$signed({2'b0,(height>>1)+(height>>3)});
 wire signed [13:0] delta_l=$signed({2'b0,ypos[4]})-curve_l;
 wire signed [13:0] delta_r=$signed({2'b0,ypos[4]})-curve_r;
 wire [13:0] thickness=height>=900 ? 14'd3 : height>=600 ? 14'd2 : 14'd1;
 integer i;
 always @(posedge video_clk)begin
  pixels[0]<=rgb;ypos[0]<=y;
  for(i=1;i<6;i=i+1)pixels[i]<=pixels[i-1];
  for(i=1;i<5;i=i+1)ypos[i]<=ypos[i-1];
  hpipe<={hpipe[4:0],hs};vpipe<={vpipe[4:0],vs};dpipe<={dpipe[4:0],de};
  enable_pipe<={enable_pipe[4:0],active&&!copying&&valid_history&&width>=256&&height>=240};
  fraction_q<=position_x[7:0];
  previous_l<=$signed(history_q[31:24]);previous_r<=$signed(history_q[23:16]);
  blend_l<=difference_l*$signed({1'b0,fraction_q});blend_r<=difference_r*$signed({1'b0,fraction_q});
  interpolated_l<=previous_l+8'(blend_l>>>8);interpolated_r<=previous_r+8'(blend_r>>>8);
  product_l<=interpolated_l*amplitude;product_r<=interpolated_r*amplitude;
  curve_l<=center_l-14'(product_l>>>7);curve_r<=center_r+14'(product_r>>>7);
  distance_l<=delta_l[13] ? -delta_l : delta_l;
  distance_r<=delta_r[13] ? -delta_r : delta_r;
  hs_out<=hpipe[5];vs_out<=vpipe[5];de_out<=dpipe[5];
  rgb_out<=pixels[5];
  if(enable_pipe[5]&&dpipe[5])begin
   rgb_out<=24'h030810;
   if(distance_l<=thickness*4)rgb_out<=24'h083340;
   if(distance_r<=thickness*4)rgb_out<=24'h402010;
   if(distance_l<=thickness*2)rgb_out<=24'h127a90;
   if(distance_r<=thickness*2)rgb_out<=24'h904020;
   if(distance_l<=thickness)rgb_out<={8'h60,8'h7f+snapshot[7:0],8'hff};
   if(distance_r<=thickness)rgb_out<={8'hff,8'h60+snapshot[7:0],8'h50};
  end
 end
endmodule
