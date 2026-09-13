// One-cycle cache-response delivery, with a local data register per consumer.
// The caller qualifies ownership when the shared cache produces the word.
// Data is only observable with its matching ready pulse; owner-enabled writes
// retain independent register states and avoid recreating a shared fanout net.
module mpeg2_h262_reference_response_handoff (
    input wire clk,reset,
    input wire [63:0] shared_word,
    input wire mixed_valid,b_valid,
    output wire [63:0] mixed_word,b_word,
    output reg mixed_ready,b_ready
);
(* dont_merge *) reg [63:0] mixed_word_q;
(* dont_merge *) reg [63:0] b_word_q;
assign mixed_word=mixed_word_q;
assign b_word=b_word_q;
always @(posedge clk) begin
    if(reset) begin
        mixed_word_q<=64'd0;
        b_word_q<=64'd0;
        mixed_ready<=1'b0;
        b_ready<=1'b0;
    end else begin
        if(mixed_valid) mixed_word_q<=shared_word;
        if(b_valid) b_word_q<=shared_word;
        mixed_ready<=mixed_valid;
        b_ready<=b_valid;
    end
end
endmodule
