//============================================================================
// DVD authored-menu overlay
//
// The ARM helper sends a packed 720x480 two-bit SPU plane plus four-entry
// normal/highlight RGBA palettes through the in-band B9 record channel.  The
// plane is double-buffered in otherwise unused DDR frame regions 5 and 6.
// Two 23-word M10K line caches cover one even and one odd raster line; the
// native interlaced raster requests row N+2 during row N's horizontal blank.
//============================================================================

module mpeg2_h262_dvd_overlay
(
    input  wire        mem_clk,
    input  wire        mem_reset,

    input  wire  [7:0] record_data,
    input  wire        record_start,
    input  wire        record_last,
    input  wire        record_valid,
    output wire        record_ready,
    output reg         protocol_error,

    output wire  [7:0] writer_burstcnt,
    output wire [28:0] writer_addr,
    output wire        writer_rd,
    output wire [63:0] writer_din,
    output wire  [7:0] writer_be,
    output wire        writer_we,
    input  wire        writer_busy,

    output wire  [7:0] reader_burstcnt,
    output wire [28:0] reader_addr,
    output wire        reader_rd,
    input  wire        reader_busy,
    input  wire [63:0] reader_dout,
    input  wire        reader_dout_ready,

    input  wire        video_clk,
    input  wire        video_reset,
    input  wire        pixel_ce,
    input  wire [11:0] h_pos,
    input  wire [11:0] v_pos,
    input  wire        native_active,
    input  wire  [7:0] base_r,
    input  wire  [7:0] base_g,
    input  wire  [7:0] base_b,
    input  wire        base_de,
    output reg   [7:0] video_r,
    output reg   [7:0] video_g,
    output reg   [7:0] video_b
);

localparam [7:0] COMMAND_CLEAR  = 8'd0;
localparam [7:0] COMMAND_CONFIG = 8'd1;
localparam [7:0] COMMAND_DATA   = 8'd2;
localparam [7:0] COMMAND_COMMIT = 8'd3;
localparam [7:0] COMMAND_STYLE  = 8'd4;

localparam [28:0] PLANE0_BASE = 29'h06050000;
localparam [28:0] PLANE1_BASE = 29'h06060000;
localparam [16:0] PLANE_BYTES = 17'd86400;
localparam [13:0] PLANE_WORDS = 14'd10800;

reg [7:0] current_command;
reg [5:0] payload_index;
reg [16:0] received_bytes;
reg [13:0] write_word_index;
reg [2:0] write_byte_lane;
reg [63:0] write_word;
reg write_pending;
reg display_bank;

reg staging_visible;
reg staging_menu;
reg [127:0] staging_normal;
reg [127:0] staging_highlight;
reg [15:0] staging_x1, staging_y1, staging_x2, staging_y2;

reg published_visible;
reg published_menu;
reg [127:0] published_normal;
reg [127:0] published_highlight;
reg [15:0] published_x1, published_y1, published_x2, published_y2;
reg style_toggle_mem;
reg style_publish_pending;

reg [1:0] row_pending;
reg [8:0] row_pending_value [0:1];
reg [1:0] preload_mask;
reg plane_publish_pending;

reg [1:0] read_state;
localparam [1:0] READ_IDLE=2'd0, READ_ISSUE=2'd1, READ_RECEIVE=2'd2;
reg read_parity;
reg [8:0] read_row;
reg [4:0] read_word_index;

reg [5:0] cache_wr_addr;
reg [63:0] cache_wr_data;
reg cache_wr_en;
reg [8:0] row_tag_mem [0:1];
reg [1:0] row_tag_toggle_mem;

reg [1:0] row_request_toggle_sync0;
reg [1:0] row_request_toggle_sync1;
reg [1:0] row_request_toggle_seen;
reg [8:0] row_request_value_m1 [0:1];
reg [8:0] row_request_value_m2 [0:1];

wire writer_accept = write_pending && !writer_busy;
assign record_ready = !write_pending;
assign writer_burstcnt = write_pending ? 8'd1 : 8'd0;
assign writer_addr = (display_bank ? PLANE0_BASE : PLANE1_BASE) +
                     {15'd0, write_word_index};
assign writer_rd = 1'b0;
assign writer_din = write_word;
assign writer_be = 8'hff;
assign writer_we = write_pending;

wire [28:0] read_plane_base = display_bank ? PLANE1_BASE : PLANE0_BASE;
wire [28:0] read_row_word =
    ({20'd0,read_row} << 4) +
    ({20'd0,read_row} << 2) +
    ({20'd0,read_row} << 1) +
    {21'd0,read_row[8:1]};
assign reader_burstcnt = (read_state == READ_ISSUE) ? 8'd23 : 8'd0;
assign reader_addr = read_plane_base + read_row_word;
assign reader_rd = (read_state == READ_ISSUE);

integer init_index;
always @(posedge mem_clk) begin
    if (mem_reset) begin
        current_command <= COMMAND_CLEAR;
        payload_index <= 6'd0;
        received_bytes <= 17'd0;
        write_word_index <= 14'd0;
        write_byte_lane <= 3'd0;
        write_word <= 64'd0;
        write_pending <= 1'b0;
        display_bank <= 1'b0;
        staging_visible <= 1'b0;
        staging_menu <= 1'b0;
        staging_normal <= 128'd0;
        staging_highlight <= 128'd0;
        staging_x1 <= 16'd0;
        staging_y1 <= 16'd0;
        staging_x2 <= 16'd0;
        staging_y2 <= 16'd0;
        published_visible <= 1'b0;
        published_menu <= 1'b0;
        published_normal <= 128'd0;
        published_highlight <= 128'd0;
        published_x1 <= 16'd0;
        published_y1 <= 16'd0;
        published_x2 <= 16'd0;
        published_y2 <= 16'd0;
        style_toggle_mem <= 1'b0;
        style_publish_pending <= 1'b0;
        row_pending <= 2'b00;
        row_pending_value[0] <= 9'd0;
        row_pending_value[1] <= 9'd1;
        preload_mask <= 2'b00;
        plane_publish_pending <= 1'b0;
        read_state <= READ_IDLE;
        read_parity <= 1'b0;
        read_row <= 9'd0;
        read_word_index <= 5'd0;
        cache_wr_addr <= 6'd0;
        cache_wr_data <= 64'd0;
        cache_wr_en <= 1'b0;
        row_tag_mem[0] <= 9'h1ff;
        row_tag_mem[1] <= 9'h1ff;
        row_tag_toggle_mem <= 2'b00;
        row_request_toggle_sync0 <= 2'b00;
        row_request_toggle_sync1 <= 2'b00;
        row_request_toggle_seen <= 2'b00;
        row_request_value_m1[0] <= 9'd0;
        row_request_value_m1[1] <= 9'd1;
        row_request_value_m2[0] <= 9'd0;
        row_request_value_m2[1] <= 9'd1;
        protocol_error <= 1'b0;
    end
    else begin
        cache_wr_en <= 1'b0;

        row_request_toggle_sync0 <= row_request_toggle_video;
        row_request_toggle_sync1 <= row_request_toggle_sync0;
        row_request_value_m1[0] <= row_request_value_video[0];
        row_request_value_m1[1] <= row_request_value_video[1];
        row_request_value_m2[0] <= row_request_value_m1[0];
        row_request_value_m2[1] <= row_request_value_m1[1];
        for (init_index=0; init_index<2; init_index=init_index+1) begin
            if (row_request_toggle_sync1[init_index] !=
                row_request_toggle_seen[init_index]) begin
                row_request_toggle_seen[init_index] <=
                    row_request_toggle_sync1[init_index];
                if (row_pending[init_index])
                    protocol_error <= 1'b1;
                row_pending[init_index] <= 1'b1;
                row_pending_value[init_index] <=
                    row_request_value_m2[init_index];
            end
        end

        if (writer_accept) begin
            write_pending <= 1'b0;
            write_word_index <= write_word_index + 14'd1;
        end

        if (style_publish_pending) begin
            published_visible <= staging_visible;
            published_menu <= staging_menu;
            published_normal <= staging_normal;
            published_highlight <= staging_highlight;
            published_x1 <= staging_x1;
            published_y1 <= staging_y1;
            published_x2 <= staging_x2;
            published_y2 <= staging_y2;
            style_toggle_mem <= ~style_toggle_mem;
            style_publish_pending <= 1'b0;
        end

        if (record_valid && record_ready) begin
            if (record_start) begin
                current_command <= record_data;
                payload_index <= 6'd0;
                case (record_data)
                    COMMAND_CLEAR: begin
                        if (!record_last)
                            protocol_error <= 1'b1;
                        published_visible <= 1'b0;
                        style_toggle_mem <= ~style_toggle_mem;
                    end
                    COMMAND_CONFIG: begin
                        received_bytes <= 17'd0;
                        write_word_index <= 14'd0;
                        write_byte_lane <= 3'd0;
                        write_word <= 64'd0;
                        if (record_last)
                            protocol_error <= 1'b1;
                    end
                    COMMAND_DATA: begin
                        if (record_last)
                            protocol_error <= 1'b1;
                    end
                    COMMAND_COMMIT: begin
                        if (!record_last || received_bytes != PLANE_BYTES ||
                            write_byte_lane != 3'd0 || write_pending ||
                            write_word_index != PLANE_WORDS) begin
                            protocol_error <= 1'b1;
                        end
                        else begin
                            display_bank <= ~display_bank;
                            row_pending <= 2'b11;
                            row_pending_value[0] <= 9'd0;
                            row_pending_value[1] <= 9'd1;
                            preload_mask <= 2'b11;
                            plane_publish_pending <= 1'b1;
                        end
                    end
                    COMMAND_STYLE: begin
                        if (record_last)
                            protocol_error <= 1'b1;
                    end
                    default: protocol_error <= 1'b1;
                endcase
            end
            else begin
                payload_index <= payload_index + 6'd1;
                if (current_command == COMMAND_DATA) begin
                    if (received_bytes == PLANE_BYTES)
                        protocol_error <= 1'b1;
                    else begin
                        write_word[write_byte_lane*8 +: 8] <= record_data;
                        received_bytes <= received_bytes + 17'd1;
                        if (write_byte_lane == 3'd7) begin
                            write_pending <= 1'b1;
                            write_byte_lane <= 3'd0;
                        end
                        else
                            write_byte_lane <= write_byte_lane + 3'd1;
                    end
                end
                else if (current_command == COMMAND_CONFIG ||
                         current_command == COMMAND_STYLE) begin
                    if (payload_index == 6'd0) begin
                        staging_visible <= record_data[0];
                        staging_menu <= record_data[1];
                    end
                    else if (payload_index <= 6'd16)
                        staging_normal[(payload_index-1)*8 +: 8] <= record_data;
                    else if (payload_index <= 6'd32)
                        staging_highlight[(payload_index-17)*8 +: 8] <= record_data;
                    else begin
                        case (payload_index)
                            6'd33: staging_x1[15:8] <= record_data;
                            6'd34: staging_x1[7:0]  <= record_data;
                            6'd35: staging_y1[15:8] <= record_data;
                            6'd36: staging_y1[7:0]  <= record_data;
                            6'd37: staging_x2[15:8] <= record_data;
                            6'd38: staging_x2[7:0]  <= record_data;
                            6'd39: staging_y2[15:8] <= record_data;
                            6'd40: staging_y2[7:0]  <= record_data;
                            default: protocol_error <= 1'b1;
                        endcase
                    end
                    if (record_last) begin
                        if (payload_index != 6'd40)
                            protocol_error <= 1'b1;
                        else if (current_command == COMMAND_STYLE)
                            style_publish_pending <= 1'b1;
                    end
                end
                else
                    protocol_error <= 1'b1;
            end
        end

        case (read_state)
            READ_IDLE: begin
                if (row_pending[0]) begin
                    read_parity <= 1'b0;
                    read_row <= row_pending_value[0];
                    read_word_index <= 5'd0;
                    read_state <= READ_ISSUE;
                end
                else if (row_pending[1]) begin
                    read_parity <= 1'b1;
                    read_row <= row_pending_value[1];
                    read_word_index <= 5'd0;
                    read_state <= READ_ISSUE;
                end
            end
            READ_ISSUE: begin
                if (!reader_busy)
                    read_state <= READ_RECEIVE;
            end
            READ_RECEIVE: begin
                if (reader_dout_ready) begin
                    cache_wr_addr <= (read_parity ? 6'd23 : 6'd0) +
                                     {1'b0,read_word_index};
                    cache_wr_data <= reader_dout;
                    cache_wr_en <= 1'b1;
                    if (read_word_index == 5'd22) begin
                        row_pending[read_parity] <= 1'b0;
                        row_tag_mem[read_parity] <= read_row;
                        row_tag_toggle_mem[read_parity] <=
                            ~row_tag_toggle_mem[read_parity];
                        preload_mask[read_parity] <= 1'b0;
                        read_state <= READ_IDLE;
                        if (plane_publish_pending &&
                            ((preload_mask & ~(2'b01 << read_parity)) == 2'b00)) begin
                            published_visible <= staging_visible;
                            published_menu <= staging_menu;
                            published_normal <= staging_normal;
                            published_highlight <= staging_highlight;
                            published_x1 <= staging_x1;
                            published_y1 <= staging_y1;
                            published_x2 <= staging_x2;
                            published_y2 <= staging_y2;
                            style_toggle_mem <= ~style_toggle_mem;
                            plane_publish_pending <= 1'b0;
                        end
                    end
                    else
                        read_word_index <= read_word_index + 5'd1;
                end
            end
            default: read_state <= READ_IDLE;
        endcase
    end
end

wire [5:0] cache_rd_addr;
wire [63:0] cache_rd_word;

altsyncram #(
    .operation_mode                 ("DUAL_PORT"),
    .width_a                        (64),
    .widthad_a                      (6),
    .numwords_a                     (46),
    .width_b                        (64),
    .widthad_b                      (6),
    .numwords_b                     (46),
    .outdata_reg_b                  ("UNREGISTERED"),
    .address_reg_b                  ("CLOCK1"),
    .read_during_write_mode_mixed_ports ("DONT_CARE"),
    .ram_block_type                 ("M10K"),
    .intended_device_family         ("Cyclone V")
) dvd_overlay_line_cache (
    .clock0         (mem_clk),
    .clock1         (video_clk),
    .address_a      (cache_wr_addr),
    .data_a         (cache_wr_data),
    .wren_a         (cache_wr_en),
    .address_b      (cache_rd_addr),
    .q_b            (cache_rd_word),
    .aclr0          (1'b0),
    .aclr1          (1'b0),
    .addressstall_a (1'b0),
    .addressstall_b (1'b0),
    .byteena_a      (1'b1),
    .byteena_b      (1'b1),
    .data_b         (64'd0),
    .wren_b         (1'b0),
    .q_a            ()
);

reg [1:0] row_request_toggle_video;
reg [8:0] row_request_value_video [0:1];
reg [2:0] style_toggle_sync;
reg style_toggle_seen;
reg [127:0] normal_v1, normal_v2, highlight_v1, highlight_v2;
reg [15:0] x1_v1,y1_v1,x2_v1,y2_v1;
reg [15:0] x1_v2,y1_v2,x2_v2,y2_v2;
reg visible_v1,visible_v2,menu_v1,menu_v2;
reg [127:0] normal_visible, highlight_visible;
reg [15:0] x1_visible,y1_visible,x2_visible,y2_visible;
reg visible_video, menu_video;
reg [2:0] row_tag_toggle0_sync,row_tag_toggle1_sync;
reg [1:0] row_tag_toggle_seen_video;
reg [8:0] row_tag0_v1,row_tag0_v2,row_tag1_v1,row_tag1_v2;
reg [8:0] row_tag_visible [0:1];

wire [8:0] overlay_byte_index = {1'b0,h_pos[9:2]} +
                                (v_pos[0] ? 9'd4 : 9'd0);
wire [4:0] overlay_word_index = overlay_byte_index[8:3];
wire [2:0] overlay_byte_lane = overlay_byte_index[2:0];
assign cache_rd_addr = (v_pos[0] ? 6'd23 : 6'd0) +
                       {1'b0,overlay_word_index};

reg [7:0] packed_pixels;
always @* begin
    case (overlay_byte_lane)
        3'd0: packed_pixels = cache_rd_word[7:0];
        3'd1: packed_pixels = cache_rd_word[15:8];
        3'd2: packed_pixels = cache_rd_word[23:16];
        3'd3: packed_pixels = cache_rd_word[31:24];
        3'd4: packed_pixels = cache_rd_word[39:32];
        3'd5: packed_pixels = cache_rd_word[47:40];
        3'd6: packed_pixels = cache_rd_word[55:48];
        default: packed_pixels = cache_rd_word[63:56];
    endcase
end

reg [1:0] color_index;
always @* begin
    case (h_pos[1:0])
        2'd0: color_index = packed_pixels[7:6];
        2'd1: color_index = packed_pixels[5:4];
        2'd2: color_index = packed_pixels[3:2];
        default: color_index = packed_pixels[1:0];
    endcase
end

wire highlight_active = menu_video &&
    (h_pos >= x1_visible) && (h_pos <= x2_visible) &&
    (v_pos >= y1_visible) && (v_pos <= y2_visible);
wire [127:0] selected_palette = highlight_active ?
    highlight_visible : normal_visible;
wire [31:0] selected_rgba = selected_palette[color_index*32 +: 32];
wire [7:0] overlay_r = selected_rgba[7:0];
wire [7:0] overlay_g = selected_rgba[15:8];
wire [7:0] overlay_b = selected_rgba[23:16];
wire [7:0] overlay_a = selected_rgba[31:24];
wire overlay_sample_valid = visible_video && native_active && base_de &&
    (h_pos < 12'd720) && (v_pos < 12'd480) &&
    (row_tag_visible[v_pos[0]] == v_pos[8:0]);

function automatic [7:0] blend_channel;
    input [7:0] background;
    input [7:0] foreground;
    input [7:0] alpha;
    reg [16:0] total;
    begin
        if (alpha == 8'd0)
            blend_channel = background;
        else if (alpha == 8'hff)
            blend_channel = foreground;
        else begin
            total = foreground * alpha + background * (8'hff-alpha) + 17'd128;
            blend_channel = (total + {9'd0,total[16:8]}) >> 8;
        end
    end
endfunction

always @(posedge video_clk) begin
    if (video_reset) begin
        row_request_toggle_video <= 2'b00;
        row_request_value_video[0] <= 9'd0;
        row_request_value_video[1] <= 9'd1;
        style_toggle_sync <= 3'b000;
        style_toggle_seen <= 1'b0;
        normal_v1 <= 128'd0;
        normal_v2 <= 128'd0;
        highlight_v1 <= 128'd0;
        highlight_v2 <= 128'd0;
        x1_v1<=0;y1_v1<=0;x2_v1<=0;y2_v1<=0;
        x1_v2<=0;y1_v2<=0;x2_v2<=0;y2_v2<=0;
        visible_v1<=0;visible_v2<=0;menu_v1<=0;menu_v2<=0;
        normal_visible <= 128'd0;
        highlight_visible <= 128'd0;
        x1_visible<=0;y1_visible<=0;x2_visible<=0;y2_visible<=0;
        visible_video <= 1'b0;
        menu_video <= 1'b0;
        row_tag_toggle0_sync <= 3'b000;
        row_tag_toggle1_sync <= 3'b000;
        row_tag_toggle_seen_video <= 2'b00;
        row_tag0_v1<=9'h1ff;row_tag0_v2<=9'h1ff;
        row_tag1_v1<=9'h1ff;row_tag1_v2<=9'h1ff;
        row_tag_visible[0]<=9'h1ff;row_tag_visible[1]<=9'h1ff;
        video_r <= 8'd0;
        video_g <= 8'd0;
        video_b <= 8'd0;
    end
    else begin
        style_toggle_sync <= {style_toggle_sync[1:0],style_toggle_mem};
        normal_v1 <= published_normal;
        normal_v2 <= normal_v1;
        highlight_v1 <= published_highlight;
        highlight_v2 <= highlight_v1;
        x1_v1<=published_x1;y1_v1<=published_y1;
        x2_v1<=published_x2;y2_v1<=published_y2;
        x1_v2<=x1_v1;y1_v2<=y1_v1;x2_v2<=x2_v1;y2_v2<=y2_v1;
        visible_v1<=published_visible;visible_v2<=visible_v1;
        menu_v1<=published_menu;menu_v2<=menu_v1;

        row_tag_toggle0_sync <=
            {row_tag_toggle0_sync[1:0],row_tag_toggle_mem[0]};
        row_tag_toggle1_sync <=
            {row_tag_toggle1_sync[1:0],row_tag_toggle_mem[1]};
        row_tag0_v1<=row_tag_mem[0];row_tag0_v2<=row_tag0_v1;
        row_tag1_v1<=row_tag_mem[1];row_tag1_v2<=row_tag1_v1;

        if (style_toggle_sync[2] != style_toggle_seen) begin
            style_toggle_seen <= style_toggle_sync[2];
            normal_visible <= normal_v2;
            highlight_visible <= highlight_v2;
            x1_visible<=x1_v2;y1_visible<=y1_v2;
            x2_visible<=x2_v2;y2_visible<=y2_v2;
            visible_video<=visible_v2;menu_video<=menu_v2;
        end
        if (row_tag_toggle0_sync[2] != row_tag_toggle_seen_video[0]) begin
            row_tag_toggle_seen_video[0] <= row_tag_toggle0_sync[2];
            row_tag_visible[0] <= row_tag0_v2;
        end
        if (row_tag_toggle1_sync[2] != row_tag_toggle_seen_video[1]) begin
            row_tag_toggle_seen_video[1] <= row_tag_toggle1_sync[2];
            row_tag_visible[1] <= row_tag1_v2;
        end

        if (pixel_ce && native_active && h_pos == 12'd720 &&
            v_pos < 12'd478) begin
            row_request_value_video[v_pos[0]] <= v_pos[8:0] + 9'd2;
            row_request_toggle_video[v_pos[0]] <=
                ~row_request_toggle_video[v_pos[0]];
        end

        if (pixel_ce) begin
            if (overlay_sample_valid && overlay_a != 8'd0) begin
                video_r <= blend_channel(base_r,overlay_r,overlay_a);
                video_g <= blend_channel(base_g,overlay_g,overlay_a);
                video_b <= blend_channel(base_b,overlay_b,overlay_a);
            end
            else begin
                video_r <= base_r;
                video_g <= base_g;
                video_b <= base_b;
            end
        end
    end
end

endmodule
