/**
 * @file stall_flush_controler.sv
 * @brief 五级流水线 CPU - Stall/Flush 控制器
 *
 * 功能：
 * 协调四个流水线寄存器的 stall 和 bubble 信号
 * - ID 的 stall 导致 IF 暂停、ID/EXE 插入 bubble
 * - EXE 的 flush 导致 IF/ID/EXE 插入 bubble
 * - MEM 的 stall 导致整个流水线暂停
 */

`include "mytype.sv"

module stall_flush_controller (
    input  logic         clk,
    input  logic         rst,

    // IF 阶段控制
    input  stall_flush_out if_out_i,
    output stall_flush_in  if_id_in_o,

    // ID 阶段控制
    input  stall_flush_out id_out_i,
    output stall_flush_in  id_ex_in_o,

    // EXE 阶段控制
    input  stall_flush_out exe_out_i,
    output stall_flush_in  exe_mem_in_o,

    // MEM 阶段控制
    input  stall_flush_out mem_out_i,
    output stall_flush_in  mem_wb_in_o
);

// ============================================================
// Stall 和 Flush 信号处理逻辑
// ============================================================

// 根据文档要求的逻辑：
// 1. ID 的 stall_o 导致：IF/ID 寄存器 stall，ID/EXE 寄存器 bubble
// 2. EXE 的 flush_o 导致：IF/ID、ID/EXE、EXE/MEM 寄存器都 bubble
// 3. MEM 的 stall_o 导致：所有前级寄存器 stall
// 4. IF 的 stall_o 导致：IF/ID 寄存器 stall

always_comb begin
    // ============================================================
    // IF/ID 寄存器控制
    // ============================================================
    // Stall: 当 IF 自身或 ID 或 MEM 发出 stall 请求时
    if_id_in_o.stall_i = if_out_i.stall_o || id_out_i.stall_o || mem_out_i.stall_o;

    // Bubble: 当 EXE 发出 flush 请求时，或复位时
    if_id_in_o.bubble_i = exe_out_i.flush_o || rst;

    // ============================================================
    // ID/EXE 寄存器控制
    // ============================================================
    // Stall: 当 MEM 发出 stall 请求时（但不包括 ID 的 stall，ID stall 时应该插入 bubble）
    id_ex_in_o.stall_i = mem_out_i.stall_o && !id_out_i.stall_o;

    // Bubble: 当 ID 发出 stall 或 EXE 发出 flush 请求时，或复位时
    id_ex_in_o.bubble_i = id_out_i.stall_o || exe_out_i.flush_o || rst;

    // ============================================================
    // EXE/MEM 寄存器控制
    // ============================================================
    // Stall: 当 MEM 发出 stall 请求时
    exe_mem_in_o.stall_i = mem_out_i.stall_o;

    // Bubble: 当 EXE 发出 flush 请求时，或复位时
    exe_mem_in_o.bubble_i = exe_out_i.flush_o || rst;

    // ============================================================
    // MEM/WB 寄存器控制
    // ============================================================
    // Stall: MEM 阶段不会被后级阻塞（没有后级）
    mem_wb_in_o.stall_i = 1'b0;

    // Bubble: 仅在复位时
    mem_wb_in_o.bubble_i = rst;
end

endmodule
