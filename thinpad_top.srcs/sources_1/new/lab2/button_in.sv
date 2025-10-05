`default_nettype none

module button_in (
    input wire clk,
    input wire reset,
    input wire push_btn,
    output logic step
);

  // 使用两个触发器检测上升沿
  logic push_btn_r1, push_btn_r2;
  
  always_ff @(posedge clk) begin
    if (reset) begin
      push_btn_r1 <= 1'b0;
      push_btn_r2 <= 1'b0;
    end else begin
      push_btn_r1 <= push_btn;
      push_btn_r2 <= push_btn_r1;
    end
  end
  
  // 上升沿检测：当前值为1，前一个值为0
  assign step = push_btn_r1 & ~push_btn_r2;

endmodule