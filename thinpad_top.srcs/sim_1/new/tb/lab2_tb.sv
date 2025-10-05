`timescale 1ns / 1ps
module lab2_tb;

  wire clk_50M, clk_11M0592;

  reg push_btn;   // BTN5 按钮开关，带消抖电路，按下时为 1
  reg reset_btn;  // BTN6 复位按钮，带消抖电路，按下时为 1

  reg [3:0] touch_btn; // BTN1~BTN4，按钮开关，按下时为 1
  reg [31:0] dip_sw;   // 32 位拨码开关，拨到“ON”时为 1

  wire [15:0] leds;  // 16 位 LED，输出时 1 点亮
  wire [7:0] dpy0;   // 数码管低位信号，包括小数点，输出 1 点亮
  wire [7:0] dpy1;   // 数码管高位信号，包括小数点，输出 1 点亮

  // 实验 3 用到的指令格式
  `define inst_rtype(rd, rs1, rs2, op) \
    {7'b0, rs2, rs1, 3'b0, rd, op, 3'b001}

  `define inst_itype(rd, imm, op) \
    {imm, 4'b0, rd, op, 3'b010}
  
  `define inst_poke(rd, imm) `inst_itype(rd, imm, 4'b0001)
  `define inst_peek(rd, imm) `inst_itype(rd, imm, 4'b0010)

  // opcode table
  typedef enum logic [3:0] {
    ADD = 4'b0001,
    SUB = 4'b0010,
    AND = 4'b0011,
    OR  = 4'b0100,
    XOR = 4'b0101,
    NOT = 4'b0110,
    SLL = 4'b0111,
    SRL = 4'b1000,
    SRA = 4'b1001,
    ROL = 4'b1010
  } opcode_t;

  logic is_rtype, is_itype, is_load, is_store, is_unknown;
  logic [15:0] imm;
  logic [4:0] rd, rs1, rs2;
  logic [3:0] opcode;

  // 用于验证结果的变量
  logic [15:0] expected_result;
  logic [15:0] reg_values[31:0];
  
  // 用于生成随机指令的变量
  opcode_t random_op;
  logic [4:0] random_rd, random_rs1, random_rs2;
  logic [15:0] random_imm;

  initial begin
    // 在这里可以自定义测试输入序列，例如：
    dip_sw = 32'h0;
    touch_btn = 0;
    reset_btn = 0;
    push_btn = 0;

    // 初始化寄存器值跟踪数组
    for (int i = 0; i < 32; i = i + 1) begin
      reg_values[i] = 0;
    end

    #100;
    reset_btn = 1;
    #100;
    reset_btn = 0;
    #1000;  // 等待复位结束

    // 样例：使用 POKE 指令为寄存器赋随机初值
    for (int i = 1; i < 32; i = i + 1) begin
      #100;
      rd = i;   // only lower 5 bits
      random_imm = $urandom_range(0, 65535);
      dip_sw = `inst_poke(rd, random_imm);
      push_btn = 1;
      
      // 更新我们跟踪的寄存器值
      reg_values[rd] = random_imm;

      #100;
      push_btn = 0;

      #1000;
    end

    // 随机测试各种指令
    for (int test = 0; test < 100; test = test + 1) begin
      #100;
      
      // 随机决定使用R型指令还是I型指令
      if ($urandom_range(0, 1) == 0) begin
        // 测试R型指令
        random_op = opcode_t'($urandom_range(1, 10)); // 随机选择一个操作码
        random_rd = $urandom_range(1, 31); // 目标寄存器，避免使用r0
        random_rs1 = $urandom_range(1, 31); // 源寄存器1
        random_rs2 = $urandom_range(1, 31); // 源寄存器2
        
        // 构造指令
        dip_sw = `inst_rtype(random_rd, random_rs1, random_rs2, random_op);
        
        // 计算预期结果
        case (random_op)
          ADD: expected_result = reg_values[random_rs1] + reg_values[random_rs2];
          SUB: expected_result = reg_values[random_rs1] - reg_values[random_rs2];
          AND: expected_result = reg_values[random_rs1] & reg_values[random_rs2];
          OR:  expected_result = reg_values[random_rs1] | reg_values[random_rs2];
          XOR: expected_result = reg_values[random_rs1] ^ reg_values[random_rs2];
          NOT: expected_result = ~reg_values[random_rs1];
          SLL: expected_result = reg_values[random_rs1] << reg_values[random_rs2][3:0];
          SRL: expected_result = reg_values[random_rs1] >> reg_values[random_rs2][3:0];
          SRA: begin
            logic signed [15:0] signed_a = reg_values[random_rs1];
            expected_result = signed_a >>> reg_values[random_rs2][3:0];
          end
          ROL: expected_result = (reg_values[random_rs1] << reg_values[random_rs2][3:0]) | 
                                (reg_values[random_rs1] >> (16 - reg_values[random_rs2][3:0]));
          default: expected_result = 16'b0;
        endcase
        
        // 更新我们跟踪的寄存器值
        reg_values[random_rd] = expected_result;
        
        // 打印测试信息
        $display("Test %0d: R-type op=%0d, rd=%0d, rs1=%0d, rs2=%0d, expected=%0h", 
                 test, random_op, random_rd, random_rs1, random_rs2, expected_result);
      end else begin
        // 测试POKE指令
        random_rd = $urandom_range(1, 31); // 目标寄存器，避免使用r0
        random_imm = $urandom_range(0, 65535); // 随机立即数
        
        // 构造POKE指令
        dip_sw = `inst_poke(random_rd, random_imm);
        
        // 更新我们跟踪的寄存器值
        reg_values[random_rd] = random_imm;
        
        // 打印测试信息
        $display("Test %0d: POKE rd=%0d, imm=%0h", test, random_rd, random_imm);
      end
      
      // 执行指令
      push_btn = 1;
      #100;
      push_btn = 0;
      #1000;
      
      // 每隔10条指令，使用PEEK指令验证一个随机寄存器的值
      if (test % 10 == 9) begin
        random_rd = $urandom_range(1, 31); // 随机选择一个寄存器验证
        
        // 构造PEEK指令
        dip_sw = `inst_peek(random_rd, 16'h0); // 立即数在PEEK指令中不使用
        
        // 执行PEEK指令
        push_btn = 1;
        #100;
        push_btn = 0;
        #1000;
        
        // 验证LED显示的值是否与我们跟踪的寄存器值一致
        if (leds !== reg_values[random_rd]) begin
          $display("ERROR: PEEK rd=%0d, expected=%0h, actual=%0h", 
                   random_rd, reg_values[random_rd], leds);
        end else begin
          $display("PASS: PEEK rd=%0d, value=%0h", random_rd, leds);
        end
      end
    end

    #10000 $finish;
  end

  // 待测试用户设计
  lab2_top dut (
      .clk_50M(clk_50M),
      .clk_11M0592(clk_11M0592),
      .push_btn(push_btn),
      .reset_btn(reset_btn),
      .touch_btn(touch_btn),
      .dip_sw(dip_sw),
      .leds(leds),
      .dpy1(dpy1),
      .dpy0(dpy0),

      .txd(),
      .rxd(1'b1),
      .uart_rdn(),
      .uart_wrn(),
      .uart_dataready(1'b0),
      .uart_tbre(1'b0),
      .uart_tsre(1'b0),
      .base_ram_data(),
      .base_ram_addr(),
      .base_ram_ce_n(),
      .base_ram_oe_n(),
      .base_ram_we_n(),
      .base_ram_be_n(),
      .ext_ram_data(),
      .ext_ram_addr(),
      .ext_ram_ce_n(),
      .ext_ram_oe_n(),
      .ext_ram_we_n(),
      .ext_ram_be_n(),
      .flash_d(),
      .flash_a(),
      .flash_rp_n(),
      .flash_vpen(),
      .flash_oe_n(),
      .flash_ce_n(),
      .flash_byte_n(),
      .flash_we_n()
  );

  // 时钟源
  clock osc (
      .clk_11M0592(clk_11M0592),
      .clk_50M    (clk_50M)
  );

endmodule
