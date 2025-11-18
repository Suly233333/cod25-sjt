`include "../type.sv"

module EXE(
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] pc_i,
    input wire [31:0] inst_i,
    input wire [31:0] rf_rdata_a_i,
    input wire [31:0] rf_rdata_b_i,
    input wire [4:0] rf_waddr_i,
    input wire [3:0] imm_type_i,
    input wire [4:0] alu_op_i,
    input wire [3:0] instr_type_i,
    input wire [7:0] instr_code_i,
    input wire use_rs2_i,
    input wire rf_wen_i,
    input wire mem_en_i,

    output logic [31:0] pc_o,
    output logic [31:0] inst_o,
    output logic [31:0] imm_o,
    output logic [7:0] instr_code_o,
    output logic mem_en_o,
    output logic rf_wen_o,
    output logic [31:0] mem_data_o,
    output logic [31:0] mem_addr_o,
    output logic [31:0] alu_a_o,
    output logic [31:0] alu_b_o,
    output logic [4:0] alu_op_o,
    output logic exe_stall_o,
    output logic exe_flush_o,
    output logic [4:0] rf_waddr_o,
    output logic jump_o,
    output logic [31:0] pc_jump_o

);

logic [31:0] imm_I, imm_S, imm_B, imm_U, imm_J;
logic [31:0] imm_generated;

// Generate immediates based on imm_type
always_comb begin
    imm_I = {{20{inst_i[31]}}, inst_i[31:20]};
    imm_S = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
    imm_B = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
    imm_U = {inst_i[31:12], {12{1'b0}}};
    imm_J = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};

    case (imm_type_i)
        IMM_TYPE_I: imm_generated = imm_I;
        IMM_TYPE_S: imm_generated = imm_S;
        IMM_TYPE_B: imm_generated = imm_B;
        IMM_TYPE_U: imm_generated = imm_U;
        IMM_TYPE_J: imm_generated = imm_J;
        default: imm_generated = 32'b0;
    endcase
end

always_comb begin
    pc_o = pc_i;
    inst_o = inst_i;
    imm_o = imm_generated;
    instr_code_o = instr_code_i;
    mem_en_o = mem_en_i;
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
            // ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
            alu_a_o = rf_rdata_a_i;
            alu_b_o = rf_rdata_b_i;
        end

        INSTR_TYPE_I: begin
            // I-type: ALU operation with immediate or Load/Jump
            alu_a_o = rf_rdata_a_i;

            // Distinguish between arithmetic/logic ops and Load/JALR
            if (mem_en_i) begin
                // Load instructions: LB, LH, LW, LBU, LHU
                alu_b_o = imm_generated;
                mem_addr_o = rf_rdata_a_i + $signed(imm_generated);
            end else if (instr_code_i == INSTR_JALR) begin
                // JALR - Jump and Link Register
                // Write rd = pc + 4, and jump to (rs1 + imm) & ~1
                alu_a_o = pc_i;
                alu_b_o = 32'd4;
                pc_jump_o = (rf_rdata_a_i + $signed(imm_generated)) & 32'hFFFFFFFE;  // Clear LSB
                jump_o = 1'b1;
                exe_flush_o = 1'b1;
            end else begin
                // Arithmetic/Logic immediate instructions: ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI
                alu_b_o = imm_generated;
            end
        end

        INSTR_TYPE_S: begin
            // S-type: Store instruction
            // SB, SH, SW
            alu_a_o = rf_rdata_a_i;
            alu_b_o = imm_generated;
            mem_addr_o = rf_rdata_a_i + $signed(imm_generated);

            // Prepare store data based on instr_code
            case (instr_code_i)
                INSTR_SB: mem_data_o = {24'b0, rf_rdata_b_i[7:0]};               // SB - Store Byte
                INSTR_SH: mem_data_o = {16'b0, rf_rdata_b_i[15:0]};             // SH - Store Half-word
                INSTR_SW: mem_data_o = rf_rdata_b_i;                            // SW - Store Word
                default: mem_data_o = 32'b0;
            endcase
        end

        INSTR_TYPE_B: begin
            // B-type: Branch instruction
            // BEQ, BNE, BLT, BGE, BLTU, BGEU
            alu_a_o = rf_rdata_a_i;
            alu_b_o = rf_rdata_b_i;

            // Branch condition evaluation
            case (instr_code_i)
                INSTR_BEQ: begin
                    if (rf_rdata_a_i == rf_rdata_b_i) begin
                        jump_o = 1'b1;
                        pc_jump_o = pc_i + $signed(imm_generated);
                        exe_flush_o = 1'b1;
                    end
                end
                INSTR_BNE: begin
                    if (rf_rdata_a_i != rf_rdata_b_i) begin
                        jump_o = 1'b1;
                        pc_jump_o = pc_i + $signed(imm_generated);
                        exe_flush_o = 1'b1;
                    end
                end
                INSTR_BLT: begin
                    if ($signed(rf_rdata_a_i) < $signed(rf_rdata_b_i)) begin
                        jump_o = 1'b1;
                        pc_jump_o = pc_i + $signed(imm_generated);
                        exe_flush_o = 1'b1;
                    end
                end
                INSTR_BGE: begin
                    if ($signed(rf_rdata_a_i) >= $signed(rf_rdata_b_i)) begin
                        jump_o = 1'b1;
                        pc_jump_o = pc_i + $signed(imm_generated);
                        exe_flush_o = 1'b1;
                    end
                end
                INSTR_BLTU: begin
                    if (rf_rdata_a_i < rf_rdata_b_i) begin
                        jump_o = 1'b1;
                        pc_jump_o = pc_i + $signed(imm_generated);
                        exe_flush_o = 1'b1;
                    end
                end
                INSTR_BGEU: begin
                    if (rf_rdata_a_i >= rf_rdata_b_i) begin
                        jump_o = 1'b1;
                        pc_jump_o = pc_i + $signed(imm_generated);
                        exe_flush_o = 1'b1;
                    end
                end
                default: begin
                    jump_o = 1'b0;
                    exe_flush_o = 1'b0;
                end
            endcase
        end

        INSTR_TYPE_U: begin
            // U-type: Load Upper Immediate
            // LUI, AUIPC
            case (instr_code_i)
                INSTR_LUI: begin
                    alu_a_o = imm_generated;
                    alu_b_o = 32'b0;
                end
                INSTR_AUIPC: begin
                    alu_a_o = pc_i;
                    alu_b_o = imm_generated;
                end
                default: begin
                    alu_a_o = imm_generated;
                    alu_b_o = 32'b0;
                end
            endcase
        end

        INSTR_TYPE_J: begin
            // J-type: Jump and Link
            // JAL
            alu_a_o = pc_i;
            alu_b_o = 32'd4;  // PC + 4 will be returned as ALU result for storing in rd
            pc_jump_o = pc_i + $signed(imm_generated);
            jump_o = 1'b1;
            exe_flush_o = 1'b1;
        end

        default: begin
            alu_a_o = 32'b0;
            alu_b_o = 32'b0;
        end
    endcase
end


endmodule