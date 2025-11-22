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

    output logic [31:0] pc_o,
    output logic [31:0] inst_o,
    output logic if_stall_o,
    output logic if_flush_o,

    output reg wb_cyc_o,
    output reg wb_stb_o,
    input wire wb_ack_i,
    output logic [ADDR_WIDTH-1:0] wb_adr_o,
    output logic [DATA_WIDTH-1:0] wb_dat_o,
    input wire [DATA_WIDTH-1:0] wb_dat_i,
    output logic [DATA_WIDTH/8-1:0] wb_sel_o,
    output logic wb_we_o,
    output logic valid

);

typedef enum logic [1:0] {
    ST_IDLE = 0,
    ST_READ = 1

} state_t;

logic [31:0] pc_next, pc_branch_reg;
logic branch_reg;
logic [31:0] pc_current;
logic [31:0] cache_inst;
logic cache_hit;

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
    .fill_valid_i(wb_ack_i)
);

state_t state;

always_ff @ (posedge clk_i) begin
    if(rst_i)begin
        pc_next <= 32'h8000_0000;
        pc_current <= 32'b0;
        pc_o <= 32'h8000_0000;
        inst_o <= 32'b0;
        if_stall_o <= 0;
        if_flush_o <= 0;
        state <= ST_IDLE;
        wb_cyc_o <= 0;
        wb_stb_o <= 0;
        wb_sel_o <= 4'b0000;
        wb_dat_o <= 32'b0;
        branch_reg <= 0;
        pc_branch_reg <= 32'h8000_0000;
        wb_adr_o <= 32'b0;
        wb_we_o <= 1'b0;
        valid <= 1'b0;

    end else begin
        case(state)
            ST_IDLE: begin
                if(!if_stall_i)begin
                    logic [31:0] next_pc;
                    next_pc = branch_reg ? pc_branch_reg : jump_i ? pc_jump_i : pc_next;
                    
                    // Try to read from cache for next_pc
                    // But we can't check cache_hit directly here since pc_i is combinational
                    // We need to latch next_pc first, then check cache on it
                    pc_current <= next_pc;
                    pc_next <= branch_reg ? pc_branch_reg + 4 : jump_i ? pc_jump_i + 4 : pc_next + 4;
                    branch_reg <= 1'b0;
                    
                    // Go to ST_READ to check if cache_hit and fetch if miss
                    state <= ST_READ;
                    wb_adr_o <= next_pc;
                    if_stall_o <= 1;
                end
            end
            ST_READ: begin
                if(jump_i)begin
                    branch_reg <= jump_i;
                    pc_branch_reg <= pc_jump_i;
                end
                
                // Now we can check cache_hit on the current pc_current
                if(cache_hit) begin
                    // Cache hit - output cached instruction
                    state <= ST_IDLE;
                    if_stall_o <= 0;
                    if_flush_o <= 0;
                    pc_o <= pc_current;
                    inst_o <= cache_inst;
                    valid <= (jump_i && pc_current != pc_jump_i) ? 1'b0 : 
                             (branch_reg && pc_current != pc_branch_reg) ? 1'b0 : 1'b1;
                    wb_cyc_o <= 0;
                    wb_stb_o <= 0;
                    wb_we_o <= 0;
                end else if(wb_ack_i == 1)begin
                    // Cache miss and Wishbone data received
                    // Cache will automatically store this via fill port
                    wb_cyc_o <= 0;
                    wb_stb_o <= 0;
                    wb_we_o <= 0;
                    state <= ST_IDLE;
                    if_stall_o <= 0;
                    if_flush_o <= 0;
                    pc_o <= pc_current;
                    inst_o <= wb_dat_i;
                    valid <= (jump_i && pc_current != pc_jump_i) ? 1'b0 : 
                             (branch_reg && pc_current != pc_branch_reg) ? 1'b0 : 1'b1;
                end else if(!wb_cyc_o) begin
                    // Cache miss and need to initiate Wishbone read
                    wb_cyc_o <= 1;
                    wb_stb_o <= 1;
                    wb_we_o <= 0;
                    wb_sel_o <= 4'b1111;
                end
            end
        endcase     
    end
end



endmodule


