module exe_master (
    input wire clk_i,
    input wire rst_i,

    // from ID/EX Pipeline Register
    input wire [31:0] pc_i,
    input wire [31:0] inst_i,
    input wire [31:0] rf_rdata_a_i,
    input wire [31:0] rf_rdata_b_i,
    input wire [2:0]  imm_type_i,
    input wire [4:0]  rf_waddr_i,
    input wire        rf_we_i,
    input wire        use_rs2_i,
    input wire [3:0]  alu_op_i,
    input wire [3:0]  instr_type_i,
    input wire        mem_en_i,

    // to ALU
    output reg [31:0] alu_operand_a_o,
    output reg [31:0] alu_operand_b_o,
    output reg [3:0]  alu_op_o,

    // to EXE/MEM Pipeline Register
    output reg [3:0]  instr_type_o,
    output reg [4:0]  rf_waddr_o,
    output reg [31:0] rf_wdata_o,//imm in U-type instruction
    output reg [31:0] mem_addr_o,
    output reg [31:0] mem_data_o,
    output reg        rf_we_o,
    output reg        mem_en_o,
    //output reg [31:0] imm_value_o,

    // to IF stage for branch
    output logic [31:0] pc_branch_o,
    output logic        branch_o,

    // to Control Unit
    output reg        stall_o,
    output reg        flush_o
);

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

logic [31:0] imm_value;

// generate immediate value
always_comb begin
    case (imm_type_i)
        IMM_TYPE_I: imm_value = {{20{inst_i[31]}}, inst_i[31:20]};
        IMM_TYPE_S: imm_value = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
        IMM_TYPE_B: imm_value = {{19{inst_i[31]}}, inst_i[31:25], inst_i[11:7], 1'b0};
        IMM_TYPE_U: imm_value = {inst_i[31:12], 12'b0};
        IMM_TYPE_J: imm_value = {{11{inst_i[31]}}, inst_i[31:12], 1'b0};
        default: imm_value = 32'b0;
    endcase
end

always_comb begin
    alu_operand_a_o = rf_rdata_a_i;
    if (use_rs2_i) begin
        alu_operand_b_o = rf_rdata_b_i;
    end else begin
        alu_operand_b_o = imm_value;
    end
    alu_op_o = alu_op_i;
end

always_comb begin
    rf_waddr_o = rf_waddr_i;
    rf_wdata_o = 32'b0;
    rf_we_o = rf_we_i;
    mem_en_o = mem_en_i;
    stall_o = 1'b0;
    flush_o = 1'b0;
    branch_o = 1'b0;
    pc_branch_o = 32'b0;
    case (imm_type_i)
        IMM_TYPE_I: begin
            if (mem_en_i) begin
                mem_addr_o = alu_operand_a_o + $signed(imm_value);
            end else begin
                mem_addr_o = 32'b0;
            end
        end
        IMM_TYPE_S: begin
            mem_addr_o = alu_operand_a_o + $signed(imm_value);
            if (instr_type_i == SB) begin
                mem_data_o = {24'b0, alu_operand_b_o[7:0]};
            end else begin
                mem_data_o = alu_operand_b_o;
            end 
        end
        IMM_TYPE_B: begin
            mem_addr_o = 32'b0;
            mem_data_o = 32'b0;
            if (alu_operand_a_o == alu_operand_b_o) begin
                branch_o = 1'b1;
                pc_branch_o = pc_i + $signed(imm_value);
                flush_o = 1'b1;
            end else begin
                branch_o = 1'b0;
                pc_branch_o = 32'b0;
                flush_o = 1'b0;
            end
        end
        IMM_TYPE_U: begin
            mem_addr_o = 32'b0;
            mem_data_o = 32'b0;
            rf_wdata_o = imm_value;
        end
        IMM_TYPE_J: begin
            mem_addr_o = 32'b0;
            mem_data_o = 32'b0;
            branch_o = 1'b1;
            pc_branch_o = pc_i + $signed(imm_value);
            flush_o = 1'b1;
        end
        default: begin
            mem_addr_o = 32'b0;
            mem_data_o = 32'b0;
        end
    endcase
end

endmodule