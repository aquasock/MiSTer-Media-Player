//============================================================================
// MiSTer processed-HDMI deinterlacer selection
//
// HDMI_BOB_DEINT is consumed by MiSTer's scaler. It has no effect on direct
// video, so native raw 480i remains raw while the processed HDMI path can
// choose the framework's existing weave or bob reconstruction.
//============================================================================
module mpeg2_hdmi_deinterlace_control
(
    input  wire clk,
    input  wire reset,
    input  wire native_interlaced,
    input  wire bob_selected_async,
    output wire hdmi_bob_deint
);

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [1:0] bob_selected_sync;

always @(posedge clk) begin
    if (reset)
        bob_selected_sync <= 2'b00;
    else
        bob_selected_sync <= {bob_selected_sync[0], bob_selected_async};
end

assign hdmi_bob_deint = native_interlaced && bob_selected_sync[1];

endmodule
