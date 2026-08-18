//============================================================================
// MiSTer Media Player - small P/B prediction-reference word cache
//
// The generalized raster engines consume one byte from each 64-bit DDR word.
// Adjacent integer and half-pel taps therefore revisit the same two-dimensional
// reference words many times.  This four-entry fully-associative cache sits on
// the engines' existing single-outstanding-request handshake and returns those
// words without changing request order or decoded-pel arithmetic.
//
// Only requests explicitly marked cacheable may fill or hit.  Destination
// verification reads always bypass the cache.  active is the live raster
// transaction, so dropping active invalidates every entry before a later
// picture can reuse a rewritten reference-bank address.
//============================================================================
module mpeg2_h262_reference_word_cache
(
    input  wire        clk,
    input  wire        reset,
    input  wire        active,

    input  wire [7:0]  request_burstcnt,
    input  wire [28:0] request_addr,
    input  wire        request_read,
    input  wire        request_cacheable,
    output wire        request_busy,
    output reg  [63:0] request_dout,
    output reg         request_dout_ready,

    input  wire        downstream_busy,
    input  wire [63:0] downstream_dout,
    input  wire        downstream_dout_ready,
    output wire [7:0]  downstream_burstcnt,
    output wire [28:0] downstream_addr,
    output wire        downstream_read,

    output reg  [31:0] cache_hit_count,
    output reg  [31:0] cache_miss_count,
    output reg  [31:0] uncached_count
);

reg        cache_valid0,cache_valid1,cache_valid2,cache_valid3;
reg [28:0] cache_tag0,cache_tag1,cache_tag2,cache_tag3;
reg [63:0] cache_data0,cache_data1,cache_data2,cache_data3;
reg [1:0]  cache_replace;

wire cache_lookup0=cache_valid0&&(cache_tag0==request_addr);
wire cache_lookup1=cache_valid1&&(cache_tag1==request_addr);
wire cache_lookup2=cache_valid2&&(cache_tag2==request_addr);
wire cache_lookup3=cache_valid3&&(cache_tag3==request_addr);
wire cache_lookup_hit=request_cacheable&&
    (cache_lookup0||cache_lookup1||cache_lookup2||cache_lookup3);
wire [63:0] cache_lookup_data=cache_lookup0?cache_data0:
    cache_lookup1?cache_data1:cache_lookup2?cache_data2:cache_data3;

reg        request_active;
reg [7:0]  request_burstcnt_reg;
reg [28:0] request_addr_reg;
reg        request_cacheable_reg;
reg        request_hit_reg;
reg [63:0] request_hit_data_reg;
reg        response_pending;

// Match the established raster handshake: busy becomes low for the one cycle
// in which the held request is accepted.  A hit is always immediately
// acceptable; a miss follows the downstream DDR client's busy indication.
assign request_busy=!(request_active&&
    (request_hit_reg||!downstream_busy));

assign downstream_burstcnt=
    (request_active&&!request_hit_reg)?request_burstcnt_reg:8'd0;
assign downstream_addr=
    (request_active&&!request_hit_reg)?request_addr_reg:29'd0;
assign downstream_read=request_active&&!request_hit_reg;

always @(posedge clk) begin
    if(reset) begin
        cache_valid0<=1'b0;
        cache_valid1<=1'b0;
        cache_valid2<=1'b0;
        cache_valid3<=1'b0;
        cache_tag0<=29'd0;
        cache_tag1<=29'd0;
        cache_tag2<=29'd0;
        cache_tag3<=29'd0;
        cache_data0<=64'd0;
        cache_data1<=64'd0;
        cache_data2<=64'd0;
        cache_data3<=64'd0;
        cache_replace<=2'd0;
        request_active<=1'b0;
        request_burstcnt_reg<=8'd0;
        request_addr_reg<=29'd0;
        request_cacheable_reg<=1'b0;
        request_hit_reg<=1'b0;
        request_hit_data_reg<=64'd0;
        response_pending<=1'b0;
        request_dout<=64'd0;
        request_dout_ready<=1'b0;
        cache_hit_count<=32'd0;
        cache_miss_count<=32'd0;
        uncached_count<=32'd0;
    end else begin
        request_dout_ready<=1'b0;

        if(!active) begin
            cache_valid0<=1'b0;
            cache_valid1<=1'b0;
            cache_valid2<=1'b0;
            cache_valid3<=1'b0;
            cache_replace<=2'd0;
            request_active<=1'b0;
            response_pending<=1'b0;
        end else begin
            if(!request_active&&!response_pending&&request_read) begin
                request_active<=1'b1;
                request_burstcnt_reg<=request_burstcnt;
                request_addr_reg<=request_addr;
                request_cacheable_reg<=request_cacheable;
                request_hit_reg<=cache_lookup_hit;
                request_hit_data_reg<=cache_lookup_data;
                if(cache_lookup_hit)
                    cache_hit_count<=cache_hit_count+1'b1;
                else if(request_cacheable)
                    cache_miss_count<=cache_miss_count+1'b1;
                else
                    uncached_count<=uncached_count+1'b1;
            end

            if(request_active&&request_hit_reg) begin
                request_active<=1'b0;
                request_dout<=request_hit_data_reg;
                request_dout_ready<=1'b1;
            end else if(request_active&&!downstream_busy) begin
                request_active<=1'b0;
                response_pending<=1'b1;
            end

            // Some DDR models return in the acceptance cycle; the second term
            // preserves that legal behavior as well as ordinary delayed data.
            if(downstream_dout_ready&&
               (response_pending||
                (request_active&&!request_hit_reg&&!downstream_busy))) begin
                response_pending<=1'b0;
                request_dout<=downstream_dout;
                request_dout_ready<=1'b1;
                if(request_cacheable_reg) begin
                    case(cache_replace)
                        2'd0: begin
                            cache_valid0<=1'b1;
                            cache_tag0<=request_addr_reg;
                            cache_data0<=downstream_dout;
                        end
                        2'd1: begin
                            cache_valid1<=1'b1;
                            cache_tag1<=request_addr_reg;
                            cache_data1<=downstream_dout;
                        end
                        2'd2: begin
                            cache_valid2<=1'b1;
                            cache_tag2<=request_addr_reg;
                            cache_data2<=downstream_dout;
                        end
                        default: begin
                            cache_valid3<=1'b1;
                            cache_tag3<=request_addr_reg;
                            cache_data3<=downstream_dout;
                        end
                    endcase
                    cache_replace<=cache_replace+1'b1;
                end
            end
        end
    end
end

endmodule
