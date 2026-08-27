`timescale 1ns/1ps
// Directed controller/CDC contract test. Synthetic two-field windows allow a
// dense phase sweep; the native suite separately verifies physical geometry.
module tb_h262_native_startup;
reg clk=0,video_clk=0,reset=1,download=0;
always #5 clk=~clk;
always #5.555 video_clk=~video_clk;
wire rearm;
wire decode_reset=reset||rearm;
reg native_request=1,first=0,candidate=0,eos=0,bypass_event=0,bob=0;
reg [3:0] rate=4;
reg [7:0] raster=0;
wire frame_window=(raster>=220);
reg window_d=0,window_video=0;
reg [2:0] window_sync=0;
wire raw_swap=window_sync[1]&&!window_sync[2];
wire enabled,blank,hdmi_bob;
integer boundaries=0,shown_boundary=-1,first_swap_boundary=-1;
integer phase,scenario=0;
reg blank_d=1,monitor=0;
mpeg2_h262_download_rearm download_rearm(.clk(clk),.reset(reset),
    .download_async(download),.rearm_reset(rearm));
mpeg2_h262_native_startup dut(.clk_mpeg2(clk),.reset_mpeg2(decode_reset),
    .clk_video(video_clk),.reset_video(reset),.native_request(native_request),
    .frame_rate_code(rate),.first_picture_complete(first),
    .candidate_presentable(candidate),.sequence_end_seen(eos),
    .bypass_event(bypass_event),.frame_window(frame_window),
    .swaps_enabled(enabled),.video_blank(blank));
mpeg2_hdmi_deinterlace_control deint(.clk(video_clk),.reset(reset),
    .native_interlaced(native_request),.bob_selected_async(bob),.hdmi_bob_deint(hdmi_bob));
always @(posedge video_clk) begin
    if(reset)begin raster<=0;window_d<=0;window_video<=0;boundaries=0;end
    else begin
        raster <= raster==239 ? 0 : raster+1;
        window_d<=frame_window;window_video<=frame_window;
        if(frame_window&&!window_d)boundaries=boundaries+1;
    end
end
always @(negedge video_clk) begin
    if(monitor&&blank_d&&!blank)begin
        if(!frame_window||raster!=221)$fatal(1,"visible outside pair edge scenario=%0d",scenario);
        shown_boundary=boundaries;
    end
    blank_d=blank;
end
always @(posedge clk)begin
    if(decode_reset)window_sync<=0;
    else begin
        window_sync<={window_sync[1:0],window_video};
        if(monitor&&raw_swap&&enabled&&first_swap_boundary<0)begin
            first_swap_boundary=boundaries;
            if(shown_boundary<0 || boundaries!=shown_boundary+1)
                $fatal(1,"first bank did not receive one full pair shown=%0d swap=%0d",shown_boundary,boundaries);
        end
    end
end
task warm_start;
begin
    monitor=0;download=0;
    repeat(12)@(negedge clk);
    first=0;candidate=0;eos=0;bypass_event=0;native_request=1;rate=4;
    download=1;wait(rearm);wait(!rearm);
    repeat(20)@(negedge clk);
    if(enabled||!blank)$fatal(1,"warm download retained startup state");
    shown_boundary=-1;first_swap_boundary=-1;blank_d=1;scenario=scenario+1;
end
endtask
task complete_start;
begin
    wait(!blank);wait(first_swap_boundary>=0);
    repeat(12)begin
        @(negedge clk);bob=~bob;
        if(!enabled||blank)$fatal(1,"Bob/Weave rearmed startup");
    end
end
endtask
initial begin
    repeat(10)@(negedge clk);reset=0;
    // Sweep readiness on both sides of the video blanking edge, with clocks
    // neither identical nor aligned. Restart uses the real eight-cycle rearm.
    for(phase=0;phase<24;phase=phase+1)begin
        warm_start();monitor=1;first=1;
        repeat(300)@(negedge clk);
        if(enabled||!blank)$fatal(1,"first picture alone released startup");
        wait(raster==phase*10);@(negedge clk);candidate=1;
        complete_start();
    end
    warm_start();monitor=1;first=1;eos=1;complete_start(); // short EOF
    warm_start();first=1;native_request=0;
    repeat(20)@(negedge clk);
    if(!enabled||blank)$fatal(1,"progressive bypass failed");
    native_request=1;repeat(20)@(negedge clk);
    if(!enabled||blank)$fatal(1,"mode return rearmed startup");
    warm_start();bypass_event=1;@(negedge clk);bypass_event=0;
    repeat(20)@(negedge clk);
    if(!enabled||blank)$fatal(1,"metadata/PCM/header/error bypass failed");
    warm_start();first=1;rate=3;
    repeat(20)@(negedge clk);
    if(!enabled||blank)$fatal(1,"other cadence bypass failed");
    // A download interrupted before readiness must not leak its request into
    // the next download, even though the video timing keeps running.
    warm_start();first=1;candidate=1;repeat(2)@(negedge clk);
    warm_start();monitor=1;first=1;eos=1;complete_start();
    $display("PASS native startup: 24 readiness phases, full first pair, EOF, warm rearm, interrupted reserve, bypass, Bob/Weave");
    $finish;
end
initial begin #2000000;$fatal(1,"startup timeout scenario=%0d",scenario);end
endmodule
