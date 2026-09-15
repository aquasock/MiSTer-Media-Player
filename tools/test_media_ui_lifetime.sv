`timescale 1ns/1ps
module test_media_ui_lifetime;
reg clk=0;always #5 clk=~clk;
reg [1:0] phase=0;always @(posedge clk) phase<=phase+1'b1;
wire ce=phase==0;
reg [90:0] state_in={16'd1,1'b1,1'b1,1'b0,1'b0,1'b1,35'd36000000,35'd3600000};
wire tw,ow,commit,pending,ack;
wire [8:0] ta;wire [7:0] td;wire [3:0] oa,scale;
wire [55:0] od;wire [15:0] epoch;wire [1:0] groups;
reg atw=0,aow=0,ac=0,av=0;reg [7:0] ata=0,atd=0;reg [1:0] aoa=0;reg [55:0] aod=0;
reg [15:0] ae=1;
reg vs=0;
media_ui_scene scene(.clk(clk),.ce(ce),.state_in(state_in),.width(12'd720),.height(12'd480),
 .pending(pending),.acknowledged(ack),.text_we(tw),.text_addr(ta),.text_data(td),
 .object_we(ow),.object_addr(oa),.object_data(od),.commit(commit),.commit_epoch(epoch),.commit_groups(groups),.commit_scale(scale),
 .aux_text_we(atw),.aux_text_addr(ata),.aux_text_data(atd),.aux_object_we(aow),.aux_object_addr(aoa),.aux_object_data(aod),
 .aux_commit(ac),.aux_epoch(ae),.aux_auto_layout(1'b0),.aux_length0(7'd0),.aux_length1(7'd0),.aux_visible(av));
media_overlay_compositor renderer(.layout_de(1'b0),.clk(clk),.rgb(24'h203040),.hs(1'b0),.vs(vs),.de(1'b0),.current_epoch(state_in[90:75]),
 .text_we(tw),.text_addr(ta),.text_data(td),.object_we(ow),.object_addr(oa),.object_data(od),
 .commit(commit),.commit_epoch(epoch),.commit_groups(groups),.commit_scale(scale),
 .pending(pending),.acknowledged(ack),.width(),.height(),.rgb_out(),.hs_out(),.vs_out(),.de_out());
reg [7:0] previous_state;reg [8:0] previous_addr;reg enabled;
always @(posedge clk) begin
 enabled=ce;previous_state=scene.state;previous_addr=ta;
 #1;if(!enabled && (scene.state!==previous_state || ta!==previous_addr)) $fatal(1,"scene advanced off enable");
end
task publish;
 reg page;
 begin
  wait(pending);page=renderer.page;
  repeat(29) @(negedge clk);
  if(renderer.page!=page || ack) $fatal(1,"publication before frame");
  vs=1;@(negedge clk);vs=0;
  wait(ack);@(negedge clk);
  repeat(2) @(negedge clk);
 end
endtask
task check_aux;
 begin
  if(!renderer.active[4][55] || !renderer.groups[1] || renderer.text_mem[{renderer.page,3'd4,6'd0}]!="A")
   $fatal(1,"provider content lost on HUD update");
 end
endtask
initial begin
 // Write a synthetic future provider, with a deliberate gap before commit.
 @(negedge clk);atw=1;atd="A";ata=0;
 @(negedge clk);atw=0;aow=1;aod={1'b1,1'b1,2'd3,4'd0,12'd106,12'd307,12'd300,12'd100};
 @(negedge clk);aow=0;
 repeat(4000) @(negedge clk);
 if(commit || pending) $fatal(1,"partial provider published");
 av=1;ac=1;@(negedge clk);ac=0;
 publish;check_aux;
 state_in[73]=0;state_in[34:0]=7200000;
 publish;publish;check_aux;
 if(renderer.groups[0]) $fatal(1,"HUD did not hide independently");
 // Cancel a completed but unpublished old-epoch scene at the frame boundary.
 wait(pending);state_in[90:75]=2;
 publish;
 if(renderer.active_epoch==2) $fatal(1,"stale scene adopted new epoch");
 publish;
 if(renderer.active_epoch!=2 || renderer.groups[1]) $fatal(1,"old cue epoch survived seek/file change");
 $display("UI_LIFETIME_PASS atomic publication, retained provider, independent groups, stale epoch rejection");$finish;
end
initial begin #5000000;$fatal(1,"timeout state=%0d",scene.state);end
endmodule
