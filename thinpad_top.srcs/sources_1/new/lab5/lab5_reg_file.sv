`default_nettype none

module lab5_regfile #(
    parameter DATA_WIDTH = 32
) (
    input wire clk,
    input wire reset,

    // 写端口
    input wire [4:0] waddr,
    input wire [DATA_WIDTH-1:0] wdata,
    input wire we,
    // 读端口A
    input wire [4:0] raddr_a,
    output reg [DATA_WIDTH-1:0] rdata_a,
    // 读端口B
    input wire [4:0] raddr_b,
    output reg [DATA_WIDTH-1:0] rdata_b
);

    logic [DATA_WIDTH-1:0] regs [0:31]; // 32 * 32位寄存器

  // 写入操作 - 时序逻辑
  always_ff @(posedge clk) begin
    if (reset) begin
      // 复位时清零所有寄存器
      for (int i = 0; i < 32; i++) begin
        regs[i] <= 32'b0;
      end
    end else if (we && waddr != 5'b0) begin
      // 写使能有效且不是0号寄存器时写入数据
      regs[waddr] <= wdata;
    end
  end
  
  // 读取操作 - 组合逻辑
  always_comb begin
    // 读端口A
    rdata_a = (raddr_a == 5'b0) ? 32'b0 : regs[raddr_a];
    // 读端口B
    rdata_b = (raddr_b == 5'b0) ? 32'b0 : regs[raddr_b];
  end

endmodule
