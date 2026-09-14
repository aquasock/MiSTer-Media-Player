`timescale 1ns/1ps
module test_idct_storage;
reg clk = 0;
always #5 clk = !clk;
reg reset = 1;
reg coeff_block_start = 0, coeff_valid = 0, coeff_block_end = 0;
reg [5:0] coeff_index = 0;
reg signed [11:0] coeff_value = 0;
wire block_complete, idct_error, sample_valid;
wire [5:0] sample_index;
wire signed [15:0] sample_value, first_luma_sample00, first_luma_sample77;
wire ref_complete, ref_error, ref_valid;
wire [5:0] ref_index;
wire signed [15:0] ref_value, ref_first, ref_last;
mpeg2_h262_idct dut (.*);
mpeg2_h262_idct_reference reference_idct (
    .clk(clk), .reset(reset), .coeff_block_start(coeff_block_start),
    .coeff_valid(coeff_valid), .coeff_index(coeff_index), .coeff_value(coeff_value),
    .coeff_block_end(coeff_block_end), .block_complete(ref_complete),
    .idct_error(ref_error), .sample_valid(ref_valid), .sample_index(ref_index),
    .sample_value(ref_value), .first_luma_sample00(ref_first),
    .first_luma_sample77(ref_last)
);
integer cycles = 0, samples = 0, completed = 0, block_samples = 0;
reg [31:0] rng = 32'h8c1297ab;
function automatic [31:0] random_word;
    begin
        rng = rng ^ (rng << 13);
        rng = rng ^ (rng >> 17);
        rng = rng ^ (rng << 5);
        random_word = rng;
    end
endfunction
always @(posedge clk) begin
    #1;
    cycles = cycles + 1;
    if ({block_complete, idct_error, sample_valid, sample_index, sample_value,
         first_luma_sample00, first_luma_sample77} !==
        {ref_complete, ref_error, ref_valid, ref_index, ref_value, ref_first, ref_last})
        $fatal(1, "IDCT mismatch cycle=%0d sample=%0d got=%0d expected=%0d",
               cycles, sample_index, sample_value, ref_value);
    if (reset || coeff_block_start) block_samples = 0;
    if (sample_valid) begin
        if ((^sample_value) === 1'bx || sample_index !== block_samples[5:0])
            $fatal(1, "Unknown or out-of-order sample");
        block_samples = block_samples + 1;
        samples = samples + 1;
        if (sample_index == 63) begin
            if (!block_complete || block_samples != 64) $fatal(1, "Incomplete block");
            completed = completed + 1;
        end
    end
end
task automatic idle;
    begin
        @(negedge clk);
        coeff_block_start = 0; coeff_valid = 0; coeff_block_end = 0;
    end
endtask
task automatic restart;
    begin
        idle(); reset = 1;
        repeat (2) idle();
        reset = 0;
    end
endtask
// mode 0 empty, 1 impulse, 2 dense signed extreme, 3 randomized sparse.
task automatic capture(input integer mode, input integer arg);
    integer k;
    reg [31:0] r;
    begin
        idle(); coeff_block_start = 1;
        if (mode == 0) coeff_block_end = 1;
        else begin
            for (k = 0; k < 64; k = k + 1) begin
                idle(); r = random_word();
                if (mode == 3 && r[3:0] == 0) idle();
                coeff_index = mode == 3 ? (63-k) : k;
                coeff_valid = mode != 1 || k == (arg % 64);
                if (mode == 3) coeff_valid = r[4];
                if (mode == 1) coeff_value = arg < 64 ? 2047 : -2048;
                else if (mode == 2) coeff_value = ((k + arg) & 1) ? -2048 : 2047;
                else coeff_value = r[31:20];
            end
            // End together with the final coefficient; this must not drop it.
            coeff_block_end = 1;
        end
        idle();
    end
endtask
task automatic finish_block;
    integer timeout;
    begin
        timeout = 0;
        while (!block_complete && timeout < 140) begin idle(); timeout = timeout + 1; end
        if (!block_complete || idct_error || block_samples != 64)
            $fatal(1, "IDCT block did not finish cleanly");
    end
endtask
integer n;
initial begin
    restart();
    capture(0, 0); finish_block();
    for (n = 0; n < 128; n = n + 1) begin capture(1, n); finish_block(); end
    for (n = 0; n < 2; n = n + 1) begin capture(2, n); finish_block(); end
    for (n = 0; n < 512; n = n + 1) begin capture(3, n); finish_block(); end
    // Abort at every cycle across both passes and the pipeline transitions.
    // Immediately follow each reset with an empty block to expose stale RAM.
    for (n = 0; n < 133; n = n + 1) begin
        capture(2, n);
        repeat (n) idle();
        restart(); capture(0, 0); finish_block();
    end
    // Reset during coefficient capture, then exercise start/value/end together.
    idle(); coeff_block_start = 1; coeff_valid = 1; coeff_value = -2048;
    restart();
    idle(); coeff_block_start = 1; coeff_valid = 1;
    coeff_index = 0; coeff_value = 2047; coeff_block_end = 1;
    idle(); finish_block();
    // Invalid overlapping start must retain the baseline sticky error behavior.
    capture(2, 0); coeff_block_start = 1;
    idle(); repeat (140) idle();
    if (!idct_error) $fatal(1, "Missing overlap error");
    restart(); capture(0, 0); finish_block();
    $display("IDCT_STORAGE_PASS cycles=%0d completed=%0d samples=%0d reset_offsets=133 random_blocks=512", cycles, completed, samples);
    $finish;
end
initial begin #3000000; $fatal(1, "IDCT test timeout"); end
endmodule
