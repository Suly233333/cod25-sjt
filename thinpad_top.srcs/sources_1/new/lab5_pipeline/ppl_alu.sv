`default_nettype none

module ppl_alu #(
    parameter int DATA_WIDTH = 32
) (
    input wire reset,

    input wire [DATA_WIDTH-1:0] alu_a,
    input wire [DATA_WIDTH-1:0] alu_b,
    input wire [4:0] alu_op,
    output logic [DATA_WIDTH-1:0] alu_y
);

  // ALU操作定义
  localparam OP_ADD = 5'b00001;  // 加法
  localparam OP_SUB = 5'b00010;  // 减法
  localparam OP_AND = 5'b00011;  // 按位与
  localparam OP_OR  = 5'b00100;  // 按位或
  localparam OP_XOR = 5'b00101;  // 按位异或
  localparam OP_NOT = 5'b00110;  // 按位取非
  localparam OP_SLL = 5'b00111;  // 逻辑左移
  localparam OP_SRL = 5'b01000;  // 逻辑右移
  localparam OP_SRA = 5'b01001;  // 算术右移
  localparam OP_ROL = 5'b01010;   // 循环左移
  localparam OP_SLT = 5'b01011;   // 小于(有符号)
  localparam OP_SLTU = 5'b01100;  // 小于(无符号)
  localparam OP_MIN = 5'b01101;   // 最小值(有符号)
  localparam OP_SBSET = 5'b01110; // 置位
  localparam OP_CTZ = 5'b01111;    // 计算尾随零
  
  // ALU运算
  reg signed [31:0] compute_reg;
  reg [9:0] num;
  integer i;
  reg [31:0] ctz_result;
  reg found_local;

  always_comb begin
    if (reset) begin
        alu_y = {DATA_WIDTH{1'b0}};
        compute_reg = 32'b0;
        num = 10'b0;
        ctz_result = 32'b0;
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
        OP_MIN: begin
          // Minimum (signed)
          alu_y = ($signed(alu_a) < $signed(alu_b)) ? alu_a : alu_b;
        end
        OP_SBSET: begin
          // Set Bit: rd = rs1 | (1 << (rs2 & 31))
          num = alu_b[4:0];  // Only lower 5 bits
          alu_y = alu_a | (32'h00000001 << num);
        end
        OP_CTZ: begin
          // Count Trailing Zeros - synthesizable priority encoder
          if (alu_a == 32'b0) begin
            ctz_result = 32'd32;
          end else begin
            ctz_result = 32'd0;
            found_local = 1'b0;
            // iterate bits from LSB to MSB and capture first '1'
            for (i = 0; i < 32; i = i + 1) begin
              if (!found_local && alu_a[i]) begin
                ctz_result = i;
                found_local = 1'b1;
              end
            end
          end
          alu_y = ctz_result;
        end
        default: alu_y = {DATA_WIDTH{1'b0}};  // 默认输出0
      endcase
    end
  end

endmodule
