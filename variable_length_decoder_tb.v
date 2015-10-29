module variable_length_decoder_tb;
    parameter WIDTH_OUT=8;
    parameter WIDTH_IN=8;
    parameter BUFFER_WIDTH=16;
    reg clk, rst, push;
    localparam LOG2_BUFFER_WIDTH = log2(BUFFER_WIDTH - 1);
    localparam LOG2_WIDTH_OUT = log2(WIDTH_OUT - 1);
    localparam LOG2_WIDTH_IN = log2(WIDTH_IN - 1);
    wire full;
    wire [LOG2_BUFFER_WIDTH:0] size;
    reg [LOG2_WIDTH_OUT:0] pop;
    reg [WIDTH_IN - 1:0] d;
    wire [WIDTH_OUT - 1:0] q;

    variable_length_decoder #(WIDTH_OUT, WIDTH_IN, BUFFER_WIDTH) dut(clk, rst, push, full, size, pop, d, q);

    initial begin
        clk = 0;
        forever #5 clk = !clk;
    end

    initial begin
        #1000 $display("watchdog timer reached");
        $finish;
    end

    initial begin
        rst = 1;
        push = 0;
        pop = 0;
        d = 0;
        #100 rst = 0;
        if(size != 0) begin
            $display("size not reset correctly: %d", size);
            $finish;
        end
        #20 push = 1;
        d = 'HAB;
        #10 push = 0;
        $display("size: %d", size);
        #10 pop = 4;
        $display("q: %H", q);
        #10 pop = 4;
        $display("q: %H", q);
        #10 pop = 0;
    end

    always @(posedge clk) begin
    end
    `include "common.vh"
endmodule
