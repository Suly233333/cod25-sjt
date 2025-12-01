// Branch Target Buffer (BTB) Module
// 直接映射 BTB，用于分支预测
// BTB 大小: 64 条目 (256 字节)
// 索引方式: PC[7:2] (6 位)
// 内容: 饱和计数器 + 预测 PC

module btb #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BTB_SIZE = 64        // 64 entries
) (
    input wire clk_i,
    input wire rst_i,

    // 查询端口 (组合逻辑)
    input wire [ADDR_WIDTH-1:0] pc_i,
    output logic pred_taken_o,     // 分支预测: 是否跳转
    output logic [ADDR_WIDTH-1:0] pred_target_o,  // 预测的目标 PC

    // 更新端口 (同步)
    input wire update_valid_i,     // 更新有效
    input wire [ADDR_WIDTH-1:0] update_pc_i,      // 分支指令 PC
    input wire actual_taken_i,     // 实际是否跳转
    input wire [ADDR_WIDTH-1:0] actual_target_i,  // 实际目标 PC
    
    // 刷新信号
    input wire flush_i             // 清空 BTB (FENCE.I)
);

    // BTB 表项结构
    // [31:0] target_pc - 跳转目标 PC
    // [1:0] saturating_counter - 2-bit 饱和计数器
    //       00: 强不跳转 (WNT - Weakly Not Taken)
    //       01: 弱不跳转
    //       10: 弱跳转 (WT - Weakly Taken)
    //       11: 强跳转 (SNT - Strongly Taken)
    // [0] valid - 条目有效位
    
    typedef struct packed {
        logic [ADDR_WIDTH-1:0] target_pc;
        logic [1:0]  sat_counter;    // 饱和计数器: 00=WNT, 01=weak_NT, 10=weak_T, 11=ST
        logic        valid;
    } btb_entry_t;
    
    // btb_entry_t btb_table [BTB_SIZE-1:0];   // 错
    btb_entry_t btb_table [BTB_SIZE];   // 对
    
    // 从 PC 计算 BTB 索引 (直接映射)
    wire [5:0] query_index = pc_i[7:2];
    wire [5:0] update_index = update_pc_i[7:2];

    always_comb begin
        // 预测: 计数器 >= 10 (10 或 11) 表示预测跳转
        pred_taken_o = btb_table[query_index].valid && (btb_table[query_index].sat_counter[1] == 1'b1);
        pred_target_o = btb_table[query_index].target_pc;
    end
    
    // 更新逻辑 (同步)
    always_ff @ (posedge clk_i) begin
        if (rst_i) begin
            // 初始化所有条目无效
            for (int i = 0; i < BTB_SIZE; i++) begin
                btb_table[i].valid <= 1'b0;
                btb_table[i].target_pc <= 32'b0;
                btb_table[i].sat_counter <= 2'b00;
            end
        end else if (flush_i) begin
            // 刷新所有条目 (FENCE.I)
            for (int i = 0; i < BTB_SIZE; i++) begin
                btb_table[i].valid <= 1'b0;
                btb_table[i].target_pc <= 32'b0;
                btb_table[i].sat_counter <= 2'b00;
            end
        end else if (update_valid_i) begin
            // 如果是新条目或地址不同，先无效化
            if ((!btb_table[update_index].valid || btb_table[update_index].target_pc != actual_target_i)) begin
                btb_table[update_index].valid <= 1'b1;
                btb_table[update_index].target_pc <= actual_target_i;
            end
            
            // 更新饱和计数器
            // 饱和计数器状态转移:
            //   00 (WNT)     -> not_taken: 00 | taken: 01
            //   01 (weak_NT) -> not_taken: 00 | taken: 10
            //   10 (weak_T)  -> not_taken: 01 | taken: 11
            //   11 (ST)      -> not_taken: 10 | taken: 11
            
            case ({btb_table[update_index].sat_counter, actual_taken_i})
                {2'b00, 1'b0}: btb_table[update_index].sat_counter <= 2'b00;  // WNT, not_taken -> WNT
                {2'b00, 1'b1}: btb_table[update_index].sat_counter <= 2'b01;  // WNT, taken -> weak_NT
                {2'b01, 1'b0}: btb_table[update_index].sat_counter <= 2'b00;  // weak_NT, not_taken -> WNT
                {2'b01, 1'b1}: btb_table[update_index].sat_counter <= 2'b10;  // weak_NT, taken -> weak_T
                {2'b10, 1'b0}: btb_table[update_index].sat_counter <= 2'b01;  // weak_T, not_taken -> weak_NT
                {2'b10, 1'b1}: btb_table[update_index].sat_counter <= 2'b11;  // weak_T, taken -> ST
                {2'b11, 1'b0}: btb_table[update_index].sat_counter <= 2'b10;  // ST, not_taken -> weak_T
                {2'b11, 1'b1}: btb_table[update_index].sat_counter <= 2'b11;  // ST, taken -> ST
                default: btb_table[update_index].sat_counter <= 2'b00;
            endcase
        end
    end

endmodule
