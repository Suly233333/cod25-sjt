/**
 * @file lab5_top.sv
 * @brief 五级流水线 CPU 顶层模块
 *
 * 功能：
 * 1. PLL 时钟分频
 * 2. 集成五级流水线各阶段模块（IF, ID, EXE, MEM, WB）
 * 3. Stall/Flush 控制器
 * 4. 寄存器文件
 * 5. Wishbone 仲裁器和多路复用器
 * 6. SRAM 和 UART 控制器
 */
`default_nettype none
`include "mytype.sv"

module lab5_top (
    input wire clk_50M,     // 50MHz 时钟输入
    input wire clk_11M0592, // 11.0592MHz 时钟输入（备用，可不用）

    input wire push_btn,  // BTN5 按钮开关，带消抖电路，按下时为 1
    input wire reset_btn, // BTN6 复位按钮，带消抖电路，按下时为 1

    input  wire [ 3:0] touch_btn,  // BTN1~BTN4，按钮开关，按下时为 1
    input  wire [31:0] dip_sw,     // 32 位拨码开关，拨到"ON"时为 1
    output wire [15:0] leds,       // 16 位 LED，输出时 1 点亮
    output wire [ 7:0] dpy0,       // 数码管低位信号，包括小数点，输出 1 点亮
    output wire [ 7:0] dpy1,       // 数码管高位信号，包括小数点，输出 1 点亮

    // CPLD 串口控制器信号
    output wire uart_rdn,        // 读串口信号，低有效
    output wire uart_wrn,        // 写串口信号，低有效
    input  wire uart_dataready,  // 串口数据准备好
    input  wire uart_tbre,       // 发送数据标志
    input  wire uart_tsre,       // 数据发送完毕标志

    // BaseRAM 信号
    inout wire [31:0] base_ram_data,  // BaseRAM 数据，低 8 位与 CPLD 串口控制器共享
    output wire [19:0] base_ram_addr,  // BaseRAM 地址
    output wire [3:0] base_ram_be_n,  // BaseRAM 字节使能，低有效。如果不使用字节使能，请保持为 0
    output wire base_ram_ce_n,  // BaseRAM 片选，低有效
    output wire base_ram_oe_n,  // BaseRAM 读使能，低有效
    output wire base_ram_we_n,  // BaseRAM 写使能，低有效

    // ExtRAM 信号
    inout wire [31:0] ext_ram_data,  // ExtRAM 数据
    output wire [19:0] ext_ram_addr,  // ExtRAM 地址
    output wire [3:0] ext_ram_be_n,  // ExtRAM 字节使能，低有效。如果不使用字节使能，请保持为 0
    output wire ext_ram_ce_n,  // ExtRAM 片选，低有效
    output wire ext_ram_oe_n,  // ExtRAM 读使能，低有效
    output wire ext_ram_we_n,  // ExtRAM 写使能，低有效

    // 直连串口信号
    output wire txd,  // 直连串口发送端
    input  wire rxd,  // 直连串口接收端

    // Flash 存储器信号，参考 JS28F640 芯片手册
    output wire [22:0] flash_a,  // Flash 地址，a0 仅在 8bit 模式有效，16bit 模式无意义
    inout wire [15:0] flash_d,  // Flash 数据
    output wire flash_rp_n,  // Flash 复位信号，低有效
    output wire flash_vpen,  // Flash 写保护信号，低电平时不能擦除、烧写
    output wire flash_ce_n,  // Flash 片选信号，低有效
    output wire flash_oe_n,  // Flash 读使能信号，低有效
    output wire flash_we_n,  // Flash 写使能信号，低有效
    output wire flash_byte_n, // Flash 8bit 模式选择，低有效。在使用 flash 的 16 位模式时请设为 1

    // USB 控制器信号，参考 SL811 芯片手册
    output wire sl811_a0,
    // inout  wire [7:0] sl811_d,     // USB 数据线与网络控制器的 dm9k_sd[7:0] 共享
    output wire sl811_wr_n,
    output wire sl811_rd_n,
    output wire sl811_cs_n,
    output wire sl811_rst_n,
    output wire sl811_dack_n,
    input  wire sl811_intrq,
    input  wire sl811_drq_n,

    // 网络控制器信号，参考 DM9000A 芯片手册
    output wire dm9k_cmd,
    inout wire [15:0] dm9k_sd,
    output wire dm9k_iow_n,
    output wire dm9k_ior_n,
    output wire dm9k_cs_n,
    output wire dm9k_pwrst_n,
    input wire dm9k_int,

    // 图像输出信号
    output wire [2:0] video_red,    // 红色像素，3 位
    output wire [2:0] video_green,  // 绿色像素，3 位
    output wire [1:0] video_blue,   // 蓝色像素，2 位
    output wire       video_hsync,  // 行同步（水平同步）信号
    output wire       video_vsync,  // 场同步（垂直同步）信号
    output wire       video_clk,    // 像素时钟输出
    output wire       video_de      // 行数据有效信号，用于区分消隐区
);

  /* =========== Demo code begin =========== */

  // PLL 分频示例
  logic locked, clk_10M, clk_20M;
  pll_example clock_gen (
      // Clock in ports
      .clk_in1(clk_50M),  // 外部时钟输入
      // Clock out ports
      .clk_out1(clk_10M),  // 时钟输出 1，频率在 IP 配置界面中设置
      .clk_out2(clk_20M),  // 时钟输出 2，频率在 IP 配置界面中设置
      // Status and control signals
      .reset(reset_btn),  // PLL 复位输入
      .locked(locked)  // PLL 锁定指示输出，"1"表示时钟稳定，
                       // 后级电路复位信号应当由它生成（见下）
  );

  logic reset_of_clk10M;
  // 异步复位，同步释放，将 locked 信号转为后级电路的复位 reset_of_clk10M
  always_ff @(posedge clk_10M or negedge locked) begin
    if (~locked) reset_of_clk10M <= 1'b1;
    else reset_of_clk10M <= 1'b0;
  end

  /* =========== Demo code end =========== */

  logic sys_clk;
  logic sys_rst;

  assign sys_clk = clk_10M;
  assign sys_rst = reset_of_clk10M;

  // 本实验不使用 CPLD 串口，禁用防止总线冲突
  assign uart_rdn = 1'b1;
  assign uart_wrn = 1'b1;

  // ============================================================
  // 流水线寄存器
  // ============================================================
  if_id_reg if_id_reg_r;
  id_ex_reg id_ex_reg_r;
  ex_mem_reg ex_mem_reg_r;
  mem_wb_reg mem_wb_reg_r;

  // ============================================================
  // Stall/Flush 信号
  // ============================================================
  stall_flush_in stall_flush_if_id_in;
  stall_flush_in stall_flush_id_ex_in;
  stall_flush_in stall_flush_ex_mem_in;
  stall_flush_in stall_flush_mem_wb_in;

  stall_flush_out stall_flush_if_out;
  stall_flush_out stall_flush_id_out;
  stall_flush_out stall_flush_exe_out;
  stall_flush_out stall_flush_mem_out;

  // ============================================================
  // 分支跳转信号
  // ============================================================
  logic [31:0] pc_jump;
  logic pc_jump_valid;

  // ============================================================
  // Wishbone 总线信号 - IF 和 MEM 到仲裁器
  // ============================================================
  // IF Master
  logic [31:0] if_wb_adr;
  logic [31:0] if_wb_dat_i;
  logic [31:0] if_wb_dat_o;
  logic if_wb_we;
  logic [3:0] if_wb_sel;
  logic if_wb_stb;
  logic if_wb_ack;
  logic if_wb_cyc;

  // MEM Master
  logic [31:0] mem_wb_adr;
  logic [31:0] mem_wb_dat_i;
  logic [31:0] mem_wb_dat_o;
  logic mem_wb_we;
  logic [3:0] mem_wb_sel;
  logic mem_wb_stb;
  logic mem_wb_ack;
  logic mem_wb_cyc;

  // 仲裁器输出（到 MUX）
  logic [31:0] arb_wb_adr;
  logic [31:0] arb_wb_dat_i;
  logic [31:0] arb_wb_dat_o;
  logic arb_wb_we;
  logic [3:0] arb_wb_sel;
  logic arb_wb_stb;
  logic arb_wb_ack;
  logic arb_wb_cyc;

  // ============================================================
  // 寄存器文件信号
  // ============================================================
  logic [4:0] rf_raddr_a;
  logic [4:0] rf_raddr_b;
  logic [31:0] rf_rdata_a;
  logic [31:0] rf_rdata_b;

  // ============================================================
  // Stall/Flush 控制器
  // ============================================================
  stall_flush_controller stall_flush_ctrl (
      .clk(sys_clk),
      .rst(sys_rst),

      .if_out_i(stall_flush_if_out),
      .if_id_in_o(stall_flush_if_id_in),

      .id_out_i(stall_flush_id_out),
      .id_ex_in_o(stall_flush_id_ex_in),

      .exe_out_i(stall_flush_exe_out),
      .exe_mem_in_o(stall_flush_ex_mem_in),

      .mem_out_i(stall_flush_mem_out),
      .mem_wb_in_o(stall_flush_mem_wb_in)
  );

  // ============================================================
  // IF 阶段
  // ============================================================
  cpu_if_master if_stage (
      .clk(sys_clk),
      .rst(sys_rst),

      .stall_flush_in_i(stall_flush_if_id_in),
      .stall_flush_out_o(stall_flush_if_out),

      .pc_jump_i(pc_jump),
      .pc_jump_valid_i(pc_jump_valid),

      // Wishbone 接口
      .wb_adr_o(if_wb_adr),
      .wb_dat_i(if_wb_dat_i),
      .wb_we_o(if_wb_we),
      .wb_sel_o(if_wb_sel),
      .wb_stb_o(if_wb_stb),
      .wb_ack_i(if_wb_ack),
      .wb_cyc_o(if_wb_cyc),

      .if_id_o(if_id_reg_r)
  );

  assign if_wb_dat_o = 32'b0;  // IF 只读不写

  // ============================================================
  // ID 阶段
  // ============================================================
  cpu_id_master id_stage (
      .clk(sys_clk),
      .rst(sys_rst),

      .stall_flush_in_i(stall_flush_id_ex_in),
      .stall_flush_out_o(stall_flush_id_out),

      .if_id_i(if_id_reg_r),

      // 寄存器文件读端口
      .rf_raddr_a_o(rf_raddr_a),
      .rf_raddr_b_o(rf_raddr_b),
      .rf_rdata_a_i(rf_rdata_a),
      .rf_rdata_b_i(rf_rdata_b),

      // 数据冲突检测信号
      .exe_mem_wen_i(ex_mem_reg_r.rf_wen),
      .exe_mem_waddr_i(ex_mem_reg_r.rf_waddr),
      .mem_wb_wen_i(mem_wb_reg_r.rf_wen),
      .mem_wb_waddr_i(mem_wb_reg_r.rf_waddr),
      .wb_wen_i(1'b0),
      .wb_waddr_i(5'b0),

      .id_ex_o(id_ex_reg_r)
  );

  // ============================================================
  // EXE 阶段
  // ============================================================
  cpu_exe_master exe_stage (
      .clk(sys_clk),
      .rst(sys_rst),

      .stall_flush_in_i(stall_flush_ex_mem_in),
      .stall_flush_out_o(stall_flush_exe_out),

      .id_ex_i(id_ex_reg_r),

      // WB 阶段数据前递
      .wb_rf_wdata_i(mem_wb_reg_r.rf_wdata),
      .wb_rf_waddr_i(mem_wb_reg_r.rf_waddr),
      .wb_rf_wen_i(mem_wb_reg_r.rf_wen),

      // 分支跳转
      .pc_jump_o(pc_jump),
      .pc_jump_valid_o(pc_jump_valid),

      .ex_mem_o(ex_mem_reg_r)
  );

  // ============================================================
  // MEM 阶段
  // ============================================================
  cpu_mem_master mem_stage (
      .clk(sys_clk),
      .rst(sys_rst),

      .stall_flush_in_i(stall_flush_mem_wb_in),
      .stall_flush_out_o(stall_flush_mem_out),

      .ex_mem_i(ex_mem_reg_r),

      // Wishbone 接口
      .wb_adr_o(mem_wb_adr),
      .wb_dat_i(mem_wb_dat_i),
      .wb_dat_o(mem_wb_dat_o),
      .wb_we_o(mem_wb_we),
      .wb_sel_o(mem_wb_sel),
      .wb_stb_o(mem_wb_stb),
      .wb_ack_i(mem_wb_ack),
      .wb_cyc_o(mem_wb_cyc),

      .mem_wb_o(mem_wb_reg_r)
  );

  // ============================================================
  // 寄存器文件
  // ============================================================
  register_file regfile (
      .clk(sys_clk),
      .reset(sys_rst),

      // 写端口
      .waddr(mem_wb_reg_r.rf_waddr),
      .wdata(mem_wb_reg_r.rf_wdata),
      .we(mem_wb_reg_r.rf_wen),

      // 读端口 A
      .raddr_a(rf_raddr_a),
      .rdata_a(rf_rdata_a),

      // 读端口 B
      .raddr_b(rf_raddr_b),
      .rdata_b(rf_rdata_b)
  );

  // ============================================================
  // Wishbone 仲裁器（IF 和 MEM）
  // ============================================================
  wb_arbiter_2 #(
      .DATA_WIDTH(32),
      .ADDR_WIDTH(32),
      .SELECT_WIDTH(4),
      .ARB_TYPE_ROUND_ROBIN(0),
      .ARB_LSB_HIGH_PRIORITY(1)  // Master 0 (MEM) 优先级更高
  ) wb_arbiter (
      .clk(sys_clk),
      .rst(sys_rst),

      // Master 0: MEM (高优先级)
      .wbm0_adr_i(mem_wb_adr),
      .wbm0_dat_i(mem_wb_dat_o),
      .wbm0_dat_o(mem_wb_dat_i),
      .wbm0_we_i(mem_wb_we),
      .wbm0_sel_i(mem_wb_sel),
      .wbm0_stb_i(mem_wb_stb),
      .wbm0_ack_o(mem_wb_ack),
      .wbm0_err_o(),
      .wbm0_rty_o(),
      .wbm0_cyc_i(mem_wb_cyc),

      // Master 1: IF (低优先级)
      .wbm1_adr_i(if_wb_adr),
      .wbm1_dat_i(if_wb_dat_o),
      .wbm1_dat_o(if_wb_dat_i),
      .wbm1_we_i(if_wb_we),
      .wbm1_sel_i(if_wb_sel),
      .wbm1_stb_i(if_wb_stb),
      .wbm1_ack_o(if_wb_ack),
      .wbm1_err_o(),
      .wbm1_rty_o(),
      .wbm1_cyc_i(if_wb_cyc),

      // Slave: 到 MUX
      .wbs_adr_o(arb_wb_adr),
      .wbs_dat_i(arb_wb_dat_i),
      .wbs_dat_o(arb_wb_dat_o),
      .wbs_we_o(arb_wb_we),
      .wbs_sel_o(arb_wb_sel),
      .wbs_stb_o(arb_wb_stb),
      .wbs_ack_i(arb_wb_ack),
      .wbs_err_i(1'b0),
      .wbs_rty_i(1'b0),
      .wbs_cyc_o(arb_wb_cyc)
  );

  /* =========== Wishbone MUX begin =========== */
  // Wishbone MUX (仲裁器) => 外设 Slaves
  logic wbs0_cyc_o;
  logic wbs0_stb_o;
  logic wbs0_ack_i;
  logic [31:0] wbs0_adr_o;
  logic [31:0] wbs0_dat_o;
  logic [31:0] wbs0_dat_i;
  logic [3:0] wbs0_sel_o;
  logic wbs0_we_o;

  logic wbs1_cyc_o;
  logic wbs1_stb_o;
  logic wbs1_ack_i;
  logic [31:0] wbs1_adr_o;
  logic [31:0] wbs1_dat_o;
  logic [31:0] wbs1_dat_i;
  logic [3:0] wbs1_sel_o;
  logic wbs1_we_o;

  logic wbs2_cyc_o;
  logic wbs2_stb_o;
  logic wbs2_ack_i;
  logic [31:0] wbs2_adr_o;
  logic [31:0] wbs2_dat_o;
  logic [31:0] wbs2_dat_i;
  logic [3:0] wbs2_sel_o;
  logic wbs2_we_o;

  wb_mux_3 wb_mux (
      .clk(sys_clk),
      .rst(sys_rst),

      // Master interface (from arbiter)
      .wbm_adr_i(arb_wb_adr),
      .wbm_dat_i(arb_wb_dat_o),
      .wbm_dat_o(arb_wb_dat_i),
      .wbm_we_i(arb_wb_we),
      .wbm_sel_i(arb_wb_sel),
      .wbm_stb_i(arb_wb_stb),
      .wbm_ack_o(arb_wb_ack),
      .wbm_err_o(),
      .wbm_rty_o(),
      .wbm_cyc_i(arb_wb_cyc),

      // Slave interface 0 (to BaseRAM controller)
      // Address range: 0x8000_0000 ~ 0x803F_FFFF
      .wbs0_addr    (32'h8000_0000),
      .wbs0_addr_msk(32'hFFC0_0000),

      .wbs0_adr_o(wbs0_adr_o),
      .wbs0_dat_i(wbs0_dat_i),
      .wbs0_dat_o(wbs0_dat_o),
      .wbs0_we_o (wbs0_we_o),
      .wbs0_sel_o(wbs0_sel_o),
      .wbs0_stb_o(wbs0_stb_o),
      .wbs0_ack_i(wbs0_ack_i),
      .wbs0_err_i('0),
      .wbs0_rty_i('0),
      .wbs0_cyc_o(wbs0_cyc_o),

      // Slave interface 1 (to ExtRAM controller)
      // Address range: 0x8040_0000 ~ 0x807F_FFFF
      .wbs1_addr    (32'h8040_0000),
      .wbs1_addr_msk(32'hFFC0_0000),

      .wbs1_adr_o(wbs1_adr_o),
      .wbs1_dat_i(wbs1_dat_i),
      .wbs1_dat_o(wbs1_dat_o),
      .wbs1_we_o (wbs1_we_o),
      .wbs1_sel_o(wbs1_sel_o),
      .wbs1_stb_o(wbs1_stb_o),
      .wbs1_ack_i(wbs1_ack_i),
      .wbs1_err_i('0),
      .wbs1_rty_i('0),
      .wbs1_cyc_o(wbs1_cyc_o),

      // Slave interface 2 (to UART controller)
      // Address range: 0x1000_0000 ~ 0x1000_FFFF
      .wbs2_addr    (32'h1000_0000),
      .wbs2_addr_msk(32'hFFFF_0000),

      .wbs2_adr_o(wbs2_adr_o),
      .wbs2_dat_i(wbs2_dat_i),
      .wbs2_dat_o(wbs2_dat_o),
      .wbs2_we_o (wbs2_we_o),
      .wbs2_sel_o(wbs2_sel_o),
      .wbs2_stb_o(wbs2_stb_o),
      .wbs2_ack_i(wbs2_ack_i),
      .wbs2_err_i('0),
      .wbs2_rty_i('0),
      .wbs2_cyc_o(wbs2_cyc_o)
  );

  /* =========== Wishbone MUX end =========== */

  /* =========== Slaves begin =========== */
  sram_controller #(
      .SRAM_ADDR_WIDTH(20),
      .SRAM_DATA_WIDTH(32)
  ) sram_controller_base (
      .clk_i(sys_clk),
      .rst_i(sys_rst),

      // Wishbone slave (to MUX)
      .wb_cyc_i(wbs0_cyc_o),
      .wb_stb_i(wbs0_stb_o),
      .wb_ack_o(wbs0_ack_i),
      .wb_adr_i(wbs0_adr_o),
      .wb_dat_i(wbs0_dat_o),
      .wb_dat_o(wbs0_dat_i),
      .wb_sel_i(wbs0_sel_o),
      .wb_we_i (wbs0_we_o),

      // To SRAM chip
      .sram_addr(base_ram_addr),
      .sram_data(base_ram_data),
      .sram_ce_n(base_ram_ce_n),
      .sram_oe_n(base_ram_oe_n),
      .sram_we_n(base_ram_we_n),
      .sram_be_n(base_ram_be_n)
  );

  sram_controller #(
      .SRAM_ADDR_WIDTH(20),
      .SRAM_DATA_WIDTH(32)
  ) sram_controller_ext (
      .clk_i(sys_clk),
      .rst_i(sys_rst),

      // Wishbone slave (to MUX)
      .wb_cyc_i(wbs1_cyc_o),
      .wb_stb_i(wbs1_stb_o),
      .wb_ack_o(wbs1_ack_i),
      .wb_adr_i(wbs1_adr_o),
      .wb_dat_i(wbs1_dat_o),
      .wb_dat_o(wbs1_dat_i),
      .wb_sel_i(wbs1_sel_o),
      .wb_we_i (wbs1_we_o),

      // To SRAM chip
      .sram_addr(ext_ram_addr),
      .sram_data(ext_ram_data),
      .sram_ce_n(ext_ram_ce_n),
      .sram_oe_n(ext_ram_oe_n),
      .sram_we_n(ext_ram_we_n),
      .sram_be_n(ext_ram_be_n)
  );

  // 串口控制器模块
  // NOTE: 如果修改系统时钟频率，也需要修改此处的时钟频率参数
  uart_controller #(
      .CLK_FREQ(10_000_000),
      .BAUD    (115200)
  ) uart_controller (
      .clk_i(sys_clk),
      .rst_i(sys_rst),

      .wb_cyc_i(wbs2_cyc_o),
      .wb_stb_i(wbs2_stb_o),
      .wb_ack_o(wbs2_ack_i),
      .wb_adr_i(wbs2_adr_o),
      .wb_dat_i(wbs2_dat_o),
      .wb_dat_o(wbs2_dat_i),
      .wb_sel_i(wbs2_sel_o),
      .wb_we_i (wbs2_we_o),

      // to UART pins
      .uart_txd_o(txd),
      .uart_rxd_i(rxd)
  );

  /* =========== Slaves end =========== */

endmodule
