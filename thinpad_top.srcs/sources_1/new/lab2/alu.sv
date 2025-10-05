`default_nettype none

module alu (
    input wire [15:0] a,
    input wire [15:0] b,
    input wire [3:0] op,
    output logic [15:0] y
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
  localparam OP_ROL = 4'b1010;  // 循环左移
  
  // ALU运算
  always_comb begin
    logic signed [15:0] sra_temp;  // 有符号中间变量
    case (op)
      OP_ADD: y = a + b;
      OP_SUB: y = a - b;
      OP_AND: y = a & b;
      OP_OR:  y = a | b;
      OP_XOR: y = a ^ b;
      OP_NOT: y = ~a;
      OP_SLL: y = a << b[3:0];  // 只使用低4位作为移位量，移动0~15位
      OP_SRL: y = a >> b[3:0];
      OP_SRA: begin
        sra_temp = $signed(a) >>> b[3:0];  // 中间结果为有符号
        y = $unsigned(sra_temp);  // 转换为无符号
      end
      OP_ROL: y = (a << b[3:0]) | (a >> (16 - b[3:0]));
      default: y = 16'b0;
    endcase
  end

endmodule