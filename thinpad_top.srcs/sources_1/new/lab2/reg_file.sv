`default_nettype none

module reg_file (
    input wire clk,
    input wire reset,
    
    // 写端口
    input wire [4:0] waddr,
    input wire [15:0] wdata,
    input wire we,
    
    // 读端口A
    input wire [4:0] raddr_a,
    output logic [15:0] rdata_a,
    
    // 读端口B
    input wire [4:0] raddr_b,
    output logic [15:0] rdata_b
);

  // 32个16位寄存器
  logic [15:0] regs [31:0];
  
  // 写入操作 - 时序逻辑
  always_ff @(posedge clk) begin
    if (reset) begin
      // 复位时清零所有寄存器
      for (int i = 0; i < 32; i++) begin
        regs[i] <= 16'b0;
      end
    end else if (we && waddr != 5'b0) begin
      // 写使能有效且不是0号寄存器时写入数据
      regs[waddr] <= wdata;
    end
  end
  
  // 读取操作 - 组合逻辑
  always_comb begin
    // 读端口A
    rdata_a = (raddr_a == 5'b0) ? 16'b0 : regs[raddr_a];
    // 读端口B
    rdata_b = (raddr_b == 5'b0) ? 16'b0 : regs[raddr_b];
  end

endmodule