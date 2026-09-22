`timescale 1ns/1ps

module pyflate_real_trace_tb;
    localparam int MAX_BITS = 20;
    localparam int MAX_SYMBOLS = 258;
    localparam int NUM_TABLES = 6;
    localparam int SYMBOL_W = 9;
    localparam int LEN_W = $clog2(MAX_BITS + 1);
    localparam int INDEX_W = $clog2(MAX_SYMBOLS);
    localparam int TABLE_W = $clog2(NUM_TABLES);
    localparam int COUNT_W = $clog2(64 + 1);
    localparam int MAX_EXPECTED = 200000;
    localparam int MAX_STREAM_BYTES = 70000;

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

    logic [63:0] metadata [0:5];
    logic [9:0] bounds [0:NUM_TABLES-1];
    logic [49:0] length_records [0:NUM_TABLES*(MAX_BITS+1)-1];
    logic [8:0] symbol_records [0:NUM_TABLES*MAX_SYMBOLS-1];
    logic [16:0] expected_records [0:MAX_EXPECTED-1];
    logic [7:0] stream_bytes [0:MAX_STREAM_BYTES-1];

    integer failures = 0;
    integer expected_count;
    integer stream_byte_count;
    integer symbols_in_use;
    integer input_stall_observations = 0;
    logic decode_done = 1'b0;
    string trace_dir;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    pyflate_huffman_accelerator dut (.*);

    task automatic clear_table(input logic [TABLE_W-1:0] table_id);
        begin
            while (!cfg_ready) @(negedge clk);
            cfg_table_select = table_id;
            cfg_clear = 1'b1;
            @(negedge clk);
            cfg_clear = 1'b0;
        end
    endtask

    task automatic set_bounds(
        input logic [TABLE_W-1:0] table_id,
        input logic [LEN_W-1:0] minimum,
        input logic [LEN_W-1:0] maximum
    );
        begin
            while (!cfg_ready) @(negedge clk);
            cfg_table_select = table_id;
            cfg_min_length = minimum;
            cfg_max_length = maximum;
            cfg_bounds_valid = 1'b1;
            @(negedge clk);
            cfg_bounds_valid = 1'b0;
        end
    endtask

    task automatic set_length(
        input logic [TABLE_W-1:0] table_id,
        input logic [LEN_W-1:0] length,
        input logic [MAX_BITS-1:0] first_code,
        input logic [MAX_BITS-1:0] last_code,
        input logic [INDEX_W-1:0] first_symbol_index
    );
        begin
            while (!cfg_ready) @(negedge clk);
            cfg_table_select = table_id;
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
        input logic [TABLE_W-1:0] table_id,
        input logic [INDEX_W-1:0] index,
        input logic [SYMBOL_W-1:0] value
    );
        begin
            while (!cfg_ready) @(negedge clk);
            cfg_table_select = table_id;
            cfg_symbol_index = index;
            cfg_symbol_value = value;
            cfg_symbol_valid = 1'b1;
            @(negedge clk);
            cfg_symbol_valid = 1'b0;
        end
    endtask

    task automatic seed_residual_bits;
        begin
            while (!seed_ready) @(negedge clk);
            seed_count = COUNT_W'(metadata[0]);
            seed_data = metadata[1];
            seed_valid = 1'b1;
            @(negedge clk);
            seed_valid = 1'b0;
        end
    endtask

    task automatic feed_stream;
        integer byte_index;
        begin
            byte_index = 0;
            while ((byte_index < stream_byte_count) && !decode_done) begin
                @(negedge clk);
                if (byte_ready) begin
                    byte_data = stream_bytes[byte_index];
                    byte_valid = 1'b1;
                    @(negedge clk);
                    byte_valid = 1'b0;
                    byte_index = byte_index + 1;
                end
            end
            byte_valid = 1'b0;
        end
    endtask

    task automatic check_all_symbols;
        integer expected_index;
        logic [TABLE_W-1:0] expected_table;
        logic [SYMBOL_W-1:0] expected_symbol;
        logic [LEN_W-1:0] expected_length;
        begin
            for (expected_index = 0;
                 expected_index < expected_count;
                 expected_index = expected_index + 1) begin
                expected_table = expected_records[expected_index][16:14];
                expected_symbol = expected_records[expected_index][13:5];
                expected_length = expected_records[expected_index][4:0];

                @(negedge clk);
                decode_table_select = expected_table;
                decode_valid = 1'b1;
                while (!decode_ready) @(negedge clk);
                @(negedge clk);
                decode_valid = 1'b0;
                if (!busy) begin
                    $display("FAIL trace[%0d]: busy did not assert", expected_index);
                    failures = failures + 1;
                end
                while (!symbol_valid) begin
                    if (need_more_bits)
                        input_stall_observations = input_stall_observations + 1;
                    @(negedge clk);
                end

                if (decode_error ||
                    (symbol_value !== expected_symbol) ||
                    (bits_consumed !== expected_length)) begin
                    if (failures < 20)
                        $display("FAIL trace[%0d]: table=%0d expected=%0d/%0d got=%0d/%0d error=%0b buffered=%0d",
                                 expected_index, expected_table,
                                 expected_symbol, expected_length,
                                 symbol_value, bits_consumed,
                                 decode_error, buffered_bits);
                    failures = failures + 1;
                end

                if ((expected_index > 0) &&
                    ((expected_index % 25000) == 0))
                    $display("Checked %0d/%0d symbols", expected_index,
                             expected_count);

                @(negedge clk);
            end
            decode_done = 1'b1;
        end
    endtask

    integer table_id;
    integer length;
    logic [6:0] record_index;
    integer symbol_index;

    initial begin
        if (!$value$plusargs("TRACE_DIR=%s", trace_dir))
            trace_dir = "pyflate/hardware/build/real_trace";

        $readmemh({trace_dir, "/metadata.hex"}, metadata);
        stream_byte_count = int'(metadata[2]);
        expected_count = int'(metadata[3]);
        symbols_in_use = int'(metadata[4]);
        if ((expected_count > MAX_EXPECTED) ||
            (stream_byte_count > MAX_STREAM_BYTES))
            $fatal(1, "Trace exceeds testbench array bounds");

        $readmemh({trace_dir, "/bounds.hex"}, bounds);
        $readmemh({trace_dir, "/lengths.hex"}, length_records);
        $readmemh({trace_dir, "/symbols.hex"}, symbol_records);
        $readmemh({trace_dir, "/expected.hex"}, expected_records,
                  0, expected_count - 1);
        $readmemh({trace_dir, "/stream_bytes.hex"}, stream_bytes,
                  0, stream_byte_count - 1);

        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        for (table_id = 0; table_id < NUM_TABLES; table_id = table_id + 1) begin
            clear_table(TABLE_W'(table_id));
            set_bounds(TABLE_W'(table_id), bounds[table_id][9:5],
                       bounds[table_id][4:0]);
            for (length = 1; length <= MAX_BITS; length = length + 1) begin
                record_index = 7'(table_id * (MAX_BITS + 1) + length);
                if (length_records[record_index][49])
                    set_length(
                        TABLE_W'(table_id), LEN_W'(length),
                        length_records[record_index][48:29],
                        length_records[record_index][28:9],
                        length_records[record_index][8:0]);
            end
            for (symbol_index = 0;
                 symbol_index < symbols_in_use;
                 symbol_index = symbol_index + 1)
                set_symbol(
                    TABLE_W'(table_id), INDEX_W'(symbol_index),
                    symbol_records[table_id * MAX_SYMBOLS + symbol_index]);
        end

        stream_reset = 1'b1;
        @(negedge clk);
        stream_reset = 1'b0;
        seed_residual_bits();

        $display("Starting real trace: %0d symbols, %0d bytes, %0d seed bits",
                 expected_count, stream_byte_count, metadata[0]);
        fork
            feed_stream();
            check_all_symbols();
        join

        if (failures == 0)
            $display("REAL TRACE PASSED: %0d/%0d symbols matched Python",
                     expected_count, expected_count);
        else
            $display("REAL TRACE FAILED: %0d mismatch(es)", failures);
        $display("Observed %0d decoder cycles waiting for input",
                 input_stall_observations);

        #20;
        $finish;
    end

    initial begin
        #50_000_000;
        if (!decode_done)
            $fatal(1, "Timeout during real Pyflate trace");
    end

endmodule
