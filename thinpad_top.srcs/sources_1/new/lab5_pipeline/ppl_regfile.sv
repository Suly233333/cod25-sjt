`default_nettype none

module ppl_regfile #(
    parameter DATA_WIDTH = 32
) (
    input wire clk,
    input wire reset,

    // 写端口
    input wire [4:0] rf_waddr,
    input wire [DATA_WIDTH-1:0] rf_wdata,
    input wire rf_we,
    // 读端口A
    input wire [4:0] rf_raddr_a,
    output reg [DATA_WIDTH-1:0] rf_rdata_a,
    // 读端口B
    input wire [4:0] rf_raddr_b,
    output reg [DATA_WIDTH-1:0] rf_rdata_b
);

    logic [DATA_WIDTH-1:0] regs [0:31]; // 32 * 32位寄存器

  // 写入操作 - 时序逻辑
  always_ff @(posedge clk) begin
    if (reset) begin
      // 复位时清零所有寄存器
      for (int i = 0; i < 32; i++) begin
        regs[i] <= 32'b0;
      end
    end else if (rf_we && rf_waddr != 5'b0) begin
      // 写使能有效且不是0号寄存器时写入数据
      regs[rf_waddr] <= rf_wdata;
    end
  end
  
  // 读取操作 - 组合逻辑
  always_comb begin
    // 读端口A
    rf_rdata_a = (rf_raddr_a == 5'b0) ? 32'b0 : (rf_we && rf_raddr_a == rf_waddr) ? rf_wdata : regs[rf_raddr_a];
    // 读端口B
    rf_rdata_b = (rf_raddr_b == 5'b0) ? 32'b0 : (rf_we && rf_raddr_b == rf_waddr) ? rf_wdata : regs[rf_raddr_b];
  end

endmodule
