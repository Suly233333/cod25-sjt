module IF_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] pc_jump_i,
    input wire jump_i,
    input wire if_stall_i,
    input wire icache_flush_i,      // FENCE.I cache flush signal
    input wire btb_flush_i,         // BTB flush signal

    // BTB 更新端口
    input wire btb_update_valid_i,  // BTB 更新有效
    input wire [31:0] btb_update_pc_i,      // 分支指令 PC
    input wire btb_actual_taken_i,  // 实际是否跳转
    input wire [31:0] btb_actual_target_i,  // 实际目标 PC

    output logic [31:0] pc_o,
    output logic [31:0] inst_o,
    output logic if_stall_o,
    output logic if_flush_o,
    output logic pred_jump_o,   // 预测跳转标志

    output logic wb_cyc_o,
    output logic wb_stb_o,
    input wire wb_ack_i,
    output logic [ADDR_WIDTH-1:0] wb_adr_o,
    output logic [DATA_WIDTH-1:0] wb_dat_o,
    input wire [DATA_WIDTH-1:0] wb_dat_i,
    output logic [DATA_WIDTH/8-1:0] wb_sel_o,
    output logic wb_we_o,
    output logic valid

);

logic [31:0] pc_next;
logic [31:0] pc_current;
logic [31:0] cache_inst;
logic cache_hit;
logic wb_req_interrupted; // Flag to track if WB request was interrupted/address changed
logic jump_reg;

// BTB prediction signals
logic [31:0] btb_pred_target;

// ICache instance
icache icache_inst (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .flush_i(icache_flush_i),
    .pc_i(pc_current),
    .inst_o(cache_inst),
    .hit_o(cache_hit),
    .fill_addr_i(wb_adr_o),
    .fill_data_i(wb_dat_i),
    .fill_valid_i(wb_ack_i && !wb_req_interrupted && !jump_reg)
);

// BTB instance
btb btb_inst (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .pc_i(pc_o),
    .pred_taken_o(pred_jump_o),
    .pred_target_o(btb_pred_target),
    .update_valid_i(btb_update_valid_i),
    .update_pc_i(btb_update_pc_i),
    .actual_taken_i(btb_actual_taken_i),
    .actual_target_i(btb_actual_target_i),
    .flush_i(btb_flush_i)
);

logic [31:0] next_pc;
logic wb_cyc_o_ff, wb_stb_o_ff, wb_ack_reg;
logic [ADDR_WIDTH-1:0] wb_addr_reg;

always_comb begin
    // Priority: jump (from EXE) > BTB prediction > sequential
    // 优先级: 从EXE的跳转 > BTB预测 > 顺序PC
    if (jump_i) begin
        // 来自 EXE 的跳转有最高优先级
        next_pc = pc_jump_i;
    end else if (pred_jump_o) begin
        // BTB 预测跳转
        next_pc = btb_pred_target;
    end else if (cache_hit) begin
        // 顺序执行
        next_pc = pc_next;
    end else begin
        next_pc = pc_current;
    end
    wb_cyc_o = wb_cyc_o_ff && !if_stall_i;
    wb_stb_o = wb_stb_o_ff && !if_stall_i;
    wb_adr_o = next_pc;
end

always_ff @ (posedge clk_i) begin
    if(rst_i)begin
        pc_next <= 32'h8000_0000;
        pc_current <= 32'h8000_0000;
        pc_o <= 32'h8000_0000;
        inst_o <= 32'b0;
        if_stall_o <= 0;
        if_flush_o <= 0;
        wb_cyc_o_ff <= 0;
        wb_stb_o_ff <= 0;
        wb_sel_o <= 4'b0000;
        wb_dat_o <= 32'b0;
        wb_we_o <= 1'b0;
        valid <= 1'b0;
        wb_ack_reg <= 1'b0;
        wb_addr_reg <= 32'h8000_0000;
        wb_req_interrupted <= 1'b0;
        jump_reg <= 1'b0;
    end else begin

        wb_addr_reg <= wb_adr_o;
        wb_ack_reg <= wb_ack_i;
        jump_reg <= jump_i;
        
        // Check for WB request interruption or address change during active cycle
        if (wb_cyc_o_ff && wb_stb_o_ff && !wb_ack_i && !wb_ack_reg) begin
            if (if_stall_i || (wb_adr_o != wb_addr_reg && wb_addr_reg != 0)) begin
                wb_req_interrupted <= 1'b1;
            end
        end

        if(!if_stall_i) begin
            if_stall_o <= 0;
            pc_current <= next_pc;
            pc_next <= next_pc + 4;
        end
        if(jump_i)begin
            // 来自 EXE 的确定跳转
            pc_o <= pc_jump_i;
            pc_current <= pc_jump_i;
            pc_next <= pc_jump_i + 4;
        end else if (if_stall_i) begin
            wb_cyc_o_ff <= 0;
            wb_stb_o_ff <= 0;
        end else if(cache_hit) begin
            // Cache hit - output cached instruction
            pc_o <= pc_current;
            inst_o <= cache_inst;
            valid <= 1'b1;
        end else if(wb_ack_i)begin
            // Cache miss and Wishbone data received
            if (wb_req_interrupted) begin
                // Data potentially corrupted due to interruption, retry
                wb_cyc_o_ff <= 1;
                wb_stb_o_ff <= 1;
                wb_we_o <= 0;
                wb_sel_o <= 4'b1111;
                if_stall_o <= 1;
                wb_req_interrupted <= 1'b0;
            end else begin
                pc_o <= pc_current;
                inst_o <= wb_dat_i;
                valid <= 1'b1;
            end
        end else begin
            // Cache miss and need to initiate Wishbone read
            wb_cyc_o_ff <= 1;
            wb_stb_o_ff <= 1;
            wb_we_o <= 0;
            wb_sel_o <= 4'b1111;
            if_stall_o <= 1;
        end
        if (!if_stall_i && valid && (!cache_hit || wb_ack_reg && wb_dat_i == cache_inst || pc_o == pc_current) || jump_i)
            valid <= 1'b0;
    end
end



endmodule


