        default:;
        endcase
        match_motion_code={valid,code[5:0]};
    end
endfunction
wire [6:0] motion_match=match_motion_code(motion_bits_next,motion_len_next);

function automatic signed [7:0] reconstruct_mv_f3;
    input signed [7:0] pred; input signed [5:0] code; input [1:0] residual;
    reg [5:0] mag; reg signed [9:0] delta,vec;
    begin
        if(code==0)delta=0;
        else begin
            if(code<0)mag=-code;else mag=code;
            delta=(($signed({1'b0,mag})-1)<<<2)+$signed({8'd0,residual})+1;
            if(code<0)delta=-delta;
        end
        vec=$signed(pred)+delta;
        if(vec>63)vec=vec-128;else if(vec< -64)vec=vec+128;
        reconstruct_mv_f3=vec[7:0];
    end
endfunction

function automatic [5:0] direction_index;
    input [1:0] d;
    begin direction_index=(d==2'd1)?6'h38:(d==2'd2)?6'h39:6'h3a; end
endfunction

// H.262 Table B.9 coded_block_pattern for 4:2:0.
function automatic [6:0] match_cbp_code;
    input [8:0] bits; input [3:0] len;
    reg valid; reg [5:0] value;
    begin
        valid=0;value=0;
        case(len)
        4'd3: if(bits[2:0]==3'b111) begin valid=1;value=60;end
        4'd4: case(bits[3:0])
            4'b1010:begin valid=1;value=32;end
            4'b1011:begin valid=1;value=16;end
            4'b1100:begin valid=1;value=8;end
            4'b1101:begin valid=1;value=4;end
            default:;
        endcase
        4'd5: case(bits[4:0])
            5'b01000:begin valid=1;value=62;end
            5'b01001:begin valid=1;value=2;end
            5'b01010:begin valid=1;value=61;end
            5'b01011:begin valid=1;value=1;end
            5'b01100:begin valid=1;value=56;end
            5'b01101:begin valid=1;value=52;end
            5'b01110:begin valid=1;value=44;end
            5'b01111:begin valid=1;value=28;end
            5'b10000:begin valid=1;value=40;end
            5'b10001:begin valid=1;value=20;end
            5'b10010:begin valid=1;value=48;end
            5'b10011:begin valid=1;value=12;end
            default:;
        endcase
        4'd6: case(bits[5:0])
            6'b001100:begin valid=1;value=63;end
            6'b001101:begin valid=1;value=3;end
            6'b001110:begin valid=1;value=36;end
            6'b001111:begin valid=1;value=24;end
            default:;
        endcase
        4'd7: case(bits[6:0])
            7'b0010000:begin valid=1;value=34;end
            7'b0010001:begin valid=1;value=18;end
            7'b0010010:begin valid=1;value=10;end
            7'b0010011:begin valid=1;value=6;end
            7'b0010100:begin valid=1;value=33;end
            7'b0010101:begin valid=1;value=17;end
            7'b0010110:begin valid=1;value=9;end
            7'b0010111:begin valid=1;value=5;end
            default:;
        endcase
        4'd8: case(bits[7:0])
            8'b00000100:begin valid=1;value=58;end
            8'b00000101:begin valid=1;value=54;end
            8'b00000110:begin valid=1;value=46;end
            8'b00000111:begin valid=1;value=30;end
            8'b00001000:begin valid=1;value=57;end
            8'b00001001:begin valid=1;value=53;end
            8'b00001010:begin valid=1;value=45;end
            8'b00001011:begin valid=1;value=29;end
            8'b00001100:begin valid=1;value=38;end
            8'b00001101:begin valid=1;value=26;end
            8'b00001110:begin valid=1;value=37;end
            8'b00001111:begin valid=1;value=25;end
            8'b00010000:begin valid=1;value=43;end
            8'b00010001:begin valid=1;value=23;end
            8'b00010010:begin valid=1;value=51;end
            8'b00010011:begin valid=1;value=15;end
            8'b00010100:begin valid=1;value=42;end
            8'b00010101:begin valid=1;value=22;end
            8'b00010110:begin valid=1;value=50;end
            8'b00010111:begin valid=1;value=14;end
            8'b00011000:begin valid=1;value=41;end
            8'b00011001:begin valid=1;value=21;end
            8'b00011010:begin valid=1;value=49;end
            8'b00011011:begin valid=1;value=13;end
            8'b00011100:begin valid=1;value=35;end
            8'b00011101:begin valid=1;value=19;end
            8'b00011110:begin valid=1;value=11;end
            8'b00011111:begin valid=1;value=7;end
            default:;
        endcase
        4'd9: case(bits[8:0])
            9'b000000010:begin valid=1;value=39;end
            9'b000000011:begin valid=1;value=27;end
            9'b000000100:begin valid=1;value=59;end
            9'b000000101:begin valid=1;value=55;end
            9'b000000110:begin valid=1;value=47;end
            9'b000000111:begin valid=1;value=31;end
            default:;
