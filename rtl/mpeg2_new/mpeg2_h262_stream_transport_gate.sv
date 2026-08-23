//============================================================================
// MiSTer Media Player - fail-open compressed-stream transport gate
//
// Clean operation preserves the FIFO-to-decoder ready/valid contract.  Entry
// 357 registers the aggregate fatal result before it controls this transport,
// breaking the route-dominated decoder/error/ingress combinational feedback.
// After a fault is captured, continue retiring FIFO bytes without exposing
// discarded data as valid decoder input.
//============================================================================
module mpeg2_h262_stream_transport_gate
(
    input  wire clk,
    input  wire reset,
    input  wire fifo_empty,
    input  wire decoder_ready,
    input  wire fatal_error,
    output wire fifo_read,
    output wire decoder_valid
);

reg fatal_error_latched;

always @(posedge clk) begin
    if (reset)
        fatal_error_latched <= 1'b0;
    else if (fatal_error)
        fatal_error_latched <= 1'b1;
end

assign fifo_read =
    !fifo_empty && (decoder_ready || fatal_error_latched);
assign decoder_valid = fifo_read && !fatal_error_latched;

endmodule
