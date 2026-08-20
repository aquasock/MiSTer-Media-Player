//============================================================================
// MiSTer Media Player - bounded prediction block-footprint fetcher
//
// A progressive 4:2:0 prediction phase touches a complete reference-word
// rectangle no wider than two 64-bit words and no taller than nine rows.  A B
// block may use two such phases.  This module assigns eighteen direct slots to
// each phase, generates every rectangle address once, keeps two ordered reads
// in flight, and associates each ordered response with its destination slot.
// Pixel engines consume the retained words by phase/row/column, avoiding an
// associative tag cone on their reconstruction path.
//============================================================================
module mpeg2_h262_prediction_block_fetcher
(
    input  wire        clk,
    input  wire        reset,
    input  wire        start,
    input  wire [1:0]  phase_count,
    input  wire [28:0] phase0_base_addr,
    input  wire [28:0] phase1_base_addr,
    input  wire        phase0_two_words,
    input  wire        phase1_two_words,
    input  wire [3:0]  phase0_rows,
    input  wire [3:0]  phase1_rows,
    input  wire [6:0]  row_words,

    input  wire        memory_busy,
    input  wire [63:0] memory_dout,
    input  wire        memory_dout_ready,
    output wire [28:0] memory_addr,
    output wire        memory_rd,

    input  wire        lookup_request,
    input  wire        lookup_phase,
    input  wire [3:0]  lookup_row,
    input  wire        lookup_column,
    output reg         lookup_ready,
    output reg         lookup_valid,
    output reg  [63:0] lookup_data,

    output reg         active,
    output reg         complete,
    output reg         error,
    output reg  [6:0]  issued_count,
    output reg  [6:0]  returned_count,
    output wire [1:0]  outstanding_count
);

reg [63:0] word_data [0:35];
reg [35:0] word_valid;

reg generator_phase;
reg [3:0] generator_row;
reg generator_column;
reg [28:0] generator_row_addr;
reg all_issued;

reg [5:0] descriptor_slot [0:1];
reg descriptor_head,descriptor_tail;
reg [1:0] descriptor_count;

wire generator_two_words=generator_phase?
    phase1_two_words:phase0_two_words;
wire [3:0] generator_rows=generator_phase?phase1_rows:phase0_rows;
wire generator_last_column=!generator_two_words||generator_column;
wire generator_last_row=(generator_row+1'b1)>=generator_rows;
wire generator_last_phase=generator_phase||(phase_count==2'd1);
wire generator_last=generator_last_column&&generator_last_row&&
    generator_last_phase;

wire [5:0] generator_slot=
    (generator_phase?6'd18:6'd0)+
    {generator_row,1'b0}+generator_column;
assign memory_addr=generator_row_addr+generator_column;

wire response_existing=memory_dout_ready&&(descriptor_count!=0);
wire descriptor_room=(descriptor_count<2)||response_existing;
assign memory_rd=active&&!all_issued&&descriptor_room;
wire issue_accept=memory_rd&&!memory_busy;
wire response_direct=memory_dout_ready&&(descriptor_count==0)&&issue_accept;
wire response_pop=memory_dout_ready&&(descriptor_count!=0);
wire descriptor_push=issue_accept&&!response_direct;
wire [2:0] descriptor_count_after=
    {1'b0,descriptor_count}+descriptor_push-response_pop;
assign outstanding_count=descriptor_count;

wire [5:0] lookup_slot=(lookup_phase?6'd18:6'd0)+
    {lookup_row,1'b0}+lookup_column;
wire [3:0] selected_lookup_rows=lookup_phase?phase1_rows:phase0_rows;
wire selected_lookup_two_words=lookup_phase?
    phase1_two_words:phase0_two_words;
wire lookup_in_range=(lookup_phase<phase_count)&&
    (lookup_row<selected_lookup_rows)&&
    (!lookup_column||selected_lookup_two_words);

integer clear_index;
always @(posedge clk) begin
    if(reset) begin
        word_valid<=36'd0;
        generator_phase<=1'b0;
        generator_row<=4'd0;
        generator_column<=1'b0;
        generator_row_addr<=29'd0;
        all_issued<=1'b0;
        descriptor_slot[0]<=6'd0;
        descriptor_slot[1]<=6'd0;
        descriptor_head<=1'b0;
        descriptor_tail<=1'b0;
        descriptor_count<=2'd0;
        lookup_ready<=1'b0;
        lookup_valid<=1'b0;
        lookup_data<=64'd0;
        active<=1'b0;
        complete<=1'b0;
        error<=1'b0;
        issued_count<=7'd0;
        returned_count<=7'd0;
        for(clear_index=0;clear_index<36;clear_index=clear_index+1)
            word_data[clear_index]<=64'd0;
    end else begin
        lookup_ready<=1'b0;

        if(start) begin
            complete<=1'b0;
            issued_count<=7'd0;
            returned_count<=7'd0;
            word_valid<=36'd0;
            descriptor_head<=1'b0;
            descriptor_tail<=1'b0;
            descriptor_count<=2'd0;
            generator_phase<=1'b0;
            generator_row<=4'd0;
            generator_column<=1'b0;
            generator_row_addr<=phase0_base_addr;
            all_issued<=1'b0;
            if(active||(phase_count<1)||(phase_count>2)||
               (phase0_rows<1)||(phase0_rows>9)||
               ((phase_count==2)&&
                ((phase1_rows<1)||(phase1_rows>9)))||
               (row_words==0)) begin
                active<=1'b0;
                error<=1'b1;
            end else begin
                active<=1'b1;
                error<=1'b0;
            end
        end else begin
            if(descriptor_push) begin
                descriptor_slot[descriptor_tail]<=generator_slot;
                descriptor_tail<=descriptor_tail+1'b1;
            end
            if(response_pop)
                descriptor_head<=descriptor_head+1'b1;

            case({descriptor_push,response_pop})
                2'b10:descriptor_count<=descriptor_count+1'b1;
                2'b01:descriptor_count<=descriptor_count-1'b1;
                default:descriptor_count<=descriptor_count;
            endcase

            if(issue_accept) begin
                issued_count<=issued_count+1'b1;
                if(generator_last) begin
                    all_issued<=1'b1;
                end else if(!generator_last_column) begin
                    generator_column<=1'b1;
                end else if(!generator_last_row) begin
                    generator_row<=generator_row+1'b1;
                    generator_column<=1'b0;
                    generator_row_addr<=generator_row_addr+
                        {22'd0,row_words};
                end else begin
                    generator_phase<=1'b1;
                    generator_row<=4'd0;
                    generator_column<=1'b0;
                    generator_row_addr<=phase1_base_addr;
                end
            end

            if(response_direct) begin
                word_data[generator_slot]<=memory_dout;
                word_valid[generator_slot]<=1'b1;
                returned_count<=returned_count+1'b1;
            end else if(response_pop) begin
                word_data[descriptor_slot[descriptor_head]]<=memory_dout;
                word_valid[descriptor_slot[descriptor_head]]<=1'b1;
                returned_count<=returned_count+1'b1;
            end else if(memory_dout_ready) begin
                error<=1'b1;
            end

            if((all_issued||(issue_accept&&generator_last))&&
               (descriptor_count_after==0)&&
               (!memory_dout_ready||response_direct||response_pop)) begin
                active<=1'b0;
                complete<=1'b1;
            end
        end

        if(lookup_request) begin
            lookup_ready<=1'b1;
            lookup_valid<=lookup_in_range&&word_valid[lookup_slot];
            if(lookup_in_range&&word_valid[lookup_slot])
                lookup_data<=word_data[lookup_slot];
            else
                lookup_data<=64'd0;
        end
    end
end

endmodule
