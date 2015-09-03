module variable_length_decoder(clk, rst, push, full, size, pop, d, q);
    parameter WIDTH_OUT=8;
    parameter WIDTH_IN=8;
    parameter BUFFER_WIDTH=16;
    input clk, rst, push;
    localparam LOG2_BUFFER_WIDTH = log2(BUFFER_WIDTH);
    localparam LOG2_WIDTH_OUT = log2(WIDTH_OUT);
    localparam LOG2_WIDTH_IN = log2(WIDTH_IN);
    output full;
    output [LOG2_BUFFER_WIDTH - 1:0] size;
    input [LOG2_WIDTH_OUT - 1:0] pop;
    input [WIDTH_IN - 1:0] d;
    output [WIDTH_OUT - 1:0] q;

    reg [BUFFER_WIDTH - 1:0] buffer, next_buffer;
    reg [LOG2_BUFFER_WIDTH - 1:0] buffer_end, next_buffer_end;

    always @(posedge clk) begin
        buffer_end <= next_buffer_end;
        if(rst)
            buffer_end <= 0;
        buffer <= next_buffer;
    end
    reg [LOG2_WIDTH_OUT - 1:0] rst_pop;
    always @* begin
        rst_pop = pop;
        if(rst)
            rst_pop[LOG2_WIDTH_OUT - 1] = 1;
        next_buffer = buffer >> rst_pop;
        next_buffer_end = buffer_end - pop;
        if(push) begin
            next_buffer = next_buffer | (d << next_buffer_end);
            next_buffer_end = next_buffer_end + WIDTH_IN;
        end
    end
    assign full = buffer_end > (BUFFER_WIDTH - WIDTH_IN);
    assign size = buffer_end;
    assign q = buffer[WIDTH_OUT - 1:0];
endmodule
