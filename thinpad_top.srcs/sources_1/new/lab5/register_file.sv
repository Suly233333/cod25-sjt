/**
 * @file register_file.sv
 * @brief 32位宽的寄存器文件（用于RISC-V流水线CPU）
 *
 * 功能：
 * - 32个32位寄存器（x0-x31）
 * - x0寄存器硬连线为0
 * - 双读端口（组合逻辑）
 * - 单写端口（时序逻辑）
 * - 写优先：同周期写后读可以读到新值
 */

`default_nettype none

module register_file #(
    parameter DATA_WIDTH = 32,
    parameter NUM_REGS = 32
) (
    input wire clk,
    input wire reset,

    // 写端口
    input wire [4:0] waddr,
    input wire [DATA_WIDTH-1:0] wdata,
    input wire we,

    // 读端口A
    input wire [4:0] raddr_a,
    output logic [DATA_WIDTH-1:0] rdata_a,

    // 读端口B
    input wire [4:0] raddr_b,
    output logic [DATA_WIDTH-1:0] rdata_b
);

  // 32个32位寄存器
  logic [DATA_WIDTH-1:0] regs [NUM_REGS-1:0];

  // 写入操作 - 时序逻辑
  always_ff @(posedge clk) begin
    if (reset) begin
      // 复位时清零所有寄存器
      for (int i = 0; i < NUM_REGS; i++) begin
        regs[i] <= {DATA_WIDTH{1'b0}};
      end
    end else if (we && waddr != 5'b0) begin
      // 写使能有效且不是0号寄存器时写入数据
      regs[waddr] <= wdata;
    end
  end

  // 读取操作 - 组合逻辑
  // 支持写后读：如果同一周期写入，立即读出新值
  always_comb begin
    // 读端口A
    if (raddr_a == 5'b0) begin
      rdata_a = {DATA_WIDTH{1'b0}};  // x0 始终为 0
    end else if (we && waddr == raddr_a && waddr != 5'b0) begin
      rdata_a = wdata;  // 写后读：直接返回写入的数据
    end else begin
      rdata_a = regs[raddr_a];
    end

    // 读端口B
    if (raddr_b == 5'b0) begin
      rdata_b = {DATA_WIDTH{1'b0}};  // x0 始终为 0
    end else if (we && waddr == raddr_b && waddr != 5'b0) begin
      rdata_b = wdata;  // 写后读：直接返回写入的数据
    end else begin
      rdata_b = regs[raddr_b];
    end
  end

endmodule

`default_nettype wire
