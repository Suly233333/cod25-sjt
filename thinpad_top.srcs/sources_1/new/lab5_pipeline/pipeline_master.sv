module pipeline_master (
    input wire clk,
    input wire rst,

    // From Pipeline Stages
    input wire if_stall_i,
    input wire if_flush_i,
    input wire id_stall_i,
    input wire id_flush_i,
    input wire exe_stall_i,
    input wire exe_flush_i,
    input wire mem_stall_i,
    input wire mem_flush_i,

    // To Pipeline Interstage Registers
    output logic if_id_stall_o,
    output logic if_id_bubble_o,
    output logic id_exe_stall_o,
    output logic id_exe_bubble_o,
    output logic exe_mem_stall_o,
    output logic exe_mem_bubble_o,
    output logic mem_wb_stall_o,
    output logic mem_wb_bubble_o
);
//对于每个流水线段寄存器我们都需要增加以下两个输入：
// stall_i 为 1 时，表示下个周期将忽略输入，维持输出不变
// bubble_i 为 1 时，表示下个周期清空该寄存器（变为气泡），输出也为气泡

// 对于每个流水线段（组合逻辑），我们需要增加以下输出信号：
// flush_o 为 1 时，表示这个流水线段发出请求，要将所有 之前 的流水线段清空
// stall_o 为 1 时，表示这个流水线段发出请求，要在这个阶段阻塞流水线
    // IF/ID Pipeline Register
    assign if_id_stall_o  = if_stall_i | id_stall_i | exe_stall_i | mem_stall_i;
    assign if_id_bubble_o = if_flush_i | id_flush_i | exe_flush_i | mem_flush_i;

    // ID/EXE Pipeline Register
    assign id_exe_stall_o  = id_stall_i | exe_stall_i | mem_stall_i;
    assign id_exe_bubble_o = id_flush_i | exe_flush_i | mem_flush_i;

    // EXE/MEM Pipeline Register
    assign exe_mem_stall_o  = exe_stall_i | mem_stall_i;
    assign exe_mem_bubble_o = exe_flush_i | mem_flush_i;

    // MEM/WB Pipeline Register
    assign mem_wb_stall_o  = mem_stall_i;
    assign mem_wb_bubble_o = mem_flush_i;


endmodule