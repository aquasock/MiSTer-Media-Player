// MPEG-1 Layer II, 48 kHz, 112..384 kb/s stereo/dual/joint stereo.
// One bounded frame buffer; no HPS software or soft CPU. CRC-protected frames
// are explicitly rejected until CRC checking is implemented.
module mp2_decoder (
    input wire clk, reset,
    input wire [7:0] input_data,
    input wire input_valid,
    output wire input_ready,
    input wire input_end,
    input wire [32:0] input_pts,
    input wire input_pts_valid,
    output wire pcm_valid,
    input wire pcm_ready,
    output wire signed [15:0] pcm_left, pcm_right,
    output reg [32:0] pcm_pts,
    output reg pcm_pts_valid,
    output reg error,
    output reg [31:0] frames_decoded,
    output wire idle
);
localparam COLLECT=0, HEADER=1, BEGIN_FRAME=2, GET_WAIT=3, GET_BIT=4,
    ALLOC=5, ALLOC_DONE=6, SCFSI=7, SCFSI_DONE=8, SCALE=9, SCALE_DONE=10,
    SAMPLES=11, CODE_DONE=12, UNGROUP=13, REQUANT=14, REQUANT_WAIT=15,
    REQUANT_MUL=16, STORE=17, ADVANCE=18, ZERO=19, SYNTH_START=20,
    SYNTH_WAIT=21, FINISH=22, FAILED=23;
reg [4:0] state, return_state;
reg [7:0] frame_mem [0:2047];
reg [10:0] received, frame_size;
reg [31:0] header;
reg [13:0] bit_pos;
reg [4:0] bits_left;
reg [15:0] bits_value;
reg [7:0] byte_q;
reg [4:0] sb, bound;
reg channel;
reg [1:0] part, sample_index, scale_index;
reg [1:0] granule;
reg [4:0] allocation [0:63];
reg [1:0] scfsi [0:63];
reg [5:0] scalefactor [0:191];
reg [4:0] quant;
reg [15:0] codes [0:2];
reg [15:0] grouped_code;
reg [15:0] remainder, quotient;
reg [3:0] divide_bit;
reg [3:0] group_levels;
reg [1:0] group_index;
reg shared_right;
reg [7:0] zero_addr;
reg sample_wr, synth_start;
reg [7:0] sample_addr;
reg signed [23:0] sample_data;
wire synth_busy, synth_done;
reg [32:0] pending_pts;
reg pending_pts_valid;
reg [32:0] frame_pts;
reg frame_pts_valid;
reg [30:0] scale_rom [0:1151];
reg [30:0] scale_q;
reg signed [16:0] centered;
reg signed [48:0] scaled_product;
wire [5:0] ach={sb,channel};
wire [7:0] sf_addr={2'd0,sb,channel}*8'd3+{6'd0,part};
wire [16:0] trial_remainder={remainder,grouped_code[divide_bit]};
wire [15:0] levels = quant==1 ? 16'd3 : quant==2 ? 16'd5 : quant==3 ? 16'd7 :
    quant==4 ? 16'd9 : (16'hffff >> (17-quant));
assign input_ready = state==COLLECT && !error;
assign idle=state==COLLECT && received==0;
initial $readmemh("rtl/audio/mp2_scale.hex",scale_rom);
mp2_synthesis synthesis (
    .clk(clk),.reset(reset),.sample_wr(sample_wr),.sample_addr(sample_addr),
    .sample_data(sample_data),.start(synth_start),.busy(synth_busy),.done(synth_done),
    .pcm_valid(pcm_valid),.pcm_ready(pcm_ready),.pcm_left(pcm_left),.pcm_right(pcm_right)
);
function [10:0] bytes_for_rate;
    input [3:0] idx;
    begin case(idx)
        7:bytes_for_rate=336;8:bytes_for_rate=384;9:bytes_for_rate=480;
        10:bytes_for_rate=576;11:bytes_for_rate=672;12:bytes_for_rate=768;
        13:bytes_for_rate=960;14:bytes_for_rate=1152;
        default:bytes_for_rate=0;
    endcase end
endfunction
function [4:0] quant_id;
    input [4:0] band; input [3:0] code;
    begin
        if(code==0) quant_id=0;
        else if(band<3) begin
            if(code==1) quant_id=1;
            else if(code==2) quant_id=3;
            else quant_id={1'b0,code}+5'd2;
        end else if(band<11) quant_id=code==15 ? 5'd17 : {1'b0,code};
        else if(band<23) quant_id=code==7 ? 5'd17 : {1'b0,code};
        else quant_id=code==3 ? 5'd17 : {1'b0,code};
    end
endfunction
function [4:0] quant_bits;
    input [4:0] q;
    begin case(q)
        1:quant_bits=5;2:quant_bits=7;3:quant_bits=3;4:quant_bits=10;
        default:quant_bits=q-1;
    endcase end
endfunction
task get_bits;
    input [4:0] n;
    input [4:0] dest;
    begin
        if(bit_pos+{9'd0,n}>{frame_size,3'b000}) begin error<=1; state<=FAILED; end
        else begin bits_left<=n; bits_value<=0; return_state<=dest; state<=GET_WAIT; end
    end
endtask
task next_band;
    input [4:0] again;
    input [4:0] after_bands;
    begin
        channel<=~channel;
        if(channel) begin
            channel<=0;
            if(sb==26) begin sb<=0; state<=after_bands; end
            else begin sb<=sb+5'd1; state<=again; end
        end else state<=again;
    end
endtask
always @(posedge clk) begin
    byte_q<=frame_mem[bit_pos[13:3]];
    scale_q<=scale_rom[{quant,scalefactor[sf_addr]}];
    scaled_product<=centered*$signed({1'b0,scale_q});
    sample_wr<=0; synth_start<=0;
    if(reset) begin
        state<=COLLECT; received<=0; frame_size<=0; header<=0; bit_pos<=0;
        error<=0; frames_decoded<=0; pending_pts_valid<=0;
        frame_pts<=0; frame_pts_valid<=0; pcm_pts<=0; pcm_pts_valid<=0;
        sb<=0; channel<=0; part<=0; granule<=0; sample_index<=0;
        scale_index<=0; shared_right<=0; quant<=0; centered<=0;
    end else begin
        if(pcm_valid&&pcm_ready) pcm_pts_valid<=0;
        if(input_valid&&input_ready&&input_pts_valid) begin pending_pts<=input_pts; pending_pts_valid<=1; end
        case(state)
        COLLECT: begin
            if(input_valid) begin
                frame_mem[received]<=input_data;
                if(received<4) header<={header[23:0],input_data};
                if(received==0) begin
                    if(input_pts_valid||pending_pts_valid) begin
                        frame_pts<=input_pts_valid ? input_pts : pending_pts;
                        frame_pts_valid<=1; pending_pts_valid<=0;
                    end
                end
                received<=received+11'd1;
                if(received==3) state<=HEADER;
                else if(received>=4 && received+11'd1==frame_size) state<=BEGIN_FRAME;
            end else if(input_end && received!=0) begin error<=1; state<=FAILED; end
        end
        HEADER: begin
            if(header[31:21]!=11'h7ff || header[20:19]!=3 || header[18:17]!=2 ||
               !header[16] || header[11:10]!=1 || header[7:6]==3 ||
               bytes_for_rate(header[15:12])==0) begin error<=1; state<=FAILED; end
            else begin
                frame_size<=bytes_for_rate(header[15:12])+{10'd0,header[9]};
                bound<=header[7:6]==1 ? ({3'd0,header[5:4]}+5'd1)<<2 : 5'd27;
                state<=COLLECT;
            end
        end
        BEGIN_FRAME: begin
            zero_addr<=0; bit_pos<=32; sb<=0; channel<=0; part<=0; granule<=0;
            pcm_pts<=frame_pts; pcm_pts_valid<=frame_pts_valid;
            state<=ALLOC;
        end
        GET_WAIT: state<=GET_BIT;
        GET_BIT: begin
            bits_value<={bits_value[14:0],byte_q[7-bit_pos[2:0]]};
            bit_pos<=bit_pos+14'd1; bits_left<=bits_left-5'd1;
            state<=bits_left==1 ? return_state : GET_WAIT;
        end
        ALLOC: get_bits(sb<11 ? 5'd4 : sb<23 ? 5'd3 : 5'd2,ALLOC_DONE);
        ALLOC_DONE: begin
            allocation[ach]<=quant_id(sb,bits_value[3:0]);
            if(sb>=bound) begin
                allocation[{sb,1'b1}]<=quant_id(sb,bits_value[3:0]); channel<=0;
                if(sb==26) begin sb<=0; state<=SCFSI; end
                else begin sb<=sb+5'd1; state<=ALLOC; end
            end else next_band(ALLOC,SCFSI);
        end
        SCFSI: begin
            if(allocation[ach]!=0) get_bits(2,SCFSI_DONE);
            else next_band(SCFSI,SCALE);
        end
        SCFSI_DONE: begin scfsi[ach]<=bits_value[1:0]; next_band(SCFSI,SCALE); end
        SCALE: begin
            if(allocation[ach]!=0) get_bits(6,SCALE_DONE);
            else next_band(SCALE,ZERO);
        end
        SCALE_DONE: begin
            case(scfsi[ach])
            0: begin
                scalefactor[ach*3+scale_index]<=bits_value[5:0];
                if(scale_index==2) begin scale_index<=0; next_band(SCALE,ZERO); end
                else begin scale_index<=scale_index+2'd1; state<=SCALE; end
            end
            1: if(scale_index==0) begin
                scalefactor[ach*3]<=bits_value[5:0]; scalefactor[ach*3+1]<=bits_value[5:0];
                scale_index<=2; state<=SCALE;
            end else begin scalefactor[ach*3+2]<=bits_value[5:0]; scale_index<=0; next_band(SCALE,ZERO); end
            2: begin
                scalefactor[ach*3]<=bits_value[5:0]; scalefactor[ach*3+1]<=bits_value[5:0]; scalefactor[ach*3+2]<=bits_value[5:0];
                next_band(SCALE,ZERO);
            end
            3: if(scale_index==0) begin
                scalefactor[ach*3]<=bits_value[5:0]; scale_index<=1; state<=SCALE;
            end else begin
                scalefactor[ach*3+1]<=bits_value[5:0]; scalefactor[ach*3+2]<=bits_value[5:0];
                scale_index<=0; next_band(SCALE,ZERO);
            end
            endcase
            zero_addr<=0;
        end
        ZERO: begin
            sample_wr<=1; sample_addr<=zero_addr; sample_data<=0;
            if(zero_addr==191) begin sb<=0; channel<=0; sample_index<=0; shared_right<=0; state<=SAMPLES; end
            else zero_addr<=zero_addr+8'd1;
        end
        SAMPLES: begin
            quant<=allocation[ach];
            if(allocation[ach]==0) state<=ADVANCE;
            else get_bits(quant_bits(allocation[ach]),CODE_DONE);
        end
        CODE_DONE: begin
            if(quant==1||quant==2||quant==4) begin
                grouped_code<=bits_value; group_levels<=quant==1?4'd3:quant==2?4'd5:4'd9;
                group_index<=0; divide_bit<=15; remainder<=0; quotient<=0; state<=UNGROUP;
                // Unused grouped codewords are malformed rather than wrapped.
                if((quant==1&&bits_value>=27)||(quant==2&&bits_value>=125)||(quant==4&&bits_value>=729)) begin error<=1; state<=FAILED; end
            end else begin
                codes[sample_index]<=bits_value;
                if(bits_value>=levels) begin error<=1; state<=FAILED; end
                else if(sample_index==2) begin sample_index<=0; state<=REQUANT; end
                else begin sample_index<=sample_index+2'd1; state<=SAMPLES; end
            end
        end
        UNGROUP: begin
            if(trial_remainder>={13'd0,group_levels}) begin remainder<=trial_remainder[15:0]-{12'd0,group_levels}; quotient[divide_bit]<=1; end
            else begin remainder<=trial_remainder[15:0]; quotient[divide_bit]<=0; end
            if(divide_bit==0) begin
                codes[group_index]<=trial_remainder>={13'd0,group_levels} ? trial_remainder[15:0]-{12'd0,group_levels} : trial_remainder[15:0];
                if(group_index==2) begin sample_index<=0; state<=REQUANT; end
                else begin
                    grouped_code<={quotient[15:1],trial_remainder>={13'd0,group_levels}};
                    group_index<=group_index+2'd1; divide_bit<=15; remainder<=0; quotient<=0;
                end
            end else divide_bit<=divide_bit-4'd1;
        end
        REQUANT: begin centered<=$signed({1'b0,codes[sample_index]})-$signed({2'b00,levels[15:1]}); state<=REQUANT_WAIT; end
        REQUANT_WAIT: state<=REQUANT_MUL;
        REQUANT_MUL: state<=STORE;
        STORE: begin
            sample_wr<=1; sample_addr<={sample_index,channel,sb}; sample_data<=scaled_product[33:10];
            if(sample_index!=2) begin sample_index<=sample_index+2'd1; state<=REQUANT; end
            else if(sb>=bound&&!shared_right) begin
                shared_right<=1; channel<=1; sample_index<=0; state<=REQUANT;
            end else begin sample_index<=0; shared_right<=0; state<=ADVANCE; end
        end
        ADVANCE: begin
            if(sb<bound&&!channel) begin channel<=1; state<=SAMPLES; end
            else begin
                channel<=0;
                if(sb==26) state<=SYNTH_START;
                else begin sb<=sb+5'd1; state<=SAMPLES; end
            end
        end
        SYNTH_START: if(!synth_busy) begin synth_start<=1; state<=SYNTH_WAIT; end
        SYNTH_WAIT: if(synth_done) begin
            zero_addr<=0;
            if(granule==3) begin
                granule<=0;
                if(part==2) state<=FINISH;
                else begin part<=part+2'd1; state<=ZERO; end
            end else begin granule<=granule+2'd1; state<=ZERO; end
        end
        FINISH: begin frames_decoded<=frames_decoded+32'd1; frame_pts<=frame_pts+33'd2160; received<=0; state<=COLLECT; end
        FAILED: error<=1;
        default: begin error<=1; state<=FAILED; end
        endcase
    end
end
endmodule
