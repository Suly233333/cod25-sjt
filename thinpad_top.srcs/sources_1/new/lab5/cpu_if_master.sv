/**
 * @file cpu_if_master.sv
 * @brief 五级流水线 CPU - IF 阶段（指令取指）
 *
 * 功能：
 * 1. PC 管理和更新
 * 2. 通过 Wishbone 总线读取指令
 * 3. 向下一级传递指令和 PC
 * 4. 处理气泡和暂停信号
 */
`include "mytype.sv"

module cpu_if_master (
    input  logic         clk,
    input  logic         rst,

    // Stall/Flush 控制信号
    input  stall_flush_in stall_flush_in_i,
    output stall_flush_out stall_flush_out_o,

    // 来自 EXE 的跳转目标地址
    input  logic [31:0]  pc_jump_i,
    input  logic         pc_jump_valid_i,

    // Wishbone 总线接口
    output logic [31:0]  wb_adr_o,
    input  logic [31:0]  wb_dat_i,
    output logic         wb_we_o,
    output logic [3:0]   wb_sel_o,
    output logic         wb_stb_o,
    input  logic         wb_ack_i,
    output logic         wb_cyc_o,

    // IF -> ID 流水线寄存器输出
    output if_id_reg     if_id_o
);

// ============================================================
// PC 管理
// ============================================================
logic [31:0] pc_reg, pc_next;
logic [1:0] wb_state, wb_state_next;  // 0: idle, 1: request, 2: wait_ack

always_ff @(posedge clk) begin
    if (rst) begin
        pc_reg <= 32'h80000000;  // 初始 PC
        wb_state <= 2'd0;
    end else if (stall_flush_in_i.stall_i) begin
        // 暂停时维持 PC 和总线状态
        pc_reg <= pc_reg;
        wb_state <= wb_state;
    end else if (stall_flush_in_i.bubble_i) begin
        // 气泡时也不改变 PC（等待后续处理）
        pc_reg <= pc_reg;
        wb_state <= wb_state;
    end else begin
        pc_reg <= pc_next;
        wb_state <= wb_state_next;
    end
end

// PC 更新逻辑
always_comb begin
    if (pc_jump_valid_i) begin
        // 如果有跳转请求，使用跳转地址
        pc_next = pc_jump_i;
    end else begin
        // 否则 PC += 4
        pc_next = pc_reg + 32'd4;
    end
end

// ============================================================
// Wishbone 总线控制
// ============================================================
always_comb begin
    // 只读操作，不写
    wb_we_o = 1'b0;
    wb_sel_o = 4'b1111;  // 读整个 word

    case (wb_state)
        2'd0: begin  // idle 状态
            wb_cyc_o = 1'b0;
            wb_stb_o = 1'b0;
            wb_adr_o = pc_reg;
            wb_state_next = 2'd1;  // 下一周期发送请求
        end
        2'd1: begin  // 发送请求
            wb_cyc_o = 1'b1;
            wb_stb_o = 1'b1;
            wb_adr_o = pc_reg;
            wb_state_next = 2'd2;  // 等待应答
        end
        2'd2: begin  // 等待应答
            wb_cyc_o = 1'b1;
            wb_stb_o = 1'b1;
            wb_adr_o = pc_reg;
            if (wb_ack_i) begin
                wb_state_next = 2'd0;  // 应答到来，回到 idle
            end else begin
                wb_state_next = 2'd2;  // 继续等待
            end
        end
        default: begin
            wb_cyc_o = 1'b0;
            wb_stb_o = 1'b0;
            wb_adr_o = pc_reg;
            wb_state_next = 2'd0;
        end
    endcase
end

// ============================================================
// IF -> ID 流水线寄存器
// ============================================================
if_id_reg if_id_next;

always_comb begin
    // 只有在总线应答时，才更新指令
    if (wb_state == 2'd2 && wb_ack_i) begin
        if_id_next.inst = wb_dat_i;
        if_id_next.pc = pc_reg;
        if_id_next.valid = 1'b1;
    end else begin
        // NOP 气泡
        if_id_next.inst = 32'h00000013;  // addi x0, x0, 0
        if_id_next.pc = pc_reg;
        if_id_next.valid = stall_flush_in_i.bubble_i ? 1'b0 : 1'b1;
    end
end

// 流水线寄存器
if_id_reg if_id_reg;
always_ff @(posedge clk) begin
    if (rst) begin
        if_id_reg.inst <= 32'h00000013;
        if_id_reg.pc <= 32'h80000000;
        if_id_reg.valid <= 1'b0;
    end else if (stall_flush_in_i.stall_i) begin
        // 暂停时维持输出
        if_id_reg <= if_id_reg;
    end else if (stall_flush_in_i.bubble_i) begin
        // 气泡
        if_id_reg.inst <= 32'h00000013;
        if_id_reg.valid <= 1'b0;
        if_id_reg.pc <= if_id_reg.pc;
    end else begin
        if_id_reg <= if_id_next;
    end
end

assign if_id_o = if_id_reg;

// ============================================================
// stall_flush_out 输出
// ============================================================
// IF 阶段的 wishbone 请求会阻塞流水线
assign stall_flush_out_o.stall_o = (wb_state == 2'd1 || wb_state == 2'd2) && !wb_ack_i;
assign stall_flush_out_o.flush_o = 1'b0;  // IF 阶段不发出 flush 请求

endmodule
