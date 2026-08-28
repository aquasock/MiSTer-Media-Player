// Stream-defined 4:2:0 weighting matrices: H.262 (02/2000) 6.3.11,
// 7.3.1 and 7.4.2. Matrix downloads ALWAYS use default zigzag order,
// independently of the picture's coefficient alternate_scan flag.
// Observe accepted ES bytes only. The decoder's row/picture retirement hold
// must keep header payloads behind the preceding transform transaction.
module mpeg2_h262_quant_matrices (
    input wire clk, reset,
    input wire [7:0] stream_data,
    input wire stream_valid,
    input wire [5:0] read_index,
    output wire [7:0] intra_weight, non_intra_weight,
    output reg intra_default, non_intra_default,
    output reg syntax_error,
    output wire update_now
);
reg [7:0] intra_mem [0:63];
reg [7:0] non_intra_mem [0:63];
reg [31:0] window;
reg [2:0] state;
localparam IDLE=0, SEQ=1, EXT=2, FLAG=3, WEIGHT=4;
reg [5:0] skip_bits;
reg [1:0] matrix_id;
reg [5:0] element;
reg [2:0] weight_bits;
reg [7:0] weight_shift;
reg sequence_header;
// A delimiter can complete the preceding row. Reset tables on the
// FIRST accepted header payload byte, after that row's hold has taken effect.
reg sequence_reset_pending;
wire [31:0] next_window={window[23:0],stream_data};
wire start_code=(next_window[31:8]==24'h000001);
reg [2:0] ns;
reg [5:0] nk, ne;
reg [1:0] nm;
reg [2:0] nb;
reg [7:0] nw, write_value;
reg write_enable, bad, mark_complete;
reg [1:0] write_matrix;
reg [5:0] write_index;
integer b;
function automatic [7:0] default_intra_weight;
    input [5:0] linear;
    begin
        case (linear)
             0: default_intra_weight =  8;  1: default_intra_weight = 16;
             2: default_intra_weight = 19;  3: default_intra_weight = 22;
             4: default_intra_weight = 26;  5: default_intra_weight = 27;
             6: default_intra_weight = 29;  7: default_intra_weight = 34;
             8: default_intra_weight = 16;  9: default_intra_weight = 16;
            10: default_intra_weight = 22; 11: default_intra_weight = 24;
            12: default_intra_weight = 27; 13: default_intra_weight = 29;
            14: default_intra_weight = 34; 15: default_intra_weight = 37;
            16: default_intra_weight = 19; 17: default_intra_weight = 22;
            18: default_intra_weight = 26; 19: default_intra_weight = 27;
            20: default_intra_weight = 29; 21: default_intra_weight = 34;
            22: default_intra_weight = 34; 23: default_intra_weight = 38;
            24: default_intra_weight = 22; 25: default_intra_weight = 22;
            26: default_intra_weight = 26; 27: default_intra_weight = 27;
            28: default_intra_weight = 29; 29: default_intra_weight = 34;
            30: default_intra_weight = 37; 31: default_intra_weight = 40;
            32: default_intra_weight = 22; 33: default_intra_weight = 26;
            34: default_intra_weight = 27; 35: default_intra_weight = 29;
            36: default_intra_weight = 32; 37: default_intra_weight = 35;
            38: default_intra_weight = 40; 39: default_intra_weight = 48;
            40: default_intra_weight = 26; 41: default_intra_weight = 27;
            42: default_intra_weight = 29; 43: default_intra_weight = 32;
            44: default_intra_weight = 35; 45: default_intra_weight = 40;
            46: default_intra_weight = 48; 47: default_intra_weight = 58;
            48: default_intra_weight = 26; 49: default_intra_weight = 27;
            50: default_intra_weight = 29; 51: default_intra_weight = 34;
            52: default_intra_weight = 38; 53: default_intra_weight = 46;
            54: default_intra_weight = 56; 55: default_intra_weight = 69;
            56: default_intra_weight = 27; 57: default_intra_weight = 29;
            58: default_intra_weight = 35; 59: default_intra_weight = 38;
            60: default_intra_weight = 46; 61: default_intra_weight = 56;
            62: default_intra_weight = 69; 63: default_intra_weight = 83;
            default: default_intra_weight = 8'd16;
        endcase
    end
endfunction
function automatic [5:0] zigzag;
    input [5:0] index;
    begin
        case(index)
            6'd0: zigzag=6'd0;
            6'd1: zigzag=6'd1;
            6'd2: zigzag=6'd8;
            6'd3: zigzag=6'd16;
            6'd4: zigzag=6'd9;
            6'd5: zigzag=6'd2;
            6'd6: zigzag=6'd3;
            6'd7: zigzag=6'd10;
            6'd8: zigzag=6'd17;
            6'd9: zigzag=6'd24;
            6'd10: zigzag=6'd32;
            6'd11: zigzag=6'd25;
            6'd12: zigzag=6'd18;
            6'd13: zigzag=6'd11;
            6'd14: zigzag=6'd4;
            6'd15: zigzag=6'd5;
            6'd16: zigzag=6'd12;
            6'd17: zigzag=6'd19;
            6'd18: zigzag=6'd26;
            6'd19: zigzag=6'd33;
            6'd20: zigzag=6'd40;
            6'd21: zigzag=6'd48;
            6'd22: zigzag=6'd41;
            6'd23: zigzag=6'd34;
            6'd24: zigzag=6'd27;
            6'd25: zigzag=6'd20;
            6'd26: zigzag=6'd13;
            6'd27: zigzag=6'd6;
            6'd28: zigzag=6'd7;
            6'd29: zigzag=6'd14;
            6'd30: zigzag=6'd21;
            6'd31: zigzag=6'd28;
            6'd32: zigzag=6'd35;
            6'd33: zigzag=6'd42;
            6'd34: zigzag=6'd49;
            6'd35: zigzag=6'd56;
            6'd36: zigzag=6'd57;
            6'd37: zigzag=6'd50;
            6'd38: zigzag=6'd43;
            6'd39: zigzag=6'd36;
            6'd40: zigzag=6'd29;
            6'd41: zigzag=6'd22;
            6'd42: zigzag=6'd15;
            6'd43: zigzag=6'd23;
            6'd44: zigzag=6'd30;
            6'd45: zigzag=6'd37;
            6'd46: zigzag=6'd44;
            6'd47: zigzag=6'd51;
            6'd48: zigzag=6'd58;
            6'd49: zigzag=6'd59;
            6'd50: zigzag=6'd52;
            6'd51: zigzag=6'd45;
            6'd52: zigzag=6'd38;
            6'd53: zigzag=6'd31;
            6'd54: zigzag=6'd39;
            6'd55: zigzag=6'd46;
            6'd56: zigzag=6'd53;
            6'd57: zigzag=6'd60;
            6'd58: zigzag=6'd61;
            6'd59: zigzag=6'd54;
            6'd60: zigzag=6'd47;
            6'd61: zigzag=6'd55;
            6'd62: zigzag=6'd62;
            6'd63: zigzag=6'd63;
        endcase
    end
endfunction
assign intra_weight=intra_default ? default_intra_weight(read_index) : intra_mem[read_index];
assign non_intra_weight=non_intra_default ? 8'd16 : non_intra_mem[read_index];
assign update_now=stream_valid && (sequence_reset_pending || write_enable);

// At most one weight completes per byte. A byte can also contain adjacent
// load flags (including the two forbidden chroma flags for 4:2:0).
always @* begin
    b=0;
    ns=state; nk=skip_bits; ne=element; nm=matrix_id;
    nb=weight_bits; nw=weight_shift;
    write_enable=0; write_value=0; write_matrix=0; write_index=0;
    bad=0; mark_complete=0;
    if (!start_code) begin
        if (state==EXT) begin
            if (stream_data[7:4]==4'h3) begin ns=FLAG; nk=0; nm=0; end
            else ns=IDLE;
        end
        for (b=7;b>=0;b=b-1) begin
            if ((state!=EXT)||(b<4)) begin
                case(ns)
                    SEQ: begin
                        if(nk==1) begin ns=FLAG; nk=0; end
                        else nk=nk-1'b1;
                    end
                    FLAG: begin
                        if(stream_data[b]) begin
                            if(nm[1]) bad=1;
                            ns=WEIGHT; ne=0; nb=0; nw=0;
                        end else if ((sequence_header && nm==1)||nm==3)
                            ns=IDLE;
                        else nm=nm+1'b1;
                    end
                    WEIGHT: begin
                        nw={nw[6:0],stream_data[b]};
                        if(nb==7) begin
                            write_enable=1; write_value=nw;
                            write_matrix=nm; write_index=zigzag(ne);
                            if(nw==0 || (!nm[0] && ne==0 && nw!=8)) bad=1;
                            if(ne==63) begin
                                mark_complete=1;
                                if((sequence_header && nm==1)||nm==3) ns=IDLE;
                                else begin ns=FLAG; nm=nm+1'b1; end
                            end else ne=ne+1'b1;
                            nb=0;
                        end else nb=nb+1'b1;
                    end
                    default: ;
                endcase
            end
        end
    end
end
always @(posedge clk) begin
    if(reset) begin
        window<=0; state<=IDLE; skip_bits<=0; matrix_id<=0;
        element<=0; weight_bits<=0; weight_shift<=0;
        sequence_header<=0; sequence_reset_pending<=0;
        intra_default<=1; non_intra_default<=1; syntax_error<=0;
    end else if(stream_valid) begin
        window<=next_window;
        if(start_code) begin
            if(state!=IDLE && state!=EXT) syntax_error<=1;
            state<=IDLE;
            if(next_window[7:0]==8'hb3) begin
                state<=SEQ; skip_bits<=62; matrix_id<=0;
                sequence_header<=1; sequence_reset_pending<=1;
            end else if(next_window[7:0]==8'hb5) begin
                state<=EXT; sequence_header<=0;
            end
        end else begin
            state<=ns; skip_bits<=nk; matrix_id<=nm; element<=ne;
            weight_bits<=nb; weight_shift<=nw;
            if(sequence_reset_pending) begin
                intra_default<=1; non_intra_default<=1;
                sequence_reset_pending<=0;
            end
            if(bad) syntax_error<=1;
            if(write_enable && !write_matrix[1]) begin
                if(!write_matrix[0]) intra_mem[write_index]<=write_value;
                else non_intra_mem[write_index]<=write_value;
                if(mark_complete) begin
                    if(!write_matrix[0]) intra_default<=0;
                    else non_intra_default<=0;
                end
            end
        end
    end
end
endmodule
