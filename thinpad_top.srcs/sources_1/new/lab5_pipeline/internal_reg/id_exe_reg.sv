module id_exe (
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] pc_i,
    input wire [31:0] inst_i,
    input wire [31:0] rf_rdata_a_i,
    input wire [31:0] rf_rdata_b_i,
    input wire [2:0] imm_type_i,
    input wire [4:0]  rf_waddr_i,
    input wire        rf_we_i,
    input wire        use_rs2_i,
    input wire [3:0]  alu_op_i,
    input wire [3:0]  instr_type_i,
    input wire        mem_en_i,

    output logic [31:0] pc_o,
    output logic [31:0] inst_o,
    output logic [31:0] rf_rdata_a_o,
    output logic [31:0] rf_rdata_b_o,
    output logic [2:0] imm_type_o,
    output logic [4:0]  rf_waddr_o,
    output logic        rf_we_o,
    output logic        use_rs2_o,
    output logic [3:0]  alu_op_o,
    output logic [3:0]  instr_type_o,
    output logic        mem_en_o,

    input wire stall_i,
    input wire bubble_i

);

always_ff @(posedge clk_i) begin
    if(rst_i) begin
        //reset logics
        pc_o <= 32'h8000_0000;
        inst_o <= 32'b0;
        rf_rdata_a_o <= 32'b0;
        rf_rdata_b_o <= 32'b0;
        imm_type_o <= 3'b1;
        rf_waddr_o <= 5'b0;
        rf_we_o <= 1'b0;
        use_rs2_o <= 1'b0;
        alu_op_o <= 4'b1;
        instr_type_o <= 4'b0;
        mem_en_o <= 1'b0;
    end else if(stall_i) begin
        //do nothing
    end else if(bubble_i) begin
        //change regs to bubble
        pc_o <= 32'b0;
        inst_o <= 32'h00000013;
        rf_rdata_a_o <= 32'b0;
        rf_rdata_b_o <= 32'b0;
        imm_type_o <= 3'b1;
        rf_waddr_o <= 5'b0;
        rf_we_o <= 1'b0;
        use_rs2_o <= 1'b0;
        alu_op_o <= 4'b1;
        instr_type_o <= 4'b0;
        mem_en_o <= 1'b0;
    end else begin
        //change regs to input
        pc_o <= pc_i;
        inst_o <= inst_i;
        rf_rdata_a_o <= rf_rdata_a_i;
        rf_rdata_b_o <= rf_rdata_b_i;
        imm_type_o <= imm_type_i;
        rf_waddr_o <= rf_waddr_i;
        rf_we_o <= rf_we_i;
        use_rs2_o <= use_rs2_i;
        alu_op_o <= alu_op_i;
        instr_type_o <= instr_type_i;
        mem_en_o <= mem_en_i;
    end
end
endmodule