module sparse_matrix_decoder_tb;
    parameter ID = 0;
    parameter REGISTERS_START = 4;
    parameter REGISTERS_END = REGISTERS_START + 10;
    `include "smac.vh"

    reg clk;
    reg [63:0] op;
    wire busy;

    wire req_mem_ld;
    wire [47:0] req_mem_addr;
    wire [1:0] req_mem_tag;
    reg req_mem_stall;
    reg rsp_mem_push;
    reg [1:0] rsp_mem_tag;
    reg [63:0] rsp_mem_q;
    wire rsp_mem_stall;

    wire req_scratch_ld;
    wire req_scratch_st;
    wire [12:0] req_scratch_addr;
    wire [63:0] req_scratch_d;
    reg req_scratch_stall;
    reg rsp_scratch_push;
    reg [63:0] rsp_scratch_q;
    wire rsp_scratch_stall;

    wire push_index;
    wire [31:0] row;
    wire [31:0] col;
    reg stall_index;
    wire push_val;
    wire [63:0] val;
    reg stall_val;

    sparse_matrix_decoder #(0, 4, 8, 512) dut(clk, op, busy, req_mem_ld, req_mem_addr,
    req_mem_tag, req_mem_stall, rsp_mem_push, rsp_mem_tag, rsp_mem_q,
    rsp_mem_stall, req_scratch_ld, req_scratch_st, req_scratch_addr,
    req_scratch_d, req_scratch_stall, rsp_scratch_push, rsp_scratch_q,
    rsp_scratch_stall, push_index, row, col, stall_index, push_val, val,
    stall_val);

    initial begin
        clk = 0;
        forever #5 clk = !clk;
    end

    initial begin
        #10000000 $display("watchdog timer reached");
        $finish;
    end
    reg [63:0] mock_main_memory [0:1000000 - 1];
    initial $readmemh("example.hex", mock_main_memory);
    //initial $readmemh("consph0.hex", mock_main_memory);
    /*
struct SmacHeader{
    ull r0;
    ull width;
    ull height;
    ull nnz;
    ull spmCodeStreamBitLength;
    ull spmArgumentStreamBitLength;
    ull fzipCodeStreamBitLength;
    ull fzipArgumentStreamBitLength;
    ull r1[8];
    ull spmCodesPtr;
    ull fzipCodesPtr;
    ull commonDoublesPtr;
    ull spmCodeStreamPtr;
    ull spmArgumentStreamPtr;
    ull fzipCodeStreamPtr;
    ull fzipArgumentStreamPtr;
    ull size;
    ull r2[8];
};
*/
    wire [63:0] nnz = mock_main_memory[3];

    wire [63:0] spmCodesPtr = mock_main_memory[16];
    wire [63:0] fzipCodesPtr = mock_main_memory[17];
    wire [63:0] commonDoublesPtr = mock_main_memory[18];
    wire [63:0] spmCodeStreamPtr = mock_main_memory[19];
    wire [63:0] spmArgumentStreamPtr = mock_main_memory[20];
    wire [63:0] fzipCodeStreamPtr = mock_main_memory[21];
    wire [63:0] fzipArgumentStreamPtr = mock_main_memory[22];
    wire [63:0] size = mock_main_memory[23];
    integer tmp;

    `include "spmv_opcodes.vh"
    initial begin
        op[OPCODE_ARG_PE - 1:0] = OP_RST; //reset
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 0;
        op[63:OPCODE_ARG_2] = 0;
        req_mem_stall = 0;
        stall_index = 0;
        stall_val = 0;
        #100 op = OP_NOP;
        #100;
        $display("starting to load delta codes");
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+2;
        op[63:OPCODE_ARG_2] = spmCodesPtr;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+6;
        op[63:OPCODE_ARG_2] = fzipCodesPtr;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+3;
        op[63:OPCODE_ARG_2] = 0;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+7;
        op[63:OPCODE_ARG_2] = 2**7*8;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD_DELTA_CODES;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 0;
        op[63:OPCODE_ARG_2] = 0;
        #10 op = OP_NOP;
        while(busy)begin
            #10;
        end
        $display("starting to load prefix codes");
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+2;
        op[63:OPCODE_ARG_2] = fzipCodesPtr;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+6;
        op[63:OPCODE_ARG_2] = commonDoublesPtr;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+3;
        op[63:OPCODE_ARG_2] = 0;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+7;
        op[63:OPCODE_ARG_2] = 2**9*8*2;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD_PREFIX_CODES;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 0;
        op[63:OPCODE_ARG_2] = 0;
        #10;
        op = OP_NOP;
        while(busy)begin
            #10;
        end

        $display("starting to load common codes");
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+2;
        op[63:OPCODE_ARG_2] = commonDoublesPtr;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+6;
        op[63:OPCODE_ARG_2] = spmCodeStreamPtr;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+3;
        op[63:OPCODE_ARG_2] = 0;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+7;
        op[63:OPCODE_ARG_2] = 2**9*16;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD_COMMON_CODES;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 0;
        op[63:OPCODE_ARG_2] = 0;
        #10;
        op = OP_NOP;
        while(busy)begin
            #10;
        end
        $display("starting steady state");
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+2;
        op[63:OPCODE_ARG_2] = spmCodeStreamPtr;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+3;
        op[63:OPCODE_ARG_2] = spmArgumentStreamPtr;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+4;
        op[63:OPCODE_ARG_2] = fzipCodeStreamPtr;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+5;
        op[63:OPCODE_ARG_2] = fzipArgumentStreamPtr;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+6;
        op[63:OPCODE_ARG_2] = spmArgumentStreamPtr;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+7;
        op[63:OPCODE_ARG_2] = fzipCodeStreamPtr;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+8;
        op[63:OPCODE_ARG_2] = fzipArgumentStreamPtr;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+9;
        op[63:OPCODE_ARG_2] = size;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+10;
        op[63:OPCODE_ARG_2] = nnz - 1;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_LD;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 2+11;
        op[63:OPCODE_ARG_2] = nnz - 1;
        #10;
        op[OPCODE_ARG_PE - 1:0] = OP_STEADY;
        op[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = 0;
        op[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = 0;
        op[63:OPCODE_ARG_2] = 0;
        #10 op = OP_NOP;
        //TODO: load spm codes
        //TODO: load fzip codes
        //TODO: load common codes
        //TODO: steady state
    end

    //TODO: memory interface
    always @(posedge clk) begin
        rsp_mem_push <= 0;
        rsp_mem_tag <= 0;
        rsp_mem_q <= 0;
        if(req_mem_ld) begin
            rsp_mem_push <= 1;
            rsp_mem_tag <= req_mem_tag;
            rsp_mem_q <= mock_main_memory[req_mem_addr / 8];
        end
    end
    reg [63:0] mock_scratch_pad [0:512*16 - 1];
    //TODO: scratch pad interface
    always @(posedge clk) begin
        rsp_scratch_push <= 0;
        rsp_scratch_q <= 0;
        if(req_scratch_st) begin
            mock_scratch_pad[req_scratch_addr] <= req_scratch_d;
        end
        if(req_scratch_ld) begin
            $display("loading to scratchpad");
            rsp_scratch_push <= 1;
            rsp_scratch_q <= mock_scratch_pad[req_scratch_addr];
        end
    end

    //TODO: check output
    integer push_index_count;
    initial push_index_count = 0;
    integer push_val_count;
    initial push_val_count = 0;
    always @(posedge clk) begin
        if(push_index) begin
            //if(push_index_count >= 121)
            //    $finish;
            $display("push_index: row: %d col: %d", row, col);
            push_index_count = push_index_count + 1;
        end
        if(push_val) begin
            /*
            if(push_val_count >= 4)
                $finish;
            */
            $display("push_val: %f", $bitstoreal(val));
            push_val_count = push_val_count + 1;
        end
    end

    always @(posedge clk) begin
        //$display("state: %d", dut.state);
        /*
        if(dut.state == 1) begin
            $display("state 1: at %d", $time);
            $display("r[2]: %d", dut.registers[2]);
            $display("r[6]: %d", dut.registers[6]);
        end
        */
    end
    `include "common.vh"
endmodule
