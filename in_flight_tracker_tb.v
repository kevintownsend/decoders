module in_flight_tracker_tb;
    parameter COLORS = 4;
    parameter MIN_DEPTH = 32;
    parameter MAX_DEPTH = 512;
    localparam HEAD_ROOM = MAX_DEPTH - COLORS * MIN_DEPTH;
    localparam LOG2_COLORS = log2(COLORS);
    localparam LOG2_MAX_DEPTH = log2(MAX_DEPTH);
    reg clk;
    reg push;
    reg [LOG2_COLORS - 1:0] push_tag;
    reg pop;
    reg [LOG2_COLORS - 1:0] pop_tag;
    reg [LOG2_COLORS - 1:0] read;
    wire [LOG2_MAX_DEPTH - 1:0] count;
    wire ready;
    in_flight_tracker dut(clk, push, push_tag, pop, pop_tag, ready);
    initial begin
        clk = 0;
        forever #5 clk = !clk;
    end
    integer i;
    initial begin
        push = 0;
        push_tag = 0;
        pop = 0;
        pop_tag = 0;
        read = 0;
        #10;
        i = 0;
        while(ready) begin
            push = 1;
            #10;
            i = i + 1;
        end
        $display("push count: %d", i);

        push = 0;
        #10 push_tag = 1;
        #10 $display("ready: %d", ready);
        i = 0;
        while(ready) begin
            push = 1;
            #10;
            i = i + 1;
        end
        $display("push count: %d", i);
        $finish;
    end
    `include "common.vh"
endmodule
