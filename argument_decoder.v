module argument_decoder(clk, rst, push, d, q, full, half_full, ready, pop);
    parameter WIDTH_OUT = 8;
    parameter WIDTH_IN = 8;
    parameter INTERMEDIATE_WIDTH = WIDTH_OUT;
    input clk, rst;
    input push;
    input [WIDTH_IN - 1:0] d;
    output [WIDTH_OUT - 1:0] q;
    output full;
    output half_full;
    output ready;
    input pop;
    reg fifo_pop;
    wire [INTERMEDIATE_WIDTH - 1:0] fifo_q;
    wire fifo_empty, fifo_almost_empty, fifo_almost_full;
    asymetric_fifo #() fifo(rst, clk, push, d, fifo_pop, fifo_q, fifo_empty, full, fifo_almost_empty, fifo_almost_full);
    wire vld_full;
    vld_size;
    parameter BUFFER_WIDTH = WIDTH_OUT + INTERMEDIATE_WIDTH;
    variable_length_decoder #(WIDTH_OUT, INTERMEDIATE_WIDTH, BUFFER_WIDTH) vld(clk, rst, !fifo_empty && !vld_full, vld_size, pop, fifo_q, q);
    //variable_length_decoder vld();
    //TODO: finish
endmodule
