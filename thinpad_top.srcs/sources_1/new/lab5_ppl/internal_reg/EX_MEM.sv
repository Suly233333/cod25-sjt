module ex_mem(
    input wire clk_i,
    input wire rst_i,

    input wire stall_i,
    input wire bubble_i,

    input wire [31:0] pc_i,
    input wire [31:0] alu_result_i,
    input wire [31:0] mem_addr_i,
    input wire [31:0] mem_data_i,
    input wire [31:0] inst_i,
    input wire [31:0] imm_i,
    input wire [4:0] rf_waddr_i,
    input wire [3:0] imm_type_i,
    input wire [3:0] instr_type_i,
    input wire [7:0] instr_code_i,
    input wire mem_en_i,
    input wire rf_wen_i,

    output logic [31:0] pc_o,
    output logic [31:0] alu_result_o,
    output logic [31:0] mem_addr_o,
    output logic [31:0] mem_data_o,
    output logic [31:0] inst_o,
    output logic [31:0] imm_o,
    output logic [4:0] rf_waddr_o,
    output logic [3:0] imm_type_o,
    output logic [3:0] instr_type_o,
    output logic [7:0] instr_code_o,
    output logic mem_en_o,
    output logic rf_wen_o

);

    always_ff @(posedge clk_i) begin
    if(rst_i) begin
        //reset logics
        pc_o <= 32'h8000_0000;
        inst_o <= 32'b0;
        alu_result_o <= 32'b0;
        mem_addr_o <= 32'b0;
        mem_data_o <= 32'b0;
        imm_o <= 32'b0;
        imm_type_o <= 4'b0;
        instr_type_o <= 4'b0;
        instr_code_o <= 8'b0;
        mem_en_o <= 0;
        rf_wen_o <= 0;
        rf_waddr_o <= 0;
    end else if(stall_i) begin
        //do nothing
    end else if(bubble_i) begin
        //change regs to bubble
        pc_o <= 32'b0;
        inst_o <= 32'h00000013;
        alu_result_o <= 32'b0;
        mem_addr_o <= 32'b0;
        mem_data_o <= 32'b0;
        imm_o <= 32'b0;
        imm_type_o <= 4'b0;
        instr_type_o <= 4'b0;
        instr_code_o <= 8'b0;
        mem_en_o <= 0;
        rf_wen_o <= 0;
        rf_waddr_o <= 0;
    end else begin
        //change regs to input
        pc_o <= pc_i;
        inst_o <= inst_i;
        alu_result_o <= alu_result_i;
        mem_addr_o <= mem_addr_i;
        mem_data_o <= mem_data_i;
        imm_o <= imm_i;
        imm_type_o <= imm_type_i;
        instr_type_o <= instr_type_i;
        instr_code_o <= instr_code_i;
        mem_en_o <= mem_en_i;
        rf_wen_o <= rf_wen_i;
        rf_waddr_o <= rf_waddr_i;
    end
end



endmodule