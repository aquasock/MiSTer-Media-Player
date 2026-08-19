//============================================================================
// MiSTer Media Player - generalized progressive 4:2:0 B-picture raster engine
//
// kate - Commit 169: widen the established bidirectional B reconstruction path
// through the 720x480 / 45x30 macroblock envelope. Ordered B motion metadata is
// retained in synchronous M10K-oriented RAM.
// kate - Commit 170: widen sparse residual metadata/storage to the same bounded
// 16-block envelope used by generalized P, including luma and chroma blocks.
// B output remains in the non-reference scratch frame and retires only after
// the writer accepts all eight DDR row writes for every block.
//
// Sideband protocol:
//   0x37:           intra macroblock marker (reference bypass)
//   0x38/0x39/0x3a: first motion word, forward/backward/interpolated direction
//   0x3c:           geometry {4'b0, mb_width[5:0], mb_height[5:0]}
//   0x3b:           second motion word, backward vector
//   0x3f, 1ixxxxxxxxxxxbbb: block descriptor (i=intra, 11-bit MB + block)
//   0x00..0x3f:     64 signed residual samples after a descriptor
//   0x3f, A3FE:     intermediate-row metadata terminator
//   0x3f, A3FF:     metadata terminator
// Commit 199 error_source is first-fault-only: 1 sample order, 2 first motion,
// 3 geometry, 4 second motion, 5 descriptor, 6 terminator, 7 unknown metadata,
// 8 admission, 9 timeout, 10 motion range, 11 direction/bounds,
// 12 unexpected DDR response, 13 reserved, 14 descriptor count,
// 15 motion count.
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
    output wire residual_store_write,
    output wire [16:0] residual_store_write_address,
    output wire signed [15:0] residual_store_write_data,
    output wire [16:0] residual_store_read_address,
    input  wire signed [15:0] residual_store_read_data,
    input  wire reference_valid,
    input  wire future_reference_bank,
    input  wire scratch_frame_bank,
    input  wire store_block_stored,
    input  wire ddram_busy,
    input  wire [63:0] ddram_dout,
    input  wire ddram_dout_ready,
    input  wire ddram_lookup_ready,
    input  wire ddram_lookup_hit,
    input  wire [63:0] ddram_lookup_data,
    output wire [7:0] ddram_burstcnt,
    output wire [28:0] ddram_addr,
    output wire ddram_rd,
    output wire ddram_cacheable,
    output wire ddram_lookup_request,
    output wire ddram_lookup_consume,
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
    output reg  row_persisted,
    output reg  error,
    output reg [4:0] error_source
);

localparam [28:0]
    Y_BASE      = 29'h06000000,
    CB_BASE     = 29'h0600A8C0,
    CR_BASE     = 29'h0600D2F0,
    BANK_OFF    = 29'h00010000;
localparam integer MAX_MB=1350;
localparam integer MAX_BLOCKS=2048;

// Captured before any scratch address is issued.  Declare it ahead of the
// address helpers so both simulation and Quartus resolve the selected bank
// without relying on an implicit forward declaration.
reg scratch_bank_latched;

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
