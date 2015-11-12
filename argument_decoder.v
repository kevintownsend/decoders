module argument_decoder(clk, rst, push, d, q, full, half_full, ready, pop, almost_empty);
    parameter WIDTH_OUT = 64;
    parameter WIDTH_IN = 64;
    parameter INTERMEDIATE_WIDTH = WIDTH_OUT;
    parameter LOG2_WIDTH_OUT = log2(WIDTH_OUT);
    parameter BUFFER_WIDTH = WIDTH_OUT + INTERMEDIATE_WIDTH;
    parameter LOG2_BUFFER_WIDTH = log2(BUFFER_WIDTH);
    input clk, rst;
    input push;
    input [WIDTH_IN - 1:0] d;
    output [WIDTH_OUT - 1:0] q;
    output full;
    output half_full;
    output ready;
    input [LOG2_WIDTH_OUT - 1:0] pop;
    output almost_empty;
    reg fifo_pop;
    wire [INTERMEDIATE_WIDTH - 1:0] fifo_q;
    wire fifo_empty, fifo_almost_empty, fifo_almost_full;
    localparam LOG2_FIFO_DEPTH = log2(32 - 1);
    asymmetric_fifo #(.WIDTH_IN(WIDTH_IN), .WIDTH_OUT(INTERMEDIATE_WIDTH), .DEPTH_IN(32), .ALMOST_EMPTY_COUNT(4), .ALMOST_FULL_COUNT(16)) fifo(rst, clk, push, fifo_pop, d, fifo_q, full, fifo_empty, , fifo_almost_empty, half_full);
    wire vld_full;
    wire [LOG2_BUFFER_WIDTH - 1:0] vld_size;
    always @*
        fifo_pop = !fifo_empty && !vld_full;

    variable_length_decoder #(WIDTH_OUT, INTERMEDIATE_WIDTH, BUFFER_WIDTH) vld(clk, rst, fifo_pop, vld_full, vld_size, pop, fifo_q, q);

    assign ready = vld_size >= WIDTH_OUT;
    assign almost_empty = fifo_almost_empty;
    //variable_length_decoder vld();
    //TODO: finish
    always @(posedge clk) begin
        if(pop && !ready) begin
            $display("ERROR: underflow at %m");
            $finish;
        end
    end
    `include "common.vh"
endmodule
