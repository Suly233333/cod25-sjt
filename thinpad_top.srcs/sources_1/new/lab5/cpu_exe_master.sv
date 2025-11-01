/**
 * @file exe.sv
 * @brief 五级流水线 CPU - EXE 阶段（执行）
 *
 * 功能：
 * 1. ALU 执行计算（ADD, SUB, AND 等）
 * 2. 立即数生成和操作
 * 3. 分支判断（BEQ）
 * 4. LUI 指令处理
 * 5. 数据前递（从 WB 阶段）
 */
`include "mytype.sv"

module cpu_exe_master (
    input  logic         clk,
    input  logic         rst,

    // Stall/Flush 控制信号
    input  stall_flush_in stall_flush_in_i,
    output stall_flush_out stall_flush_out_o,

    // ID/EXE 流水线寄存器输入
    input  id_ex_reg     id_ex_i,

    // 从 WB 阶段的数据前递
    input  logic [31:0]  wb_rf_wdata_i,
    input  logic [4:0]   wb_rf_waddr_i,
    input  logic         wb_rf_wen_i,

    // 分支跳转信号
    output logic [31:0]  pc_jump_o,
    output logic         pc_jump_valid_o,

    // EXE -> MEM 流水线寄存器输出
    output ex_mem_reg    ex_mem_o
);

// ============================================================
// 数据前递逻辑
// ============================================================
logic [31:0] rs1_data, rs2_data;

always_comb begin
    // rs1 数据选择
    if (wb_rf_wen_i && wb_rf_waddr_i != 5'b0 && wb_rf_waddr_i == id_ex_i.rf_raddr_a) begin
        rs1_data = wb_rf_wdata_i;
    end else begin
        rs1_data = id_ex_i.rf_rdata_a;
    end

    // rs2 数据选择
    if (wb_rf_wen_i && wb_rf_waddr_i != 5'b0 && wb_rf_waddr_i == id_ex_i.rf_raddr_b) begin
        rs2_data = wb_rf_wdata_i;
    end else begin
        rs2_data = id_ex_i.rf_rdata_b;
    end
end

// ============================================================
// 立即数生成
// ============================================================
logic [31:0] immediate;

always_comb begin
    case (id_ex_i.imm_type)
        IMM_I: immediate = {{20{id_ex_i.inst[31]}}, id_ex_i.inst[31:20]};
        IMM_S: immediate = {{20{id_ex_i.inst[31]}}, id_ex_i.inst[31:25], id_ex_i.inst[11:7]};
        IMM_B: immediate = {{20{id_ex_i.inst[31]}}, id_ex_i.inst[7], id_ex_i.inst[30:25], id_ex_i.inst[11:8], 1'b0};
        IMM_U: immediate = {id_ex_i.inst[31:12], 12'b0};
        IMM_J: immediate = {{12{id_ex_i.inst[31]}}, id_ex_i.inst[19:12], id_ex_i.inst[20], id_ex_i.inst[30:21], 1'b0};
        default: immediate = 32'b0;
    endcase
end

// ============================================================
// ALU 操作数选择
// ============================================================
logic [31:0] alu_a, alu_b;

// ALU 操作数 A: 对于 LUI 指令使用 0，其他指令使用 rs1
assign alu_a = (id_ex_i.imm_type == IMM_U) ? 32'b0 : rs1_data;

// ALU 操作数 B: 根据 use_rs2 选择
assign alu_b = id_ex_i.use_rs2 ? rs2_data : immediate;

// ============================================================
// ALU 实现
// ============================================================
logic [31:0] alu_result;

always_comb begin
    case (id_ex_i.alu_op)
        ALU_ADD: alu_result = alu_a + alu_b;
        ALU_SUB: alu_result = alu_a - alu_b;
        ALU_AND: alu_result = alu_a & alu_b;
        ALU_OR:  alu_result = alu_a | alu_b;
        ALU_XOR: alu_result = alu_a ^ alu_b;
        default: alu_result = 32'b0;
    endcase
end

// ============================================================
// 分支跳转逻辑
// ============================================================
logic jump_valid;
logic [31:0] target_pc;

always_comb begin
    jump_valid = 1'b0;
    target_pc = 32'b0;

    // BEQ 指令判断：当 imm_type == IMM_B 且 rs1 == rs2 时跳转
    if (id_ex_i.imm_type == IMM_B && id_ex_i.valid) begin
        // ALU 已经执行了 SUB 操作，如果结果为 0 则相等
        if (alu_result == 32'b0) begin
            jump_valid = 1'b1;
            target_pc = id_ex_i.pc + immediate;
        end
    end
end

assign pc_jump_o = target_pc;
assign pc_jump_valid_o = jump_valid;

// ============================================================
// 内存字节选择逻辑
// ============================================================
logic [3:0] mem_sel;
logic [6:0] opcode;
logic [2:0] funct3;

assign opcode = id_ex_i.inst[6:0];
assign funct3 = id_ex_i.inst[14:12];

always_comb begin
    mem_sel = 4'b0000;

    if (id_ex_i.mem_en) begin
        case (opcode)
            7'b0000011: begin  // Load 指令
                case (funct3)
                    3'b000, 3'b100: begin  // LB/LBU: 字节访问
                        case (alu_result[1:0])
                            2'b00: mem_sel = 4'b0001;  // byte 0
                            2'b01: mem_sel = 4'b0010;  // byte 1
                            2'b10: mem_sel = 4'b0100;  // byte 2
                            2'b11: mem_sel = 4'b1000;  // byte 3
                        endcase
                    end
                    3'b010: mem_sel = 4'b1111;  // LW: 字访问
                    default: mem_sel = 4'b0000;
                endcase
            end
            7'b0100011: begin  // Store 指令
                case (funct3)
                    3'b000: begin  // SB: 字节访问
                        case (alu_result[1:0])
                            2'b00: mem_sel = 4'b0001;  // byte 0
                            2'b01: mem_sel = 4'b0010;  // byte 1
                            2'b10: mem_sel = 4'b0100;  // byte 2
                            2'b11: mem_sel = 4'b1000;  // byte 3
                        endcase
                    end
                    3'b010: mem_sel = 4'b1111;  // SW: 字访问
                    default: mem_sel = 4'b0000;
                endcase
            end
            default: mem_sel = 4'b0000;
        endcase
    end
end

// ============================================================
// 判断是否为 Store 指令
// ============================================================
logic mem_wr;
assign mem_wr = (opcode == 7'b0100011) ? 1'b1 : 1'b0;

// ============================================================
// 准备写回数据（用于 Store 指令）
// ============================================================
logic [31:0] store_data;

always_comb begin
    // 根据地址偏移调整写入数据的位置
    case (alu_result[1:0])
        2'b00: store_data = rs2_data;
        2'b01: store_data = {rs2_data[23:0], 8'b0};
        2'b10: store_data = {rs2_data[15:0], 16'b0};
        2'b11: store_data = {rs2_data[7:0], 24'b0};
    endcase
end

// ============================================================
// EXE -> MEM 流水线寄存器
// ============================================================
ex_mem_reg ex_mem_next;

always_comb begin
    ex_mem_next.alu_result = alu_result;
    ex_mem_next.rf_rdata_b = store_data;  // 用于存储指令的数据
    ex_mem_next.mem_en = id_ex_i.mem_en;
    ex_mem_next.mem_wr = mem_wr;
    ex_mem_next.mem_addr = alu_result;
    ex_mem_next.rf_wen = id_ex_i.rf_wen;
    ex_mem_next.rf_waddr = id_ex_i.rf_waddr;
    ex_mem_next.rf_wdata = alu_result;
    ex_mem_next.mem_sel = mem_sel;
    ex_mem_next.inst = id_ex_i.inst;
    ex_mem_next.valid = id_ex_i.valid;
end

ex_mem_reg ex_mem_reg_r;

always_ff @(posedge clk) begin
    if (rst) begin
        ex_mem_reg_r.inst <= 32'h00000013;
        ex_mem_reg_r.valid <= 1'b0;
        ex_mem_reg_r.rf_wen <= 1'b0;
        ex_mem_reg_r.mem_en <= 1'b0;
        ex_mem_reg_r.mem_wr <= 1'b0;
        ex_mem_reg_r.alu_result <= 32'b0;
        ex_mem_reg_r.rf_rdata_b <= 32'b0;
        ex_mem_reg_r.mem_addr <= 32'b0;
        ex_mem_reg_r.rf_waddr <= 5'b0;
        ex_mem_reg_r.rf_wdata <= 32'b0;
        ex_mem_reg_r.mem_sel <= 4'b0;
    end else if (stall_flush_in_i.stall_i) begin
        // 暂停时维持输出
        ex_mem_reg_r <= ex_mem_reg_r;
    end else if (stall_flush_in_i.bubble_i) begin
        // 气泡
        ex_mem_reg_r.inst <= 32'h00000013;
        ex_mem_reg_r.valid <= 1'b0;
        ex_mem_reg_r.rf_wen <= 1'b0;
        ex_mem_reg_r.mem_en <= 1'b0;
    end else begin
        ex_mem_reg_r <= ex_mem_next;
    end
end

assign ex_mem_o = ex_mem_reg_r;

// ============================================================
// stall_flush_out 输出
// ============================================================
assign stall_flush_out_o.stall_o = 1'b0;  // EXE 阶段不产生 stall
assign stall_flush_out_o.flush_o = jump_valid;  // 跳转时需要 flush

endmodule
