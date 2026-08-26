//============================================================================
// MiSTer Media Player - Phase 1S/1T DDR request arbiter
//
// kate - Phase 1R introduced concurrent decoder writes and presentation reads.
// Phase 1S repeats the two-bank ping-pong cycle, so the arbiter must also enforce
// frame-bank ownership: a new picture may not overwrite the bank still owned by
// the display reader.
//
// Reader requests have priority.  A bounded ordered descriptor queue retains
// response owner and burst length while DDR services accepted commands.  The
// display reader's accepted bank transfers presentation ownership; prediction
// reads never alter that ownership. Production defaults to depth four;
// simulation may override the shared descriptor-depth macro.
//
// kate - Phase 1T-f adds one decoder-side prediction reader. Display reads keep
// highest priority, prediction reads are next, and writes remain lowest priority.
// Response-ready is demultiplexed by the recorded read owner so the framebuffer
// cannot consume a prediction response and vice versa.
//
// kate - Phase 1T-o removes the temporary Phase 1T-m/n prediction-write command.
// The first reconstructed P block now uses the ordinary block writer, so this
// arbiter returns to three explicit clients: presentation read, prediction read,
// and reconstruction write. No prediction-side write encoding remains.
//
// Commit 142 extends display ownership to the B scratch frame.  Entry 276 adds
// a third retained reference at region 100.  Writer exclusion therefore keeps
// all three region bits [18:16]; truncating the tag would alias reference bank
// two with bank zero and can permanently block the next reference write.
//============================================================================

`ifndef H262_PREDICTION_DESCRIPTOR_DEPTH
`define H262_PREDICTION_DESCRIPTOR_DEPTH 4
`endif

module mpeg2_h262_ddram_arbiter
(
    input  wire        clk,
    input  wire        reset,

    input  wire [7:0]  writer_burstcnt,
    input  wire [28:0] writer_addr,
    input  wire        writer_rd,
    input  wire [63:0] writer_din,
    input  wire [7:0]  writer_be,
    input  wire        writer_we,
    output wire        writer_busy,

    input  wire [7:0]  reader_burstcnt,
    input  wire [28:0] reader_addr,
    input  wire        reader_rd,
    output wire        reader_busy,
    output wire        reader_dout_ready,

    input  wire [7:0]  prediction_burstcnt,
    input  wire [28:0] prediction_addr,
    input  wire        prediction_rd,
    output wire        prediction_busy,
    output wire        prediction_dout_ready,

    input  wire        ddram_busy,
    input  wire        ddram_dout_ready,
    output wire [7:0]  ddram_burstcnt,
    output wire [28:0] ddram_addr,
    output wire        ddram_rd,
    output wire [63:0] ddram_din,
    output wire [7:0]  ddram_be,
    output wire        ddram_we,
    // Entry 531: passive pulse identifying the exact cycle on which the
    // writer request above is accepted by the external DDR interface.
    output wire        writer_accept_debug
);

localparam integer DESCRIPTOR_DEPTH=`H262_PREDICTION_DESCRIPTOR_DEPTH;
localparam integer DESCRIPTOR_POINTER_WIDTH=
    (DESCRIPTOR_DEPTH<=2)?1:$clog2(DESCRIPTOR_DEPTH);
localparam integer DESCRIPTOR_COUNT_WIDTH=$clog2(DESCRIPTOR_DEPTH+1);

reg [DESCRIPTOR_COUNT_WIDTH-1:0] read_descriptor_count;
reg [DESCRIPTOR_POINTER_WIDTH-1:0]
    read_descriptor_head,read_descriptor_tail;
reg       read_descriptor_owner [0:DESCRIPTOR_DEPTH-1];
reg [7:0] read_descriptor_words [0:DESCRIPTOR_DEPTH-1];
reg       reader_bank_valid;
reg [2:0] reader_frame_region;

wire read_outstanding=(read_descriptor_count!=0);
wire read_owner_prediction=read_outstanding?
    read_descriptor_owner[read_descriptor_head]:1'b0;
wire [7:0] read_words_remaining=read_outstanding?
    read_descriptor_words[read_descriptor_head]:8'd0;
wire response_existing=ddram_dout_ready&&read_outstanding;
wire response_finishes=response_existing&&(read_words_remaining<=8'd1);
wire read_descriptor_room=(read_descriptor_count<DESCRIPTOR_DEPTH)||
    response_finishes;

wire writer_targets_reader_region =
    reader_bank_valid && (writer_addr[18:16] == reader_frame_region);

wire grant_reader =
    read_descriptor_room && reader_rd;

wire grant_prediction =
    read_descriptor_room && !reader_rd && prediction_rd;

wire grant_writer =
    !read_outstanding && !reader_rd && !prediction_rd &&
    writer_we && !writer_targets_reader_region;

// Busy reports capacity/priority independently of the corresponding request.
// This is a ready/valid boundary: acceptance below remains request-qualified,
// but no client valid may feed back combinationally into its own readiness.
assign reader_busy = !read_descriptor_room||ddram_busy;

assign prediction_busy =
    !read_descriptor_room||reader_rd||ddram_busy;

assign writer_busy = read_outstanding||reader_rd||prediction_rd||
    writer_targets_reader_region||ddram_busy;

assign ddram_burstcnt =
    grant_reader ? reader_burstcnt :
    grant_prediction ? prediction_burstcnt :
    grant_writer ? writer_burstcnt : 8'd0;

assign ddram_addr =
    grant_reader ? reader_addr :
    grant_prediction ? prediction_addr :
    grant_writer ? writer_addr : 29'd0;

assign ddram_rd =
    grant_reader ? 1'b1 :
    grant_prediction ? 1'b1 : 1'b0;

assign ddram_din =
    grant_writer ? writer_din : 64'd0;

assign ddram_be =
    grant_writer ? writer_be : 8'hFF;

assign ddram_we =
    grant_writer ? writer_we : 1'b0;

wire reader_accept=grant_reader&&!ddram_busy;
wire prediction_accept=grant_prediction&&!ddram_busy;
assign writer_accept_debug=grant_writer&&!ddram_busy;
wire read_accept=reader_accept||prediction_accept;
wire accepted_owner_prediction=prediction_accept;
wire [7:0] accepted_words=reader_accept?
    reader_burstcnt:prediction_burstcnt;
wire direct_response=ddram_dout_ready&&!read_outstanding&&read_accept;
wire direct_response_finishes=direct_response&&(accepted_words<=8'd1);
wire descriptor_push=read_accept&&!direct_response_finishes;
wire descriptor_pop=response_finishes;
wire [7:0] pushed_words=direct_response?
    (accepted_words-8'd1):accepted_words;
wire [DESCRIPTOR_POINTER_WIDTH-1:0] read_descriptor_head_next=
    (read_descriptor_head==(DESCRIPTOR_DEPTH-1))?
    {DESCRIPTOR_POINTER_WIDTH{1'b0}}:read_descriptor_head+1'b1;
wire [DESCRIPTOR_POINTER_WIDTH-1:0] read_descriptor_tail_next=
    (read_descriptor_tail==(DESCRIPTOR_DEPTH-1))?
    {DESCRIPTOR_POINTER_WIDTH{1'b0}}:read_descriptor_tail+1'b1;

assign reader_dout_ready =
    (response_existing&&!read_owner_prediction)||
    (direct_response&&reader_accept);

assign prediction_dout_ready =
    (response_existing&&read_owner_prediction)||
    (direct_response&&prediction_accept);

integer descriptor_index;
always @(posedge clk) begin
    if (reset) begin
        read_descriptor_count <= {DESCRIPTOR_COUNT_WIDTH{1'b0}};
        read_descriptor_head  <= {DESCRIPTOR_POINTER_WIDTH{1'b0}};
        read_descriptor_tail  <= {DESCRIPTOR_POINTER_WIDTH{1'b0}};
        for(descriptor_index=0;descriptor_index<DESCRIPTOR_DEPTH;
            descriptor_index=descriptor_index+1)begin
            read_descriptor_owner[descriptor_index] <= 1'b0;
            read_descriptor_words[descriptor_index] <= 8'd0;
        end
        reader_bank_valid     <= 1'b0;
        reader_frame_region   <= 3'b000;
    end
    else begin
        if(descriptor_push)begin
            read_descriptor_owner[read_descriptor_tail]<=
                accepted_owner_prediction;
            read_descriptor_words[read_descriptor_tail]<=pushed_words;
            read_descriptor_tail<=read_descriptor_tail_next;
        end
        if(descriptor_pop)
            read_descriptor_head<=read_descriptor_head_next;
        else if(response_existing)
            read_descriptor_words[read_descriptor_head]<=
                read_words_remaining-8'd1;

        case({descriptor_push,descriptor_pop})
            2'b10:read_descriptor_count<=read_descriptor_count+1'b1;
            2'b01:read_descriptor_count<=read_descriptor_count-1'b1;
            default:read_descriptor_count<=read_descriptor_count;
        endcase

        if(reader_accept)begin
            reader_bank_valid<=1'b1;
            reader_frame_region<=reader_addr[18:16];
        end
    end
end

wire unused_writer_rd = writer_rd;

endmodule
