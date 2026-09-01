`timescale 1ns/1ps

module test_mpeg2_audio_ui;
reg clk=0,reset=1;
always #5 clk=~clk;

reg [7:0] record_data;
reg record_start,record_last,record_valid;
wire record_ready;
wire [7:0] dvd_data,ui_data;
wire dvd_start,dvd_last,dvd_valid,ui_start,ui_last,ui_valid;
reg dvd_ready=1;
wire ui_ready;
wire router_error;

wire [7:0] writer_burstcnt;
wire [28:0] writer_addr;
wire writer_rd;
wire [63:0] writer_din;
wire [7:0] writer_be;
wire writer_we;
reg writer_busy=0;
reg publish_window=0;
wire ui_error,mode_active,loading_active,display_bank,picture_publish;
wire [15:0] committed_frames;

integer writes=0,dvd_records=0,payload_index=0,record_offset,count;
integer lane_index;
integer failures=0;
reg [63:0] expected_word;

mpeg2_h262_display_record_router router(
 .clk(clk),.reset(reset),.record_data(record_data),
 .record_start(record_start),.record_last(record_last),
 .record_valid(record_valid),.record_ready(record_ready),
 .dvd_data(dvd_data),.dvd_start(dvd_start),.dvd_last(dvd_last),
 .dvd_valid(dvd_valid),.dvd_ready(dvd_ready),
 .ui_data(ui_data),.ui_start(ui_start),.ui_last(ui_last),
 .ui_valid(ui_valid),.ui_ready(ui_ready),.protocol_error(router_error));

mpeg2_h262_audio_ui ui(
 .clk(clk),.reset(reset),.record_data(ui_data),.record_start(ui_start),
 .record_last(ui_last),.record_valid(ui_valid),.record_ready(ui_ready),
 .protocol_error(ui_error),.writer_burstcnt(writer_burstcnt),
 .writer_addr(writer_addr),.writer_rd(writer_rd),.writer_din(writer_din),
 .writer_be(writer_be),.writer_we(writer_we),.writer_busy(writer_busy),
 .publish_window(publish_window),.mode_active(mode_active),
 .loading_active(loading_active),.display_bank(display_bank),
 .picture_publish(picture_publish),.committed_frames(committed_frames));

task send_byte;
 input [7:0] data;
 input start_flag,last_flag;
 begin
  @(negedge clk);record_data=data;record_start=start_flag;
  record_last=last_flag;record_valid=1;
  while(!record_ready)@(negedge clk);
  @(negedge clk);record_valid=0;record_start=0;record_last=0;
 end
endtask

always @(posedge clk) begin
 if(dvd_valid&&dvd_ready&&dvd_start&&dvd_last)dvd_records<=dvd_records+1;
 if(writer_we&&!writer_busy)begin
  expected_word=0;
  for(lane_index=0;lane_index<8;lane_index=lane_index+1)
   expected_word[lane_index*8+:8]=(writes*8+lane_index)&8'hff;
  if(writer_addr!==(29'h06010000+writes))begin
   $display("FAIL address write=%0d got=%h",writes,writer_addr);failures=failures+1;
  end
  if(writer_din!==expected_word||writer_be!==8'hff||writer_burstcnt!==1)begin
   $display("FAIL word write=%0d got=%h expected=%h",writes,writer_din,expected_word);
   failures=failures+1;
  end
  writes<=writes+1;
 end
end

initial begin
 record_data=0;record_start=0;record_last=0;record_valid=0;
 repeat(4)@(negedge clk);reset=0;

 // Existing DVD command must remain on the DVD sink.
 send_byte(8'h00,1,1);
 // Begin one complete audio UI frame.
 send_byte(8'h10,1,1);
 for(record_offset=0;record_offset<518400;record_offset=record_offset+4096)begin
  count=518400-record_offset;
  if(count>4096)count=4096;
  send_byte(8'h11,1,0);
  for(payload_index=0;payload_index<count;payload_index=payload_index+1)
   send_byte((record_offset+payload_index)&8'hff,0,payload_index==count-1);
 end
 while(writer_we)@(negedge clk);
 send_byte(8'h12,1,1);
 repeat(3)@(negedge clk);
 if(mode_active||!loading_active)begin
  $display("FAIL published before frame window");failures=failures+1;
 end
 publish_window=1;@(negedge clk);publish_window=0;
 repeat(3)@(negedge clk);
 if(!mode_active||loading_active||!display_bank||committed_frames!=1)begin
  $display("FAIL publish mode=%b loading=%b bank=%b commits=%0d",
   mode_active,loading_active,display_bank,committed_frames);failures=failures+1;
 end
 if(writes!=64800||dvd_records!=1||router_error||ui_error||writer_rd)begin
  $display("FAIL totals writes=%0d dvd=%0d router=%b ui=%b rd=%b",
   writes,dvd_records,router_error,ui_error,writer_rd);failures=failures+1;
 end
 // A commit without an open, complete frame is rejected and cannot publish.
 send_byte(8'h12,1,1);
 publish_window=1;@(negedge clk);publish_window=0;
 repeat(2)@(negedge clk);
 if(!ui_error||committed_frames!=1)begin
  $display("FAIL malformed UI commit error=%b commits=%0d",
   ui_error,committed_frames);failures=failures+1;
 end
 // Unknown display commands are drained and reported by the shared router.
 send_byte(8'h80,1,1);
 repeat(2)@(negedge clk);
 if(!router_error)begin
  $display("FAIL unknown display command was not rejected");failures=failures+1;
 end
 if(failures)begin $display("audio UI FAIL count=%0d",failures);$fatal(1);end
 $display("audio UI PASS writes=%0d commits=%0d",writes,committed_frames);
 $finish;
end
endmodule
