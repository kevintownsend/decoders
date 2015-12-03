module in_flight_tracker(clk, push, push_tag, pop, pop_tag, ready);
    parameter COLORS = 4;
    parameter MIN_DEPTH = 32;
    parameter MAX_DEPTH = 512;
    localparam HEAD_ROOM = MAX_DEPTH - COLORS * MIN_DEPTH;
    localparam LOG2_COLORS = log2(COLORS - 1);
    localparam LOG2_MAX_DEPTH = log2(MAX_DEPTH - 1);
    input clk;
    input push;
    input [LOG2_COLORS - 1:0] push_tag;
    input pop;
    input [LOG2_COLORS - 1:0] pop_tag;
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
            push_count[push_tag] <= push_count[push_tag] + 1;
        if(pop)
            pop_count[pop_tag] <= pop_count[pop_tag] + 1;
        if(push && pop) begin
        end else if(push) begin
            total <= total + 1;
        end else if(pop) begin
            total <= total - 1;
        end
    end

    //TODO: make output faster
    //wire [LOG2_MAX_DEPTH - 1:0] count = push_count[push_tag] - pop_count[push_tag];
    //assign ready = (total < HEAD_ROOM) || (count < 32);
    reg [LOG2_COLORS - 1:0] counter_stage_0;
    initial counter_stage_0 = 0;
    always @(posedge clk) counter_stage_0 <= counter_stage_0 + 1;
    reg [LOG2_MAX_DEPTH - 1:0] push_count_r_stage_1, pop_count_r_stage_1;
    always @(posedge clk) begin
        push_count_r_stage_1 <= push_count[counter_stage_0];
        pop_count_r_stage_1 <= pop_count[counter_stage_0];
    end
    reg [LOG2_MAX_DEPTH - 1:0] count_stage_2;
    always @(posedge clk) count_stage_2 <= push_count_r_stage_1 - pop_count_r_stage_1;
    reg count_is_small_stage_3, total_is_small_stage_3;
    always @(posedge clk) begin
        count_is_small_stage_3 <= count_stage_2 < 32;
        total_is_small_stage_3 <= total < HEAD_ROOM;
    end
    reg ready_stage_4;
    reg [LOG2_COLORS - 1:0] counter_stage_4;
    always @* counter_stage_4 = counter_stage_0;
    always @(posedge clk) ready_stage_4 <= count_is_small_stage_3 || total_is_small_stage_3;
    reg [0:COLORS - 1] ready_array;
    always @(posedge clk) ready_array[counter_stage_4] <= ready_stage_4;
    assign ready = ready_array[push_tag];

    `include "common.vh"
endmodule
