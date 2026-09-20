`timescale 1ns/1ps

module bit_buffer #(
    parameter int BUFFER_BITS = 64,
    parameter int MAX_BITS    = 20,
    parameter int COUNT_W     = $clog2(BUFFER_BITS + 1),
    parameter int LEN_W       = $clog2(MAX_BITS + 1)
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  clear,

    // Seed residual bits when software hands off a stream mid-byte. Valid
    // bits are MSB-aligned in seed_data.
    input  logic                  seed_valid,
    output logic                  seed_ready,
    input  logic [BUFFER_BITS-1:0] seed_data,
    input  logic [COUNT_W-1:0]    seed_count,

    input  logic                  byte_valid,
    output logic                  byte_ready,
    input  logic [7:0]            byte_data,

    input  logic                  consume_valid,
    input  logic [LEN_W-1:0]      consume_count,

    output logic [MAX_BITS-1:0]   peek_window,
    output logic [COUNT_W-1:0]    available_bits,
    output logic                  consume_error
);

    logic [BUFFER_BITS-1:0] reservoir;
    logic [COUNT_W-1:0] bit_count;

    assign available_bits = bit_count;
    assign peek_window = reservoir[BUFFER_BITS-1 -: MAX_BITS];

    // Keeping push and consume mutually exclusive makes the state transition
    // unambiguous. A byte can be accepted on the following cycle.
    assign seed_ready = !clear && !consume_valid && (bit_count == 0);
    assign byte_ready = !clear && !seed_valid && !consume_valid &&
                        (bit_count <= COUNT_W'(BUFFER_BITS - 8));

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reservoir    <= '0;
            bit_count    <= '0;
            consume_error <= 1'b0;
        end else if (clear) begin
            reservoir    <= '0;
            bit_count    <= '0;
            consume_error <= 1'b0;
        end else begin
            consume_error <= 1'b0;

            if (seed_valid && seed_ready) begin
                if (seed_count > COUNT_W'(BUFFER_BITS)) begin
                    consume_error <= 1'b1;
                end else begin
                    reservoir <= seed_data;
                    bit_count <= seed_count;
                end
            end else if (consume_valid) begin
                if ((consume_count == 0) ||
                    (COUNT_W'(consume_count) > bit_count)) begin
                    consume_error <= 1'b1;
                end else begin
                    reservoir <= reservoir << consume_count;
                    bit_count <= bit_count - COUNT_W'(consume_count);
                end
            end else if (byte_valid && byte_ready) begin
                reservoir <= reservoir |
                    ({{(BUFFER_BITS-8){1'b0}}, byte_data}
                     << (BUFFER_BITS - int'(bit_count) - 8));
                bit_count <= bit_count + COUNT_W'(8);
            end
        end
    end

endmodule
