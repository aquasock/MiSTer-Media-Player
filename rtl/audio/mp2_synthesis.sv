// Serialized 32-subband synthesis. All memories have synchronous read ports.
// Subbands: signed Q20; cosine/window: signed Q16; V history: signed Q20.
module mp2_synthesis (
    input wire clk, reset,
    input wire sample_wr,
    input wire [7:0] sample_addr,
    input wire signed [23:0] sample_data,
    input wire start,
    output wire busy,
    output reg done,
    output reg pcm_valid,
    input wire pcm_ready,
    output reg signed [15:0] pcm_left, pcm_right
);
reg signed [23:0] samples [0:191];
reg signed [17:0] cosine [0:2047];
reg signed [17:0] window_rom [0:511];
reg signed [26:0] history [0:2047];
reg signed [15:0] left_samples [0:31];
initial begin
    $readmemh("rtl/audio/mp2_cos.hex", cosine);
    $readmemh("rtl/audio/mp2_window.hex", window_rom);
end
localparam CLEAR=0, IDLE=1, DREAD=2, DMUL=3, DADD=4,
           WREAD=5, WMUL=6, WADD=7, EMIT=8;
reg [3:0] state;
reg [10:0] clear_addr;
reg [9:0] vpos;
reg [1:0] slot;
reg channel;
reg [5:0] row;
reg [4:0] band;
reg [3:0] tap;
reg signed [23:0] sample_q;
reg signed [17:0] cos_q, window_q;
reg signed [26:0] history_q;
reg signed [41:0] dproduct;
reg signed [44:0] wproduct;
reg signed [48:0] accumulator;
wire signed [48:0] dsum = accumulator + {{7{dproduct[41]}},dproduct};
wire signed [48:0] wsum = accumulator + {{4{wproduct[44]}},wproduct};
wire [9:0] history_offset = {tap[3:1],7'd0} + (tap[0] ? 10'd96 : 10'd0) + {5'd0,band};
wire [9:0] history_read_addr = vpos + history_offset;
wire [9:0] history_write_addr = vpos + {4'd0,row};
assign busy = state != IDLE;
function signed [15:0] clamp_pcm;
    input signed [48:0] value;
    reg signed [48:0] scaled;
    begin
        scaled = (value + 49'sd1048576) >>> 21;
        if (scaled > 32767) clamp_pcm=16'sh7fff;
        else if (scaled < -32768) clamp_pcm=16'sh8000;
        else clamp_pcm=scaled[15:0];
    end
endfunction
always @(posedge clk) begin
    if (sample_wr) samples[sample_addr] <= sample_data;
    sample_q <= samples[{slot,channel,band}];
    cos_q <= cosine[{row,band}];
    window_q <= window_rom[{tap,band}];
    history_q <= history[{channel,history_read_addr}];
    dproduct <= sample_q * cos_q;
    wproduct <= history_q * window_q;
    done <= 0;
    if (reset) begin
        state<=CLEAR; clear_addr<=0; vpos<=0;
        pcm_valid<=0; pcm_left<=0; pcm_right<=0;
        slot<=0; channel<=0; row<=0; band<=0; tap<=0; accumulator<=0;
    end else case(state)
        CLEAR: begin
            history[clear_addr]<=0;
            if (clear_addr==2047) state<=IDLE;
            else clear_addr<=clear_addr+11'd1;
        end
        IDLE: if(start) begin
            slot<=0; channel<=0; row<=0; band<=0;
            vpos<=vpos-10'd64; accumulator<=0; state<=DREAD;
        end
        DREAD: state<=DMUL;
        DMUL: state<=DADD;
        DADD: begin
            if(band==31) begin
                history[{channel,history_write_addr}] <= dsum[42:16];
                accumulator<=0; band<=0;
                if(row==63) begin tap<=0; state<=WREAD; end
                else begin row<=row+6'd1; state<=DREAD; end
            end else begin accumulator<=dsum; band<=band+5'd1; state<=DREAD; end
        end
        WREAD: state<=WMUL;
        WMUL: state<=WADD;
        WADD: begin
            if(tap==15) begin
                accumulator<=0; tap<=0;
                if(!channel) begin
                    left_samples[band]<=clamp_pcm(wsum);
                    if(band==31) begin channel<=1; row<=0; band<=0; state<=DREAD; end
                    else begin band<=band+5'd1; state<=WREAD; end
                end else begin
                    pcm_left<=left_samples[band]; pcm_right<=clamp_pcm(wsum);
                    pcm_valid<=1; state<=EMIT;
                end
            end else begin accumulator<=wsum; tap<=tap+4'd1; state<=WREAD; end
        end
        EMIT: if(pcm_ready) begin
            pcm_valid<=0;
            if(band!=31) begin band<=band+5'd1; state<=WREAD; end
            else if(slot==2) begin done<=1; state<=IDLE; end
            else begin
                slot<=slot+2'd1; channel<=0; row<=0; band<=0;
                vpos<=vpos-10'd64; state<=DREAD;
            end
        end
        default: state<=CLEAR;
    endcase
end
endmodule
