`timescale 1ns/1ps

module pyflate_huffman_accelerator #(
    parameter int BUFFER_BITS = 64,
    parameter int MAX_BITS = 20,
    parameter int MAX_SYMBOLS = 258,
    parameter int NUM_TABLES = 6,
    parameter int SYMBOL_W = 9,
    parameter int LEN_W = $clog2(MAX_BITS + 1),
    parameter int INDEX_W = $clog2(MAX_SYMBOLS),
    parameter int TABLE_W = $clog2(NUM_TABLES),
    parameter int COUNT_W = $clog2(BUFFER_BITS + 1)
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  stream_reset,

    input  logic                  seed_valid,
    output logic                  seed_ready,
    input  logic [BUFFER_BITS-1:0] seed_data,
    input  logic [COUNT_W-1:0]    seed_count,

    input  logic                  byte_valid,
    output logic                  byte_ready,
    input  logic [7:0]            byte_data,

    input  logic                  cfg_clear,
    input  logic [TABLE_W-1:0]    cfg_table_select,
    input  logic                  cfg_bounds_valid,
    input  logic [LEN_W-1:0]      cfg_min_length,
    input  logic [LEN_W-1:0]      cfg_max_length,
    input  logic                  cfg_length_valid,
    input  logic [LEN_W-1:0]      cfg_length,
    input  logic [MAX_BITS-1:0]   cfg_first_code,
    input  logic [MAX_BITS-1:0]   cfg_last_code,
    input  logic [INDEX_W-1:0]    cfg_first_symbol_index,
    input  logic                  cfg_symbol_valid,
    input  logic [INDEX_W-1:0]    cfg_symbol_index,
    input  logic [SYMBOL_W-1:0]   cfg_symbol_value,
    output logic                  cfg_ready,

    input  logic                  decode_valid,
    input  logic [TABLE_W-1:0]    decode_table_select,
    output logic                  decode_ready,
    output logic [SYMBOL_W-1:0]   symbol_value,
    output logic                  symbol_valid,
    input  logic                  symbol_ready,
    output logic [LEN_W-1:0]      bits_consumed,
    output logic                  need_more_bits,
    output logic                  decode_error,
    output logic                  busy,
    output logic [COUNT_W-1:0]    buffered_bits
);

    logic [MAX_BITS-1:0] peek_window;
    logic consume_valid;
    logic [LEN_W-1:0] consume_count;
    logic consume_error;
    logic decoder_error;

    bit_buffer #(
        .BUFFER_BITS(BUFFER_BITS),
        .MAX_BITS(MAX_BITS),
        .COUNT_W(COUNT_W),
        .LEN_W(LEN_W)
    ) input_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .clear(stream_reset),
        .seed_valid(seed_valid),
        .seed_ready(seed_ready),
        .seed_data(seed_data),
        .seed_count(seed_count),
        .byte_valid(byte_valid),
        .byte_ready(byte_ready),
        .byte_data(byte_data),
        .consume_valid(consume_valid),
        .consume_count(consume_count),
        .peek_window(peek_window),
        .available_bits(buffered_bits),
        .consume_error(consume_error)
    );

    huffman_decoder #(
        .MAX_BITS(MAX_BITS),
        .MAX_SYMBOLS(MAX_SYMBOLS),
        .NUM_TABLES(NUM_TABLES),
        .SYMBOL_W(SYMBOL_W),
        .LEN_W(LEN_W),
        .INDEX_W(INDEX_W),
        .TABLE_W(TABLE_W),
        .COUNT_W(COUNT_W)
    ) decoder (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_clear(cfg_clear),
        .cfg_table_select(cfg_table_select),
        .cfg_bounds_valid(cfg_bounds_valid),
        .cfg_min_length(cfg_min_length),
        .cfg_max_length(cfg_max_length),
        .cfg_length_valid(cfg_length_valid),
        .cfg_length(cfg_length),
        .cfg_first_code(cfg_first_code),
        .cfg_last_code(cfg_last_code),
        .cfg_first_symbol_index(cfg_first_symbol_index),
        .cfg_symbol_valid(cfg_symbol_valid),
        .cfg_symbol_index(cfg_symbol_index),
        .cfg_symbol_value(cfg_symbol_value),
        .cfg_ready(cfg_ready),
        .peek_window(peek_window),
        .available_bits(buffered_bits),
        .consume_valid(consume_valid),
        .consume_count(consume_count),
        .need_more_bits(need_more_bits),
        .request_valid(decode_valid),
        .request_table_select(decode_table_select),
        .request_ready(decode_ready),
        .symbol_value(symbol_value),
        .symbol_valid(symbol_valid),
        .symbol_ready(symbol_ready),
        .bits_consumed(bits_consumed),
        .decode_error(decoder_error),
        .busy(busy)
    );

    // A consume error should be unreachable because the decoder waits until
    // enough bits are available. Expose it as a decode failure if it occurs.
    assign decode_error = decoder_error | consume_error;

endmodule
