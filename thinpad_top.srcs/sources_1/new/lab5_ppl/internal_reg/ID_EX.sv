module id_ex (
    input wire clk_i,
    input wire rst_i,

    input wire stall_i,
    input wire bubble_i,

    input wire [31:0] pc_i,
    input wire [31:0] inst_i,
    input wire [31:0] rf_rdata_a_i,
    input wire [31:0] rf_rdata_b_i,
    input wire [4:0] rf_waddr_i,
    input wire [3:0] imm_type_i,
    input wire [3:0] alu_op_i,
    input wire [3:0] instr_type_i,
    input wire [7:0] instr_code_i,
    input wire use_rs2_i,
    input wire rf_wen_i,
    input wire mem_wen_i,

    output logic [31:0] pc_o,
    output logic [31:0] inst_o,
    output logic [31:0] rf_rdata_a_o,
    output logic [31:0] rf_rdata_b_o,
    output logic [4:0] rf_waddr_o,
    output logic [3:0] imm_type_o,
    output logic [3:0] alu_op_o,
    output logic [3:0] instr_type_o,
    output logic [7:0] instr_code_o,
    output logic use_rs2_o,
    output logic rf_wen_o,
    output logic mem_wen_o
);

always_ff @(posedge clk_i) begin
    if(rst_i) begin
        //reset logics
        pc_o <= 32'h8000_0000;
        inst_o <= 32'b0;
        rf_rdata_a_o <= 32'b0;
        rf_rdata_b_o <= 32'b0;
        rf_waddr_o <= 5'b0;
        imm_type_o <= 4'b0;
        alu_op_o <= 4'b0;
        instr_type_o <= 4'b0;
        instr_code_o <= 8'b0;
        use_rs2_o <= 1'b0;
        rf_wen_o <= 1'b0;
        mem_wen_o <= 1'b0;
    end else if(stall_i) begin
        //do nothing
    end else if(bubble_i) begin
        //change regs to bubble
        pc_o <= 32'b0;
        inst_o <= 32'h00000013;
        rf_rdata_a_o <= 32'b0;
        rf_rdata_b_o <= 32'b0;
        rf_waddr_o <= 5'b0;
        imm_type_o <= 4'b0;
        alu_op_o <= 4'b0;
        instr_type_o <= 4'b0;
        instr_code_o <= 8'b0;
        use_rs2_o <= 1'b0;
        rf_wen_o <= 1'b0;
        mem_wen_o <= 1'b0;
    end else begin
        //change regs to input
        pc_o <= pc_i;
        inst_o <= inst_i;
        rf_rdata_a_o <= rf_rdata_a_i;
        rf_rdata_b_o <= rf_rdata_b_i;
        rf_waddr_o <= rf_waddr_i;
        imm_type_o <= imm_type_i;
        alu_op_o <= alu_op_i;
        instr_type_o <= instr_type_i;
        instr_code_o <= instr_code_i;
        use_rs2_o <= use_rs2_i;
        rf_wen_o <= rf_wen_i;
        mem_wen_o <= mem_wen_i;
    end
end
endmodule