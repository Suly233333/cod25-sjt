`default_nettype none

module ppl_alu #(
    parameter int DATA_WIDTH = 32
) (
    input wire reset,

    input wire [DATA_WIDTH-1:0] alu_a,
    input wire [DATA_WIDTH-1:0] alu_b,
    input wire [3:0] alu_op,
    output logic [DATA_WIDTH-1:0] alu_y
);

  // ALU操作定义
  localparam OP_ADD = 4'b0001;  // 加法
  localparam OP_SUB = 4'b0010;  // 减法
  localparam OP_AND = 4'b0011;  // 按位与
  localparam OP_OR  = 4'b0100;  // 按位或
  localparam OP_XOR = 4'b0101;  // 按位异或
  localparam OP_NOT = 4'b0110;  // 按位取非
  localparam OP_SLL = 4'b0111;  // 逻辑左移
  localparam OP_SRL = 4'b1000;  // 逻辑右移
  localparam OP_SRA = 4'b1001;  // 算术右移
  localparam OP_ROL = 4'b1010;   // 循环左移
  localparam OP_SLT = 4'b1011;   // 小于(有符号)
  localparam OP_SLTU = 4'b1100;  // 小于(无符号)

  // ALU运算
  reg signed [31:0] compute_reg;
  reg [9:0] num;

  always_comb begin
    if (reset) begin
        alu_y = {DATA_WIDTH{1'b0}};
        compute_reg = 32'b0;
        num = 10'b0;
    end else begin
      case (alu_op)
        OP_ADD: alu_y = alu_a + alu_b;
        OP_SUB: alu_y = alu_a - alu_b;
        OP_AND: alu_y = alu_a & alu_b;
        OP_OR:  alu_y = alu_a | alu_b;
        OP_XOR: alu_y = alu_a ^ alu_b;
        OP_NOT: alu_y = ~alu_a;
        OP_SLL: begin
          num = alu_b % 32;  // 使用模32，而不是仅[3:0]
          alu_y = alu_a << num;
        end
        OP_SRL: begin
          num = alu_b % 32;
          alu_y = alu_a >> num;
        end
        OP_SRA: begin
          num = alu_b % 32;
          compute_reg = $signed(alu_a) >>> num;  // 中间结果为有符号
          alu_y = $unsigned(compute_reg);       // 转换为无符号
        end
        OP_ROL: begin
          num = alu_b % 32;
          alu_y = (alu_a << num) | (alu_a >> (32 - num));
        end
        OP_SLT: begin
          // Set Less Than (signed)
          alu_y = ($signed(alu_a) < $signed(alu_b)) ? 32'h00000001 : 32'h00000000;
        end
        OP_SLTU: begin
          // Set Less Than Unsigned
          alu_y = (alu_a < alu_b) ? 32'h00000001 : 32'h00000000;
        end
        default: alu_y = {DATA_WIDTH{1'b0}};  // 默认输出0
      endcase
    end
  end

endmodule
