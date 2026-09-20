`timescale 1ns/1ps

module huffman_decoder #(
    parameter int MAX_BITS    = 20,
    parameter int MAX_SYMBOLS = 258,
    parameter int NUM_TABLES  = 6,
    parameter int SYMBOL_W    = 9,
    parameter int LEN_W       = $clog2(MAX_BITS + 1),
    parameter int INDEX_W     = $clog2(MAX_SYMBOLS),
    parameter int TABLE_W     = $clog2(NUM_TABLES),
    parameter int COUNT_W     = 7
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // Configuration interface. Configuration is performed while idle.
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

    // Runtime interface to the bit buffer.
    input  logic [MAX_BITS-1:0]   peek_window,
    input  logic [COUNT_W-1:0]    available_bits,
    output logic                  consume_valid,
    output logic [LEN_W-1:0]      consume_count,
    output logic                  need_more_bits,

    // One request decodes one Huffman symbol.
    input  logic                  request_valid,
    input  logic [TABLE_W-1:0]    request_table_select,
    output logic                  request_ready,
    output logic [SYMBOL_W-1:0]   symbol_value,
    output logic                  symbol_valid,
    input  logic                  symbol_ready,
    output logic [LEN_W-1:0]      bits_consumed,
    output logic                  decode_error,
    output logic                  busy
);

    typedef enum logic [1:0] {
        STATE_IDLE,
        STATE_CHECK,
        STATE_OUTPUT
    } state_t;

    state_t state;

    localparam int META_ENTRIES = NUM_TABLES * (MAX_BITS + 1);
    localparam int SYMBOL_ENTRIES = NUM_TABLES * MAX_SYMBOLS;
    localparam int META_ADDR_W = $clog2(META_ENTRIES);
    localparam int SYMBOL_ADDR_W = $clog2(SYMBOL_ENTRIES);

    // Flattened bank addressing lets synthesis tools infer ordinary memories.
    logic [MAX_BITS-1:0] first_code [0:META_ENTRIES-1];
    logic [MAX_BITS-1:0] last_code  [0:META_ENTRIES-1];
    logic [INDEX_W-1:0]  first_index[0:META_ENTRIES-1];
    logic                 length_valid[0:META_ENTRIES-1];
    logic [SYMBOL_W-1:0] symbol_memory[0:SYMBOL_ENTRIES-1];

    logic [LEN_W-1:0] min_length [0:NUM_TABLES-1];
    logic [LEN_W-1:0] max_length [0:NUM_TABLES-1];
    logic [TABLE_W-1:0] active_table;
    logic [LEN_W-1:0] current_length;
    logic [MAX_BITS-1:0] candidate_code;
    logic [MAX_BITS:0] candidate_index;
    logic [META_ADDR_W-1:0] active_meta_address;

    integer i;

    function automatic logic [META_ADDR_W-1:0] meta_address(
        input logic [TABLE_W-1:0] table_number,
        input logic [LEN_W-1:0] length
    );
        meta_address = META_ADDR_W'(
            int'(table_number) * (MAX_BITS + 1) + int'(length));
    endfunction

    function automatic logic [SYMBOL_ADDR_W-1:0] symbol_address(
        input logic [TABLE_W-1:0] table_number,
        input logic [INDEX_W-1:0] symbol_index
    );
        symbol_address = SYMBOL_ADDR_W'(
            int'(table_number) * MAX_SYMBOLS + int'(symbol_index));
    endfunction

    always_comb begin
        active_meta_address = meta_address(active_table, current_length);

        if ((current_length >= LEN_W'(1)) &&
            (current_length <= LEN_W'(MAX_BITS)))
            candidate_code = peek_window >> (MAX_BITS - int'(current_length));
        else
            candidate_code = '0;

        candidate_index =
            {{(MAX_BITS + 1 - INDEX_W){1'b0}},
             first_index[active_meta_address]} +
            {1'b0, candidate_code} -
            {1'b0, first_code[active_meta_address]};
    end

    assign request_ready  = (state == STATE_IDLE) && !symbol_valid;
    assign cfg_ready      = (state == STATE_IDLE) && !symbol_valid && !request_valid;
    assign need_more_bits = (state == STATE_CHECK) &&
                            (available_bits < COUNT_W'(current_length));
    assign busy           = (state != STATE_IDLE) || symbol_valid;

    // Configuration memories use a synchronous write-only process with no
    // reset so they can map to RAM on targets that provide suitable blocks.
    always_ff @(posedge clk) begin
        if (cfg_clear && cfg_ready &&
            (cfg_table_select < TABLE_W'(NUM_TABLES))) begin
            min_length[cfg_table_select] <= '0;
            max_length[cfg_table_select] <= '0;
            for (i = 0; i <= MAX_BITS; i = i + 1)
                length_valid[meta_address(cfg_table_select, LEN_W'(i))]
                    <= 1'b0;
        end

        if (cfg_bounds_valid && cfg_ready &&
            (cfg_table_select < TABLE_W'(NUM_TABLES))) begin
            min_length[cfg_table_select] <= cfg_min_length;
            max_length[cfg_table_select] <= cfg_max_length;
        end

        if (cfg_length_valid && cfg_ready &&
            (cfg_table_select < TABLE_W'(NUM_TABLES)) &&
            (cfg_length >= LEN_W'(1)) &&
            (cfg_length <= LEN_W'(MAX_BITS))) begin
            first_code[meta_address(cfg_table_select, cfg_length)]
                <= cfg_first_code;
            last_code[meta_address(cfg_table_select, cfg_length)]
                <= cfg_last_code;
            first_index[meta_address(cfg_table_select, cfg_length)]
                <= cfg_first_symbol_index;
            length_valid[meta_address(cfg_table_select, cfg_length)]
                <= 1'b1;
        end

        if (cfg_symbol_valid && cfg_ready &&
            (cfg_table_select < TABLE_W'(NUM_TABLES)) &&
            (cfg_symbol_index < INDEX_W'(MAX_SYMBOLS)))
            symbol_memory[symbol_address(cfg_table_select, cfg_symbol_index)]
                <= cfg_symbol_value;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= STATE_IDLE;
            active_table    <= '0;
            current_length  <= '0;
            consume_valid   <= 1'b0;
            consume_count   <= '0;
            symbol_value    <= '0;
            symbol_valid    <= 1'b0;
            bits_consumed   <= '0;
            decode_error    <= 1'b0;
            // Table memories intentionally have no reset. Software configures
            // every active bank before use, allowing synthesis tools to map
            // the arrays to RAM instead of thousands of resettable flip-flops.
        end else begin
            consume_valid <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    if (request_valid && request_ready) begin
                        symbol_valid   <= 1'b0;
                        decode_error   <= 1'b0;
                        bits_consumed  <= '0;

                        if (request_table_select >= TABLE_W'(NUM_TABLES)) begin
                            decode_error <= 1'b1;
                            symbol_valid <= 1'b1;
                            state        <= STATE_OUTPUT;
                        end else begin
                            active_table   <= request_table_select;
                            current_length <= min_length[request_table_select];

                            if ((min_length[request_table_select] < LEN_W'(1)) ||
                                (max_length[request_table_select] <
                                 min_length[request_table_select]) ||
                                (max_length[request_table_select] >
                                 LEN_W'(MAX_BITS))) begin
                                decode_error <= 1'b1;
                                symbol_valid <= 1'b1;
                                state        <= STATE_OUTPUT;
                            end else begin
                                state <= STATE_CHECK;
                            end
                        end
                    end
                end

                STATE_CHECK: begin
                    if (available_bits >= COUNT_W'(current_length)) begin
                        if (length_valid[active_meta_address] &&
                            (candidate_code >=
                             first_code[active_meta_address]) &&
                            (candidate_code <=
                             last_code[active_meta_address])) begin
                            if (candidate_index < (MAX_BITS + 1)'(MAX_SYMBOLS)) begin
                                symbol_value <= symbol_memory[symbol_address(
                                    active_table,
                                    candidate_index[INDEX_W-1:0])];
                                bits_consumed  <= current_length;
                                consume_count  <= current_length;
                                consume_valid  <= 1'b1;
                                symbol_valid   <= 1'b1;
                                decode_error   <= 1'b0;
                                state          <= STATE_OUTPUT;
                            end else begin
                                decode_error <= 1'b1;
                                symbol_valid <= 1'b1;
                                state        <= STATE_OUTPUT;
                            end
                        end else if (current_length >= max_length[active_table]) begin
                            decode_error <= 1'b1;
                            symbol_valid <= 1'b1;
                            state        <= STATE_OUTPUT;
                        end else begin
                            current_length <= current_length + 1'b1;
                        end
                    end
                end

                STATE_OUTPUT: begin
                    if (symbol_valid && symbol_ready) begin
                        symbol_valid <= 1'b0;
                        decode_error <= 1'b0;
                        state        <= STATE_IDLE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
