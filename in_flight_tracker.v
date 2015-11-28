module in_flight_tracker(clk, push, push_tag, pop, pop_tag, read, count, ready);
    parameter COLORS = 4;
    parameter MIN_DEPTH = 32;
    parameter MAX_DEPTH = 512;
    localparam HEAD_ROOM = MAX_DEPTH - COLORS * MIN_DEPTH;
    localparam LOG2_COLORS = log2(COLORS);
    localparam LOG2_MAX_DEPTH = log2(MAX_DEPTH);
    input clk;
    input push;
    input [LOG2_COLORS - 1:0] push_tag;
    input pop;
    input [LOG2_COLORS - 1:0] pop_tag;
    input [LOG2_COLORS - 1:0] read;
    output [LOG2_MAX_DEPTH - 1:0] count;
    output ready;

    reg [LOG2_MAX_DEPTH - 1:0] push_count [0:COLORS - 1];
    reg [LOG2_MAX_DEPTH - 1:0] pop_count [0:COLORS - 1];
    integer i;
    initial for(i = 0; i < COLORS; i = i + 1) begin
        push_count[i] = 0;
        pop_count[i] = 0;
    end
    reg [LOG2_MAX_DEPTH - 1:0] total;
    initial total = 0;
    always @(posedge clk) begin
        if(push)
            push_count[push_tag] = push_count[push_tag] + 1;
        if(pop)
            pop_count[pop_tag] = pop_count[pop_tag] + 1;
        if(push && pop) begin
        end else if(push) begin
            total = total + 1;
        end else if(pop) begin
            total = total - 1;
        end

    end

    //TODO: make output faster
    assign count = push_count[read] - pop_count[read];
    assign ready = (total < HEAD_ROOM) || (count < 32);

    `include "common.vh"
endmodule
