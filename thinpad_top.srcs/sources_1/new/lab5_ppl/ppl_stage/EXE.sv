module EXE(
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] pc_i,
    input wire [31:0] inst_i,
    input wire [31:0] rf_rdata_a_i,
    input wire [31:0] rf_rdata_b_i,
    input wire [4:0] rf_waddr_i,
    input wire [2:0] imm_type_i,
    input wire [3:0] alu_op_i,
    input wire [3:0] instr_type_i,
    input wire use_rs2_i,
    input wire rf_wen_i,
    input wire mem_wen_i,

    output logic [31:0] pc_o,
    output logic [31:0] inst_o,
    output logic [31:0] imm_o,
    output logic mem_en_o,
    output logic rf_wen_o,
    output logic [31:0] mem_data_o,
    output logic [31:0] mem_addr_o,
    output logic [31:0] alu_a_o,
    output logic [31:0] alu_b_o,
    output logic [3:0] alu_op_o,
    output logic exe_stall_o,
    output logic exe_flush_o,
    output logic [4:0] rf_waddr_o,
    output logic jump_o,
    output logic [31:0] pc_jump_o

);

// Immediate type encoding (match ID.sv)
typedef enum logic [2:0] {
    IMM_TYPE_NONE = 3'b000,
    IMM_TYPE_I = 3'b001,
    IMM_TYPE_S = 3'b010,
    IMM_TYPE_B = 3'b011,
    IMM_TYPE_U = 3'b100
} imm_type_t;

// Instruction type encoding (match ID.sv)
typedef enum logic [3:0] {
    INSTR_TYPE_ERR = 4'b0000,
    INSTR_TYPE_R = 4'b0001,
    INSTR_TYPE_I = 4'b0010,
    INSTR_TYPE_S = 4'b0011,
    INSTR_TYPE_B = 4'b0100,
    INSTR_TYPE_U = 4'b0101
} instr_type_t;

logic [31:0] imm_I, imm_S, imm_B, imm_U;
logic [31:0] imm_generated;

// Generate immediates based on imm_type
always_comb begin
    imm_I = {{20{inst_i[31]}}, inst_i[31:20]};
    imm_S = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
    imm_B = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
    imm_U = {inst_i[31:12], {12{1'b0}}};

    case (imm_type_i)
        IMM_TYPE_I: imm_generated = imm_I;
        IMM_TYPE_S: imm_generated = imm_S;
        IMM_TYPE_B: imm_generated = imm_B;
        IMM_TYPE_U: imm_generated = imm_U;
        default: imm_generated = 32'b0;
    endcase
end

always_comb begin
    pc_o = pc_i;
    inst_o = inst_i;
    imm_o = imm_generated;
    mem_en_o = mem_wen_i;
    rf_wen_o = rf_wen_i;
    mem_data_o = 32'b0;
    mem_addr_o = 32'b0;
    exe_flush_o = 1'b0;
    jump_o = 1'b0;
    pc_jump_o = 32'b0;
    rf_waddr_o = rf_waddr_i;
    exe_stall_o = 1'b0;
    alu_op_o = alu_op_i;

    case (instr_type_i)
        INSTR_TYPE_R: begin
            // R-type: ALU operation with two register operands
            alu_a_o = rf_rdata_a_i;
            alu_b_o = rf_rdata_b_i;
        end

        INSTR_TYPE_I: begin
            // I-type: ALU operation or Load
            alu_a_o = rf_rdata_a_i;
            alu_b_o = imm_generated;

            // For Load instructions, calculate address
            if (mem_wen_i) begin
                mem_addr_o = rf_rdata_a_i + $signed(imm_generated);
            end
        end

        INSTR_TYPE_S: begin
            // S-type: Store instruction
            alu_a_o = rf_rdata_a_i;
            alu_b_o = imm_generated;
            mem_addr_o = rf_rdata_a_i + $signed(imm_generated);

            // Prepare store data based on funct3
            if (inst_i[14:12] == 3'b000) begin  // SB
                mem_data_o = {24'b0, rf_rdata_b_i[7:0]};
            end else begin  // SW
                mem_data_o = rf_rdata_b_i;
            end
        end

        INSTR_TYPE_B: begin
            // B-type: Branch instruction
            alu_a_o = rf_rdata_a_i;
            alu_b_o = rf_rdata_b_i;

            // Check if branch condition is met (assuming BEQ)
            if (rf_rdata_a_i == rf_rdata_b_i) begin
                jump_o = 1'b1;
                pc_jump_o = pc_i + $signed(imm_generated);
                exe_flush_o = 1'b1;
            end
        end

        INSTR_TYPE_U: begin
            // U-type: Load Upper Immediate
            alu_a_o = imm_generated;
            alu_b_o = 32'b0;
        end

        default: begin
            alu_a_o = 32'b0;
            alu_b_o = 32'b0;
        end
    endcase
end



endmodule