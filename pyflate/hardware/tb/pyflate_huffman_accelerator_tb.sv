`timescale 1ns/1ps

module pyflate_huffman_accelerator_tb;
    localparam int MAX_BITS = 20;
    localparam int MAX_SYMBOLS = 258;
    localparam int NUM_TABLES = 6;
    localparam int SYMBOL_W = 9;
    localparam int LEN_W = $clog2(MAX_BITS + 1);
    localparam int INDEX_W = $clog2(MAX_SYMBOLS);
    localparam int TABLE_W = $clog2(NUM_TABLES);
    localparam int COUNT_W = $clog2(64 + 1);

    logic clk;
    logic rst_n = 1'b0;
    logic stream_reset = 1'b0;
    logic seed_valid = 1'b0;
    logic seed_ready;
    logic [63:0] seed_data = '0;
    logic [COUNT_W-1:0] seed_count = '0;
    logic byte_valid = 1'b0;
    logic byte_ready;
    logic [7:0] byte_data = '0;
    logic cfg_clear = 1'b0;
    logic [TABLE_W-1:0] cfg_table_select = '0;
    logic cfg_bounds_valid = 1'b0;
    logic [LEN_W-1:0] cfg_min_length = '0;
    logic [LEN_W-1:0] cfg_max_length = '0;
    logic cfg_length_valid = 1'b0;
    logic [LEN_W-1:0] cfg_length = '0;
    logic [MAX_BITS-1:0] cfg_first_code = '0;
    logic [MAX_BITS-1:0] cfg_last_code = '0;
    logic [INDEX_W-1:0] cfg_first_symbol_index = '0;
    logic cfg_symbol_valid = 1'b0;
    logic [INDEX_W-1:0] cfg_symbol_index = '0;
    logic [SYMBOL_W-1:0] cfg_symbol_value = '0;
    logic cfg_ready;
    logic decode_valid = 1'b0;
    logic [TABLE_W-1:0] decode_table_select = '0;
    logic decode_ready;
    logic [SYMBOL_W-1:0] symbol_value;
    logic symbol_valid;
    logic symbol_ready = 1'b1;
    logic [LEN_W-1:0] bits_consumed;
    logic need_more_bits;
    logic decode_error;
    logic busy;
    logic [COUNT_W-1:0] buffered_bits;

    int failures = 0;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    pyflate_huffman_accelerator dut (.*);

    task automatic pulse_stream_reset;
        begin
            @(negedge clk);
            stream_reset = 1'b1;
            @(negedge clk);
            stream_reset = 1'b0;
        end
    endtask

    task automatic clear_table;
        begin
            while (!cfg_ready) @(negedge clk);
            cfg_clear = 1'b1;
            @(negedge clk);
            cfg_clear = 1'b0;
        end
    endtask

    task automatic select_config_table(input logic [TABLE_W-1:0] table_id);
        begin
            while (!cfg_ready) @(negedge clk);
            cfg_table_select = table_id;
        end
    endtask

    task automatic set_bounds(
        input logic [LEN_W-1:0] minimum,
        input logic [LEN_W-1:0] maximum
    );
        begin
            while (!cfg_ready) @(negedge clk);
            cfg_min_length = minimum;
            cfg_max_length = maximum;
            cfg_bounds_valid = 1'b1;
            @(negedge clk);
            cfg_bounds_valid = 1'b0;
        end
    endtask

    task automatic set_length(
        input logic [LEN_W-1:0] length,
        input logic [MAX_BITS-1:0] first_code,
        input logic [MAX_BITS-1:0] last_code,
        input logic [INDEX_W-1:0] first_symbol_index
    );
        begin
            while (!cfg_ready) @(negedge clk);
            cfg_length = length;
            cfg_first_code = first_code;
            cfg_last_code = last_code;
            cfg_first_symbol_index = first_symbol_index;
            cfg_length_valid = 1'b1;
            @(negedge clk);
            cfg_length_valid = 1'b0;
        end
    endtask

    task automatic set_symbol(
        input logic [INDEX_W-1:0] index,
        input logic [SYMBOL_W-1:0] value
    );
        begin
            while (!cfg_ready) @(negedge clk);
            cfg_symbol_index = index;
            cfg_symbol_value = value;
            cfg_symbol_valid = 1'b1;
            @(negedge clk);
            cfg_symbol_valid = 1'b0;
        end
    endtask

    task automatic send_byte(input logic [7:0] value);
        begin
            @(negedge clk);
            byte_data = value;
            byte_valid = 1'b1;
            while (!byte_ready) @(negedge clk);
            @(negedge clk);
            byte_valid = 1'b0;
        end
    endtask

    task automatic seed_stream(
        input logic [63:0] value,
        input logic [COUNT_W-1:0] count
    );
        begin
            @(negedge clk);
            seed_data = value;
            seed_count = count;
            seed_valid = 1'b1;
            while (!seed_ready) @(negedge clk);
            @(negedge clk);
            seed_valid = 1'b0;
        end
    endtask

    task automatic start_decode(input logic [TABLE_W-1:0] table_id);
        begin
            @(negedge clk);
            decode_table_select = table_id;
            decode_valid = 1'b1;
            while (!decode_ready) @(negedge clk);
            @(negedge clk);
            decode_valid = 1'b0;
        end
    endtask

    task automatic expect_symbol(
        input logic [SYMBOL_W-1:0] expected_symbol,
        input logic [LEN_W-1:0] expected_length
    );
        begin
            start_decode('0);
            if (!busy) begin
                $display("FAIL protocol: busy did not assert after request");
                failures = failures + 1;
            end
            while (!symbol_valid) @(negedge clk);
            if (decode_error || symbol_value !== expected_symbol ||
                bits_consumed !== expected_length) begin
                $display("FAIL symbol: expected value=%0d len=%0d, got value=%0d len=%0d error=%0b",
                         expected_symbol, expected_length, symbol_value,
                         bits_consumed, decode_error);
                failures = failures + 1;
            end else begin
                $display("PASS symbol: value=%0d len=%0d", symbol_value, bits_consumed);
            end
            @(negedge clk);
        end
    endtask

    initial begin
        $dumpfile("pyflate_huffman_accelerator.vcd");
        $dumpvars(0, pyflate_huffman_accelerator_tb);

        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        // Canonical table: A=0, B=10, C=110, D=111.
        clear_table();
        set_bounds(1, 3);
        set_length(1, 0, 0, 0);
        set_length(2, 2, 2, 1);
        set_length(3, 6, 7, 2);
        set_symbol(0, 65);
        set_symbol(1, 66);
        set_symbol(2, 67);
        set_symbol(3, 68);

        // A second BZip2 table can be selected without reconfiguration.
        select_config_table(1);
        clear_table();
        set_bounds(1, 1);
        set_length(1, 0, 1, 0);
        set_symbol(0, 80);
        set_symbol(1, 81);
        select_config_table(0);

        // 0|10|110|111 = 010110111. D crosses the byte boundary.
        send_byte(8'h5b);
        send_byte(8'h80);
        expect_symbol(65, 1);
        expect_symbol(66, 2);
        expect_symbol(67, 3);
        expect_symbol(68, 3);

        // The next buffered bit is 0. Decode it with table 1, where 0 -> P,
        // then restore the original stream position expectation (6 bits left).
        start_decode(1);
        while (!symbol_valid) @(negedge clk);
        if (decode_error || symbol_value !== 80 || bits_consumed !== 1) begin
            $display("FAIL table-bank selection");
            failures = failures + 1;
        end else begin
            $display("PASS table-bank selection");
        end
        @(negedge clk);

        if (buffered_bits !== 6) begin
            $display("FAIL bit count: expected 6, got %0d", buffered_bits);
            failures = failures + 1;
        end else begin
            $display("PASS byte-boundary bit count");
        end

        // Reload the table and issue a request before data arrives. The
        // decoder must wait for the bit buffer to be refilled.
        pulse_stream_reset();
        select_config_table(0);
        clear_table();
        set_bounds(1, 1);
        set_length(1, 0, 1, 0);
        set_symbol(0, 88);
        set_symbol(1, 89);
        start_decode('0);
        repeat (3) @(negedge clk);
        if (!need_more_bits) begin
            $display("FAIL underflow: need_more_bits was not asserted");
            failures = failures + 1;
        end else begin
            $display("PASS underflow stall");
        end
        // Seed two residual bits (0,1) as a software handoff in mid-byte.
        seed_stream(64'h4000_0000_0000_0000, 2);
        while (!symbol_valid) @(negedge clk);
        if (decode_error || symbol_value !== 88 || bits_consumed !== 1) begin
            $display("FAIL refill decode");
            failures = failures + 1;
        end else begin
            $display("PASS refill decode");
        end
        @(negedge clk);
        expect_symbol(89, 1);

        // Deliberately incomplete table: only code 0 is valid. Input 1 must
        // produce an error without consuming the bit.
        pulse_stream_reset();
        clear_table();
        set_bounds(1, 1);
        set_length(1, 0, 0, 0);
        set_symbol(0, 90);
        send_byte(8'h80);
        start_decode('0);
        while (!symbol_valid) @(negedge clk);
        if (!decode_error || buffered_bits !== 8) begin
            $display("FAIL invalid-code handling: error=%0b bits=%0d",
                     decode_error, buffered_bits);
            failures = failures + 1;
        end else begin
            $display("PASS invalid-code handling");
        end
        @(negedge clk);

        // NUM_TABLES is six, so selector seven must be rejected cleanly.
        start_decode(3'd7);
        while (!symbol_valid) @(negedge clk);
        if (!decode_error || buffered_bits !== 8) begin
            $display("FAIL invalid-table handling: error=%0b bits=%0d",
                     decode_error, buffered_bits);
            failures = failures + 1;
        end else begin
            $display("PASS invalid-table handling");
        end

        if (failures == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED: %0d failure(s)", failures);

        #20;
        $finish;
    end

endmodule
