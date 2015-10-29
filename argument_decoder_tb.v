module argument_decoder_tb;
    parameter WIDTH_OUT = 8;
    parameter WIDTH_IN = 8;
    parameter INTERMEDIATE_WIDTH = WIDTH_OUT;
    parameter LOG2_WIDTH_OUT = log2(WIDTH_OUT - 1);
    parameter BUFFER_WIDTH = WIDTH_OUT + INTERMEDIATE_WIDTH;
    reg clk, rst;
    reg push;
    reg [WIDTH_IN - 1:0] d;
    wire [WIDTH_OUT - 1:0] q;
    wire full;
    wire half_full;
    wire ready;
    reg [LOG2_WIDTH_OUT:0] pop;
    argument_decoder #(WIDTH_OUT, WIDTH_IN) dut(clk, rst, push, d, q, full, half_full, ready, pop);

    initial begin
        clk = 0;
        forever #5 clk = !clk;
    end

    initial begin
        #1000 $display("watchdog reached");
        $finish;
    end

    initial begin
        rst = 1;
        push = 0;
        d = 0;
        pop = 0;
        #100 rst = 0;
        if(full == 1) begin
            $display("full not 0");
            $finish;
        end
        if(half_full == 1) begin
            $display("half_full not 0");
            $finish;
        end
        if(ready == 1) begin
            $display("ready not 0");
            $finish;
        end
        #100 d = 'HAB;
        push = 1;
        #10 push = 0;
        #100
        if(ready != 1)
            $display("ready not 1");
        pop = 4;
        if(q != 'HAB)
            $display("q not correct first test");
        #10 pop = 0;
        if(q != 'HA)
            $display("q not correct second test");
        d = 1;
        $display("half_full %d", half_full);
        while(half_full == 0) begin
            $display("half_full %d", half_full);
            push = 1;
            d = d + 1;
            #10;
        end
        push = 0;
        $display("d: %d", d);
        while(full == 0) begin
            $display("full %d", full);
            push = 1;
            d = d + 1;
            #10;
        end
        push = 0;
        $display("d: %d", d);

    end

    always @(posedge clk) begin
        //$display("fifo size: %d", dut.fifo_size);
    end
    `include "common.vh"
endmodule
