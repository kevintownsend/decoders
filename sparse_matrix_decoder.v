module sparse_matrix_decoder(clk, op_in, op_out, busy, req_mem_ld, req_mem_addr,
    req_mem_tag, req_mem_stall, rsp_mem_push, rsp_mem_tag, rsp_mem_q,
    rsp_mem_stall, req_scratch_ld, req_scratch_st, req_scratch_addr,
    req_scratch_d, req_scratch_stall, rsp_scratch_push, rsp_scratch_q,
    rsp_scratch_stall, push_index, row, col, stall_index, push_val, val,
    stall_val);
    parameter ID = 0;
    parameter REGISTERS_START = 2;
    parameter REGISTERS_END = REGISTERS_START + 10;
    `include "smac.vh"

    input clk;
    input [63:0] op_in;
    output reg [63:0] op_out;
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
    integer i;
    initial for(i = REGISTERS_START; i < REGISTERS_END; i = i + 1)
        registers[i] = 0;

    localparam DEBUG_REGISTERS_START = 22;
    localparam DEBUG_REGISTERS_END = DEBUG_REGISTERS_START + 8;
    reg [47:0] debug_registers[DEBUG_REGISTERS_START:DEBUG_REGISTERS_END - 1];
    reg [47:0] next_debug_registers[DEBUG_REGISTERS_START:DEBUG_REGISTERS_END - 1];
    initial for(i = DEBUG_REGISTERS_START; i < DEBUG_REGISTERS_END; i = i + 1)
        debug_registers[i] = 0;

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
    initial state = IDLE;
    wire r2_eq_r6 = registers[REGISTERS_START] == registers[REGISTERS_START + 4];
    wire r3_eq_r7 = registers[REGISTERS_START + 1] == registers[REGISTERS_START + 5];
    wire r4_eq_r8 = registers[REGISTERS_START + 2] == registers[REGISTERS_START + 6];
    wire r5_eq_r9 = registers[REGISTERS_START + 3] == registers[REGISTERS_START + 7];

    wire steady_state = (state == STEADY_1) || (state == STEADY_2) || (state == STEADY_3) || (state == STEADY_4);

    reg all_eq;
    reg rst, rst_1, rst_2, next_rst;
    initial rst = 1;
    always @(posedge clk) begin
        all_eq <= r2_eq_r6 & r3_eq_r7 & r4_eq_r8 & r5_eq_r9 & registers[REGISTERS_START + 8][47] & registers[REGISTERS_START + 9][47];
        rst_1 <= next_rst;
        rst_2 <= rst_1;
        rst <= rst_2;
        for(i = REGISTERS_START; i < REGISTERS_END; i = i + 1)
            registers[i] <= next_registers[i];
        for(i = DEBUG_REGISTERS_START; i < DEBUG_REGISTERS_END; i = i + 1)
            debug_registers[i] <= next_debug_registers[i];
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

    reg [63:0] op_r;
    always @(posedge clk) op_r <= op_in;
    wire opcode_active = op_r[OPCODE_ARG_1 - 1] || (op_r[OPCODE_ARG_1 - 2:OPCODE_ARG_PE] == ID);

    reg next_req_mem_ld;
    reg [47:0] next_req_mem_addr;
    reg [1:0] next_req_mem_tag;
    reg req_mem_stall_r;
    always @(posedge clk) begin
        req_mem_stall_r <= req_mem_stall;
        req_mem_ld <= next_req_mem_ld;
        req_mem_addr <= next_req_mem_addr;
        req_mem_tag <= next_req_mem_tag;
    end

    reg [63:0] next_op_out;
    always @(posedge clk) op_out <= next_op_out;

    wire spm_stream_decoder_half_full;
    wire spm_argument_decoder_half_full;
    wire fzip_stream_decoder_half_full;
    wire fzip_argument_decoder_half_full;
    reg spm_stage_4;
    reg spm_stage_5;
    reg fzip_stage_6;
    //registers:
    //0: index opcodes stream
    //1: index argument stream
    //2: fzip opcode stream
    //3: fzip argument stream
    //4: index opcodes end
    //5: index argument end
    //6: fzip opcode end
    //7: fzip argument end
    //8: index nnz count down
    //9: fzip nnz count down
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

    wire [47:0] debug_register_0 = debug_registers[DEBUG_REGISTERS_START];
    wire [47:0] debug_register_1 = debug_registers[DEBUG_REGISTERS_START + 1];
    wire [47:0] debug_register_2 = debug_registers[DEBUG_REGISTERS_START + 2];
    wire [47:0] debug_register_3 = debug_registers[DEBUG_REGISTERS_START + 3];
    wire [47:0] debug_register_4 = debug_registers[DEBUG_REGISTERS_START + 4];
    wire [47:0] debug_register_5 = debug_registers[DEBUG_REGISTERS_START + 5];
    wire [47:0] debug_register_6 = debug_registers[DEBUG_REGISTERS_START + 6];
    wire [47:0] debug_register_7 = debug_registers[DEBUG_REGISTERS_START + 7];

    reg [0:3] memory_response_not_starving;
    wire in_flight_not_full;
    reg [0:3] input_fifos_half_full;

    wire memory_response_fifo_0_empty;
    wire memory_response_fifo_1_empty;
    wire memory_response_fifo_2_empty;
    wire memory_response_fifo_3_empty;

    wire fzip_is_common_fifo_almost_full;
    wire fzip_not_common_fifo_almost_full;
    wire fzip_req_common_fifo_almost_full;

    always @* begin
        next_req_mem_ld = 0;
        next_req_mem_addr = register_4;
        next_req_mem_tag = 0;
        next_op_out = 0;
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

        next_debug_registers[DEBUG_REGISTERS_START] = debug_register_0;
        next_debug_registers[DEBUG_REGISTERS_START + 1] = debug_register_1;
        next_debug_registers[DEBUG_REGISTERS_START + 2] = debug_register_2;
        next_debug_registers[DEBUG_REGISTERS_START + 3] = debug_register_3;
        next_debug_registers[DEBUG_REGISTERS_START + 4] = debug_register_4;
        next_debug_registers[DEBUG_REGISTERS_START + 5] = debug_register_5;
        next_debug_registers[DEBUG_REGISTERS_START + 6] = debug_register_6;
        next_debug_registers[DEBUG_REGISTERS_START + 7] = debug_register_7;
        case(state)
            IDLE:
                busy = 0;
            LD_DELTA_CODES: begin
                if(!r2_eq_r6 && !req_mem_stall_r) begin
                    next_registers[REGISTERS_START] = r2_plus_8;
                    next_req_mem_ld = 1;
                end
                if(r3_eq_r7)
                    next_state = IDLE;
                if(rsp_mem_push) begin
                    next_registers[REGISTERS_START + 1] = r3_plus_8;
                end
            end
            LD_PREFIX_CODES: begin
                if(!r2_eq_r6 && !req_mem_stall_r) begin
                    next_registers[REGISTERS_START] = r2_plus_8;
                    next_req_mem_ld = 1;
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
                if(!r2_eq_r6 && !req_mem_stall_r) begin
                    next_registers[REGISTERS_START] = r2_plus_8;
                    next_req_mem_ld = 1;
                end
                if(r3_eq_r7) begin
                    next_state = IDLE;
                end
                if(rsp_mem_push) begin
                    next_registers[REGISTERS_START + 1] = r3_plus_8;
                end
            end
            STEADY_1: begin //index code stream
                next_req_mem_tag = 0;
                if(!r2_eq_r6 && !req_mem_stall_r && in_flight_not_full) begin
                    next_registers[REGISTERS_START] = r2_plus_8;
                    next_req_mem_ld = 1;
                end
                if(recurring_timer || !in_flight_not_full || r2_eq_r6 || input_fifos_half_full[0])
                    next_state = STEADY_2;
                if(all_eq) begin
                    next_state = IDLE;
                end
            end
            STEADY_2: begin //index stream arguments
                next_req_mem_tag = 1;
                next_req_mem_addr = register_5;
                if(!r3_eq_r7 && !req_mem_stall_r && in_flight_not_full) begin
                    next_registers[REGISTERS_START + 1] = r3_plus_8;
                    next_req_mem_ld = 1;
                end
                if(recurring_timer || !in_flight_not_full || r3_eq_r7 || input_fifos_half_full[1])
                    next_state = STEADY_3;
            end
            STEADY_3: begin //floating point code stream
                next_req_mem_tag = 2;
                next_req_mem_addr = register_6;
                if(!r4_eq_r8 && !req_mem_stall_r && in_flight_not_full) begin
                    next_registers[REGISTERS_START + 2] = r4_plus_8;
                    next_req_mem_ld = 1;
                end
                if(recurring_timer || !in_flight_not_full || r4_eq_r8 || input_fifos_half_full[2])
                    next_state = STEADY_4;
            end
            STEADY_4: begin //floating point argument stream
                next_req_mem_tag = 3;
                next_req_mem_addr = register_7;
                if(!r5_eq_r9 && !req_mem_stall_r && in_flight_not_full) begin
                    next_registers[REGISTERS_START + 3] = r5_plus_8;
                    next_req_mem_ld = 1;
                end
                //if(recurring_timer || !in_flight_not_full || r5_eq_r9 || input_fifos_half_full[3])
                if(!in_flight_not_full || r5_eq_r9)
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
        if(opcode_active) begin
            case(op_r[OPCODE_ARG_PE - 1:0])
                OP_RST: begin
                    $display("@verilog: decoder reset");
                    next_rst = 1;
                    next_state = IDLE;
                end
                OP_LD_DELTA_CODES: begin
                    next_state = LD_DELTA_CODES;
                    $display("@verilog: %m loading delta codes");
                    for(i = REGISTERS_START; i < REGISTERS_END; i = i + 1) begin
                        $display("@verilog: r[%d] = %d", i, registers[i]);
                    end
                end
                OP_LD_PREFIX_CODES: begin
                    next_state = LD_PREFIX_CODES;
                    $display("@verilog: %m loading prefix codes");
                    for(i = REGISTERS_START; i < REGISTERS_END; i = i + 1) begin
                        $display("@verilog: r[%d] = %d", i, registers[i]);
                    end
                end
                OP_LD_COMMON_CODES: begin
                    next_state = LD_COMMON_CODES;
                    $display("@verilog: %m loading common codes");
                    for(i = REGISTERS_START; i < REGISTERS_END; i = i + 1) begin
                        $display("@verilog: r[%d] = %d", i, registers[i]);
                    end
                end
                OP_STEADY: begin
                    next_state = STEADY_1;
                    $display("@verilog: %m starting steady state");
                    for(i = REGISTERS_START; i < REGISTERS_END; i = i + 1) begin
                        $display("@verilog: r[%d] = %d", i, registers[i]);
                    end
                end
                OP_LD: begin
                    for(i = REGISTERS_START; i < REGISTERS_END; i = i + 1)
                        if(i == op_r[OPCODE_ARG_2 - 1:OPCODE_ARG_1])
                            next_registers[i] = op_r[63:OPCODE_ARG_2];
                    for(i = DEBUG_REGISTERS_START; i < DEBUG_REGISTERS_END; i = i + 1)
                        if(i == op_r[OPCODE_ARG_2 - 1:OPCODE_ARG_1])
                            next_debug_registers[i] = op_r[63:OPCODE_ARG_2];
                end
                OP_READ: begin
                    if(op_r[OPCODE_ARG_2 - 1:OPCODE_ARG_1] >= REGISTERS_START && op_r[OPCODE_ARG_2 - 1:OPCODE_ARG_1] < REGISTERS_END) begin
                        next_op_out[OPCODE_ARG_PE - 1:0] = OP_RETURN;
                        next_op_out[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = ID;
                        next_op_out[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = op_r[OPCODE_ARG_2 - 1:OPCODE_ARG_1];
                        next_op_out[63:OPCODE_ARG_2] = registers[op_r[OPCODE_ARG_2 - 1:OPCODE_ARG_1]];
                    end
                    if(op_r[OPCODE_ARG_2 - 1:OPCODE_ARG_1] >= DEBUG_REGISTERS_START && op_r[OPCODE_ARG_2 - 1:OPCODE_ARG_1] < DEBUG_REGISTERS_END) begin
                        next_op_out[OPCODE_ARG_PE - 1:0] = OP_RETURN;
                        next_op_out[OPCODE_ARG_1 - 1:OPCODE_ARG_PE] = ID;
                        next_op_out[OPCODE_ARG_2 - 1:OPCODE_ARG_1] = op_r[OPCODE_ARG_2 - 1:OPCODE_ARG_1];
                        next_op_out[63:OPCODE_ARG_2] = debug_registers[op_r[OPCODE_ARG_2 - 1:OPCODE_ARG_1]];
                    end
                end
            endcase
        end
    if(state[2]) begin //TODO: semantics
        //next_debug_registers[DEBUG_REGISTERS_START] = 0; //flags
        //TODO: count times mac stalls
        next_debug_registers[DEBUG_REGISTERS_START + 1] = debug_register_1 + 1;
        if(memory_response_fifo_0_empty)
            next_debug_registers[DEBUG_REGISTERS_START + 2] = debug_register_2 + 1;
        if(memory_response_fifo_1_empty)
            next_debug_registers[DEBUG_REGISTERS_START + 3] = debug_register_3 + 1;
        if(memory_response_fifo_2_empty)
            next_debug_registers[DEBUG_REGISTERS_START + 4] = debug_register_4 + 1;
        if(memory_response_fifo_3_empty)
            next_debug_registers[DEBUG_REGISTERS_START + 5] = debug_register_5 + 1;
        if(fzip_is_common_fifo_almost_full)
            next_debug_registers[DEBUG_REGISTERS_START + 6] = debug_register_6 + 1;
        if(fzip_not_common_fifo_almost_full)
            next_debug_registers[DEBUG_REGISTERS_START + 7] = debug_register_7 + 1;
        if(fzip_not_common_fifo_almost_full)
            next_debug_registers[DEBUG_REGISTERS_START + 7] = debug_register_7 + 1;
        if(fzip_req_common_fifo_almost_full)
            next_debug_registers[DEBUG_REGISTERS_START] = debug_register_0 + 1;

    end
    if(rst) begin
        for(i = DEBUG_REGISTERS_START; i < DEBUG_REGISTERS_END; i = i + 1) begin
            next_debug_registers[i] = 0;
        end
    end
    reg memory_response_fifo_pop;
    reg [1:0] memory_response_fifo_pop_tag;
    reg memory_response_fifo_pop_delay;
    initial memory_response_fifo_pop_delay = 0;
    reg [1:0] memory_response_fifo_pop_tag_delay;
    always @(posedge clk) begin
        memory_response_fifo_pop_delay <= memory_response_fifo_pop;
        memory_response_fifo_pop_tag_delay <= memory_response_fifo_pop_tag;
    end
    localparam INITIAL_RESPONSE_FIFO_DEPTH = 512;
    //localparam MIN_IN_FLIGHT = 500;
    localparam MIN_IN_FLIGHT = 256;
    in_flight_tracker #(4, MIN_IN_FLIGHT, MIN_IN_FLIGHT * 4) tracker(clk, req_mem_ld && steady_state, req_mem_tag, memory_response_fifo_pop_delay, memory_response_fifo_pop_tag_delay, next_req_mem_tag, in_flight_not_full);
    //in_flight_tracker #(4, MIN_IN_FLIGHT, MIN_IN_FLIGHT * 4, INITIAL_RESPONSE_FIFO_DEPTH) tracker(clk, req_mem_ld && steady_state, req_mem_tag, memory_response_fifo_pop_delay, memory_response_fifo_pop_tag_delay, next_req_mem_tag, in_flight_not_full);

    reg memory_response_fifo_push;
    //localparam INITIAL_RESPONSE_FIFO_DEPTH = 512;
    reg memory_response_fifo_0_pop;
    wire [63:0] memory_response_fifo_0_q;
    wire memory_response_fifo_0_full;
    wire memory_response_fifo_0_almost_empty;
    wire memory_response_fifo_0_almost_full;
    std_fifo #(.WIDTH(64), .DEPTH(INITIAL_RESPONSE_FIFO_DEPTH), .ALMOST_FULL_COUNT(8), .ALMOST_EMPTY_COUNT(32)) initial_response_fifo_0(rst, clk, memory_response_fifo_push && rsp_mem_tag == 0, memory_response_fifo_0_pop, rsp_mem_q, memory_response_fifo_0_q, memory_respones_fifo_0_full, memory_response_fifo_0_empty, , memory_response_fifo_0_almost_empty, memory_response_fifo_0_almost_full);

    reg memory_response_fifo_1_pop;
    wire [63:0] memory_response_fifo_1_q;
    wire memory_response_fifo_1_full;
    wire memory_response_fifo_1_almost_empty;
    wire memory_response_fifo_1_almost_full;
    std_fifo #(.WIDTH(64), .DEPTH(INITIAL_RESPONSE_FIFO_DEPTH), .ALMOST_FULL_COUNT(8), .ALMOST_EMPTY_COUNT(32)) initial_response_fifo_1(rst, clk, memory_response_fifo_push && rsp_mem_tag == 1, memory_response_fifo_1_pop, rsp_mem_q, memory_response_fifo_1_q, memory_respones_fifo_1_full, memory_response_fifo_1_empty, , memory_response_fifo_1_almost_empty, memory_response_fifo_1_almost_full);

    reg memory_response_fifo_2_pop;
    wire [63:0] memory_response_fifo_2_q;
    wire memory_response_fifo_2_full;
    wire memory_response_fifo_2_almost_empty;
    wire memory_response_fifo_2_almost_full;
    std_fifo  #(.WIDTH(64), .DEPTH(INITIAL_RESPONSE_FIFO_DEPTH), .ALMOST_FULL_COUNT(8), .ALMOST_EMPTY_COUNT(32)) initial_response_fifo_2(rst, clk, memory_response_fifo_push && rsp_mem_tag == 2, memory_response_fifo_2_pop, rsp_mem_q, memory_response_fifo_2_q, memory_respones_fifo_2_full, memory_response_fifo_2_empty, , memory_response_fifo_2_almost_empty, memory_response_fifo_2_almost_full);

    reg memory_response_fifo_3_pop;
    wire [63:0] memory_response_fifo_3_q;
    wire memory_response_fifo_3_full;
    wire memory_response_fifo_3_almost_empty;
    wire memory_response_fifo_3_almost_full;
    std_fifo  #(.WIDTH(64), .DEPTH(INITIAL_RESPONSE_FIFO_DEPTH), .ALMOST_FULL_COUNT(8), .ALMOST_EMPTY_COUNT(32)) initial_response_fifo_3(rst, clk, memory_response_fifo_push && rsp_mem_tag == 3, memory_response_fifo_3_pop, rsp_mem_q, memory_response_fifo_3_q, memory_respones_fifo_3_full, memory_response_fifo_3_empty, , memory_response_fifo_3_almost_empty, memory_response_fifo_3_almost_full);

    wire [63:0] linked_list_fifo_q;
    wire memory_response_fifo_empty;
    wire memory_response_fifo_full;
    wire memory_response_fifo_almost_full;
    localparam RESPONSE_FIFO_DEPTH = 1024;
    localparam LOG2_RESPONSE_FIFO_DEPTH = log2(RESPONSE_FIFO_DEPTH - 1);
    wire [LOG2_RESPONSE_FIFO_DEPTH:0] memory_response_free_count;
    wire [4 * LOG2_RESPONSE_FIFO_DEPTH - 1:0] memory_response_count_unrolled;
    //linked_list_fifo #(64, RESPONSE_FIFO_DEPTH, 4) memory_response_fifo(rst, clk, memory_response_fifo_push, rsp_mem_tag, memory_response_fifo_pop, memory_response_fifo_pop_tag, rsp_mem_q, linked_list_fifo_q, memory_response_fifo_empty, memory_response_fifo_full, memory_response_count_unrolled, memory_response_fifo_almost_full, memory_response_free_count);
    reg [LOG2_RESPONSE_FIFO_DEPTH - 1:0] memory_response_count [0:3];
    always @* begin
        for(i = 0; i < 4; i = i + 1) begin
            memory_response_count[i] = memory_response_count_unrolled[(i+1)*LOG2_RESPONSE_FIFO_DEPTH - 1 -:LOG2_RESPONSE_FIFO_DEPTH];
        end
    end
    always @(posedge clk) begin
        memory_response_not_starving <= {!memory_response_fifo_0_almost_empty, !memory_response_fifo_1_almost_empty, !memory_response_fifo_2_almost_empty, !memory_response_fifo_3_almost_empty};
    end

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
    //localparam SPM_TABLE_DEPTH = 2**7;
    //localparam LOG2_SPM_TABLE_DEPTH = 7;
    reg [SPM_MAX_CODE_LENGTH - 1:0] spm_stream_decoder_table_addr;
    //localparam LOG2_LOG2_SPM_TABLE_DEPTH = 3;
    reg [LOG2_SPM_MAX_CODE_LENGTH - 1:0] spm_stream_decoder_table_code_width;
    reg [2 + 5 - 1:0] spm_stream_decoder_table_data;
    wire spm_stream_decoder_almost_full;
    stream_decoder #(.WIDTH_IN(64), .WIDTH_OUT(7), .MAX_CODE_LENGTH(SPM_MAX_CODE_LENGTH), .INTERMEDIATE_WIDTH(8), .ALMOST_FULL_COUNT(4)) spm_stream_decoder(clk, rst, spm_stream_decoder_push, memory_response_fifo_0_q, spm_stream_decoder_q, spm_stream_decoder_full, spm_stream_decoder_half_full, spm_stream_decoder_ready, spm_stream_decoder_pop, spm_stream_decoder_table_push, spm_stream_decoder_table_addr, spm_stream_decoder_table_code_width, spm_stream_decoder_table_data, spm_stream_decoder_almost_full);

    always @* begin
        spm_stream_decoder_table_push = 0;
        spm_stream_decoder_table_addr = register_5 / 8;
        spm_stream_decoder_table_code_width = rsp_mem_q[LOG2_SPM_MAX_CODE_LENGTH - 1:0];
        spm_stream_decoder_table_data = rsp_mem_q[5 + 2 + LOG2_SPM_MAX_CODE_LENGTH - 1 -: 5 + 2];
        if(state == LD_DELTA_CODES && rsp_mem_push)
            spm_stream_decoder_table_push = 1;
    end

    reg spm_argument_decoder_push;
    wire [30:0] spm_argument_decoder_q;
    wire spm_argument_decoder_full;
    wire spm_argument_decoder_ready;
    reg [4:0] spm_argument_decoder_pop;
    wire spm_argument_decoder_almost_empty;
    wire spm_argument_decoder_almost_full;
    argument_decoder #(.WIDTH_OUT(31), .WIDTH_IN(64), .INTERMEDIATE_WIDTH(32), .ALMOST_FULL_COUNT(4)) spm_argument_decoder(clk, rst, spm_argument_decoder_push, memory_response_fifo_1_q, spm_argument_decoder_q, spm_argument_decoder_full, spm_argument_decoder_half_full, spm_argument_decoder_ready, spm_argument_decoder_pop, spm_argument_decoder_almost_empty, spm_argument_decoder_almost_full);
    reg [2:0] strain_counter;
    initial strain_counter = 0;
    reg spm_argument_decoder_go_ahead;
    always @(posedge clk) begin
        strain_counter <= strain_counter + 1;
        if(strain_counter[2])
            strain_counter[2] <= 0;
        spm_argument_decoder_go_ahead <= !spm_argument_decoder_almost_empty || (strain_counter[2] && spm_argument_decoder_ready);
    end

    wire spm_stage_0 = spm_stream_decoder_ready && spm_argument_decoder_go_ahead && !stall_index; //TODO: fix with almost empty and counter

    reg spm_stage_1;
    always @* begin
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
    reg [31:0] spm_first_bit_stage_2;
    always @(posedge clk) begin
        spm_argument_pop_stage_2 <= 0;
        if(spm_stage_1 && spm_stream_decoder_code_stage_1[1])
            spm_argument_pop_stage_2 <= spm_stream_decoder_delta_stage_1;
        spm_stage_2 <= spm_stage_1;
        spm_delta_stage_2 <= spm_stream_decoder_delta_stage_1;
        spm_code_stage_2 <= spm_stream_decoder_code_stage_1;
        spm_mask_stage_2 <= 32'HFFFFFFFF >> (32 - spm_stream_decoder_delta_stage_1);
        spm_first_bit_stage_2 <= 32'H1 << spm_stream_decoder_delta_stage_1;
    end
    always @*
        spm_argument_decoder_pop = spm_argument_pop_stage_2;

    reg spm_stage_3;
    reg [31:0] spm_delta_stage_3;
    reg spm_code_stage_3;
    always @(posedge clk) begin
        spm_stage_3 <= spm_stage_2;
        spm_delta_stage_3 <= spm_delta_stage_2 + 1;
        if(spm_code_stage_2[1])
            spm_delta_stage_3 <= (spm_mask_stage_2 & spm_argument_decoder_q | spm_first_bit_stage_2) + 1;
        spm_code_stage_3 <= spm_code_stage_2[0] || spm_code_stage_2[1];
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

    integer stage_1_count, stage_0_count, stage_2_count;
    initial begin
        stage_0_count = 0;
        stage_1_count = 0;
        stage_2_count = 0;
    end
    always @(posedge clk) begin
        if(spm_stage_0) begin
            $display("spm_stage_0: %d", stage_0_count);
            $display("buffer: %B", spm_stream_decoder.ad.vld.buffer);
            $display("buffer_end: %d", spm_stream_decoder.ad.vld.buffer_end);
            stage_0_count = stage_0_count + 1;
        end
        if(spm_stage_1) begin
            $display("spm_stage_1: %d", stage_1_count);
            $display("spm_stream_decoder_q: %B %d", spm_stream_decoder_q[1:0], spm_stream_decoder_q[6:2]);
            //$display("buffer_end: %d", spm_stream_decoder.ad.vld.buffer_end);
            stage_1_count = stage_1_count + 1;
        end
        if(spm_stage_2) begin
            $display("spm_stage_2: %d", stage_2_count);
            $display("buffer_end: %d", spm_argument_decoder.vld.buffer_end);
            stage_2_count = stage_2_count + 1;
        end
    end

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
    wire fzip_stream_decoder_almost_full;
    stream_decoder #(.WIDTH_IN(64), .WIDTH_OUT(64 + 8), .MAX_CODE_LENGTH(FZIP_MAX_CODE_LENGTH), .INTERMEDIATE_WIDTH(16), .ALMOST_FULL_COUNT(4)) fzip_stream_decoder(clk, rst, fzip_stream_decoder_push, memory_response_fifo_2_q, fzip_stream_decoder_q, fzip_stream_decoder_full, fzip_stream_decoder_half_full, fzip_stream_decoder_ready, fzip_stream_decoder_pop, fzip_stream_decoder_table_push, fzip_stream_decoder_table_addr, fzip_stream_decoder_table_code_width, fzip_stream_decoder_table_data, fzip_stream_decoder_almost_full);

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
    wire fzip_argument_decoder_almost_empty;
    wire fzip_argument_decoder_almost_full;
    argument_decoder #(.WIDTH_OUT(63), .WIDTH_IN(64), .INTERMEDIATE_WIDTH(64), .ALMOST_FULL_COUNT(4)) fzip_argument_decoder(clk, rst, fzip_argument_decoder_push, memory_response_fifo_3_q, fzip_argument_decoder_q, fzip_argument_decoder_full, fzip_argument_decoder_half_full, fzip_argument_decoder_ready, fzip_argument_decoder_pop, fzip_argument_decoder_almost_empty, fzip_argument_decoder_almost_full);

    //common codes

    reg [63:0] fzip_value_stage_3;
    wire [12:0] fzip_req_common_fifo_q;
    always @* begin
        req_scratch_st = 0;
        req_scratch_addr = register_5 / 8;
        req_scratch_d = rsp_mem_q;
        if(state == LD_COMMON_CODES && rsp_mem_push) begin
            req_scratch_st = 1;
        end
        if(req_scratch_ld)
            req_scratch_addr = fzip_req_common_fifo_q;
    end

    always @(posedge clk) begin
        rsp_mem_stall <= |{memory_response_fifo_0_almost_full, memory_response_fifo_1_almost_full, memory_response_fifo_2_almost_full, memory_response_fifo_3_almost_full};
        if(rsp_mem_stall) begin
            $display("@verilog: rsp_mem_stall high at %m at time %d", $time);
            $display("@verilog: total: %d", tracker.total);
            $display("@verilog: fifo0 count: %d", initial_response_fifo_0.count);
            $display("@verilog: fifo0 count: %d", initial_response_fifo_1.count);
            $display("@verilog: fifo0 count: %d", initial_response_fifo_2.count);
            $display("@verilog: fifo0 count: %d", initial_response_fifo_3.count);
        end
        if(state == LD_COMMON_CODES && rsp_scratch_stall)
            rsp_mem_stall <= 1;
    end
    reg fzip_argument_decoder_go_ahead;
    always @(posedge clk)
        fzip_argument_decoder_go_ahead <= !fzip_argument_decoder_almost_empty || (strain_counter[2] && fzip_argument_decoder_ready);

    wire fzip_stage_0 = fzip_stream_decoder_ready & fzip_argument_decoder_go_ahead & !fzip_is_common_fifo_almost_full & !fzip_not_common_fifo_almost_full & !fzip_req_common_fifo_almost_full;
    integer fzip_stage_0_count;
    initial fzip_stage_0_count = 0;
    integer fzip_stage_1_count;
    initial fzip_stage_1_count = 0;
    integer fzip_stage_2_count;
    initial fzip_stage_2_count = 0;
    integer fzip_stage_3_count;
    initial fzip_stage_3_count = 0;
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
    /*
    always @(posedge clk) begin
        if(fzip_stage_0) begin
            $display("fzip_stage_0: %d", fzip_stage_0_count);
            $display("fzip_argument_decoder_almost_empty: %d", fzip_argument_decoder_almost_empty);
            $display("fzip_argument_decoder_ready: %d", fzip_argument_decoder_ready);
            $display("what maddness is this?: %d", fzip_argument_decoder.fifo.count);
            $display("what maddness is this?: %d %d", fzip_argument_decoder.fifo.r_beg, fzip_argument_decoder.fifo.r_end);
            fzip_stage_0_count = fzip_stage_0_count + 1;
        end
        if(fzip_stage_1) begin
            $display("fzip_stage_1: %d", fzip_stage_1_count);
            $display("fzip_is_common: %d", fzip_is_common_stage_1);
            $display("fzip_prefix_length: %d", fzip_prefix_length_stage_1);
            $display("fzip_prefix: %H", fzip_prefix_stage_1);
            fzip_stage_1_count = fzip_stage_1_count + 1;
        end
        if(fzip_stage_2) begin
            $display("fzip_stage_2: %d", fzip_stage_2_count);
            $display("fzip_is_common: %d", fzip_is_common_stage_2);
            $display("fzip_mask_stage_2: %B", fzip_mask_stage_2);
            $display("fzip_value: %H", fzip_value_stage_2);
            $display("fzip_pop: %d", fzip_argument_pop_stage_2);
            $display("curr value: %f", $bitstoreal(fzip_value_stage_2 | (fzip_mask_stage_2 & fzip_argument_decoder_q)));
            $display("argument ready: %d", fzip_argument_decoder_ready);
            $display("argument decoder buffer: %B", fzip_argument_decoder.vld.buffer);
            $display("argument decoder buffer_end: %d", fzip_argument_decoder.vld.buffer_end);
            fzip_stage_2_count = fzip_stage_2_count + 1;
        end
    end
    */

    //bit fifo
    reg fzip_is_common_fifo_pop;
    wire fzip_is_common_fifo_q;
    wire fzip_is_common_fifo_full;
    wire fzip_is_common_fifo_empty;
    std_fifo #(.WIDTH(1), .DEPTH(512), .LATENCY(0), .ALMOST_FULL_COUNT(3)) fzip_is_common_fifo(rst, clk, fzip_stage_3, fzip_is_common_fifo_pop, fzip_is_common_stage_3, fzip_is_common_fifo_q, fzip_is_common_fifo_full, fzip_is_common_fifo_empty, , , fzip_is_common_fifo_almost_full);

    //value fifo
    reg fzip_not_common_fifo_pop;
    wire [63:0] fzip_not_common_fifo_q;
    wire fzip_not_common_fifo_full;
    wire fzip_not_common_fifo_empty;
    std_fifo #(.WIDTH(64), .DEPTH(512), .ALMOST_FULL_COUNT(3)) fzip_not_common_fifo(rst, clk, fzip_stage_3 && !fzip_is_common_stage_3, fzip_not_common_fifo_pop, fzip_value_stage_3, fzip_not_common_fifo_q, fzip_not_common_fifo_full, fzip_not_common_fifo_empty, , , fzip_not_common_fifo_almost_full);

    reg fzip_req_common_fifo_push, fzip_req_common_fifo_pop;
    wire fzip_req_common_fifo_full, fzip_req_common_fifo_empty;
    always @* begin
        fzip_req_common_fifo_push = fzip_stage_3 && fzip_is_common_stage_3;
        fzip_req_common_fifo_pop = !fzip_req_common_fifo_empty && !req_scratch_stall;
    end
    std_fifo #(.WIDTH(13), .DEPTH(32), .LATENCY(0), .ALMOST_FULL_COUNT(3)) fzip_req_common_fifo(rst, clk, fzip_req_common_fifo_push, fzip_req_common_fifo_pop, fzip_value_stage_3[12:0], fzip_req_common_fifo_q, fzip_req_common_fifo_full, fzip_req_common_fifo_empty, , , fzip_req_common_fifo_almost_full);
    always @* begin
        req_scratch_ld = fzip_req_common_fifo_pop;
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
        fzip_common_stage_4 = fzip_is_common_fifo_q && !fzip_common_fifo_empty && !stall_val;
        fzip_not_common_stage_4 = !fzip_is_common_fifo_q && !fzip_is_common_fifo_empty && !stall_val;
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
    initial input_arbiter = 4;
    wire [0:3] input_fifos_full = {spm_stream_decoder_full, spm_argument_decoder_full, fzip_stream_decoder_full, fzip_argument_decoder_full};
    reg [0:3] input_fifos_almost_full;
    always @(posedge clk) input_fifos_almost_full <= {spm_stream_decoder_almost_full, spm_argument_decoder_almost_full, fzip_stream_decoder_almost_full, fzip_argument_decoder_almost_full};
    always @(posedge clk) input_fifos_half_full <= {spm_stream_decoder_half_full, spm_argument_decoder_half_full, fzip_stream_decoder_half_full, fzip_argument_decoder_half_full};
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
        memory_response_fifo_0_pop = 0;
        memory_response_fifo_1_pop = 0;
        memory_response_fifo_2_pop = 0;
        memory_response_fifo_3_pop = 0;
        /*
        if(!memory_response_fifo_0_empty && !input_fifos_almost_full[0]) begin
            $display("here0");
            next_spm_stream_decoder_push = 1;
            memory_response_fifo_0_pop = 1;
        end
        if(!memory_response_fifo_1_empty && !input_fifos_almost_full[1]) begin
            $display("here1");
            next_spm_argument_decoder_push = 1;
            memory_response_fifo_1_pop = 1;
        end
        if(!memory_response_fifo_2_empty && !input_fifos_almost_full[2]) begin
            $display("here2");
            next_fzip_stream_decoder_push = 1;
            memory_response_fifo_2_pop = 1;
        end
        if(!memory_response_fifo_3_empty && !input_fifos_almost_full[3]) begin
            next_fzip_argument_decoder_push = 1;
            memory_response_fifo_3_pop = 1;
        end
        */
        case(input_arbiter)
            0: if(!memory_response_fifo_0_empty) begin
                next_spm_stream_decoder_push = 1;
                memory_response_fifo_0_pop = 1;
                memory_response_fifo_pop = 1;
            end
            1: if(!memory_response_fifo_1_empty) begin
                next_spm_argument_decoder_push = 1;
                memory_response_fifo_1_pop = 1;
                memory_response_fifo_pop = 1;
            end
            2: if(!memory_response_fifo_2_empty) begin
                next_fzip_stream_decoder_push = 1;
                memory_response_fifo_2_pop = 1;
                memory_response_fifo_pop = 1;
            end
            3: if(!memory_response_fifo_3_empty) begin
                next_fzip_argument_decoder_push = 1;
                memory_response_fifo_3_pop = 1;
                memory_response_fifo_pop = 1;
            end
            default: begin
            end
        endcase
    end
    //TODO: stream decoders and luts
    //TODO: deltas to indices logic

    //Debug
    // synthesis translate_off
    integer half_full_count [0:3];
    initial for(i = 0; i < 4; i = i + 1) begin
        half_full_count[i] = 0;
    end
    always @(posedge clk) begin
        for(i = 0; i < 4; i = i + 1) begin
            if(input_fifos_half_full[i])
                half_full_count[i] = half_full_count[i] + 1;
        end
        //$display("@verilog: %m debug:");
        //$display("@verilog: state: %d stall: %d", state, busy);
        //$display("@verilog decoder debug: %d", $time);
        //$display("@verilog: state: %d", state);
        //$display("@verilog: rst: %d", rst);
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
