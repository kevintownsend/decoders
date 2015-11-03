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
    output reg rsp_mem_stall;

    output reg req_scratch_ld;
    output reg req_scratch_st;
    output reg [12:0] req_scratch_addr;
    output reg [63:0] req_scratch_d;
    input req_scratch_stall;
    input rsp_scratch_push;
    input [63:0] rsp_scratch_q;
    output reg rsp_scratch_stall;

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

    reg [5:0] counter;
    initial counter = 0;
    always @(posedge clk) begin
        counter <= counter + 1;
        if(counter[5])
            counter[5] <= 0;
    end
    wire recurring_timer = counter[5];

    wire [47:0] r2_plus_8 = registers[2] + 8;
    wire [47:0] r3_plus_8 = registers[3] + 8;
    wire [47:0] r4_plus_8 = registers[4] + 8;
    wire [47:0] r5_plus_8 = registers[5] + 8;

    wire opcode_active = op[OPCODE_ARG_1 - 1] || (op[OPCODE_ARG_1 - 2:OPCODE_ARG_PE] == ID);

    wire spm_stream_decoder_half_full;
    wire spm_argument_decoder_half_full;
    wire fzip_stream_decoder_half_full;
    wire fzip_argument_decoder_half_full;
    reg spm_stage_4;
    reg spm_stage_5;
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
                    req_mem_ld = 1;
                end
                if(r3_eq_r7) begin
                    next_state = IDLE;
                end
                if(rsp_mem_push) begin
                    next_registers[10] = rsp_mem_q[11:4];
                    next_registers[3] = r3_plus_8;
                end

            end
            LD_COMMON_CODES: begin
                if(!r2_eq_r6 && !req_mem_stall) begin
                    next_registers[2] = r2_plus_8;
                    req_mem_ld = 1;
                end
                if(r3_eq_r7) begin
                    next_state = IDLE;
                end
                if(rsp_mem_push) begin
                    next_registers[3] = r3_plus_8;
                end
            end
            STEADY_1: begin //index code stream
                if(!r2_eq_r6 && !req_mem_stall) begin
                    next_registers[2] = r2_plus_8;
                    req_mem_ld = 1;
                    req_mem_tag = 0;
                end
                if(all_eq) begin
                    next_state = IDLE;
                end
                if(recurring_timer || spm_stream_decoder_half_full)
                    next_state = STEADY_2;
            end
            STEADY_2: begin //index stream arguments
                if(!r3_eq_r7 && !req_mem_stall) begin
                    next_registers[3] = r3_plus_8;
                    req_mem_ld = 1;
                    req_mem_tag = 1;
                end
                if(recurring_timer || spm_argument_decoder_half_full)
                    next_state = STEADY_3;
            end
            STEADY_3: begin //floating point code stream
                if(!r4_eq_r8 && !req_mem_stall) begin
                    next_registers[4] = r4_plus_8;
                    req_mem_ld = 1;
                    req_mem_tag = 2;
                end
                if(recurring_timer || fzip_stream_decoder_half_full)
                    next_state = STEADY_4;
            end
            STEADY_4: begin //floating point argument stream
                if(!r5_eq_r9 && !req_mem_stall) begin
                    next_registers[5] = r5_plus_8;
                    req_mem_ld = 1;
                    req_mem_tag = 3;
                end
                if(recurring_timer || fzip_argument_decoder_half_full)
                    next_state = STEADY_1;
            end
        endcase
        if(state[2]) begin //TODO: semantic
            //TODO: response logic
        end
        if(spm_stage_4)
            next_registers[10] = registers[10] - 1;
    end

    wire [63:0] linked_list_fifo_q;
    reg memory_response_fifo_push;
    reg memory_response_fifo_pop;
    reg [1:0] memory_response_fifo_pop_tag;
    wire memory_response_fifo_empty;
    wire memory_response_fifo_full;
    wire memory_response_fifo_almost_full;
    wire [8:0] memory_response_free_count;
    linked_list_fifo #(64, 512, 4) memory_response_fifo(rst, clk, memory_response_fifo_push, rsp_mem_tag, memory_response_fifo_pop, memory_response_fifo_pop_tag, rsp_mem_q, linked_list_fifo_q, memory_response_fifo_empty, memory_response_fifo_full, , memory_response_fifo_almost_full, memory_response_free_count);

    always @* begin
        memory_response_fifo_push = 0;
        if(rsp_mem_push && steady_state)
            memory_response_fifo_push = 1;
    end

    //spm decoders
    reg spm_stream_decoder_push;
    wire [2 + 5 - 1:0] spm_stream_decoder_q;
    wire spm_stream_decoder_full;
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

    reg spm_argument_decoder_push;
    wire [31:0] spm_argument_decoder_q;
    wire spm_argument_decoder_full;
    wire spm_argument_decoder_ready;
    reg [5:0] spm_argument_decoder_pop;
    argument_decoder #(32, 64) spm_argument_decoder(clk, rst, spm_argument_decoder_push, linked_list_fifo_q, spm_argument_decoder_q, spm_argument_decoder_full, spm_argument_decoder_half_full, spm_argument_decoder_ready, spm_argument_decoder_pop);

    wire spm_stage_0 = spm_stream_decoder_ready && spm_argument_decoder_ready && !stall_index; //TODO: fix with almost empty and counter
    reg spm_stage_1;
    integer stage_1_count, stage_0_count;
    always @* begin
        spm_argument_decoder_pop = 0;
        spm_stream_decoder_pop = spm_stage_0;
    end
    always @(posedge clk) begin
        spm_stage_1 <= spm_stage_0;
    end
    wire [1:0] spm_stream_decoder_code_stage_1 = spm_stream_decoder_q[1:0];
    localparam SPM_CODE_NEWLINE = 0;
    localparam SPM_CODE_CONTSTANT = 1;
    localparam SPM_CODE_RANGE = 2;
    wire [4:0] spm_stream_decoder_delta_stage_1 = spm_stream_decoder_q[6:2];
    reg [4:0] spm_argument_pop_stage_2;
    reg spm_stage_2;
    reg [4:0] spm_delta_stage_2;
    reg [1:0] spm_code_stage_2;
    reg [31:0] spm_mask_stage_2;
    always @(posedge clk) begin
        spm_argument_pop_stage_2 <= 0;
        if(spm_stage_1 && spm_stream_decoder_code_stage_1[1])
            spm_argument_pop_stage_2 <= spm_stream_decoder_delta_stage_1;
        spm_stage_2 <= spm_stage_1;
        spm_delta_stage_2 <= spm_stream_decoder_delta_stage_1;
        spm_code_stage_2 <= spm_stream_decoder_code_stage_1;
        spm_mask_stage_2 <= 32'HFFFFFFFF >> (32 - spm_stream_decoder_delta_stage_1);
    end
    assign argument_decoder_pop = spm_argument_pop_stage_2;

    reg spm_stage_3;
    reg [31:0] spm_delta_stage_3;
    reg spm_code_stage_3;
    always @(posedge clk) begin
        spm_stage_3 <= spm_stage_2;
        spm_delta_stage_3 <= spm_delta_stage_2 + 1;
        if(spm_code_stage_2[1])
            spm_delta_stage_3 <= spm_mask_stage_2 & spm_argument_decoder_q + 1;
        spm_code_stage_3 <= spm_code_stage_2[0];
    end

    reg [31:0] spm_row_stage_4;
    reg [31:0] spm_col_stage_4;
    localparam SUB_WIDTH = 4;
    localparam SUB_HEIGHT = 2;
    localparam LOG2_SUB_WIDTH = log2(SUB_WIDTH - 1);
    localparam LOG2_SUB_HEIGHT = log2(SUB_HEIGHT - 1);
    reg [LOG2_SUB_HEIGHT:0] next_lsb_row;
    reg [31 - LOG2_SUB_HEIGHT:0] next_msb_row;
    reg [LOG2_SUB_WIDTH:0] next_lsb_col;
    reg [31 - LOG2_SUB_WIDTH:0] next_msb_col;
    always @* begin
        next_lsb_col = spm_col_stage_4[LOG2_SUB_WIDTH - 1:0] + spm_delta_stage_3[LOG2_SUB_WIDTH - 1:0];
        next_lsb_row = spm_row_stage_4[LOG2_SUB_HEIGHT - 1:0] + spm_delta_stage_3[LOG2_SUB_WIDTH + LOG2_SUB_HEIGHT - 1:LOG2_SUB_WIDTH] + next_lsb_col[LOG2_SUB_WIDTH];
        next_msb_col = spm_col_stage_4[31:LOG2_SUB_WIDTH] + spm_delta_stage_3[31:LOG2_SUB_WIDTH + LOG2_SUB_HEIGHT] + next_lsb_row[LOG2_SUB_HEIGHT];
        next_msb_row = spm_row_stage_4[31:LOG2_SUB_HEIGHT];
        if(spm_code_stage_3 == 0)begin
            next_lsb_col = -1;
            next_lsb_row = -1;
            next_msb_col = -1;
            next_msb_row = spm_row_stage_4[31:LOG2_SUB_HEIGHT] + 1;
        end
    end
    always @(posedge clk) begin
        spm_stage_4 <= spm_stage_3 && spm_code_stage_3;
        if(spm_stage_3) begin
            spm_row_stage_4 <= {next_msb_row, next_lsb_row[LOG2_SUB_HEIGHT - 1:0]};
            spm_col_stage_4 <= {next_msb_col, next_lsb_col[LOG2_SUB_WIDTH - 1:0]};
        end
        if(rst) begin
            spm_row_stage_4 <= 0;
            spm_row_stage_4 [LOG2_SUB_HEIGHT - 1:0] <= -1;
            spm_col_stage_4 <= -1;
            spm_stage_4 <= 0;
        end
    end
    reg [31:0] spm_row_stage_5;
    reg [31:0] spm_col_stage_5;
    always @(posedge clk) begin
        spm_stage_5 <= spm_stage_4;
        if(registers[10][47])
            spm_stage_5 <= 0;
        spm_row_stage_5 <= spm_row_stage_4;
        spm_col_stage_5 <= spm_col_stage_4;
    end
    assign push_index = spm_stage_5;
    assign row = spm_row_stage_5;
    assign col = spm_col_stage_5;

    //fzip decoders
    reg fzip_stream_decoder_push;
    wire [64 + 8 - 1:0] fzip_stream_decoder_q;
    wire fzip_stream_decoder_full;
    wire fzip_stream_decoder_ready;
    reg fzip_stream_decoder_pop;
    reg fzip_stream_decoder_table_push;
    localparam FZIP_TABLE_DEPTH = 2**9;
    localparam LOG2_FZIP_TABLE_DEPTH = 9;
    reg [LOG2_FZIP_TABLE_DEPTH - 1:0] fzip_stream_decoder_table_addr;
    localparam LOG2_LOG2_FZIP_TABLE_DEPTH = 4;
    reg [LOG2_LOG2_FZIP_TABLE_DEPTH - 1:0] fzip_stream_decoder_table_code_width;
    reg [64 + 8 - 1:0] fzip_stream_decoder_table_data;
    stream_decoder #(64, 64 + 8, 9, 16) fzip_stream_decoder(clk, rst, fzip_stream_decoder_push, linked_list_fifo_q, fzip_stream_decoder_q, fzip_stream_decoder_full, fzip_stream_decoder_half_full, fzip_stream_decoder_ready, fzip_stream_decoder_pop, fzip_stream_decoder_table_push, fzip_stream_decoder_table_addr, fzip_stream_decoder_table_code_width, fzip_stream_decoder_table_data);

    always @* begin
        fzip_stream_decoder_table_push = 0;
        fzip_stream_decoder_table_addr = registers[3] / 16;
        fzip_stream_decoder_table_code_width = rsp_mem_q[3:0];
        fzip_stream_decoder_table_data = {rsp_mem_q[63:0], registers[10][7:0]};
        if(state == LD_PREFIX_CODES && rsp_mem_push && registers[3][3])
            fzip_stream_decoder_table_push = 1;
    end

    reg fzip_argument_decoder_push;
    wire [63:0] fzip_argument_decoder_q;
    wire fzip_argument_decoder_full;
    wire fzip_argument_decoder_ready;
    reg [6:0] fzip_argument_decoder_pop;
    argument_decoder #(64, 64) fzip_argument_decoder(clk, rst, fzip_argument_decoder_push, linked_list_fifo_q, fzip_argument_decoder_q, fzip_argument_decoder_full, fzip_argument_decoder_half_full, fzip_argument_decoder_ready, fzip_argument_decoder_pop);


    //common codes

    always @* begin
        req_scratch_st = 0;
        req_scratch_addr = registers[3] / 8;
        req_scratch_d = rsp_mem_q;
        if(state == LD_COMMON_CODES && rsp_mem_push) begin
            req_scratch_st = 1;
        end
    end

    always @* begin
        rsp_mem_stall = 0;
        if(state == LD_COMMON_CODES && rsp_scratch_stall)
            rsp_mem_stall = 1;
    end
    //TODO: fzip argument decoder

    //input arbitration
    reg [1:0] input_arbiter;
    initial input_arbiter = 0;
    wire [0:3] input_fifos_full = {spm_stream_decoder_full, spm_argument_decoder_full, fzip_stream_decoder_full, fzip_argument_decoder_full};
//TODO: almost full
    reg next_spm_stream_decoder_push;
    reg next_spm_argument_decoder_push;
    reg next_fzip_stream_decoder_push;
    reg next_fzip_argument_decoder_push;
    always @(posedge clk) begin
        if(input_fifos_full[input_arbiter] || memory_response_fifo_empty) begin
            input_arbiter <= input_arbiter + 1;
        end
        spm_stream_decoder_push <= next_spm_stream_decoder_push;
        spm_argument_decoder_push <= next_spm_argument_decoder_push;
        fzip_stream_decoder_push <= next_fzip_stream_decoder_push;
        fzip_argument_decoder_push <= next_fzip_argument_decoder_push;
    end
    always @* begin
        memory_response_fifo_pop_tag = input_arbiter;
        memory_response_fifo_pop = 0;
        next_spm_stream_decoder_push = 0;
        next_spm_argument_decoder_push = 0;
        next_fzip_stream_decoder_push = 0;
        next_fzip_argument_decoder_push = 0;
        if(input_arbiter == 0 && !spm_stream_decoder_full && !memory_response_fifo_empty) begin
            next_spm_stream_decoder_push = 1;
            memory_response_fifo_pop = 1;
        end
        if(input_arbiter == 1 && !spm_argument_decoder_full && !memory_response_fifo_empty) begin
            next_spm_argument_decoder_push = 1;
            memory_response_fifo_pop = 1;
        end
        if(input_arbiter == 2 && !fzip_stream_decoder_full && !memory_response_fifo_empty) begin
            next_fzip_stream_decoder_push = 1;
            memory_response_fifo_pop = 1;
        end
        if(input_arbiter == 3 && !fzip_argument_decoder_full && !memory_response_fifo_empty) begin
            next_fzip_argument_decoder_push = 1;
            memory_response_fifo_pop = 1;
        end
    end
    //TODO: stream decoders and luts
    //TODO: deltas to indices logic

    //Debug
    always @(posedge clk) begin
        /*
        if(spm_stream_decoder_push)
            $display("spm_stream_decoder_push");
        if(spm_argument_decoder_push)
            $display("spm_argument_decoder_push");
        if(state == LD_COMMON_CODES) begin
            $display("LD_COMMON_CODES state");
        end
        if(fzip_stream_decoder_table_push) begin
            $display("woot at %d", $time);
        end
        */
    end
    `include "common.vh"
endmodule
