//============================================================================
// MiSTer Media Player - generalized progressive 4:2:0 B-picture raster engine
//
// kate - Commit 169: widen the established bidirectional B reconstruction path
// through the 720x480 / 45x30 macroblock envelope. Ordered B motion metadata is
// retained in synchronous M10K-oriented RAM.
// kate - Commit 170: widen sparse residual metadata/storage to the same bounded
// 16-block envelope used by generalized P, including luma and chroma blocks.
// B output remains in the non-reference scratch frame and is verified by DDR
// readback before persisted_seen.
//
// Sideband protocol:
//   0x38/0x39/0x3a: first motion word, forward/backward/interpolated direction
//   0x3c:           geometry {4'b0, mb_width[5:0], mb_height[5:0]}
//   0x3b:           second motion word, backward vector
//   0x3f, 11xxxxxxxxxxxbbb: residual descriptor (11-bit MB + block)
//   0x00..0x3f:     64 signed residual samples after a descriptor
//   0x3f, A3FF:     metadata terminator
//============================================================================
module mpeg2_h262_b_bidirectional_raster_engine
(
    input  wire clk,
    input  wire reset,
    input  wire capture_enable,
    input  wire request,
    input  wire sideband_valid,
    input  wire [5:0] sideband_index,
    input  wire signed [15:0] sideband_value,
    input  wire reference_valid,
    input  wire future_reference_bank,
    input  wire store_block_stored,
    input  wire ddram_busy,
    input  wire [63:0] ddram_dout,
    input  wire ddram_dout_ready,
    output wire [7:0] ddram_burstcnt,
    output wire [28:0] ddram_addr,
    output wire ddram_rd,
    output wire store_select,
    output wire [7:0] store_pixel_value,
    output wire [11:0] store_pixel_x,
    output wire [11:0] store_pixel_y,
    output wire store_pixel_valid,
    output wire store_block_start,
    output wire store_block_complete,
    output reg  active,
    output reg  read_seen,
    output reg  sample_nonzero,
    output reg  half_sample_seen,
    output reg  reconstructed_seen,
    output reg  persisted_seen,
    output reg  error
);

localparam [28:0]
    Y_BASE      = 29'h06000000,
    CB_BASE     = 29'h0600A8C0,
    CR_BASE     = 29'h0600D2F0,
    BANK_OFF    = 29'h00010000,
    SCRATCH_OFF = 29'h00020000;
localparam integer MAX_MB=1350;
localparam integer MAX_BLOCKS=16;

reg [5:0] mb_width,mb_height;
reg geometry_seen;
wire geometry_ok=(mb_width!=0)&&(mb_width<=6'd45)&&(mb_height!=0)&&(mb_height<=6'd30);
wire [11:0] padded_luma_width={6'd0,mb_width}<<4;
wire [11:0] padded_luma_height={6'd0,mb_height}<<4;
wire [11:0] padded_chroma_width={6'd0,mb_width}<<3;
wire [11:0] padded_chroma_height={6'd0,mb_height}<<3;

function automatic [28:0] r90;
    input [11:0] r; reg [28:0] x;
    begin x={17'd0,r}; r90=(x<<6)+(x<<4)+(x<<3)+(x<<1); end
endfunction
function automatic [28:0] r45;
    input [11:0] r; reg [28:0] x;
    begin x={17'd0,r}; r45=(x<<5)+(x<<3)+(x<<2)+x; end
endfunction
function automatic [28:0] block_addr;
    input [5:0] c; input [5:0] mr; input [2:0] b; input [2:0] rr;
    reg [11:0] lr,lw,cr;
    begin
        if(b<4) begin
            lr=({6'd0,mr}<<4)+{8'd0,b[1],rr};
            lw=({6'd0,c}<<1)+{11'd0,b[0]};
            block_addr=Y_BASE+SCRATCH_OFF+r90(lr)+{17'd0,lw};
        end else begin
            cr=({6'd0,mr}<<3)+{9'd0,rr};
            block_addr=(b==4?CB_BASE:CR_BASE)+SCRATCH_OFF+r45(cr)+{20'd0,c};
        end
