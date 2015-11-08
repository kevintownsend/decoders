module stream_decoder(clk, rst, push, d, q, full, half_full, ready, pop, table_push, table_addr, table_code_width, table_data);
    parameter WIDTH_IN = 64;
    parameter WIDTH_OUT = 8;
    parameter MAX_CODE_LENGTH = 9;
    parameter INTERMEDIATE_WIDTH = 8;
    parameter LOG2_MAX_CODE_LENGTH = log2(MAX_CODE_LENGTH);
    parameter LOG2_WIDTH_OUT = log2(WIDTH_OUT);
    parameter RAM_DEPTH = 2**MAX_CODE_LENGTH;

    input clk, rst;
    input push;
    input [WIDTH_IN - 1:0] d;
    output [WIDTH_OUT - 1:0] q;
    output full, half_full;
    output ready;
    input pop;
    input table_push;
    input [MAX_CODE_LENGTH - 1:0] table_addr;
    input [LOG2_MAX_CODE_LENGTH - 1:0] table_code_width;
    input [WIDTH_OUT - 1:0] table_data;

    wire [MAX_CODE_LENGTH - 1:0] argument_decoder_q;
    reg [LOG2_MAX_CODE_LENGTH - 1:0] argument_decoder_pop;
    argument_decoder #(MAX_CODE_LENGTH, WIDTH_IN, INTERMEDIATE_WIDTH) ad(clk, rst, push, d, argument_decoder_q, full, half_full, ready, argument_decoder_pop);

    reg [LOG2_MAX_CODE_LENGTH - 1:0] code_width_table [0:RAM_DEPTH - 1];
    reg [WIDTH_OUT - 1:0] data_table [0:RAM_DEPTH - 1];
    reg [MAX_CODE_LENGTH - 1:0] internal_table_addr;

    reg table_push_stage_0;
    reg [MAX_CODE_LENGTH - 1:0] table_addr_stage_0;
    reg [LOG2_MAX_CODE_LENGTH - 1:0] table_code_width_stage_0;
    reg [WIDTH_OUT - 1:0] table_data_stage_0;

    always @(posedge clk) begin
        table_push_stage_0 <= table_push;
        table_addr_stage_0 <= table_addr;
        table_code_width_stage_0 <= table_code_width;
        table_data_stage_0 <= table_data;
    end

    always @* if(table_push_stage_0)
        internal_table_addr = table_addr_stage_0;
    else
        internal_table_addr = argument_decoder_q;

    always @(posedge clk) begin
        if(table_push_stage_0)
            code_width_table[internal_table_addr] <= table_code_width_stage_0;
    end
    wire [LOG2_MAX_CODE_LENGTH - 1:0] code_width_table_q = code_width_table[internal_table_addr];
    reg [WIDTH_OUT - 1:0] data_out;
    always @(posedge clk) begin
        if(table_push_stage_0)
            data_table[internal_table_addr] <= table_data_stage_0;
        data_out <= data_table[internal_table_addr];
    end
    assign q = data_out;

    always @* if(pop)
        argument_decoder_pop = code_width_table_q;
    else
        argument_decoder_pop = 0;

    `include "common.vh"
endmodule
