module argument_decoder(clk, rst, push, d, q, full, half_full, ready, pop);
    parameter WIDTH_OUT = 8;
    parameter WIDTH_IN = 16;
    parameter INTERMEDIATE_WIDTH = WIDTH_OUT;
    parameter LOG2_WIDTH_OUT = log2(WIDTH_OUT - 1);
    parameter BUFFER_WIDTH = WIDTH_OUT + INTERMEDIATE_WIDTH;
    parameter LOG2_BUFFER_WIDTH = log2(BUFFER_WIDTH - 1);
    input clk, rst;
    input push;
    input [WIDTH_IN - 1:0] d;
    output [WIDTH_OUT - 1:0] q;
    output full;
    output half_full;
    output ready;
    input [LOG2_WIDTH_OUT:0] pop;
    reg fifo_pop;
    wire [INTERMEDIATE_WIDTH - 1:0] fifo_q;
    wire fifo_empty, fifo_almost_empty, fifo_almost_full;
    localparam LOG2_FIFO_DEPTH = log2(32 - 1);
    wire [LOG2_FIFO_DEPTH:0] fifo_size;
    asymmetric_fifo #(.WIDTH_IN(WIDTH_IN), .WIDTH_OUT(INTERMEDIATE_WIDTH), .DEPTH_IN(32), .ALMOST_FULL_COUNT(16)) fifo(rst, clk, push, fifo_pop, d, fifo_q, full, fifo_empty, fifo_size, fifo_almost_empty, half_full);
    wire vld_full;
    wire [LOG2_BUFFER_WIDTH:0] vld_size;
    always @*
        fifo_pop = !fifo_empty && !vld_full;

    variable_length_decoder #(WIDTH_OUT, INTERMEDIATE_WIDTH, BUFFER_WIDTH) vld(clk, rst, fifo_pop, vld_full, vld_size, pop, fifo_q, q);

    assign ready = |vld_size[LOG2_BUFFER_WIDTH:LOG2_WIDTH_OUT];
    //variable_length_decoder vld();
    //TODO: finish
    `include "common.vh"
endmodule
