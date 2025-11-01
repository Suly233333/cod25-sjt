/**
 * @file id.sv
 * @brief 五级流水线 CPU - ID 阶段（指令解码与寄存器读取）
 *
 * 功能：
 * 1. 指令解码，生成控制信号
 * 2. 读取寄存器文件
 * 3. 数据冲突检测
 * 4. 生成立即数
 */

`include "mytype.sv"

module cpu_id_master (
    input  logic         clk,
    input  logic         rst,

    // Stall/Flush 控制信号
    input  stall_flush_in stall_flush_in_i,
    output stall_flush_out stall_flush_out_o,

    // IF/ID 流水线寄存器输入
    input  if_id_reg     if_id_i,

    // 寄存器文件读端口
    output logic [4:0]   rf_raddr_a_o,
    output logic [4:0]   rf_raddr_b_o,
    input  logic [31:0]  rf_rdata_a_i,
    input  logic [31:0]  rf_rdata_b_i,

    // 来自 EXE/MEM/WB 的写回信息（用于数据冲突检测）
    input  logic         exe_mem_wen_i,
    input  logic [4:0]   exe_mem_waddr_i,
    input  logic         mem_wb_wen_i,
    input  logic [4:0]   mem_wb_waddr_i,
    input  logic         wb_wen_i,
    input  logic [4:0]   wb_waddr_i,

    // ID -> EXE 流水线寄存器输出
    output id_ex_reg     id_ex_o
);

// ============================================================
// 指令字段提取
// ============================================================
logic [4:0] rs1_addr, rs2_addr, rd_addr;
logic [6:0] opcode;
logic [2:0] funct3;
logic [6:0] funct7;

assign opcode = if_id_i.inst[6:0];
assign funct3 = if_id_i.inst[14:12];
assign funct7 = if_id_i.inst[31:25];
assign rs1_addr = if_id_i.inst[19:15];
assign rs2_addr = if_id_i.inst[24:20];
assign rd_addr = if_id_i.inst[11:7];

// ============================================================
// 指令解码
// ============================================================
imm_type_t imm_type;
alu_op_t alu_op;
logic use_rs2;
logic mem_en;
logic mem_wr;
logic rf_wen;

always_comb begin
    // 默认值
    imm_type = IMM_NONE;
    alu_op = ALU_NOP;
    use_rs2 = 1'b0;
    mem_en = 1'b0;
    mem_wr = 1'b0;
    rf_wen = 1'b0;

    // 指令解码
    case (opcode)
        // ADD (R-type, opcode=0110011)
        7'b0110011: begin
            if (funct7 == 7'b0000000 && funct3 == 3'b000) begin
                alu_op = ALU_ADD;
                use_rs2 = 1'b1;
                rf_wen = 1'b1;
            end
        end

        // ADDI (I-type, opcode=0010011)
        7'b0010011: begin
            case (funct3)
                3'b000: begin  // ADDI
                    imm_type = IMM_I;
                    alu_op = ALU_ADD;
                    use_rs2 = 1'b0;
                    rf_wen = 1'b1;
                end
                3'b111: begin  // ANDI
                    imm_type = IMM_I;
                    alu_op = ALU_AND;
                    use_rs2 = 1'b0;
                    rf_wen = 1'b1;
                end
                default: begin
                    alu_op = ALU_NOP;
                    rf_wen = 1'b0;
                end
            endcase
        end

        // LB (I-type Load, opcode=0000011)
        7'b0000011: begin
            case (funct3)
                3'b000,  // LB (signed)
                3'b100: begin  // LBU (unsigned)
                    imm_type = IMM_I;
                    alu_op = ALU_ADD;
                    use_rs2 = 1'b0;
                    mem_en = 1'b1;
                    mem_wr = 1'b0;  // 读
                    rf_wen = 1'b1;
                end
                default: begin
                    alu_op = ALU_NOP;
                    rf_wen = 1'b0;
                end
            endcase
        end

        // SB/SW (S-type Store, opcode=0100011)
        7'b0100011: begin
            imm_type = IMM_S;
            alu_op = ALU_ADD;
            use_rs2 = 1'b1;
            mem_en = 1'b1;
            mem_wr = 1'b1;  // 写
            rf_wen = 1'b0;
        end

        // BEQ (B-type, opcode=1100011)
        7'b1100011: begin
            if (funct3 == 3'b000) begin  // BEQ
                imm_type = IMM_B;
                alu_op = ALU_SUB;  // 用于比较（计算 rs1 - rs2）
                use_rs2 = 1'b1;
                rf_wen = 1'b0;
            end
        end

        // LUI (U-type, opcode=0110111)
        7'b0110111: begin
            imm_type = IMM_U;
            alu_op = ALU_ADD;  // LUI: result = imm + 0
            use_rs2 = 1'b0;
            rf_wen = 1'b1;
        end

        // NOP (addi x0, x0, 0 = 0x00000013)
        7'b0010011: begin
            if (if_id_i.inst == 32'h00000013) begin
                imm_type = IMM_I;
                alu_op = ALU_ADD;
                use_rs2 = 1'b0;
                rf_wen = 1'b0;
            end
        end

        default: begin
            alu_op = ALU_NOP;
            rf_wen = 1'b0;
        end
    endcase
end

// ============================================================
// 立即数生成
// ============================================================
logic [31:0] imm;

always_comb begin
    case (imm_type)
        IMM_I: imm = {{20{if_id_i.inst[31]}}, if_id_i.inst[31:20]};
        IMM_S: imm = {{20{if_id_i.inst[31]}}, if_id_i.inst[31:25], if_id_i.inst[11:7]};
        IMM_B: imm = {{20{if_id_i.inst[31]}}, if_id_i.inst[7], if_id_i.inst[30:25], if_id_i.inst[11:8], 1'b0};
        IMM_U: imm = {if_id_i.inst[31:12], 12'b0};
        IMM_J: imm = {{12{if_id_i.inst[31]}}, if_id_i.inst[19:12], if_id_i.inst[20], if_id_i.inst[30:21], 1'b0};
        default: imm = 32'b0;
    endcase
end

// ============================================================
// 寄存器读取地址
// ============================================================
assign rf_raddr_a_o = rs1_addr;
assign rf_raddr_b_o = rs2_addr;

// ============================================================
// 数据冲突检测
// ============================================================
logic has_data_hazard;

always_comb begin
    has_data_hazard = 1'b0;

    // 检测 rs1 冲突
    if (rs1_addr != 5'b0) begin  // x0 不需要检测
        if ((exe_mem_wen_i && exe_mem_waddr_i == rs1_addr) ||
            (mem_wb_wen_i && mem_wb_waddr_i == rs1_addr) ||
            (wb_wen_i && wb_waddr_i == rs1_addr)) begin
            has_data_hazard = 1'b1;
        end
    end

    // 检测 rs2 冲突
    if (rs2_addr != 5'b0) begin  // x0 不需要检测
        if ((exe_mem_wen_i && exe_mem_waddr_i == rs2_addr) ||
            (mem_wb_wen_i && mem_wb_waddr_i == rs2_addr) ||
            (wb_wen_i && wb_waddr_i == rs2_addr)) begin
            has_data_hazard = 1'b1;
        end
    end
end

// ============================================================
// ID -> EXE 流水线寄存器
// ============================================================
id_ex_reg id_ex_next;

always_comb begin
    id_ex_next.inst = if_id_i.inst;
    id_ex_next.pc = if_id_i.pc;
    id_ex_next.rf_raddr_a = rs1_addr;
    id_ex_next.rf_raddr_b = rs2_addr;
    id_ex_next.rf_rdata_a = rf_rdata_a_i;
    id_ex_next.rf_rdata_b = rf_rdata_b_i;
    id_ex_next.imm_type = imm_type;
    id_ex_next.alu_op = alu_op;
    id_ex_next.use_rs2 = use_rs2;
    id_ex_next.mem_en = mem_en;
    id_ex_next.rf_wen = rf_wen;
    id_ex_next.rf_waddr = rd_addr;
    id_ex_next.valid = if_id_i.valid;
end

id_ex_reg id_ex_reg_r;
always_ff @(posedge clk) begin
    if (rst) begin
        id_ex_reg_r.inst <= 32'h00000013;
        id_ex_reg_r.valid <= 1'b0;
        id_ex_reg_r.rf_wen <= 1'b0;
    end else if (stall_flush_in_i.stall_i) begin
        // 暂停时维持输出
        id_ex_reg_r <= id_ex_reg_r;
    end else if (stall_flush_in_i.bubble_i) begin
        // 气泡
        id_ex_reg_r.inst <= 32'h00000013;
        id_ex_reg_r.valid <= 1'b0;
        id_ex_reg_r.rf_wen <= 1'b0;
    end else begin
        id_ex_reg_r <= id_ex_next;
    end
end

assign id_ex_o = id_ex_reg_r;

// ============================================================
// stall_flush_out 输出
// ============================================================
assign stall_flush_out_o.stall_o = has_data_hazard && if_id_i.valid;
assign stall_flush_out_o.flush_o = 1'b0;

endmodule
