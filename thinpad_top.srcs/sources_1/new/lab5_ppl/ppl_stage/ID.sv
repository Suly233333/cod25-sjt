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
    output logic [2:0] imm_type_o,       // Immediate type (NONE/I/S/B/U)
    output logic [3:0] alu_op_o,         // ALU operation
    output logic [3:0] instr_type_o,     // Instruction type (R/I/S/B/U)
    output logic [7:0] instr_code_o,     // Specific instruction code (LUI, ADDI, LB, LW, SB, SW, etc.)
    output logic use_rs2_o,              // Whether instruction uses rs2
    output logic mem_wen_o,              // Memory write enable
    output logic rf_wen_o,               // Register file write enable

    output logic id_stall_o,
    output logic id_flush_o

);

// Immediate type encoding
typedef enum logic [2:0] {
    IMM_TYPE_NONE = 3'b000,
    IMM_TYPE_I = 3'b001,
    IMM_TYPE_S = 3'b010,
    IMM_TYPE_B = 3'b011,
    IMM_TYPE_U = 3'b100
} imm_type_t;

// Instruction type encoding
typedef enum logic [3:0] {
    INSTR_TYPE_ERR = 4'b0000,
    INSTR_TYPE_R = 4'b0001,
    INSTR_TYPE_I = 4'b0010,
    INSTR_TYPE_S = 4'b0011,
    INSTR_TYPE_B = 4'b0100,
    INSTR_TYPE_U = 4'b0101
} instr_type_t;

// ALU operation encoding
typedef enum logic [3:0] {
    OP_NONE = 4'b0000,
    OP_ADD = 4'b0001,
    OP_SUB = 4'b0010,
    OP_AND = 4'b0011,
    OP_OR = 4'b0100,
    OP_XOR = 4'b0101,
    OP_NOT = 4'b0110,
    OP_SLL = 4'b0111,
    OP_SRL = 4'b1000,
    OP_SRA = 4'b1001
} alu_op_t;

// Specific instruction code encoding
typedef enum logic [7:0] {
    INSTR_UNKNOWN = 8'h00,
    INSTR_LUI = 8'h01,
    INSTR_ADDI = 8'h02,
    INSTR_ANDI = 8'h03,
    INSTR_ADD = 8'h04,
    INSTR_LB = 8'h05,
    INSTR_LW = 8'h06,
    INSTR_SB = 8'h07,
    INSTR_SW = 8'h08,
    INSTR_BEQ = 8'h09
} instr_code_t;

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
        7'b0110111: begin  // LUI
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

        7'b0010011: begin  // ADDI, ANDI
            imm_type_o = IMM_TYPE_I;
            instr_type_o = INSTR_TYPE_I;
            use_rs2_o = 1'b0;
            mem_wen_o = 1'b0;
            rf_wen_o = 1'b1;
            rf_raddr_a_o = rs1;
            rf_raddr_b_o = 5'b0;
            rf_waddr_o = rd;
            case (funct3)
                3'b000: begin
                    alu_op_o = OP_ADD;   // ADDI
                    instr_code_o = INSTR_ADDI;
                end
                3'b111: begin
                    alu_op_o = OP_AND;   // ANDI
                    instr_code_o = INSTR_ANDI;
                end
                default: alu_op_o = OP_NONE;
            endcase
        end

        7'b0000011: begin  // LB, LW (Load)
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
                3'b000: instr_code_o = INSTR_LB;   // LB - Load Byte
                3'b010: instr_code_o = INSTR_LW;   // LW - Load Word
                default: instr_code_o = INSTR_UNKNOWN;
            endcase
        end

        7'b0100011: begin  // SB, SW (Store)
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
                3'b010: instr_code_o = INSTR_SW;   // SW - Store Word
                default: instr_code_o = INSTR_UNKNOWN;
            endcase
        end

        7'b1100011: begin  // BEQ
            imm_type_o = IMM_TYPE_B;
            instr_type_o = INSTR_TYPE_B;
            instr_code_o = INSTR_BEQ;
            alu_op_o = OP_SUB;
            use_rs2_o = 1'b1;
            mem_wen_o = 1'b0;
            rf_wen_o = 1'b0;
            rf_raddr_a_o = rs1;
            rf_raddr_b_o = rs2;
            rf_waddr_o = 5'b0;
        end

        7'b0110011: begin  // ADD
            imm_type_o = IMM_TYPE_NONE;
            instr_type_o = INSTR_TYPE_R;
            instr_code_o = INSTR_ADD;
            alu_op_o = OP_ADD;
            use_rs2_o = 1'b1;
            mem_wen_o = 1'b0;
            rf_wen_o = 1'b1;
            rf_raddr_a_o = rs1;
            rf_raddr_b_o = rs2;
            rf_waddr_o = rd;
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

