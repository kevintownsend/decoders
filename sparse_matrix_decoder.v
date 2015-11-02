module sprase_matrix_decoder(clk, op, busy, req_mem_ld, req_mem_addr,
    req_mem_tag, req_mem_stall, rsp_mem_push, rsp_mem_tag, rsp_mem_q,
    rsp_mem_stall, req_scratch_ld, req_scratch_st, req_scratch_addr,
    req_scratch_d, req_scratch_stall, rsp_scratch_push, rsp_scratch_q,
    rsp_scratch_stall, push_index, row, col, stall_index, push_val, val,
    stall_val);

    input clk;
    input [63:0] op;
    output reg busy;

    output reg req_mem_ld;
    output reg [47:0] req_mem_addr;
    output reg [1:0] req_mem_tag;
    input req_mem_stall;
    input rsp_mem_push;
    input [1:0] rsp_mem_tag;
    input [63:0] rsp_mem_q;
    output rsp_mem_stall;

    output req_scratch_ld;
    output req_scratch_st;
    output [12:0] req_scratch_addr;
    output [63:0] req_scratch_d;
    input req_scratch_stall;
    input rsp_scratch_push;
    input [63:0] rsp_scratch_q;
    output rsp_scratch_stall;

    output push_index;
    output [31:0] row;
    output [31:0] col;
    input stall_index;
    output push_val;
    output [63:0] val;
    input stall_val;

    parameter ID = 0;
    parameter REGISTERS_START = 2;
    parameter REGISTERS_END = 12;
    reg [47:0] registers[REGISTERS_START : REGISTERS_END - 1];
    reg [47:0] next_registers[REGISTERS_START : REGISTERS_END - 1];
    `include "spmv_opcodes.vh"

    reg [2:0] state, next_state;
    localparam IDLE = 0;
    localparam LD_DELTA_CODES = 1;
    localparam LD_PREFIX_CODES = 2;
    localparam LD_COMMON_CODES = 3;
    localparam STEADY_1 = 4;
    localparam STEADY_2 = 5;
    localparam STEADY_3 = 6;
    localparam STEADY_4 = 7;
    wire r2_eq_r6 = registers[2] == registers[6];
    wire r3_eq_r7 = registers[3] == registers[7];
    wire r4_eq_r8 = registers[4] == registers[8];
    wire r5_eq_r9 = registers[5] == registers[9];

    wire steady_state = (state == STEADY_1) || (state == STEADY_2) || (state == STEADY_3) || (state == STEADY_4);

    integer i;
    reg all_eq, rst, next_rst;
    always @(posedge clk) begin
        all_eq <= r2_eq_r6 & r3_eq_r7 & r4_eq_r8 & r5_eq_r9;
        rst <= next_rst;
        for(i = REGISTERS_START; i < REGISTERS_END; i = i + 1)
            registers[i] <= next_registers[i];
        state <= next_state;
    end

    wire [47:0] r2_plus_8 = registers[2] + 8;
    wire [47:0] r3_plus_8 = registers[3] + 8;
    wire [47:0] r4_plus_8 = registers[4] + 8;
    wire [47:0] r5_plus_8 = registers[5] + 8;

    wire opcode_active = op[OPCODE_ARG_1 - 1] || (op[OPCODE_ARG_1 - 2:OPCODE_ARG_PE] == ID);

    always @* begin
        req_mem_ld = 0;
        req_mem_addr = registers[2];
        req_mem_tag = 0;
        busy = 1;
        next_rst = 0;
        next_state = state;
        for(i = REGISTERS_START; i < REGISTERS_END; i = i + 1)
            next_registers[i] = registers[i];
        if(opcode_active) begin
            $display("opcode active");
            case(op[OPCODE_ARG_PE - 1:0])
                OP_RST: begin
                    $display("reset");
                    next_rst = 1;
                    next_state = IDLE;
                end
                OP_LD_DELTA_CODES:
                    next_state = LD_DELTA_CODES;
                OP_LD_PREFIX_CODES:
                    next_state = LD_PREFIX_CODES;
                OP_LD_COMMON_CODES:
                    next_state = LD_COMMON_CODES;
                OP_STEADY:
                    next_state = STEADY_1;
                OP_LD:
                    for(i = REGISTERS_START; i < REGISTERS_END; i = i + 1)
                        if(i == op[OPCODE_ARG_2 - 1:OPCODE_ARG_1])
                            next_registers[i] = op[63:OPCODE_ARG_2];
            endcase
        end
        case(state)
            IDLE:
                busy = 0;
            LD_DELTA_CODES: begin
                if(!r2_eq_r6 && !req_mem_stall) begin
                    next_registers[2] = r2_plus_8;
                    req_mem_ld = 1;
                end
                if(r3_eq_r7)
                    next_state = IDLE;
                if(rsp_mem_push) begin
                    next_registers[3] = r3_plus_8;
                end
            end
            LD_PREFIX_CODES: begin
                if(!r2_eq_r6 && !req_mem_stall) begin
                    next_registers[2] = r2_plus_8;
                    //TODO: request memory
                end
                if(r3_eq_r7) begin
                    next_state = IDLE;
                end
                if(rsp_mem_push) begin
                    //TODO: store prefix code (16 byte values)
                    next_registers[3] = r3_plus_8;
                end
            end
            LD_COMMON_CODES: begin
                if(!r2_eq_r6 && req_mem_stall) begin
                    next_registers[2] = r2_plus_8;
                    //TODO: request memory
                end
                if(r3_eq_r7) begin
                    next_state = IDLE;
                end
                if(rsp_mem_push) begin
                    //TODO: store common codes
                    next_registers[3] = r3_plus_8;
                end
            end
            STEADY_1: begin //index code stream
                if(!r2_eq_r6 && !req_mem_stall) begin
                    next_registers[2] = r2_plus_8;
                    //TODO: request index stream
                end
                if(all_eq) begin
                end
                //TODO: next_state logic
            end
            STEADY_2: begin //index stream arguments
                if(!r3_eq_r7 && !req_mem_stall) begin
                    //TODO: request data
                    next_registers[3] = r3_plus_8;
                end
                //TODO: next_state logic
            end
            STEADY_3: begin //floating point code stream
                if(!r4_eq_r8 && !req_mem_stall) begin
                    //TODO: request data
                    next_registers[4] = r4_plus_8;
                end
                //TODO: next_state logic
            end
            STEADY_4: begin //floating point argument stream
                if(!r5_eq_r9 && !req_mem_stall) begin
                    //TODO: request data
                    next_registers[5] = r5_plus_8;
                end
                //TODO: next_state logic
            end
        endcase
        if(state[2]) begin //TODO: semantic
            //TODO: response logic
        end
    end

    reg spm_stream_decoder_push;
    wire [63:0] linked_list_fifo_q;
    wire [2 + 5 - 1:0] spm_stream_decoder_q;
    wire spm_stream_decoder_full;
    wire spm_stream_decoder_half_full;
    wire spm_stream_decoder_ready;
    reg spm_stream_decoder_pop;
    reg spm_stream_decoder_table_push;
    localparam SPM_TABLE_DEPTH = 2**7;
    localparam LOG2_SPM_TABLE_DEPTH = 7;
    reg [LOG2_SPM_TABLE_DEPTH - 1:0] spm_stream_decoder_table_addr;
    localparam LOG2_LOG2_SPM_TABLE_DEPTH = 3;
    reg [LOG2_LOG2_SPM_TABLE_DEPTH - 1:0] spm_stream_decoder_table_code_width;
    reg [2 + 5 - 1:0] spm_stream_decoder_table_data;
    stream_decoder #(64, 7, 7, 8) spm_stream_decoder(clk, rst, spm_stream_decoder_push, linked_list_fifo_q, spm_stream_decoder_q, spm_stream_decoder_full, spm_stream_decoder_half_full, spm_stream_decoder_ready, spm_stream_decoder_pop, spm_stream_decoder_table_push, spm_stream_decoder_table_addr, spm_stream_decoder_table_code_width, spm_stream_decoder_table_data);

    always @* begin
        spm_stream_decoder_table_push = 0;
        spm_stream_decoder_table_addr = registers[3] / 8;
        spm_stream_decoder_table_code_width = rsp_mem_q[2:0];
        spm_stream_decoder_table_data = rsp_mem_q[9:3];
        if(state == LD_DELTA_CODES && rsp_mem_push)
            spm_stream_decoder_table_push = 1;
    end
    //TODO: linked list fifo
    //TODO: stream decoders and luts
    //TODO: deltas to indices logic

    //Debug
    always @(posedge clk) begin
        /*
        if(spm_stream_decoder_table_push) begin
            $display("woot at %d", $time);
        end
        */
    end
endmodule
