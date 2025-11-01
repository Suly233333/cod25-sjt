`default_nettype none

module lab5_cpu_controller #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
) (
    input wire clk_i,
    input wire rst_i,

    // ALU
    input wire [DATA_WIDTH-1:0] alu_y,
    output wire [DATA_WIDTH-1:0] alu_a,
    output wire [DATA_WIDTH-1:0] alu_b,
    output wire [3:0] alu_op,

    // regfile
    input wire [DATA_WIDTH-1:0] rf_rdata_a,
    input wire [DATA_WIDTH-1:0] rf_rdata_b,
    output wire [4:0] rf_raddr_a,
    output wire [4:0] rf_raddr_b,
    output wire [4:0] rf_waddr,
    output wire [DATA_WIDTH-1:0] rf_wdata,
    output wire rf_we,

    // wishbone master
    output wire wb_cyc_o,
    output wire wb_stb_o,
    input wire wb_ack_i,
    output wire [ADDR_WIDTH-1:0] wb_adr_o,
    output wire [DATA_WIDTH-1:0] wb_dat_o,
    input wire [DATA_WIDTH-1:0] wb_dat_i,
    output wire [DATA_WIDTH/8-1:0] wb_sel_o,
    output wire wb_we_o
);
    typedef enum logic [2:0] {
        STATE_IF,
        STATE_ID,
        STATE_EXE,
        STATE_MEM,
        STATE_WB
    } state_t;
    state_t state;

    typedef enum logic [3:0] {
        LUI,
        BEQ,
        LB,
        SB,
        SW,
        ADDI,
        ANDI,
        ADD
        //ERR
    } instr_t;
    instr_t instrcode;

    typedef enum logic [3:0] {
        OP_NONE = 4'b0000,
        OP_ADD = 4'b0001,
        OP_SUB = 4'b0010,
        OP_AND = 4'b0011,
        OP_OR  = 4'b0100,
        OP_XOR = 4'b0101,
        OP_NOT = 4'b0110,
        OP_SLL = 4'b0111,
        OP_SRL = 4'b1000,
        OP_SRA = 4'b1001,
        OP_ROL = 4'b1010
    } opcode_t;
    opcode_t alu_opcode;

    reg [ADDR_WIDTH-1:0] pc_reg;
    reg [ADDR_WIDTH-1:0] pc_now_reg;
    reg [DATA_WIDTH-1:0] instr_reg;

    logic [4:0] rs1, rs2, rd;
    logic [31:0] imm;
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic is_itype, is_stype;

    reg [DATA_WIDTH-1:0] operand1_reg;
    reg [DATA_WIDTH-1:0] operand2_reg;
    reg [31:0] imm_reg;

    reg [ADDR_WIDTH-1:0] wb_addr_reg;

    reg [31:0] rf_writeback_reg;

    // 内部寄存器用于存储输出信号的值
    reg [DATA_WIDTH-1:0] alu_a_r;
    reg [DATA_WIDTH-1:0] alu_b_r;
    reg [3:0] alu_op_r;
    reg [4:0] rf_raddr_a_r;
    reg [4:0] rf_raddr_b_r;
    reg [4:0] rf_waddr_r;
    reg [DATA_WIDTH-1:0] rf_wdata_r;
    reg rf_we_r;
    reg wb_cyc_o_r;
    reg wb_stb_o_r;
    reg [ADDR_WIDTH-1:0] wb_adr_o_r;
    reg [DATA_WIDTH-1:0] wb_dat_o_r;
    reg [DATA_WIDTH/8-1:0] wb_sel_o_r;
    reg wb_we_o_r;

    // 用组合逻辑将内部寄存器驱动输出
    assign alu_a = alu_a_r;
    assign alu_b = alu_b_r;
    assign alu_op = alu_op_r;
    assign rf_raddr_a = rf_raddr_a_r;
    assign rf_raddr_b = rf_raddr_b_r;
    assign rf_waddr = rf_waddr_r;
    assign rf_wdata = rf_wdata_r;
    assign rf_we = rf_we_r;
    assign wb_cyc_o = wb_cyc_o_r;
    assign wb_stb_o = wb_stb_o_r;
    assign wb_adr_o = wb_adr_o_r;
    assign wb_dat_o = wb_dat_o_r;
    assign wb_sel_o = wb_sel_o_r;
    assign wb_we_o = wb_we_o_r;

    // 组合逻辑：解析指令字段
    always_comb begin
        rd = instr_reg[11:7];
        rs1 = instr_reg[19:15];
        rs2 = instr_reg[24:20];
        opcode = instr_reg[6:0];
        funct3 = instr_reg[14:12];
    end

    // 组合逻辑：指令译码
    always_comb begin
        imm = 0;

        // 决定指令的类型
        if (opcode == 7'b0110111) begin
            instrcode = LUI;
        end
        else if (opcode == 7'b1100011 && funct3 == 3'b000) begin
            instrcode = BEQ;
        end
        else if (opcode == 7'b0110011 && funct3 == 3'b000) begin
            instrcode = ADD;
        end
        else if (opcode == 7'b0100011) begin
            if (funct3 == 3'b000) begin
                instrcode = SB;
            end
            else if (funct3 == 3'b010) begin
                instrcode = SW;
            end
        end
        else if (opcode == 7'b0010011) begin
            if (funct3 == 3'b000) begin
                instrcode = ADDI;
            end
            else if (funct3 == 3'b111) begin
                instrcode = ANDI;
            end
        end
        else if (opcode == 7'b0000011) begin
            instrcode = LB;
        end

        is_itype = ((instrcode == LB ) || (instrcode == ADDI) || (instrcode == ANDI));
        is_stype = ((instrcode == SB) || (instrcode == SW));

        // 立即数解析
        if (is_itype) begin
            imm = {{20{instr_reg[31]}}, instr_reg[31:20]};
        end
        else if (is_stype) begin
            imm = {{20{instr_reg[31]}}, instr_reg[31:25], instr_reg[11:7]};
        end
        else if (instrcode == LUI) begin
            imm = {instr_reg[31:12], 12'b0};
        end
        else if (instrcode == BEQ) begin
            imm = {{19{instr_reg[31]}}, instr_reg[31], instr_reg[7], instr_reg[30:25], instr_reg[11:8], 1'b0};
        end
    end


    // 组合逻辑：根据当前状态生成输出信号
    always_comb begin
        // 默认值
        wb_cyc_o_r = 1'b1;
        wb_stb_o_r = 1'b1;
        wb_adr_o_r = pc_reg;
        wb_we_o_r = 1'b0;
        wb_sel_o_r = 4'b1111;
        wb_dat_o_r = 32'b0;
        alu_a_r = pc_reg;
        alu_b_r = 32'h4;
        alu_op_r = OP_ADD;
        rf_raddr_a_r = 5'b0;
        rf_raddr_b_r = 5'b0;
        rf_we_r = 1'b0;
        rf_waddr_r = 5'b0;
        rf_wdata_r = 32'b0;

        case(state)
            // 指令取值阶段
            STATE_IF: begin
                wb_cyc_o_r = 1'b1;
                wb_stb_o_r = 1'b1;
                wb_adr_o_r = pc_reg;
                wb_we_o_r = 1'b0;
                wb_sel_o_r = 4'b1111;
                wb_dat_o_r = 32'b0;
                alu_a_r = pc_reg;
                alu_b_r = 32'h4;
                alu_op_r = OP_ADD;
                rf_raddr_a_r = 5'b0;
                rf_raddr_b_r = 5'b0;
                rf_we_r = 1'b0;
                rf_waddr_r = 5'b0;
                rf_wdata_r = 32'b0;
            end
            // 指令译码阶段
            STATE_ID: begin
                wb_cyc_o_r = 1'b0;
                wb_stb_o_r = 1'b0;
                wb_adr_o_r = 32'b0;
                wb_we_o_r = 1'b0;
                wb_sel_o_r = 4'b1111;
                wb_dat_o_r = 32'b0;
                alu_a_r = 32'b0;
                alu_b_r = 32'b0;
                alu_op_r = OP_NONE;
                rf_raddr_a_r = rs1;
                rf_raddr_b_r = rs2;
                rf_we_r = 1'b0;
                rf_waddr_r = 5'b0;
                rf_wdata_r = 32'b0;
            end
            // 执行阶段
            STATE_EXE: begin
                wb_cyc_o_r = 1'b0;
                wb_stb_o_r = 1'b0;
                wb_adr_o_r = 32'b0;
                wb_we_o_r = 1'b0;
                wb_sel_o_r = 4'b1111;
                wb_dat_o_r = 32'b0;
                alu_a_r = operand1_reg;
                alu_b_r = operand2_reg;
                alu_op_r = OP_NONE;
                rf_raddr_a_r = 5'b0;
                rf_raddr_b_r = 5'b0;
                rf_we_r = 1'b0;
                rf_waddr_r = 5'b0;
                rf_wdata_r = 32'b0;

                case (instrcode)
                    ADDI: begin
                        alu_op_r = OP_ADD;
                    end
                    LUI: begin
                        alu_op_r = OP_ADD;
                    end
                    BEQ: begin
                        alu_op_r = OP_SUB;
                    end
                    LB: begin
                        alu_op_r = OP_ADD;
                    end
                    SB: begin
                        alu_op_r = OP_ADD;
                    end
                    SW: begin
                        alu_op_r = OP_ADD;
                    end
                    ANDI: begin
                        alu_op_r = OP_AND;
                    end
                    ADD: begin
                        alu_op_r = OP_ADD;
                    end
                    default: begin
                        alu_op_r = OP_NONE;
                    end
                endcase
            end
            // 存储器访问阶段
            STATE_MEM: begin
                wb_cyc_o_r = 1'b1;
                wb_stb_o_r = 1'b1;
                wb_adr_o_r = wb_addr_reg;
                wb_we_o_r = 1'b0;
                wb_sel_o_r = 4'b1111;
                wb_dat_o_r = rf_rdata_b;
                alu_a_r = 32'b0;
                alu_b_r = 32'b0;
                alu_op_r = OP_NONE;
                rf_raddr_a_r = 5'b0;
                rf_raddr_b_r = rs2;
                rf_we_r = 1'b0;
                rf_waddr_r = 5'b0;
                rf_wdata_r = 32'b0;

                if (instrcode == SB || instrcode == SW) begin
                    wb_we_o_r = 1'b1;
                end
                if (instrcode == SB || instrcode == LB) begin
                    wb_sel_o_r = (4'b0001 << (wb_addr_reg % 4));
                end
            end
            // 写回阶段
            STATE_WB: begin
                wb_cyc_o_r = 1'b0;
                wb_stb_o_r = 1'b0;
                wb_adr_o_r = 32'b0;
                wb_we_o_r = 1'b0;
                wb_sel_o_r = 4'b1111;
                wb_dat_o_r = 32'b0;
                alu_a_r = 32'b0;
                alu_b_r = 32'b0;
                alu_op_r = OP_NONE;
                rf_raddr_a_r = 5'b0;
                rf_raddr_b_r = 5'b0;
                if (instrcode != SB && instrcode != SW) begin
                    rf_we_r = 1'b1;
                    rf_waddr_r = rd;
                    rf_wdata_r = rf_writeback_reg;
                end
                else begin
                    rf_we_r = 1'b0;
                    rf_waddr_r = 5'b0;
                    rf_wdata_r = 32'b0;
                end
            end
            // 默认状态
            default: begin
                wb_cyc_o_r = 1'b1;
                wb_stb_o_r = 1'b1;
                wb_adr_o_r = pc_reg;
                wb_we_o_r = 1'b0;
                wb_sel_o_r = 4'b1111;
                wb_dat_o_r = 32'b0;
                alu_a_r = pc_reg;
                alu_b_r = 32'h4;
                alu_op_r = OP_ADD;
                rf_raddr_a_r = 5'b0;
                rf_raddr_b_r = 5'b0;
                rf_we_r = 1'b0;
                rf_waddr_r = 5'b0;
                rf_wdata_r = 32'b0;
            end
        endcase
    end

    // 时序逻辑：状态转移和内部寄存器更新
    always_ff @ (posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            state <= STATE_IF;
            operand1_reg <= 32'h0;
            operand2_reg <= 32'h0;
            pc_reg <= 32'h8000_0000;
            pc_now_reg <= 32'h8000_0000;
            instr_reg <= 32'h0;
            imm_reg <= 32'h0;
            rf_writeback_reg <= 32'h0;
            wb_addr_reg <= 32'h0;
        end
        else begin
            case(state)
                // 指令取值阶段
                STATE_IF: begin
                    imm_reg <= 32'h0;
                    pc_now_reg <= pc_reg;
                    instr_reg <= wb_dat_i;
                    if (wb_ack_i) begin
                        pc_reg <= alu_y;
                        state <= STATE_ID;
                    end else begin
                        state <= STATE_IF;
                    end
                end
                // 指令译码阶段
                STATE_ID: begin
                    imm_reg <= imm;
                    case (instrcode)
                        ADDI: begin
                            operand1_reg <= rf_rdata_a;
                            operand2_reg <= imm;
                        end
                        ADD: begin
                            operand1_reg <= rf_rdata_a;
                            operand2_reg <= rf_rdata_b;
                        end
                        LUI: begin
                            operand1_reg <= 32'h0;
                            operand2_reg <= imm;
                        end
                        BEQ: begin
                            operand1_reg <= rf_rdata_a;
                            operand2_reg <= rf_rdata_b;
                        end
                        LB: begin
                            operand1_reg <= rf_rdata_a;
                            operand2_reg <= imm;
                        end
                        SB: begin
                            operand1_reg <= rf_rdata_a;
                            operand2_reg <= imm;
                        end
                        SW: begin
                            operand1_reg <= rf_rdata_a;
                            operand2_reg <= imm;
                        end
                        ANDI: begin
                            operand1_reg <= rf_rdata_a;
                            operand2_reg <= imm;
                        end
                        default: begin
                            operand1_reg <= 0;
                            operand2_reg <= 0;
                        end
                    endcase
                    state <= STATE_EXE;
                end
                // 执行阶段
                STATE_EXE: begin
                    case (instrcode)
                        ADDI: begin
                            rf_writeback_reg <= alu_y;
                            state <= STATE_WB;
                        end
                        LUI: begin
                            rf_writeback_reg <= alu_y;
                            state <= STATE_WB;
                        end
                        BEQ: begin
                            if (alu_y == 0) begin
                                pc_reg <= pc_now_reg + imm_reg;
                            end
                            state <= STATE_IF;
                        end
                        LB: begin
                            wb_addr_reg <= alu_y;
                            state <= STATE_MEM;
                        end
                        SB: begin
                            wb_addr_reg <= alu_y;
                            state <= STATE_MEM;
                        end
                        SW: begin
                            wb_addr_reg <= alu_y;
                            state <= STATE_MEM;
                        end
                        ANDI: begin
                            rf_writeback_reg <= alu_y;
                            state <= STATE_WB;
                        end
                        ADD: begin
                            rf_writeback_reg <= alu_y;
                            state <= STATE_WB;
                        end
                        default: begin
                            state <= STATE_IF;
                        end
                    endcase
                end
                // 存储器访问阶段
                STATE_MEM: begin
                    if (instrcode == LB) begin
                        case (wb_sel_o_r)
                            4'b0001: rf_writeback_reg <= {{24{wb_dat_i[7]}}, wb_dat_i[7:0]};
                            4'b0010: rf_writeback_reg <= {{24{wb_dat_i[15]}}, wb_dat_i[15:8]};
                            4'b0100: rf_writeback_reg <= {{24{wb_dat_i[23]}}, wb_dat_i[23:16]};
                            4'b1000: rf_writeback_reg <= {{24{wb_dat_i[31]}}, wb_dat_i[31:24]};
                            default: rf_writeback_reg <= 32'b0;
                        endcase
                        if (wb_ack_i) begin
                            state <= STATE_WB;
                        end
                    end
                    else if (instrcode == SB || instrcode == SW) begin
                        if (wb_ack_i) begin
                            state <= STATE_WB;
                        end
                    end
                    else begin
                        state <= STATE_MEM;
                    end
                end
                // 写回阶段
                STATE_WB: begin
                    state <= STATE_IF;
                end
                // 默认状态
                default: begin
                    state <= STATE_IF;
                end
            endcase
        end
    end
endmodule
