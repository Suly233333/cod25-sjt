module pplmanager (
    input wire clk_i,
    input wire rst_i,

    input wire if_stall_i,
    input wire if_flush_i,
    input wire id_stall_i,
    input wire id_flush_i,
    input wire exe_stall_i,
    input wire exe_flush_i,
    input wire mem_stall_i,
    input wire mem_flush_i,

    output logic if_stall_o,
    output logic mem_stall_o,
    
    output logic if_id_stall_o,
    output logic if_id_bubble_o,
    output logic id_exe_stall_o,
    output logic id_exe_bubble_o,
    output logic exe_mem_stall_o,
    output logic exe_mem_bubble_o,
    output logic mem_wb_stall_o,
    output logic mem_wb_bubble_o
);

always_comb begin
    if_stall_o = 1'b0;
    mem_stall_o = 1'b0;
    if_id_stall_o = 1'b0;
    if_id_bubble_o = 1'b0;
    id_exe_stall_o = 1'b0;
    id_exe_bubble_o = 1'b0;
    exe_mem_stall_o = 1'b0;
    exe_mem_bubble_o = 1'b0;
    mem_wb_stall_o = 1'b0;
    mem_wb_bubble_o = 1'b0;

    if(mem_stall_i)begin
        exe_mem_stall_o = 1'b1;
        mem_stall_o = 1'b1;
        mem_wb_stall_o = 1'b1;
        if_stall_o = 1'b1;
        if_id_stall_o = 1'b1;
        id_exe_stall_o = 1'b1;
    end else if (exe_flush_i)begin
        if_stall_o = if_stall_i;
        if_id_bubble_o = 1'b1;
        id_exe_bubble_o = 1'b1;
    end else if (id_stall_i)begin
        if_stall_o = 1'b1;
        if_id_stall_o = 1'b1;
        id_exe_bubble_o = 1'b1;
    end else if(if_stall_i)begin
        // if_stall_o = 1'b1;
        // if_id_stall_o = 1'b1;
        if_id_bubble_o = 1'b1;
    end
end
endmodule