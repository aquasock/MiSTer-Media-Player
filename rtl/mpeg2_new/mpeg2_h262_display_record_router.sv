// Route the shared B9 display-record channel without exposing either sink to
// commands owned by the other. Commands 0..4 remain the authored DVD overlay;
// 0x10..0x12 belong to the audio-only full-frame uploader.
module mpeg2_h262_display_record_router
(
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] record_data,
    input  wire       record_start,
    input  wire       record_last,
    input  wire       record_valid,
    output wire       record_ready,

    output wire [7:0] dvd_data,
    output wire       dvd_start,
    output wire       dvd_last,
    output wire       dvd_valid,
    input  wire       dvd_ready,

    output wire [7:0] ui_data,
    output wire       ui_start,
    output wire       ui_last,
    output wire       ui_valid,
    input  wire       ui_ready,
    output reg        protocol_error
);

localparam [1:0] TARGET_NONE=2'd0, TARGET_DVD=2'd1,
                 TARGET_UI=2'd2, TARGET_DROP=2'd3;
reg [1:0] target;

wire start_dvd = record_data <= 8'h04;
wire start_ui = record_data >= 8'h10 && record_data <= 8'h12;
wire [1:0] selected_target = start_dvd ? TARGET_DVD :
                             start_ui ? TARGET_UI : TARGET_DROP;
wire [1:0] active_target = record_start ? selected_target : target;

assign record_ready = active_target == TARGET_DVD ? dvd_ready :
                      active_target == TARGET_UI ? ui_ready : 1'b1;

assign dvd_data = record_data;
assign dvd_start = record_start;
assign dvd_last = record_last;
assign dvd_valid = record_valid && active_target == TARGET_DVD;
assign ui_data = record_data;
assign ui_start = record_start;
assign ui_last = record_last;
assign ui_valid = record_valid && active_target == TARGET_UI;

always @(posedge clk) begin
    if (reset) begin
        target <= TARGET_NONE;
        protocol_error <= 1'b0;
    end else if (record_valid && record_ready) begin
        if (record_start) begin
            if (target != TARGET_NONE || selected_target == TARGET_DROP)
                protocol_error <= 1'b1;
            target <= record_last ? TARGET_NONE : selected_target;
        end else begin
            if (target == TARGET_NONE)
                protocol_error <= 1'b1;
            if (record_last)
                target <= TARGET_NONE;
        end
    end
end

endmodule
