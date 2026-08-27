// Native elementary-stream startup reserve. The first completed bank stays
// cached while a second picture becomes presentable. Show the first bank at a
// field-pair boundary, then allow swaps after its video-domain acknowledgement.
// No clock, sync, DE, decode ownership or timestamp admission is changed here.
module mpeg2_h262_native_startup (
    input wire clk_mpeg2, input wire reset_mpeg2,
    input wire clk_video, input wire reset_video,
    input wire native_request, input wire [3:0] frame_rate_code,
    input wire first_picture_complete, input wire candidate_presentable,
    input wire sequence_end_seen, input wire bypass_event,
    input wire frame_window,
    output wire swaps_enabled, output wire video_blank
);
reg decided, bypass, show_request;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] bypass_sync, show_request_sync, shown_sync;
reg shown, frame_window_d;

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        decided <= 1'b0;
        bypass <= 1'b0;
        show_request <= 1'b0;
        shown_sync <= 3'b000;
    end else begin
        shown_sync <= {shown_sync[1:0], shown};
        // Bypass is sticky until download rearm; mode changes never restart a
        // running session. Metadata is observed at extraction, before queuing.
        if (bypass_event || (decided && !native_request))
            bypass <= 1'b1;
        if (first_picture_complete && !decided) begin
            decided <= 1'b1;
            if (!native_request || frame_rate_code != 4'd4)
                bypass <= 1'b1;
        end
        // EOS releases a one-picture file without requiring a nonexistent
        // second picture. No arbitrary count of empty windows is involved.
        if (first_picture_complete &&
            (candidate_presentable || sequence_end_seen))
            show_request <= 1'b1;
    end
end

always @(posedge clk_video) begin
    if (reset_video) begin
        bypass_sync <= 3'b000;
        show_request_sync <= 3'b000;
        shown <= 1'b0;
        frame_window_d <= 1'b0;
    end else begin
        bypass_sync <= {bypass_sync[1:0], bypass};
        show_request_sync <= {show_request_sync[1:0], show_request};
        frame_window_d <= frame_window;
        if (!show_request_sync[2])
            shown <= 1'b0;
        else if (frame_window && !frame_window_d)
            shown <= 1'b1;
    end
end

// The raw swap-window edge crosses separately. It arrives before shown's
// acknowledgement, so the first visible bank remains for a complete pair.
assign swaps_enabled = bypass || (show_request && shown_sync[2]);
assign video_blank = !bypass_sync[2] && !shown;
endmodule
