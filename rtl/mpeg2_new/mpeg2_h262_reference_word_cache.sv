//============================================================================
// MiSTer Media Player - small P/B prediction-reference word cache
//
// The generalized raster engines consume one byte from each 64-bit DDR word.
// Adjacent integer and half-pel taps therefore revisit the same two-dimensional
// reference words many times.  This four-entry fully-associative cache accepts
// at most two ordered word misses and returns them without changing request
// order or decoded-pel arithmetic.
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
    input  wire        lookup_request,
    input  wire        lookup_consume,
    output reg         lookup_ready,
    output reg         lookup_hit,
    output reg  [63:0] lookup_data,
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

reg [1:0] response_descriptor_count;
reg response_descriptor_head,response_descriptor_tail;
reg [28:0] response_descriptor_addr[0:1];
reg response_descriptor_cacheable[0:1];

// Request hits remain immediate only when no older response precedes them.
// While a miss is outstanding, a matching later request is issued as another
// ordered miss so downstream response order alone remains sufficient.
wire ordered_request_hit=cache_lookup_hit&&(response_descriptor_count==0);
wire response_existing=downstream_dout_ready&&
    (response_descriptor_count!=0);
wire response_descriptor_room=(response_descriptor_count<2)||
    response_existing;
wire request_accept_hit=request_read&&response_descriptor_room&&
    ordered_request_hit;
wire request_accept_miss=request_read&&response_descriptor_room&&
    !ordered_request_hit&&!downstream_busy;
wire request_accept=request_accept_hit||request_accept_miss;
wire direct_miss_response=downstream_dout_ready&&
    (response_descriptor_count==0)&&request_accept_miss;
wire response_descriptor_push=request_accept_miss&&!direct_miss_response;
wire response_descriptor_pop=response_existing;

wire request_active=request_read;
wire response_pending=(response_descriptor_count!=0);
wire [28:0] request_addr_reg=response_pending?
    response_descriptor_addr[response_descriptor_head]:request_addr;

assign request_busy=!request_accept;
assign downstream_burstcnt=(request_read&&response_descriptor_room&&
    !ordered_request_hit)?request_burstcnt:8'd0;
assign downstream_addr=(request_read&&response_descriptor_room&&
    !ordered_request_hit)?request_addr:29'd0;
assign downstream_read=request_read&&response_descriptor_room&&
    !ordered_request_hit;

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
        response_descriptor_count<=2'd0;
        response_descriptor_head<=1'b0;
        response_descriptor_tail<=1'b0;
        response_descriptor_addr[0]<=29'd0;
        response_descriptor_addr[1]<=29'd0;
        response_descriptor_cacheable[0]<=1'b0;
        response_descriptor_cacheable[1]<=1'b0;
        request_dout<=64'd0;
        request_dout_ready<=1'b0;
        lookup_ready<=1'b0;
        lookup_hit<=1'b0;
        lookup_data<=64'd0;
        cache_hit_count<=32'd0;
        cache_miss_count<=32'd0;
        uncached_count<=32'd0;
    end else begin
        request_dout_ready<=1'b0;
        lookup_ready<=1'b0;

        if(!active) begin
            cache_valid0<=1'b0;
            cache_valid1<=1'b0;
            cache_valid2<=1'b0;
            cache_valid3<=1'b0;
            cache_replace<=2'd0;
            response_descriptor_count<=2'd0;
            response_descriptor_head<=1'b0;
            response_descriptor_tail<=1'b0;
        end else begin
            if(lookup_request) begin
                lookup_ready<=1'b1;
                lookup_hit<=cache_lookup_hit;
                lookup_data<=cache_lookup_data;
            end

            // A raster engine may consume an already-resident prediction word
            // directly.  No request is captured and no downstream transaction
            // is issued for this path.
            case({request_accept_hit,
                  lookup_consume&&lookup_ready&&lookup_hit})
                2'b01,2'b10:cache_hit_count<=cache_hit_count+1'b1;
                2'b11:cache_hit_count<=cache_hit_count+2'd2;
                default:cache_hit_count<=cache_hit_count;
            endcase
            if(request_accept_miss)begin
                if(request_cacheable)
                    cache_miss_count<=cache_miss_count+1'b1;
                else
                    uncached_count<=uncached_count+1'b1;
            end

            if(response_descriptor_push)begin
                response_descriptor_addr[response_descriptor_tail]<=
                    request_addr;
                response_descriptor_cacheable[response_descriptor_tail]<=
                    request_cacheable;
                response_descriptor_tail<=response_descriptor_tail+1'b1;
            end
            if(response_descriptor_pop)
                response_descriptor_head<=response_descriptor_head+1'b1;
            case({response_descriptor_push,response_descriptor_pop})
                2'b10:response_descriptor_count<=
                    response_descriptor_count+1'b1;
                2'b01:response_descriptor_count<=
                    response_descriptor_count-1'b1;
                default:response_descriptor_count<=response_descriptor_count;
            endcase

            if(request_accept_hit)begin
                request_dout<=cache_lookup_data;
                request_dout_ready<=1'b1;
            end

            if(response_existing||direct_miss_response)begin
                request_dout<=downstream_dout;
                request_dout_ready<=1'b1;
                if(direct_miss_response?request_cacheable:
                   response_descriptor_cacheable[response_descriptor_head])begin
                    case(cache_replace)
                        2'd0: begin
                            cache_valid0<=1'b1;
                            cache_tag0<=direct_miss_response?request_addr:
                                response_descriptor_addr[response_descriptor_head];
                            cache_data0<=downstream_dout;
                        end
                        2'd1: begin
                            cache_valid1<=1'b1;
                            cache_tag1<=direct_miss_response?request_addr:
                                response_descriptor_addr[response_descriptor_head];
                            cache_data1<=downstream_dout;
                        end
                        2'd2: begin
                            cache_valid2<=1'b1;
                            cache_tag2<=direct_miss_response?request_addr:
                                response_descriptor_addr[response_descriptor_head];
                            cache_data2<=downstream_dout;
                        end
                        default: begin
                            cache_valid3<=1'b1;
                            cache_tag3<=direct_miss_response?request_addr:
                                response_descriptor_addr[response_descriptor_head];
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
