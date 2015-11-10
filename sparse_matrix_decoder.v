module sparse_matrix_decoder(clk, op, busy, req_mem_ld, req_mem_addr,
    req_mem_tag, req_mem_stall, rsp_mem_push, rsp_mem_tag, rsp_mem_q,
    rsp_mem_stall, req_scratch_ld, req_scratch_st, req_scratch_addr,
    req_scratch_d, req_scratch_stall, rsp_scratch_push, rsp_scratch_q,
    rsp_scratch_stall, push_index, row, col, stall_index, push_val, val,
    stall_val);
    parameter ID = 0;
    parameter REGISTERS_START = 2;
    parameter SUB_WIDTH = 4;
    parameter SUB_HEIGHT = 2;
    parameter REGISTERS_END = REGISTERS_START + 10;
    localparam LOG2_SUB_WIDTH = log2(SUB_WIDTH - 1);
    localparam LOG2_SUB_HEIGHT = log2(SUB_HEIGHT - 1);

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
    output rsp_scratch_stall;

    output push_index;
    output [31:0] row;
    output [31:0] col;
    input stall_index;
    output push_val;
    output [63:0] val;
    input stall_val;

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
    wire r2_eq_r6 = registers[REGISTERS_START] == registers[REGISTERS_START + 4];
    wire r3_eq_r7 = registers[REGISTERS_START + 1] == registers[REGISTERS_START + 5];
    wire r4_eq_r8 = registers[REGISTERS_START + 2] == registers[REGISTERS_START + 6];
    wire r5_eq_r9 = registers[REGISTERS_START + 3] == registers[REGISTERS_START + 7];

    wire steady_state = (state == STEADY_1) || (state == STEADY_2) || (state == STEADY_3) || (state == STEADY_4);

    integer i;
    reg all_eq, rst, next_rst;
    always @(posedge clk) begin
        all_eq <= r2_eq_r6 & r3_eq_r7 & r4_eq_r8 & r5_eq_r9 & registers[REGISTERS_START + 8][47] & registers[REGISTERS_START + 9][47];
        rst <= next_rst;
        for(i = REGISTERS_START; i < REGISTERS_END; i = i + 1)
            registers[i] <= next_registers[i];
        state <= next_state;
        if(rst) begin
            $display("@verilog: sparse_matrix_decoder reset");
        end
    end

    reg [5:0] counter;
    initial counter = 0;
    always @(posedge clk) begin
        counter <= counter + 1;
        if(counter[5])
            counter[5] <= 0;
    end
    wire recurring_timer = counter[5];

    wire [47:0] r2_plus_8 = registers[REGISTERS_START] + 8;
    wire [47:0] r3_plus_8 = registers[REGISTERS_START + 1] + 8;
    wire [47:0] r4_plus_8 = registers[REGISTERS_START + 2] + 8;
    wire [47:0] r5_plus_8 = registers[REGISTERS_START + 3] + 8;

    wire opcode_active = op[OPCODE_ARG_1 - 1] || (op[OPCODE_ARG_1 - 2:OPCODE_ARG_PE] == ID);

    wire spm_stream_decoder_half_full;
    wire spm_argument_decoder_half_full;
    wire fzip_stream_decoder_half_full;
    wire fzip_argument_decoder_half_full;
    reg spm_stage_4;
    reg spm_stage_5;
    reg fzip_stage_6;
    wire [47:0] register_4 = registers[4];
    wire [47:0] register_5 = registers[5];
    wire [47:0] register_6 = registers[6];
    wire [47:0] register_7 = registers[7];
    wire [47:0] register_8 = registers[8];
    wire [47:0] register_9 = registers[9];
    wire [47:0] register_10 = registers[10];
    wire [47:0] register_11 = registers[11];
    wire [47:0] register_12 = registers[12];
    wire [47:0] register_13 = registers[13];
    always @* begin
        req_mem_ld = 0;
        req_mem_addr = register_4;
        req_mem_tag = 0;
        busy = 1;
        next_rst = 0;
        next_state = state;
        //for(i = REGISTERS_START; i < REGISTERS_END; i = i + 1)
        //    next_registers[i] = registers[i];
        next_registers[REGISTERS_START] = register_4;
        next_registers[REGISTERS_START + 1] = register_5;
        next_registers[REGISTERS_START + 2] = register_6;
        next_registers[REGISTERS_START + 3] = register_7;
        next_registers[REGISTERS_START + 4] = register_8;
        next_registers[REGISTERS_START + 5] = register_9;
        next_registers[REGISTERS_START + 6] = register_10;
        next_registers[REGISTERS_START + 7] = register_11;
        next_registers[REGISTERS_START + 8] = register_12;
        next_registers[REGISTERS_START + 9] = register_13;
        if(opcode_active) begin
            case(op[OPCODE_ARG_PE - 1:0])
                OP_RST: begin
                    $display("@verilog: decoder reset");
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
                    next_registers[REGISTERS_START] = r2_plus_8;
                    req_mem_ld = 1;
                end
                if(r3_eq_r7)
                    next_state = IDLE;
                if(rsp_mem_push) begin
                    next_registers[REGISTERS_START + 1] = r3_plus_8;
                end
            end
            LD_PREFIX_CODES: begin
                if(!r2_eq_r6 && !req_mem_stall) begin
                    next_registers[REGISTERS_START] = r2_plus_8;
                    req_mem_ld = 1;
                end
                if(r3_eq_r7) begin
                    next_state = IDLE;
                end
                if(rsp_mem_push) begin
                    next_registers[REGISTERS_START + 8] = rsp_mem_q[11:0];
                    next_registers[REGISTERS_START + 1] = r3_plus_8;
                end

            end
            LD_COMMON_CODES: begin
                if(!r2_eq_r6 && !req_mem_stall) begin
                    next_registers[REGISTERS_START] = r2_plus_8;
                    req_mem_ld = 1;
                end
                if(r3_eq_r7) begin
                    next_state = IDLE;
                end
                if(rsp_mem_push) begin
                    next_registers[REGISTERS_START + 1] = r3_plus_8;
                end
            end
            STEADY_1: begin //index code stream
                if(!r2_eq_r6 && !req_mem_stall) begin
                    next_registers[REGISTERS_START] = r2_plus_8;
                    req_mem_ld = 1;
                    req_mem_tag = 0;
                end
                if(recurring_timer || spm_stream_decoder_half_full || r2_eq_r6)
                    next_state = STEADY_2;
                if(all_eq) begin
                    next_state = IDLE;
                end
            end
            STEADY_2: begin //index stream arguments
                if(!r3_eq_r7 && !req_mem_stall) begin
                    next_registers[REGISTERS_START + 1] = r3_plus_8;
                    req_mem_ld = 1;
                    req_mem_tag = 1;
                    req_mem_addr = register_5;
                end
                if(recurring_timer || spm_argument_decoder_half_full || r3_eq_r7)
                    next_state = STEADY_3;
            end
            STEADY_3: begin //floating point code stream
                if(!r4_eq_r8 && !req_mem_stall) begin
                    next_registers[REGISTERS_START + 2] = r4_plus_8;
                    req_mem_ld = 1;
                    req_mem_tag = 2;
                    req_mem_addr = register_6;
                end
                if(recurring_timer || fzip_stream_decoder_half_full || r4_eq_r8)
                    next_state = STEADY_4;
            end
            STEADY_4: begin //floating point argument stream
                if(!r5_eq_r9 && !req_mem_stall) begin
                    //$display("here");
                    //$finish;
                    next_registers[REGISTERS_START + 3] = r5_plus_8;
                    req_mem_ld = 1;
                    req_mem_tag = 3;
                    req_mem_addr = register_7;
                end
                if(recurring_timer || fzip_argument_decoder_half_full || r5_eq_r9)
                    next_state = STEADY_1;
            end
        endcase
        if(state[2]) begin //TODO: semantic
            //TODO: response logic
        end
        if(spm_stage_4)
            next_registers[REGISTERS_START + 8] = register_12 - 1;
        if(fzip_stage_6)
            next_registers[REGISTERS_START + 9] = register_13 - 1;
    end

    wire [63:0] linked_list_fifo_q;
    reg memory_response_fifo_push;
    reg memory_response_fifo_pop;
    reg [1:0] memory_response_fifo_pop_tag;
    wire memory_response_fifo_empty;
    wire memory_response_fifo_full;
    wire memory_response_fifo_almost_full;
    wire [9:0] memory_response_free_count;
    linked_list_fifo #(64, 512, 4) memory_response_fifo(rst, clk, memory_response_fifo_push, rsp_mem_tag, memory_response_fifo_pop, memory_response_fifo_pop_tag, rsp_mem_q, linked_list_fifo_q, memory_response_fifo_empty, memory_response_fifo_full, , memory_response_fifo_almost_full, memory_response_free_count);

    
    always @(posedge clk) begin
        if(memory_response_fifo_push) begin
            $display("memory_response_fifo_push");
        end
    end
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
        spm_stream_decoder_table_addr = register_5 / 8;
        spm_stream_decoder_table_code_width = rsp_mem_q[2:0];
        spm_stream_decoder_table_data = rsp_mem_q[9:3];
        if(state == LD_DELTA_CODES && rsp_mem_push)
            spm_stream_decoder_table_push = 1;
    end

    reg spm_argument_decoder_push;
    wire [30:0] spm_argument_decoder_q;
    wire spm_argument_decoder_full;
    wire spm_argument_decoder_ready;
    reg [4:0] spm_argument_decoder_pop;
    argument_decoder #(31, 64) spm_argument_decoder(clk, rst, spm_argument_decoder_push, linked_list_fifo_q, spm_argument_decoder_q, spm_argument_decoder_full, spm_argument_decoder_half_full, spm_argument_decoder_ready, spm_argument_decoder_pop);

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
        if(registers[REGISTERS_START + 8][47])
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

    always @(posedge clk) begin
        if(spm_stream_decoder_push)
            $display("stream decoder push");
        if(fzip_stream_decoder_push)
            $display("fzip decoder push");
    end
    always @* begin
        fzip_stream_decoder_table_push = 0;
        fzip_stream_decoder_table_addr = register_5 / 16;
        fzip_stream_decoder_table_code_width = register_12[3:0];
        fzip_stream_decoder_table_data = {rsp_mem_q[63:0], register_12[11:4]};
        if(state == LD_PREFIX_CODES && rsp_mem_push && register_5[3])
            fzip_stream_decoder_table_push = 1;
    end

    reg fzip_argument_decoder_push;
    wire [62:0] fzip_argument_decoder_q;
    wire fzip_argument_decoder_full;
    wire fzip_argument_decoder_ready;
    reg [5:0] fzip_argument_decoder_pop;
    argument_decoder #(63, 64) fzip_argument_decoder(clk, rst, fzip_argument_decoder_push, linked_list_fifo_q, fzip_argument_decoder_q, fzip_argument_decoder_full, fzip_argument_decoder_half_full, fzip_argument_decoder_ready, fzip_argument_decoder_pop);


    //common codes

    reg [63:0] fzip_value_stage_3;
    always @* begin
        req_scratch_st = 0;
        req_scratch_addr = register_5 / 8;
        req_scratch_d = rsp_mem_q;
        if(state == LD_COMMON_CODES && rsp_mem_push) begin
            req_scratch_st = 1;
        end
        if(req_scratch_ld)
            req_scratch_addr = fzip_value_stage_3[12:0];
    end

    always @(posedge clk) begin
        rsp_mem_stall <= memory_response_free_count < 8;
        if(state == LD_COMMON_CODES && rsp_scratch_stall)
            rsp_mem_stall <= 1;
    end

    wire fzip_stage_0 = fzip_stream_decoder_ready & fzip_argument_decoder_ready & !stall_val;
        /*
    always @(posedge clk) begin
        if(fzip_stage_0) begin
            $display("fzip_stage_0");
        $display("debug: ");
        $display("%d %d %d", fzip_stream_decoder_ready, fzip_argument_decoder_ready, stall_val);
        $display("%d", fzip_stream_decoder_pop);
        $display("buffer_end: %d", fzip_argument_decoder.vld.buffer_end);
            $finish;
        end
        if(fzip_argument_decoder_push) begin
            $display("fzip_argument_decoder_push");
        $display("debug: ");
        $display("%d %d %d", fzip_stream_decoder_ready, fzip_argument_decoder_ready, stall_val);
        $display("%d", fzip_stream_decoder_pop);
        $display("buffer_end: %d", fzip_argument_decoder.vld.buffer_end);
        $finish;
        end

        $display("debug: ");
        $display("%d %d %d", fzip_stream_decoder_ready, fzip_argument_decoder_ready, stall_val);
        $display("%d", fzip_stream_decoder_pop);
        $display("buffer_end: %d", fzip_argument_decoder.vld.buffer_end);
        if(!rst && fzip_argument_decoder_ready !== 0 && fzip_argument_decoder_ready !== 1)
            $finish;
    end
        */
    always @* fzip_stream_decoder_pop = fzip_stage_0;
    reg fzip_stage_1;
    wire fzip_is_common_stage_1 = fzip_stream_decoder_q[0];
    wire [6:0] fzip_prefix_length_stage_1 = fzip_stream_decoder_q[7:1];
    wire [63:0] fzip_prefix_stage_1 = fzip_stream_decoder_q[71:8];
    always @(posedge clk) begin
        fzip_stage_1 <= fzip_stage_0;
    end

    reg fzip_stage_2;
    reg [63:0] fzip_value_stage_2;
    reg [5:0] fzip_argument_pop_stage_2;
    reg [63:0] fzip_mask_stage_2;
    reg fzip_is_common_stage_2;
    always @(posedge clk) begin
        fzip_stage_2 <= fzip_stage_1;
        fzip_value_stage_2 <= fzip_prefix_stage_1;
        fzip_argument_pop_stage_2 <= 0;
        if(fzip_stage_1)
            fzip_argument_pop_stage_2 <= 64 - fzip_prefix_length_stage_1;
        fzip_mask_stage_2 <= 64'HFFFFFFFFFFFFFFFF >> fzip_prefix_length_stage_1;
        fzip_is_common_stage_2 <= fzip_is_common_stage_1;
    end
    always @* fzip_argument_decoder_pop = fzip_argument_pop_stage_2;

    reg fzip_stage_3;
    reg fzip_is_common_stage_3;
    always @(posedge clk) begin
        fzip_stage_3 <= fzip_stage_2;
        fzip_value_stage_3 <= fzip_value_stage_2 | (fzip_mask_stage_2 & fzip_argument_decoder_q);
        fzip_is_common_stage_3 <= fzip_is_common_stage_2;
    end

    //TODO: bit fifo
    reg fzip_is_common_fifo_pop;
    wire fzip_is_common_fifo_q;
    wire fzip_is_common_fifo_full;
    wire fzip_is_common_fifo_empty;
    std_fifo #(.WIDTH(1), .DEPTH(64), .LATENCY(0)) fzip_is_common_fifo(rst, clk, fzip_stage_3, fzip_is_common_fifo_pop, fzip_is_common_stage_3, fzip_is_common_fifo_q, fzip_is_common_fifo_full, fzip_is_common_fifo_empty, , , );

    //TODO: value fifo
    reg fzip_not_common_fifo_pop;
    wire [63:0] fzip_not_common_fifo_q;
    wire fzip_not_common_fifo_full;
    wire fzip_not_common_fifo_empty;
    std_fifo #(64, 32) fzip_not_common_fifo(rst, clk, fzip_stage_3 && !fzip_is_common_stage_3, fzip_not_common_fifo_pop, fzip_value_stage_3, fzip_not_common_fifo_q, fzip_not_common_fifo_full, fzip_not_common_fifo_empty, , , );

    always @* begin
        req_scratch_ld = fzip_stage_3 && fzip_is_common_stage_3;
    end

    reg fzip_common_fifo_pop;
    wire [63:0] fzip_common_fifo_q;
    wire fzip_common_fifo_full;
    wire fzip_common_fifo_empty;
    std_fifo #(64, 32) fzip_common_fifo(rst, clk, rsp_scratch_push, fzip_common_fifo_pop, rsp_scratch_q, fzip_common_fifo_q, fzip_common_fifo_full, fzip_common_fifo_empty, , , rsp_scratch_stall);

    //stage_4
    reg fzip_common_stage_4;
    reg fzip_not_common_stage_4;
    always @* begin
        fzip_common_stage_4 = fzip_is_common_fifo_q && !fzip_common_fifo_empty;
        fzip_not_common_stage_4 = !fzip_is_common_fifo_q && !fzip_is_common_fifo_empty;
        fzip_is_common_fifo_pop = fzip_common_stage_4 || fzip_not_common_stage_4;
        fzip_not_common_fifo_pop = fzip_not_common_stage_4;
        fzip_common_fifo_pop = fzip_common_stage_4;
    end

    reg fzip_common_stage_5;
    reg fzip_not_common_stage_5;
    always @(posedge clk) begin
        fzip_common_stage_5 <= fzip_common_stage_4;
        fzip_not_common_stage_5 <= fzip_not_common_stage_4;
    end

    reg [63:0] fzip_value_stage_6;
    always @(posedge clk) begin
        fzip_stage_6 <= fzip_common_stage_5 || fzip_not_common_stage_5;
        fzip_value_stage_6 <= fzip_common_fifo_q;
        if(fzip_not_common_stage_5)
            fzip_value_stage_6 <= fzip_not_common_fifo_q;
    end

    reg fzip_stage_7;
    reg [63:0] fzip_value_stage_7;
    always @(posedge clk) begin
        fzip_stage_7 <= fzip_stage_6 && !registers[REGISTERS_START + 9][47];
        fzip_value_stage_7 <= fzip_value_stage_6;
    end
    assign push_val = fzip_stage_7;
    assign val = fzip_value_stage_7;


    //input arbitration
    reg [2:0] input_arbiter;
    initial input_arbiter = 0;
    wire [0:3] input_fifos_full = {spm_stream_decoder_full, spm_argument_decoder_full, fzip_stream_decoder_full, fzip_argument_decoder_full};
    reg [0:3] input_fifos_almost_full;
    always @(posedge clk) input_fifos_almost_full <= {spm_stream_decoder_half_full, spm_argument_decoder_half_full, fzip_stream_decoder_half_full, fzip_argument_decoder_half_full};
    reg [1:0] pseudo_rand;
    initial pseudo_rand = 0;
    always @(posedge clk)
        pseudo_rand <= pseudo_rand + 1;
//TODO: almost full
    reg next_spm_stream_decoder_push;
    reg next_spm_argument_decoder_push;
    reg next_fzip_stream_decoder_push;
    reg next_fzip_argument_decoder_push;
    always @(posedge clk) begin
        if(input_fifos_full[input_arbiter] || memory_response_fifo_empty) begin
            input_arbiter <= input_arbiter + 1;
        end
        if(!input_fifos_almost_full[pseudo_rand])
            input_arbiter <= pseudo_rand;
        else if(!input_fifos_almost_full[0])
            input_arbiter <= 0;
        else if(!input_fifos_almost_full[1])
            input_arbiter <= 1;
        else if(!input_fifos_almost_full[2])
            input_arbiter <= 2;
        else if(!input_fifos_almost_full[3])
            input_arbiter <= 3;
        else
            input_arbiter <= 4;
        spm_stream_decoder_push <= next_spm_stream_decoder_push;
        spm_argument_decoder_push <= next_spm_argument_decoder_push;
        fzip_stream_decoder_push <= next_fzip_stream_decoder_push;
        fzip_argument_decoder_push <= next_fzip_argument_decoder_push;
    end
    always @* begin
        memory_response_fifo_pop_tag = input_arbiter[1:0];
        memory_response_fifo_pop = 0;
        next_spm_stream_decoder_push = 0;
        next_spm_argument_decoder_push = 0;
        next_fzip_stream_decoder_push = 0;
        next_fzip_argument_decoder_push = 0;
        if(input_arbiter == 0 && !memory_response_fifo_empty) begin
            $display("here0");
            next_spm_stream_decoder_push = 1;
            memory_response_fifo_pop = 1;
        end
        if(input_arbiter == 1 && !memory_response_fifo_empty) begin
            $display("here1");
            next_spm_argument_decoder_push = 1;
            memory_response_fifo_pop = 1;
        end
        if(input_arbiter == 2 && !memory_response_fifo_empty) begin
            $display("here2");
            next_fzip_stream_decoder_push = 1;
            memory_response_fifo_pop = 1;
        end
        if(input_arbiter == 3 && !memory_response_fifo_empty) begin
            next_fzip_argument_decoder_push = 1;
            memory_response_fifo_pop = 1;
        end
    end
    //TODO: stream decoders and luts
    //TODO: deltas to indices logic

    //Debug
    // synthesis translate_off
    always @(posedge clk) begin
        $display("@verilog decoder debug: %d", $time);
        $display("@verilog: state: %d", state);
        $display("@verilog: rst: %d", rst);
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
    // synthesis translate_on
    `include "common.vh"
endmodule
