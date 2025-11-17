`include "../type.sv"

module ID (
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] pc_i,
    input wire [31:0] inst_i,

    input wire [4:0] exe_rf_waddr_i,
    input wire [4:0] mem_rf_waddr_i,
    input wire [4:0] wb_rf_waddr_i,
    input wire [4:0] mem_rf_waddr_o,

    output logic [31:0] pc_o,
    output logic [31:0] inst_o,

    output logic [4:0] rf_raddr_a_o,
    output logic [4:0] rf_raddr_b_o,
    output logic [4:0] rf_waddr_o,

    // Control signals generated in ID stage
    output logic [3:0] imm_type_o,       // Immediate type (NONE/I/S/B/U/J)
    output logic [3:0] alu_op_o,         // ALU operation
    output logic [3:0] instr_type_o,     // Instruction type (R/I/S/B/U/J)
    output logic [7:0] instr_code_o,     // Specific instruction code (LUI, ADDI, LB, LW, SB, SW, etc.)
    output logic use_rs2_o,              // Whether instruction uses rs2
    output logic mem_wen_o,              // Memory write enable
    output logic rf_wen_o,               // Register file write enable

    output logic id_stall_o,
    output logic id_flush_o

);

logic [6:0] opcode;
logic [2:0] funct3;
logic [4:0] rd, rs1, rs2;

always_comb begin
    pc_o = pc_i;
    inst_o = inst_i;

    opcode = inst_i[6:0];
    funct3 = inst_i[14:12];
    rd = inst_i[11:7];
    rs1 = inst_i[19:15];
    rs2 = inst_i[24:20];

    // Default values
    rf_raddr_a_o = 5'b0;
    rf_raddr_b_o = 5'b0;
    rf_waddr_o = 5'b0;
    imm_type_o = IMM_TYPE_NONE;
    alu_op_o = OP_NONE;
    instr_type_o = INSTR_TYPE_ERR;
    instr_code_o = INSTR_UNKNOWN;
    use_rs2_o = 1'b0;
    mem_wen_o = 1'b0;
    rf_wen_o = 1'b0;
    id_stall_o = 1'b0;
    id_flush_o = 1'b0;

    case (opcode)
        // ==================== Integer Arithmetic ====================
        7'b0110111: begin  // LUI - Load Upper Immediate
            imm_type_o = IMM_TYPE_U;
            instr_type_o = INSTR_TYPE_U;
            instr_code_o = INSTR_LUI;
            alu_op_o = OP_ADD;
            use_rs2_o = 1'b0;
            mem_wen_o = 1'b0;
            rf_wen_o = 1'b1;
            rf_raddr_a_o = 5'b0;
            rf_raddr_b_o = 5'b0;
            rf_waddr_o = rd;
        end

        7'b0010111: begin  // AUIPC - Add Upper Immediate to PC
            imm_type_o = IMM_TYPE_U;
            instr_type_o = INSTR_TYPE_U;
            instr_code_o = INSTR_AUIPC;
            alu_op_o = OP_ADD;
            use_rs2_o = 1'b0;
            mem_wen_o = 1'b0;
            rf_wen_o = 1'b1;
            rf_raddr_a_o = 5'b0;
            rf_raddr_b_o = 5'b0;
            rf_waddr_o = rd;
        end

        // ==================== Integer Immediate ====================
        7'b0010011: begin  // ADDI, SLTI, SLTIU, ANDI, ORI, XORI, SLLI, SRLI, SRAI
            imm_type_o = IMM_TYPE_I;
            instr_type_o = INSTR_TYPE_I;
            use_rs2_o = 1'b0;
            mem_wen_o = 1'b0;
            rf_wen_o = 1'b1;
            rf_raddr_a_o = rs1;
            rf_raddr_b_o = 5'b0;
            rf_waddr_o = rd;
            case (funct3)
                3'b000: begin  // ADDI
                    alu_op_o = OP_ADD;
                    instr_code_o = INSTR_ADDI;
                end
                3'b010: begin  // SLTI - Set Less Than Immediate (signed)
                    alu_op_o = OP_SLT;
                    instr_code_o = INSTR_SLTI;
                end
                3'b011: begin  // SLTIU - Set Less Than Immediate Unsigned
                    alu_op_o = OP_SLTU;
                    instr_code_o = INSTR_SLTIU;
                end
                3'b100: begin  // XORI
                    alu_op_o = OP_XOR;
                    instr_code_o = INSTR_XORI;
                end
                3'b110: begin  // ORI
                    alu_op_o = OP_OR;
                    instr_code_o = INSTR_ORI;
                end
                3'b111: begin  // ANDI
                    alu_op_o = OP_AND;
                    instr_code_o = INSTR_ANDI;
                end
                3'b001: begin  // SLLI - Shift Left Logical Immediate
                    alu_op_o = OP_SLL;
                    instr_code_o = INSTR_SLLI;
                end
                3'b101: begin  // SRLI / SRAI - Shift Right (Logical/Arithmetic) Immediate
                    if (inst_i[31:25] == 7'b0100000)
                        begin  // SRAI
                            alu_op_o = OP_SRA;
                            instr_code_o = INSTR_SRAI;
                        end
                    else
                        begin  // SRLI
                            alu_op_o = OP_SRL;
                            instr_code_o = INSTR_SRLI;
                        end
                end
                default: alu_op_o = OP_NONE;
            endcase
        end

        // ==================== Integer Register ====================
        7'b0110011: begin  // ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
            imm_type_o = IMM_TYPE_NONE;
            instr_type_o = INSTR_TYPE_R;
            use_rs2_o = 1'b1;
            mem_wen_o = 1'b0;
            rf_wen_o = 1'b1;
            rf_raddr_a_o = rs1;
            rf_raddr_b_o = rs2;
            rf_waddr_o = rd;
            case (funct3)
                3'b000: begin
                    if (inst_i[31:25] == 7'b0100000)
                        begin  // SUB
                            alu_op_o = OP_SUB;
                            instr_code_o = INSTR_SUB;
                        end
                    else
                        begin  // ADD
                            alu_op_o = OP_ADD;
                            instr_code_o = INSTR_ADD;
                        end
                end
                3'b001: begin  // SLL
                    alu_op_o = OP_SLL;
                    instr_code_o = INSTR_SLL;
                end
                3'b010: begin  // SLT - Set Less Than (signed)
                    alu_op_o = OP_SLT;
                    instr_code_o = INSTR_SLT;
                end
                3'b011: begin  // SLTU - Set Less Than Unsigned
                    alu_op_o = OP_SLTU;
                    instr_code_o = INSTR_SLTU;
                end
                3'b100: begin  // XOR
                    alu_op_o = OP_XOR;
                    instr_code_o = INSTR_XOR;
                end
                3'b101: begin  // SRL / SRA
                    if (inst_i[31:25] == 7'b0100000)
                        begin  // SRA
                            alu_op_o = OP_SRA;
                            instr_code_o = INSTR_SRA;
                        end
                    else
                        begin  // SRL
                            alu_op_o = OP_SRL;
                            instr_code_o = INSTR_SRL;
                        end
                end
                3'b110: begin  // OR
                    alu_op_o = OP_OR;
                    instr_code_o = INSTR_OR;
                end
                3'b111: begin  // AND
                    alu_op_o = OP_AND;
                    instr_code_o = INSTR_AND;
                end
                default: alu_op_o = OP_NONE;
            endcase
        end

        // ==================== Loads ====================
        7'b0000011: begin  // LB, LH, LW, LBU, LHU
            imm_type_o = IMM_TYPE_I;
            instr_type_o = INSTR_TYPE_I;
            alu_op_o = OP_ADD;
            use_rs2_o = 1'b0;
            mem_wen_o = 1'b1;
            rf_wen_o = 1'b1;
            rf_raddr_a_o = rs1;
            rf_raddr_b_o = 5'b0;
            rf_waddr_o = rd;
            case (funct3)
                3'b000: instr_code_o = INSTR_LB;    // LB - Load Byte (signed)
                3'b001: instr_code_o = INSTR_LH;    // LH - Load Half-word (signed)
                3'b010: instr_code_o = INSTR_LW;    // LW - Load Word
                3'b100: instr_code_o = INSTR_LBU;   // LBU - Load Byte Unsigned
                3'b101: instr_code_o = INSTR_LHU;   // LHU - Load Half-word Unsigned
                default: instr_code_o = INSTR_UNKNOWN;
            endcase
        end

        // ==================== Stores ====================
        7'b0100011: begin  // SB, SH, SW
            imm_type_o = IMM_TYPE_S;
            instr_type_o = INSTR_TYPE_S;
            alu_op_o = OP_ADD;
            use_rs2_o = 1'b1;
            mem_wen_o = 1'b1;
            rf_wen_o = 1'b0;
            rf_raddr_a_o = rs1;
            rf_raddr_b_o = rs2;
            rf_waddr_o = 5'b0;
            case (funct3)
                3'b000: instr_code_o = INSTR_SB;   // SB - Store Byte
                3'b001: instr_code_o = INSTR_SH;   // SH - Store Half-word
                3'b010: instr_code_o = INSTR_SW;   // SW - Store Word
                default: instr_code_o = INSTR_UNKNOWN;
            endcase
        end

        // ==================== Branches ====================
        7'b1100011: begin  // BEQ, BNE, BLT, BGE, BLTU, BGEU
            imm_type_o = IMM_TYPE_B;
            instr_type_o = INSTR_TYPE_B;
            use_rs2_o = 1'b1;
            mem_wen_o = 1'b0;
            rf_wen_o = 1'b0;
            rf_raddr_a_o = rs1;
            rf_raddr_b_o = rs2;
            rf_waddr_o = 5'b0;
            case (funct3)
                3'b000: begin  // BEQ
                    alu_op_o = OP_SUB;
                    instr_code_o = INSTR_BEQ;
                end
                3'b001: begin  // BNE
                    alu_op_o = OP_SUB;
                    instr_code_o = INSTR_BNE;
                end
                3'b100: begin  // BLT
                    alu_op_o = OP_SLT;
                    instr_code_o = INSTR_BLT;
                end
                3'b101: begin  // BGE
                    alu_op_o = OP_SLT;
                    instr_code_o = INSTR_BGE;
                end
                3'b110: begin  // BLTU
                    alu_op_o = OP_SLTU;
                    instr_code_o = INSTR_BLTU;
                end
                3'b111: begin  // BGEU
                    alu_op_o = OP_SLTU;
                    instr_code_o = INSTR_BGEU;
                end
                default: alu_op_o = OP_NONE;
            endcase
        end

        // ==================== Jumps ====================
        7'b1101111: begin  // JAL - Jump and Link
            imm_type_o = IMM_TYPE_J;
            instr_type_o = INSTR_TYPE_J;
            alu_op_o = OP_ADD;
            use_rs2_o = 1'b0;
            mem_wen_o = 1'b0;
            rf_wen_o = 1'b1;  // Write return address to rd
            rf_raddr_a_o = 5'b0;
            rf_raddr_b_o = 5'b0;
            rf_waddr_o = rd;
            instr_code_o = INSTR_JAL;
        end

        7'b1100111: begin  // JALR - Jump and Link Register
            imm_type_o = IMM_TYPE_I;
            instr_type_o = INSTR_TYPE_I;
            alu_op_o = OP_ADD;
            use_rs2_o = 1'b0;
            mem_wen_o = 1'b0;
            rf_wen_o = 1'b1;  // Write return address to rd
            rf_raddr_a_o = rs1;
            rf_raddr_b_o = 5'b0;
            rf_waddr_o = rd;
            instr_code_o = INSTR_JALR;
        end

        default: begin
            imm_type_o = IMM_TYPE_NONE;
            instr_type_o = INSTR_TYPE_ERR;
            alu_op_o = OP_NONE;
            use_rs2_o = 1'b0;
            mem_wen_o = 1'b0;
            rf_wen_o = 1'b0;
        end
    endcase

    // Data hazard detection
    id_stall_o = (exe_rf_waddr_i && (rs1 == exe_rf_waddr_i || (use_rs2_o && rs2 == exe_rf_waddr_i)))? 1'b1 :
                (mem_rf_waddr_i && (rs1 == mem_rf_waddr_i || (use_rs2_o && rs2 == mem_rf_waddr_i)))? 1'b1 :
                (wb_rf_waddr_i && (rs1 == wb_rf_waddr_i || (use_rs2_o && rs2 == wb_rf_waddr_i)))? 1'b1 :
                (mem_rf_waddr_o && (rs1 == mem_rf_waddr_o || (use_rs2_o && rs2 == mem_rf_waddr_o)))? 1'b1 : 1'b0;

    id_flush_o = 1'b0;
end



endmodule

