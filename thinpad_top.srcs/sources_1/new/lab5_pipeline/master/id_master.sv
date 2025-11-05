module id_master (
    input wire          clk,
    input wire          rst,

    // From IF/ID Pipeline Register
    input logic [31:0]  pc_i,
    input logic [31:0]  inst_i,

    // Register File Read Addresses
    output logic [4:0] rf_raddr_a_o,//rs1 segment of instruction
    output logic [4:0] rf_raddr_b_o,//rs2 segment of instruction

    // To ID/EXE Pipeline Register
    output logic [31:0] pc_o,
    output logic [31:0] inst_o,

    output logic [2:0]  imm_type_o,
    output logic [3:0]  alu_op_o,//ALU operation type
    output logic [3:0]  instr_type_o,//instruction type
    output logic        use_rs2,

    output logic        mem_en_o,

    output logic        rf_we_o,
    output logic [4:0]  rf_waddr_o,//rd segment of instruction

    // To Control Unit
    output logic          stall_o,
    output logic          flush_o

);
//这个阶段对于所有指令都需要生成对应的控制信号，同时完成寄存器的读取

typedef enum logic [2:0] {
    IMM_TYPE_I = 3'b000,
    IMM_TYPE_S = 3'b001,
    IMM_TYPE_B = 3'b010,
    IMM_TYPE_U = 3'b011,
    IMM_TYPE_J = 3'b100,
    IMM_TYPE_NONE = 3'b111
} imm_type_t;

typedef enum logic [3:0] {
    LUI = 4'b0000,
    BEQ = 4'b0001,
    LB  = 4'b0010,
    SB  = 4'b0011,
    SW  = 4'b0100,
    ADDI = 4'b0101,
    ANDI = 4'b0110,
    ADD  = 4'b0111,
    ERR = 4'b1111
} instr_type_t;
instr_type_t instr_type_reg;

assign instr_type_o = instr_type_reg;

typedef enum logic [3:0] {
    OP_NONE = 4'b0000,
    OP_ADD = 4'b0001,
    OP_SUB = 4'b0010,
    OP_AND = 4'b0011,
    OP_OR  = 4'b0100,
    OP_XOR = 4'b0101,
    OP_NOT = 4'b0110,
    OP_SLL = 4'b0111,
    OP_SRL = 4'b1000,
    OP_SRA = 4'b1001,
    OP_ROL = 4'b1010
} opcode_t;

logic [6:0] opcode;
logic [2:0] funct3;

assign opcode = inst_i[6:0];
assign funct3 = inst_i[14:12];

reg [4:0] rd_reg;
reg [4:0] rs1_reg;
reg [4:0] rs2_reg;

always_comb begin
    if (rst) begin
        pc_o = 32'b0;
        inst_o = 32'b0;
        imm_type_o = IMM_TYPE_NONE;
        alu_op_o = 4'b0;
        use_rs2 = 1'b0;
        mem_en_o = 1'b0;
        rf_we_o = 1'b0;
        rf_raddr_a_o = 5'b0;
        rf_raddr_b_o = 5'b0;
        rf_waddr_o = 5'b0;
        rd_reg = 5'b0;
        rs1_reg = 5'b0;
        rs2_reg = 5'b0;
        stall_o = 1'b0;
        flush_o = 1'b0;
    end else begin
        pc_o = pc_i;
        inst_o = inst_i;

        rd_reg = inst_i[11:7];
        rs1_reg = inst_i[19:15];
        rs2_reg = inst_i[24:20];

        case (opcode)
            7'b0110111: begin // LUI
                imm_type_o = IMM_TYPE_U;
                instr_type_reg = LUI;
                use_rs2 = 1'b0;
                mem_en_o = 1'b0;
                rf_we_o = 1'b1;
                alu_op_o = OP_ADD; // LUI uses ADD operation with immediate

                rf_raddr_a_o = 5'b0;
                rf_raddr_b_o = 5'b0;
                rf_waddr_o = rd_reg;
            end
            7'b1100011: begin // BEQ
                imm_type_o = IMM_TYPE_B;
                instr_type_reg = BEQ;
                use_rs2 = 1'b1;
                mem_en_o = 1'b0;
                rf_we_o = 1'b0;
                alu_op_o = OP_SUB; // BEQ uses SUB operation for comparison

                rf_raddr_a_o = rs1_reg;
                rf_raddr_b_o = rs2_reg;
                rf_waddr_o = 5'b0;
            end
            7'b0000011: begin // LB
                imm_type_o = IMM_TYPE_I;
                instr_type_reg = LB;
                use_rs2 = 1'b0;
                mem_en_o = 1'b1;
                rf_we_o = 1'b1;
                alu_op_o = OP_ADD; // LB uses ADD operation for address calculation

                rf_raddr_a_o = rs1_reg;
                rf_raddr_b_o = 5'b0;
                rf_waddr_o = rd_reg;
            end
            7'b0100011: begin // SB, SW
                imm_type_o = IMM_TYPE_S;
                case (funct3)
                    3'b000: instr_type_reg = SB;
                    3'b010: instr_type_reg = SW;
                    default: instr_type_reg = ERR;
                endcase
                use_rs2 = 1'b1;
                mem_en_o = 1'b1;
                rf_we_o = 1'b0;
                alu_op_o = OP_ADD; // SB uses ADD operation for address calculation

                rf_raddr_a_o = rs1_reg;
                rf_raddr_b_o = rs2_reg;
                rf_waddr_o = 5'b0;
            end
            7'b0010011: begin // ADDI, ANDI
                imm_type_o = IMM_TYPE_I;
                case (funct3)
                    3'b000: instr_type_reg = ADDI;
                    3'b111: instr_type_reg = ANDI;
                    default: instr_type_reg = ERR;
                endcase
                use_rs2 = 1'b0;
                mem_en_o = 1'b0;
                rf_we_o = 1'b1;
                alu_op_o = (funct3 == 3'b000) ? OP_ADD : OP_AND; // ADDI or ANDI operation

                rf_raddr_a_o = rs1_reg;
                rf_raddr_b_o = 5'b0;
                rf_waddr_o = rd_reg;
            end
            7'b0110011: begin // ADD
                imm_type_o = IMM_TYPE_NONE;
                instr_type_reg = ADD;
                use_rs2 = 1'b1;
                mem_en_o = 1'b0;
                rf_we_o = 1'b1;
                alu_op_o = OP_ADD; // ADD operation

                rf_raddr_a_o = rs1_reg;
                rf_raddr_b_o = rs2_reg;
                rf_waddr_o = rd_reg;
            end
            default: begin
                imm_type_o = IMM_TYPE_NONE;
                instr_type_reg = ERR;
                use_rs2 = 1'b0;
                mem_en_o = 1'b0;
                rf_we_o = 1'b0;
                alu_op_o = OP_NONE;

                rf_raddr_a_o = 5'b0;
                rf_raddr_b_o = 5'b0;
                rf_waddr_o = 5'b0;
            end
        endcase
        stall_o = 1'b0;
        flush_o = 1'b0;
    end
end

endmodule