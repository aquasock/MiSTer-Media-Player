`timescale 1ns/1ps

module altsyncram #(
    parameter operation_mode="", width_a=1, widthad_a=1, numwords_a=1,
    width_b=1, widthad_b=1, numwords_b=1, outdata_reg_b="",
    address_reg_b="", read_during_write_mode_mixed_ports="",
    ram_block_type="", intended_device_family=""
)(
    input clock0, input clock1,
    input [widthad_a-1:0] address_a,
    input [width_a-1:0] data_a, input wren_a,
    input [widthad_b-1:0] address_b,
    output [width_b-1:0] q_b,
    input aclr0, input aclr1, input addressstall_a, input addressstall_b,
    input byteena_a, input byteena_b,
    input [width_b-1:0] data_b, input wren_b,
    output [width_a-1:0] q_a
);
reg [width_a-1:0] memory [0:numwords_a-1];
reg [widthad_b-1:0] address_b_q;
reg corrupted = 1'b0;
wire corrupt_mode = $test$plusargs("CORRUPT");
always @(posedge clock0) begin
    if (wren_a) begin
        if (corrupt_mode && (numwords_a == 180) &&
            !corrupted && (address_a == 10)) begin
            memory[address_a] <= data_a ^ {{(width_a-1){1'b0}},1'b1};
            corrupted <= 1'b1;
        end
        else begin
            memory[address_a] <= data_a;
        end
    end
end
always @(posedge clock1)
    address_b_q <= address_b;
assign q_b = memory[address_b_q];
assign q_a = {width_a{1'b0}};
endmodule

module tb_native_480i_cache_refill;

reg mem_clk = 1'b0;
reg rd_clk = 1'b0;
reg reset = 1'b1;
reg picture_complete = 1'b0;
reg running = 1'b0;
reg [1:0] ce_div = 2'd0;
reg [11:0] h_pos = 12'd0;
reg [8:0] sequence_line = 9'd0;
reg fingerprint_mode = 1'b0;
reg bff_mode = 1'b0;
reg generation_mode = 1'b0;
reg [7:0] framebuffer_generation = 8'h2a;

always #8.333 mem_clk = ~mem_clk;
always #9.259 rd_clk = ~rd_clk;

wire pixel_ce = (ce_div == 2'd3);
wire pixel_en = running && (h_pos < 12'd720);
wire [8:0] field_line = (sequence_line < 9'd240) ?
    sequence_line : (sequence_line - 9'd240);
wire field_parity = (sequence_line < 9'd240) ?
    bff_mode : ~bff_mode;
wire [11:0] v_pos = {2'd0,field_line,1'b0} + field_parity;

wire [7:0] ddram_burstcnt;
wire [28:0] ddram_addr;
wire ddram_rd;
reg [63:0] ddram_dout = 64'h8080808080808080;
reg ddram_dout_ready = 1'b0;
wire cache_ready;
wire read_seen;
wire cache_error;
wire bank_overlap_error;
wire picture_present_debug;
wire prefill_deadline_missed_debug;
wire luma_fingerprint_valid_debug;
wire luma_fingerprint_first_field_debug;
wire [31:0] luma_fingerprint_raw_debug;
wire [31:0] luma_fingerprint_display_debug;
wire luma_fingerprint_mismatch_debug;
wire luma_provenance_valid_debug;
wire luma_provenance_first_field_debug;
wire luma_provenance_tag_mismatch_debug;
wire luma_provenance_content_mismatch_debug;
wire luma_provenance_expected_bank_debug;
wire luma_provenance_tagged_bank_debug;
wire [10:0] luma_provenance_expected_row_debug;
wire [10:0] luma_provenance_tagged_row_debug;
wire [7:0] luma_provenance_expected_generation_debug;
wire [7:0] luma_provenance_tagged_generation_debug;
wire [31:0] luma_provenance_raw_fingerprint_debug;
wire [31:0] luma_provenance_display_fingerprint_debug;
wire luma_write_read_valid_debug;
wire luma_write_read_first_field_debug;
wire luma_write_read_expected_valid_debug;
wire [2:0] luma_write_read_region_debug;
wire [31:0] luma_write_read_expected_fingerprint_debug;
wire [31:0] luma_write_read_raw_fingerprint_debug;
wire luma_write_read_mismatch_debug;
reg [31:0] expected_even_field_fingerprint = 32'd0;
reg [31:0] expected_odd_field_fingerprint = 32'd0;
wire write_read_expected_valid = !$test$plusargs("WRITE_INVALID");
wire [7:0] video_r;
wire [7:0] video_g;
wire [7:0] video_b;
wire video_de;
wire video_hs;
wire video_vs;

mpeg2_luma_framebuffer dut
(
    .reset              (reset),
    .mem_clk            (mem_clk),
    .picture_complete   (picture_complete),
    .horizontal_size    (14'd720),
    .vertical_size      (14'd480),
    .native_interlaced  (1'b1),
    .top_field_first    (~bff_mode),
    .framebuffer_generation(framebuffer_generation),
    .write_read_expected_region(3'd0),
    .write_read_expected_valid(write_read_expected_valid),
    .write_read_expected_even_fingerprint(expected_even_field_fingerprint),
    .write_read_expected_odd_fingerprint(expected_odd_field_fingerprint),
    .ddram_busy         (1'b0),
    .ddram_dout         (ddram_dout),
    .ddram_dout_ready   (ddram_dout_ready),
    .ddram_burstcnt     (ddram_burstcnt),
    .ddram_addr         (ddram_addr),
    .ddram_rd           (ddram_rd),
    .cache_ready        (cache_ready),
    .read_seen          (read_seen),
    .cache_error        (cache_error),
    .bank_overlap_error (bank_overlap_error),
    .picture_present_debug(picture_present_debug),
    .prefill_deadline_missed_debug(prefill_deadline_missed_debug),
    .luma_fingerprint_valid_debug(luma_fingerprint_valid_debug),
    .luma_fingerprint_first_field_debug(
        luma_fingerprint_first_field_debug),
    .luma_fingerprint_raw_debug(luma_fingerprint_raw_debug),
    .luma_fingerprint_display_debug(luma_fingerprint_display_debug),
    .luma_fingerprint_mismatch_debug(luma_fingerprint_mismatch_debug),
    .luma_provenance_valid_debug(luma_provenance_valid_debug),
    .luma_provenance_first_field_debug(luma_provenance_first_field_debug),
    .luma_provenance_tag_mismatch_debug(
        luma_provenance_tag_mismatch_debug),
    .luma_provenance_content_mismatch_debug(
        luma_provenance_content_mismatch_debug),
    .luma_provenance_expected_bank_debug(
        luma_provenance_expected_bank_debug),
    .luma_provenance_tagged_bank_debug(luma_provenance_tagged_bank_debug),
    .luma_provenance_expected_row_debug(luma_provenance_expected_row_debug),
    .luma_provenance_tagged_row_debug(luma_provenance_tagged_row_debug),
    .luma_provenance_expected_generation_debug(
        luma_provenance_expected_generation_debug),
    .luma_provenance_tagged_generation_debug(
        luma_provenance_tagged_generation_debug),
    .luma_provenance_raw_fingerprint_debug(
        luma_provenance_raw_fingerprint_debug),
    .luma_provenance_display_fingerprint_debug(
        luma_provenance_display_fingerprint_debug),
    .luma_write_read_valid_debug(luma_write_read_valid_debug),
    .luma_write_read_first_field_debug(
        luma_write_read_first_field_debug),
    .luma_write_read_expected_valid_debug(
        luma_write_read_expected_valid_debug),
    .luma_write_read_region_debug(luma_write_read_region_debug),
    .luma_write_read_expected_fingerprint_debug(
        luma_write_read_expected_fingerprint_debug),
    .luma_write_read_raw_fingerprint_debug(
        luma_write_read_raw_fingerprint_debug),
    .luma_write_read_mismatch_debug(luma_write_read_mismatch_debug),
    .rd_clk             (rd_clk),
    .h_pos              (h_pos),
    .v_pos              (v_pos),
    .pixel_ce           (pixel_ce),
    .pixel_en           (pixel_en),
    .h_sync             (1'b1),
    .v_sync             (1'b1),
    .video_r            (video_r),
    .video_g            (video_g),
    .video_b            (video_b),
    .video_de           (video_de),
    .video_hs           (video_hs),
    .video_vs           (video_vs)
);

integer response_latency;
integer response_delay = 0;
integer response_words = 0;
reg [28:0] response_address = 29'd0;
reg slow_mode = 1'b0;
reg late_prefill_mode = 1'b0;
integer fingerprint_count = 0;
integer fingerprint_mismatch_count = 0;
integer position_mismatch_count = 0;
integer provenance_count = 0;
integer provenance_tag_mismatch_count = 0;
integer provenance_content_mismatch_count = 0;
integer first_field_provenance_count = 0;
integer second_field_provenance_count = 0;
integer write_read_count = 0;
integer write_read_mismatch_count = 0;
integer first_field_write_read_count = 0;
integer second_field_write_read_count = 0;
integer generation_publication_count = 0;
reg picture_present_q = 1'b0;
reg [63:0] expected_luma_word;
reg [7:0] expected_luma_byte;

function automatic [63:0] ddr_word_pattern;
    input [28:0] word_address;
    integer lane;
    begin
        for (lane = 0; lane < 8; lane = lane + 1)
            ddr_word_pattern[lane*8 +: 8] =
                word_address[7:0] + word_address[15:8] + (lane * 8'h1d) +
                (generation_mode ? framebuffer_generation : 8'd0);
    end
endfunction

function automatic [31:0] position_fingerprint_word;
    input [2:0] region;
    input [10:0] row;
    input [6:0] word_index;
    input [63:0] value;
    reg [31:0] result;
    reg [31:0] token;
    integer lane;
    begin
        result = 32'd0;
        for (lane = 0; lane < 8; lane = lane + 1) begin
            token = {row[8:0],word_index,lane[2:0],
                     value[lane*8 +: 8],5'b10101} ^
                    {region,29'h12d4a6b};
            token = token ^ {token[15:0],token[31:16]};
            token = token ^ {token[26:0],token[31:27]};
            result = result ^ token;
        end
        position_fingerprint_word = result;
    end
endfunction

task automatic compute_expected_field_fingerprints;
    integer row;
    integer word_index;
    begin
        expected_even_field_fingerprint = 32'd0;
        expected_odd_field_fingerprint = 32'd0;
        for (row = 0; row < 480; row = row + 1)
            for (word_index = 0; word_index < 90;
                 word_index = word_index + 1)
                if (row[0])
                    expected_odd_field_fingerprint =
                        expected_odd_field_fingerprint ^
                        position_fingerprint_word(3'd0,row[10:0],
                            word_index[6:0],ddr_word_pattern(
                                29'h06000000 + (row * 90) + word_index));
                else
                    expected_even_field_fingerprint =
                        expected_even_field_fingerprint ^
                        position_fingerprint_word(3'd0,row[10:0],
                            word_index[6:0],ddr_word_pattern(
                                29'h06000000 + (row * 90) + word_index));
    end
endtask

always @(posedge rd_clk) begin
    if (reset)
        picture_present_q <= 1'b0;
    else begin
        picture_present_q <= picture_present_debug;
        if (picture_present_debug && !picture_present_q) begin
            generation_publication_count <=
                generation_publication_count + 1;
            if (generation_mode &&
                (dut.framebuffer_generation_r2 != framebuffer_generation))
                $fatal(1,{"published generation mismatch selected=%02h ",
                          "published=%02h"},framebuffer_generation,
                       dut.framebuffer_generation_r2);
        end
    end

    if (pixel_ce && fingerprint_mode &&
        dut.native_luma_sample_valid_rd) begin
        expected_luma_word = ddr_word_pattern(
            29'h06000000 + dut.row_times_90(dut.source_y_d[10:0]) +
            {22'd0,dut.source_x_d[9:3]});
        expected_luma_byte =
            expected_luma_word[dut.source_x_d[2:0]*8 +: 8];
        if (dut.y_rd_data !== expected_luma_byte) begin
            if (position_mismatch_count < 16)
                $display({"NATIVE_CACHE_POSITION_MISMATCH x=%0d y=%0d ",
                          "word=%0d lane=%0d expected=%02h actual=%02h ",
                          "rd_addr=%0d"},
                         dut.source_x_d,dut.source_y_d,
                         dut.source_x_d[9:3],dut.source_x_d[2:0],
                         expected_luma_byte,dut.y_rd_data,
                         dut.y_cache_rd_addr);
            position_mismatch_count <= position_mismatch_count + 1;
        end
    end
end

always @(posedge mem_clk) begin
    if (luma_fingerprint_valid_debug) begin
        fingerprint_count <= fingerprint_count + 1;
        if (luma_fingerprint_mismatch_debug)
            fingerprint_mismatch_count <= fingerprint_mismatch_count + 1;
        if (luma_fingerprint_mismatch_debug !=
            (luma_fingerprint_raw_debug != luma_fingerprint_display_debug))
            $fatal(1,"fingerprint mismatch flag disagrees with payload");
    end
end

always @(posedge mem_clk) begin
    if (luma_provenance_valid_debug) begin
        provenance_count <= provenance_count + 1;
        if (luma_provenance_first_field_debug)
            first_field_provenance_count <= first_field_provenance_count + 1;
        else
            second_field_provenance_count <= second_field_provenance_count + 1;
        if (luma_provenance_tag_mismatch_debug)
            provenance_tag_mismatch_count <=
                provenance_tag_mismatch_count + 1;
        if (luma_provenance_content_mismatch_debug)
            provenance_content_mismatch_count <=
                provenance_content_mismatch_count + 1;
        if (luma_provenance_tag_mismatch_debug &&
            luma_provenance_content_mismatch_debug)
            $fatal(1,"tag and content mismatch classes overlapped");
        if (!luma_provenance_tag_mismatch_debug &&
            ((luma_provenance_expected_row_debug !=
              luma_provenance_tagged_row_debug) ||
             (luma_provenance_expected_bank_debug !=
              luma_provenance_tagged_bank_debug) ||
             (luma_provenance_expected_generation_debug !=
              luma_provenance_tagged_generation_debug)))
            $fatal(1,"matching provenance carried unequal tags");
        if (generation_mode &&
            ((luma_provenance_expected_generation_debug !=
              framebuffer_generation) ||
             (luma_provenance_tagged_generation_debug !=
              framebuffer_generation)))
            $fatal(1,{"field-cache generation mismatch selected=%02h ",
                      "expected=%02h tagged=%02h field=%0d row=%0d"},
                   framebuffer_generation,
                   luma_provenance_expected_generation_debug,
                   luma_provenance_tagged_generation_debug,
                   luma_provenance_first_field_debug,
                   luma_provenance_expected_row_debug);
    end
end

always @(posedge mem_clk) begin
    if (luma_write_read_valid_debug) begin
        write_read_count <= write_read_count + 1;
        if (luma_write_read_first_field_debug)
            first_field_write_read_count <= first_field_write_read_count + 1;
        else
            second_field_write_read_count <= second_field_write_read_count + 1;
        if (luma_write_read_mismatch_debug)
            write_read_mismatch_count <= write_read_mismatch_count + 1;
        if (luma_write_read_region_debug != 3'd0)
            $fatal(1,"write/read comparison reported wrong region %0d",
                   luma_write_read_region_debug);
        if (luma_write_read_expected_valid_debug !=
            write_read_expected_valid)
            $fatal(1,"write/read expected-valid payload mismatch");
        if (!luma_write_read_mismatch_debug &&
            (luma_write_read_expected_fingerprint_debug !=
             luma_write_read_raw_fingerprint_debug))
            $fatal(1,"write/read equality flag disagrees with fingerprints");
    end
end

always @(posedge mem_clk) begin
    ddram_dout_ready <= 1'b0;

    if (reset) begin
        response_delay <= 0;
        response_words <= 0;
        response_address <= 29'd0;
        ddram_dout <= 64'd0;
    end
    else if ((response_words == 0) && ddram_rd) begin
        response_delay <= response_latency;
        response_words <= ddram_burstcnt;
        response_address <= ddram_addr;
    end
    else if (response_words != 0) begin
        if (response_delay != 0)
            response_delay <= response_delay - 1;
        else begin
            if ($test$plusargs("READ_CORRUPT") &&
                (response_address ==
                 (29'h06000000 + (29'd200 * 29'd90) + 29'd10)))
                ddram_dout <= ddr_word_pattern(response_address) ^ 64'd1;
            else
                ddram_dout <= ddr_word_pattern(response_address);
            ddram_dout_ready <= 1'b1;
            response_words <= response_words - 1;
            response_address <= response_address + 29'd1;
        end
    end
end

always @(posedge rd_clk) begin
    ce_div <= ce_div + 2'd1;
    if (reset) begin
        ce_div <= 2'd0;
        h_pos <= 12'd0;
        sequence_line <= 9'd0;
    end
    else if (pixel_ce && running) begin
        if (h_pos == 12'd857) begin
            h_pos <= 12'd0;
            sequence_line <= sequence_line + 9'd1;
            if (sequence_line == (fingerprint_mode ? 9'd479 : 9'd11))
                running <= 1'b0;
        end
        else begin
            h_pos <= h_pos + 12'd1;
        end
    end
end

task automatic run_publication_generation;
    input [7:0] generation;
    input first_generation;
    integer fingerprint_before;
    integer provenance_before;
    integer first_field_before;
    integer second_field_before;
    integer write_read_before;
    integer publication_before;
    integer tag_mismatch_before;
    integer content_mismatch_before;
    integer fingerprint_mismatch_before;
    integer write_read_mismatch_before;
    integer position_mismatch_before;
    begin
        if (first_generation) begin
            framebuffer_generation = generation;
            compute_expected_field_fingerprints();
            repeat (8) @(posedge mem_clk);
        end
        else begin
            @(negedge mem_clk);
            reset = 1'b1;
            picture_complete = 1'b0;
            running = 1'b0;
            framebuffer_generation = generation;
            compute_expected_field_fingerprints();
            repeat (8) @(posedge mem_clk);
        end

        fingerprint_before = fingerprint_count;
        provenance_before = provenance_count;
        first_field_before = first_field_provenance_count;
        second_field_before = second_field_provenance_count;
        write_read_before = write_read_count;
        publication_before = generation_publication_count;
        tag_mismatch_before = provenance_tag_mismatch_count;
        content_mismatch_before = provenance_content_mismatch_count;
        fingerprint_mismatch_before = fingerprint_mismatch_count;
        write_read_mismatch_before = write_read_mismatch_count;
        position_mismatch_before = position_mismatch_count;

        @(negedge mem_clk);
        reset = 1'b0;
        @(negedge mem_clk);
        picture_complete = 1'b1;
        @(negedge mem_clk);
        picture_complete = 1'b0;

        wait (cache_ready);
        repeat (8) @(posedge rd_clk);
        running = 1'b1;
        wait (!running);
        repeat (400) @(posedge mem_clk);

        if ((fingerprint_count - fingerprint_before) != 2)
            $fatal(1,"generation %02h fingerprints=%0d expected=2",generation,
                   fingerprint_count - fingerprint_before);
        if ((provenance_count - provenance_before) != 480)
            $fatal(1,"generation %02h provenance=%0d expected=480",generation,
                   provenance_count - provenance_before);
        if (((first_field_provenance_count - first_field_before) != 240) ||
            ((second_field_provenance_count - second_field_before) != 240))
            $fatal(1,{"generation %02h field provenance first/second=",
                      "%0d/%0d expected=240/240"},generation,
                   first_field_provenance_count - first_field_before,
                   second_field_provenance_count - second_field_before);
        if ((write_read_count - write_read_before) != 2)
            $fatal(1,"generation %02h write/read completions=%0d expected=2",
                   generation,write_read_count - write_read_before);
        if ((generation_publication_count - publication_before) != 1)
            $fatal(1,"generation %02h publications=%0d expected=1",generation,
                   generation_publication_count - publication_before);
        if ((provenance_tag_mismatch_count != tag_mismatch_before) ||
            (provenance_content_mismatch_count != content_mismatch_before) ||
            (fingerprint_mismatch_count != fingerprint_mismatch_before) ||
            (write_read_mismatch_count != write_read_mismatch_before) ||
            (position_mismatch_count != position_mismatch_before))
            $fatal(1,{"generation %02h mismatch delta tag/content/cache/",
                      "write-read/position=%0d/%0d/%0d/%0d/%0d"},generation,
                   provenance_tag_mismatch_count - tag_mismatch_before,
                   provenance_content_mismatch_count - content_mismatch_before,
                   fingerprint_mismatch_count - fingerprint_mismatch_before,
                   write_read_mismatch_count - write_read_mismatch_before,
                   position_mismatch_count - position_mismatch_before);

        $display({"NATIVE_CACHE_GENERATION generation=%02h order=%s ",
                  "fields=240/240 publication=1 mismatches=0"},generation,
                 bff_mode?"BFF":"TFF");
    end
endtask

initial begin
    slow_mode = $test$plusargs("SLOW");
    late_prefill_mode = $test$plusargs("PREFILL_LATE");
    generation_mode = $test$plusargs("GENERATIONS");
    fingerprint_mode = $test$plusargs("FINGERPRINT") || generation_mode;
    bff_mode = $test$plusargs("BFF");
    response_latency = (slow_mode || late_prefill_mode) ? 3400 : 64;
    compute_expected_field_fingerprints();

    if (generation_mode) begin
        if (late_prefill_mode || $test$plusargs("CORRUPT") ||
            $test$plusargs("READ_CORRUPT") ||
            $test$plusargs("WRITE_INVALID") ||
            $test$plusargs("WRONG_BANK"))
            $fatal(1,"generation sequence does not combine with fault injection");
        run_publication_generation(8'h2a,1'b1);
        run_publication_generation(8'h2b,1'b0);
        run_publication_generation(8'h2c,1'b0);
        $display({"NATIVE_CACHE_GENERATION_PASS order=%s generations=3 ",
                  "publications=3 fields=720/720 mismatches=0 latency=%0d"},
                 bff_mode?"BFF":"TFF",response_latency);
        $finish;
    end

    repeat (8) @(posedge mem_clk);
    reset = 1'b0;
    @(posedge mem_clk);
    picture_complete = 1'b1;
    @(posedge mem_clk);
    picture_complete = 1'b0;

    if (late_prefill_mode)
        repeat (12) @(posedge rd_clk);
    else begin
    wait (cache_ready);
    repeat (8) @(posedge rd_clk);
    if ($test$plusargs("WRONG_BANK"))
        force dut.luma_tag_bank_bank0_visible_rd = 1'b1;
    end
    running = 1'b1;
    wait (!running);
    repeat (400) @(posedge mem_clk);

    if (fingerprint_mode) begin
        if (fingerprint_count != 2)
            $fatal(1,"expected two completed field fingerprints, got %0d",
                   fingerprint_count);
        if ($test$plusargs("CORRUPT")) begin
            if (fingerprint_mismatch_count != 1)
                $fatal(1,"corrupted cache expected one mismatch, got %0d",
                       fingerprint_mismatch_count);
        end
        else if (fingerprint_mismatch_count != 0)
            $fatal(1,"matching cache produced %0d fingerprint mismatches",
                   fingerprint_mismatch_count);
        if ($test$plusargs("CORRUPT") || $test$plusargs("READ_CORRUPT")) begin
            if (position_mismatch_count != 1)
                $fatal(1,"corrupt-byte expected one position mismatch, got %0d",
                       position_mismatch_count);
        end
        else if (position_mismatch_count != 0)
            $fatal(1,"matching cache produced %0d position mismatches",
                   position_mismatch_count);
        if (provenance_count != 480)
            $fatal(1,"expected 480 line provenance events, got %0d",
                   provenance_count);
        if ((first_field_provenance_count != 240) ||
            (second_field_provenance_count != 240))
            $fatal(1,"field provenance imbalance %0d/%0d",
                   first_field_provenance_count,second_field_provenance_count);
        if ($test$plusargs("WRONG_BANK")) begin
            if ((provenance_tag_mismatch_count == 0) ||
                (provenance_content_mismatch_count != 0))
                $fatal(1,"wrong-bank classification mismatch tag/content=%0d/%0d",
                       provenance_tag_mismatch_count,
                       provenance_content_mismatch_count);
        end
        else if ($test$plusargs("CORRUPT")) begin
            if ((provenance_tag_mismatch_count != 0) ||
                (provenance_content_mismatch_count != 1))
                $fatal(1,"corrupt-byte classification mismatch tag/content=%0d/%0d",
                       provenance_tag_mismatch_count,
                       provenance_content_mismatch_count);
        end
        else if ((provenance_tag_mismatch_count != 0) ||
                 (provenance_content_mismatch_count != 0))
            $fatal(1,"matching line provenance failed tag/content=%0d/%0d",
                   provenance_tag_mismatch_count,
                   provenance_content_mismatch_count);
        if ((write_read_count != 2) ||
            (first_field_write_read_count != 1) ||
            (second_field_write_read_count != 1))
            $fatal(1,"write/read completion imbalance total/first/second=%0d/%0d/%0d",
                   write_read_count,first_field_write_read_count,
                   second_field_write_read_count);
        if ($test$plusargs("READ_CORRUPT")) begin
            if (write_read_mismatch_count != 1)
                $fatal(1,"raw DDR corruption expected one write/read mismatch, got %0d",
                       write_read_mismatch_count);
        end
        else if ($test$plusargs("WRITE_INVALID")) begin
            if (write_read_mismatch_count != 2)
                $fatal(1,"invalid writer provenance expected two mismatches, got %0d",
                       write_read_mismatch_count);
        end
        else if (write_read_mismatch_count != 0)
            $fatal(1,"matching accepted writes/readback produced %0d mismatches",
                   write_read_mismatch_count);
        $display("NATIVE_CACHE_FINGERPRINT_PASS order=%s corrupted=%0d completed=%0d mismatches=%0d",
                 bff_mode?"BFF":"TFF",$test$plusargs("CORRUPT"),
                 fingerprint_count,fingerprint_mismatch_count);
    end
    else if (late_prefill_mode) begin
        if (!prefill_deadline_missed_debug)
            $fatal(1, "late native origin did not flag prefill deadline miss");
        if (picture_present_debug)
            $fatal(1, "late native origin published an unready cache");
        $display({"NATIVE_CACHE_REFILL_PASS mode=prefill-late miss=1 ",
                  "published=0 latency=3400"});
    end
    else if (slow_mode) begin
        if (!bank_overlap_error)
            $fatal(1, "late DDR return did not flag cache-bank overlap");
        if (!picture_present_debug || prefill_deadline_missed_debug)
            $fatal(1, "delayed ready-first publication telemetry mismatch");
        $display({"NATIVE_CACHE_REFILL_PASS mode=delayed overlap=1 ",
                  "latency=3400"});
    end
    else begin
        if (cache_error || bank_overlap_error)
            $fatal(1, "ordinary DDR service flagged cache error %0d/%0d",
                   cache_error, bank_overlap_error);
        if (!picture_present_debug || prefill_deadline_missed_debug)
            $fatal(1, "ordinary publication telemetry mismatch");
        $display({"NATIVE_CACHE_REFILL_PASS mode=ordinary overlap=0 ",
                  "latency=64"});
    end
    $finish;
end

initial begin
    #100000000;
    $fatal(1, "timeout");
end

endmodule
