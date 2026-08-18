//============================================================================
// MiSTer Media Player - fail-open compressed-stream transport gate
//
// Clean operation preserves the FIFO-to-decoder ready/valid contract.  Fatal
// pipeline results are sticky at their sources; after one asserts, continue
// retiring FIFO bytes without exposing discarded data as valid decoder input.
//============================================================================
module mpeg2_h262_stream_transport_gate
(
    input  wire fifo_empty,
    input  wire decoder_ready,
    input  wire fatal_error,
    output wire fifo_read,
    output wire decoder_valid
);

assign fifo_read = !fifo_empty && (decoder_ready || fatal_error);
assign decoder_valid = fifo_read && !fatal_error;

endmodule
