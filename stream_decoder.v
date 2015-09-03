module stream_decoder(clk, rst, push_code, d, q, full, half_full, lut_counter, push_out, stall);
    parameter WIDTH_IN = 8;
    parameter WIDTH_OUT = 8;

    input clk, rst;
    input [1:0] push_code;
    input [WIDTH_IN - 1:0] d;
    output reg [WIDTH_OUT - 1:0] q;
    output full, half_full;
    output reg [WIDTH_OUT - 1:0] lut_counter;
    output push_out;
    input stall;
    argument_decoder ad();
    localparam LOG2_WIDTH_OUT = log2(WIDTH_OUT);
    reg [LOG2_WIDTH_OUT - 1:0] lut [0:2**WIDTH_OUT - 1];
    reg [WIDTH_OUT - 1:0] lut_addr;
    wire [LOG2_WIDTH_OUT - 1:0] lut_out = lut[lut_addr];
    always @(posedge clk)
        if(push_code == 3)
            lut[lut_addr] <= d;

    always @(posedge clk) begin
        if(rst)
            lut_counter <= 0;
        else if(push_code == 3)
            lut_counter <= lut_counter + 1;
    end
    always @*
        if(push_code == 3)
            lut_addr = lut_counter;
        else
            lut_addr = q;
endmodule
