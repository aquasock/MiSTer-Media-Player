// Re-establish a first-load decoder boundary for every HPS file transfer.
// ioctl_download is generated in clk_sys and remains asserted for the complete
// transfer.  Synchronize that level into clk_mpeg2, detect only its rising
// edge, and hold the MPEG-domain reset active for eight clock edges.  reset is
// the top level's already synchronized MPEG-domain reset.
//
// rearm_reset is combinationally asserted from download_start before the edge
// that records the event.  The top level also uses it to block FIFO reads, so
// a newly visible first byte cannot be consumed on the reset edge.
module mpeg2_h262_download_rearm
(
    input  wire clk,
    input  wire reset,
    input  wire download_async,
    output wire rearm_reset
);

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] download_sync;
reg       download_seen_high;
reg [2:0] rearm_count;

wire download_start = download_sync[2] && !download_seen_high;

assign rearm_reset = download_start || (rearm_count != 3'd0);

always @(posedge clk) begin
    if (reset) begin
        download_sync      <= 3'b000;
        download_seen_high <= 1'b0;
        rearm_count        <= 3'd0;
    end
    else begin
        download_sync <= {download_sync[1:0], download_async};

        if (!download_sync[2])
            download_seen_high <= 1'b0;
        else if (!download_seen_high)
            download_seen_high <= 1'b1;

        if (download_start)
            rearm_count <= 3'd7;
        else if (rearm_count != 3'd0)
            rearm_count <= rearm_count - 3'd1;
    end
end

endmodule
