`default_nettype none

module lab5_top_ppl (
    input wire clk_50M,     // 50MHz 时钟输入
    input wire clk_11M0592, // 11.0592MHz 时钟输入（备用，可不用）

    input wire push_btn,  // BTN5 按钮开关，带消抖电路，按下时为 1
    input wire reset_btn, // BTN6 复位按钮，带消抖电路，按下时为 1

    input  wire [ 3:0] touch_btn,  // BTN1~BTN4，按钮开关，按下时为 1
    input  wire [31:0] dip_sw,     // 32 位拨码开关，拨到“ON”时为 1
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

  logic reset_of_clk50M;
  // 异步复位，同步释放，将 locked 信号转为后级电路的复位 reset_of_clk50M
  always_ff @(posedge clk_50M or negedge locked) begin
    if (~locked) reset_of_clk50M <= 1'b1;
    else reset_of_clk50M <= 1'b0;
  end

  // always_ff @(posedge clk_10M or posedge reset_of_clk50M) begin
  //   if (reset_of_clk50M) begin
  //     // Your Code
  //   end else begin
  //     // Your Code
  //   end
  // end

  // 不使用内存、串口时，禁用其使能信号
//   assign base_ram_ce_n = 1'b1;
//   assign base_ram_oe_n = 1'b1;
//   assign base_ram_we_n = 1'b1;

//   assign ext_ram_ce_n = 1'b1;
//   assign ext_ram_oe_n = 1'b1;
//   assign ext_ram_we_n = 1'b1;

//   assign uart_rdn = 1'b1;
//   assign uart_wrn = 1'b1;

  // // 数码管连接关系示意图，dpy1 同理
  // // p=dpy0[0] // ---a---
  // // c=dpy0[1] // |     |
  // // d=dpy0[2] // f     b
  // // e=dpy0[3] // |     |
  // // b=dpy0[4] // ---g---
  // // a=dpy0[5] // |     |
  // // f=dpy0[6] // e     c
  // // g=dpy0[7] // |     |
  // //           // ---d---  p

  // // 7 段数码管译码器演示，将 number 用 16 进制显示在数码管上面
  // logic [7:0] number;
  // SEG7_LUT segL (
  //     .oSEG1(dpy0),
  //     .iDIG (number[3:0])
  // );  // dpy0 是低位数码管
  // SEG7_LUT segH (
  //     .oSEG1(dpy1),
  //     .iDIG (number[7:4])
  // );  // dpy1 是高位数码管

  // logic [15:0] led_bits;
  // assign leds = led_bits;

  // always_ff @(posedge clk_50M) begin
  //   if (reset_btn) begin  // 复位按下，设置 LED 为初始值
  //     led_bits <= 16'h1;
  //   end else if (push_btn) begin  // 每次按下按钮开关，LED 循环左移
  //     led_bits <= {led_bits[14:0], led_bits[15]};
  //   end
  // end

  // // 直连串口接收发送演示，从直连串口收到的数据再发送出去
  // logic [7:0] ext_uart_rx;
  // logic [7:0] ext_uart_buffer, ext_uart_tx;
  // logic ext_uart_ready, ext_uart_clear, ext_uart_busy;
  // logic ext_uart_start, ext_uart_avai;

  // assign number = ext_uart_buffer;

  // // 接收模块，9600 无检验位
  // async_receiver #(
  //     .ClkFrequency(50000000),
  //     .Baud(9600)
  // ) ext_uart_r (
  //     .clk           (clk_50M),         // 外部时钟信号
  //     .RxD           (rxd),             // 外部串行信号输入
  //     .RxD_data_ready(ext_uart_ready),  // 数据接收到标志
  //     .RxD_clear     (ext_uart_clear),  // 清除接收标志
  //     .RxD_data      (ext_uart_rx)      // 接收到的一字节数据
  // );

  // assign ext_uart_clear = ext_uart_ready; // 收到数据的同时，清除标志，因为数据已取到 ext_uart_buffer 中
  // always_ff @(posedge clk_50M) begin  // 接收到缓冲区 ext_uart_buffer
  //   if (ext_uart_ready) begin
  //     ext_uart_buffer <= ext_uart_rx;
  //     ext_uart_avai   <= 1;
  //   end else if (!ext_uart_busy && ext_uart_avai) begin
  //     ext_uart_avai <= 0;
  //   end
  // end
  // always_ff @(posedge clk_50M) begin  // 将缓冲区 ext_uart_buffer 发送出去
  //   if (!ext_uart_busy && ext_uart_avai) begin
  //     ext_uart_tx <= ext_uart_buffer;
  //     ext_uart_start <= 1;
  //   end else begin
  //     ext_uart_start <= 0;
  //   end
  // end

  // // 发送模块，9600 无检验位
  // async_transmitter #(
  //     .ClkFrequency(50000000),
  //     .Baud(9600)
  // ) ext_uart_t (
  //     .clk      (clk_50M),         // 外部时钟信号
  //     .TxD      (txd),             // 串行信号输出
  //     .TxD_busy (ext_uart_busy),   // 发送器忙状态指示
  //     .TxD_start(ext_uart_start),  // 开始发送信号
  //     .TxD_data (ext_uart_tx)      // 待发送的数据
  // );

  // // 图像输出演示，分辨率 800x600@72Hz，像素时钟为 50MHz
  // logic [11:0] hdata;
  // assign video_red   = hdata < 266 ? 3'b111 : 0;  // 红色竖条
  // assign video_green = hdata < 532 && hdata >= 266 ? 3'b111 : 0;  // 绿色竖条
  // assign video_blue  = hdata >= 532 ? 2'b11 : 0;  // 蓝色竖条
  // assign video_clk   = clk_50M;
  // vga #(12, 800, 856, 976, 1040, 600, 637, 643, 666, 1, 1) vga800x600at72 (
  //     .clk        (clk_50M),
  //     .hdata      (hdata),        // 横坐标
  //     .vdata      (),             // 纵坐标
  //     .hsync      (video_hsync),
  //     .vsync      (video_vsync),
  //     .data_enable(video_de)
  // );
  /* =========== Demo code end =========== */

logic sys_clk;
logic sys_rst;

assign sys_clk = clk_50M;
assign sys_rst = reset_of_clk50M;

// 本实验不使用 CPLD 串口，禁用防止总线冲突
assign uart_rdn = 1'b1;
assign uart_wrn = 1'b1;

logic jump_i;

logic if_stall_i, if_flush_o, if_stall_o;
logic id_flush_o, id_stall_o;
logic exe_flush_o, exe_stall_o;
logic icache_flush_o;
logic mem_stall_i, mem_flush_o, mem_stall_o;

logic if_id_stall_i, if_id_bubble_i, id_exe_stall_i, id_exe_bubble_i;
logic exe_mem_stall_i, exe_mem_bubble_i, mem_wb_stall_i, mem_wb_bubble_i;



logic        if_wb_cyc_o, mem_wb_cyc_o;
logic        if_wb_stb_o, mem_wb_stb_o;
logic        if_wb_ack_i, mem_wb_ack_i;
logic [31:0] if_wb_adr_o, mem_wb_adr_o;
logic [31:0] if_wb_dat_o, mem_wb_dat_o;
logic [31:0] if_wb_dat_i, mem_wb_dat_i;
logic [ 3:0] if_wb_sel_o, mem_wb_sel_o;
logic        if_wb_we_o, mem_wb_we_o;

logic        valid;

logic [31:0] if_pc_i, if_pc_o, pc_jump_i;
logic [31:0] if_inst_o;

// BTB signals
logic btb_update_valid;
logic [31:0] btb_update_pc;
logic btb_actual_taken;
logic [31:0] btb_actual_target;
// pred_jump is passed through pipeline registers: IF -> ID -> EXE
logic if_pred_jump;
logic id_pred_jump;
logic exe_pred_jump;

IF_master #(
    .ADDR_WIDTH(32),
    .DATA_WIDTH(32)
) sys_IF_master(
    .clk_i(sys_clk),
    .rst_i(sys_rst),

    .pc_jump_i(pc_jump_i),
    .jump_i(jump_i),
    .if_stall_i(if_stall_i),
    .icache_flush_i(icache_flush_o),

    .pc_o(if_pc_o),
    .inst_o(if_inst_o),
    .if_stall_o(if_stall_o),
    .if_flush_o(if_flush_o),

    .wb_cyc_o(if_wb_cyc_o),
    .wb_stb_o(if_wb_stb_o),
    .wb_ack_i(if_wb_ack_i),
    .wb_adr_o(if_wb_adr_o),
    .wb_dat_o(if_wb_dat_o),
    .wb_dat_i(if_wb_dat_i),
    .wb_sel_o(if_wb_sel_o),
    .wb_we_o(if_wb_we_o),
    .valid(valid),

    .btb_flush_i(icache_flush_o),
    .btb_update_valid_i(btb_update_valid),
    .btb_update_pc_i(btb_update_pc),
    .btb_actual_taken_i(btb_actual_taken),
    .btb_actual_target_i(btb_actual_target),
    .pred_jump_o(if_pred_jump)
);

logic [31:0] id_pc_i;
logic [31:0] id_inst_i;

if_id sys_if_id(
    .clk_i(sys_clk),
    .rst_i(sys_rst),

    .pc_i(if_pc_o),
    .inst_i(if_inst_o),
    .pred_jump_i(if_pred_jump),
    .valid(valid),

    .pc_o(id_pc_i),
    .inst_o(id_inst_i),
    .pred_jump_o(id_pred_jump),

    .stall_i(if_id_stall_i),
    .bubble_i(if_id_bubble_i)
);

logic [31:0] id_pc_o;
logic [31:0] id_inst_o;
logic id_rf_wen_o, id_mem_en_o;
logic [3:0] id_imm_type_o;
logic [4:0] id_alu_op_o;
logic [3:0] id_instr_type_o;
logic id_use_rs2_o;
logic [4:0] id_rf_waddr_i, id_rf_waddr_o, id_rf_raddr_a_o, id_rf_raddr_b_o;
logic id_rf_we_i;
logic [31:0] id_rf_wdata_i, id_rf_rdata_a_o, id_rf_rdata_b_o;
logic [4:0] exe_rf_waddr_i, mem_rf_waddr_i, wb_rf_waddr_i;
logic [4:0] exe_rf_waddr_o, mem_rf_waddr_o;
logic [7:0] id_instr_code_o;

ID sys_ID(
    .clk_i(sys_clk),
    .rst_i(sys_rst),

    .pc_i(id_pc_i),
    .inst_i(id_inst_i),
    .exe_rf_waddr_i(exe_rf_waddr_o),
    .mem_rf_waddr_i(mem_rf_waddr_i),
    .wb_rf_waddr_i(wb_rf_waddr_i),
    .mem_rf_waddr_o(mem_rf_waddr_o),

    .pc_o(id_pc_o),
    .inst_o(id_inst_o),
    .rf_raddr_a_o(id_rf_raddr_a_o),
    .rf_raddr_b_o(id_rf_raddr_b_o),
    .rf_waddr_o(id_rf_waddr_o),
    .imm_type_o(id_imm_type_o),
    .alu_op_o(id_alu_op_o),
    .instr_type_o(id_instr_type_o),
    .instr_code_o(id_instr_code_o),
    .use_rs2_o(id_use_rs2_o),
    .mem_en_o(id_mem_en_o),
    .rf_wen_o(id_rf_wen_o),
    .id_stall_o(id_stall_o),
    .id_flush_o(id_flush_o)
);

ppl_regfile sys_RegisterFile(
    .clk(sys_clk),
    .reset(sys_rst),
    .rf_raddr_a(id_rf_raddr_a_o),
    .rf_rdata_a(id_rf_rdata_a_o),
    .rf_raddr_b(id_rf_raddr_b_o),
    .rf_rdata_b(id_rf_rdata_b_o),
    .rf_waddr(id_rf_waddr_i),
    .rf_wdata(id_rf_wdata_i),
    .rf_we(id_rf_we_i)
);

logic [31:0] exe_pc_i;
logic [31:0] exe_inst_i;
logic [31:0] exe_rf_rdata_a_i, exe_rf_rdata_b_i;
logic [3:0] exe_imm_type_i;
logic [4:0] exe_alu_op_i;
logic [3:0] exe_instr_type_i;
logic [7:0] exe_instr_code_i;
logic exe_use_rs2_i, exe_rf_wen_i, exe_mem_en_i;

id_ex sys_id_ex(
    .clk_i(sys_clk),
    .rst_i(sys_rst),

    .stall_i(id_exe_stall_i),
    .bubble_i(id_exe_bubble_i),
    .pred_jump_i(id_pred_jump),

    .pc_i(id_pc_o),
    .inst_i(id_inst_o),
    .rf_rdata_a_i(id_rf_rdata_a_o),
    .rf_rdata_b_i(id_rf_rdata_b_o),
    .rf_waddr_i(id_rf_waddr_o),
    .imm_type_i(id_imm_type_o),
    .alu_op_i(id_alu_op_o),
    .instr_type_i(id_instr_type_o),
    .instr_code_i(id_instr_code_o),
    .use_rs2_i(id_use_rs2_o),
    .rf_wen_i(id_rf_wen_o),
    .mem_en_i(id_mem_en_o),

    .pc_o(exe_pc_i),
    .inst_o(exe_inst_i),
    .rf_rdata_a_o(exe_rf_rdata_a_i),
    .rf_rdata_b_o(exe_rf_rdata_b_i),
    .rf_waddr_o(exe_rf_waddr_i),
    .imm_type_o(exe_imm_type_i),
    .alu_op_o(exe_alu_op_i),
    .instr_type_o(exe_instr_type_i),
    .instr_code_o(exe_instr_code_i),
    .use_rs2_o(exe_use_rs2_i),
    .rf_wen_o(exe_rf_wen_i),
    .mem_en_o(exe_mem_en_i),
    .pred_jump_o(exe_pred_jump)
);

logic [31:0] exe_pc_o;
logic [31:0] exe_inst_o;
logic [31:0] exe_imm_o;
logic [7:0] exe_instr_code_o;
logic [31:0] exe_rf_wdata_o;

logic [31:0] exe_mem_addr_o, exe_mem_data_o;
logic exe_rf_wen_o, exe_mem_en_o;

logic [31:0] exe_alu_a_o, exe_alu_b_o, exe_alu_y_o;
logic [4:0] exe_alu_op_o;

EXE sys_EXE(
    .clk_i(sys_clk),
    .rst_i(sys_rst),

    .pc_i(exe_pc_i),
    .inst_i(exe_inst_i),
    .rf_rdata_a_i(exe_rf_rdata_a_i),
    .rf_rdata_b_i(exe_rf_rdata_b_i),
    .rf_waddr_i(exe_rf_waddr_i),
    .imm_type_i(exe_imm_type_i),
    .alu_op_i(exe_alu_op_i),
    .instr_type_i(exe_instr_type_i),
    .instr_code_i(exe_instr_code_i),
    .use_rs2_i(exe_use_rs2_i),
    .rf_wen_i(exe_rf_wen_i),
    .mem_en_i(exe_mem_en_i),
    .mem_stall_i(mem_stall_o),

    .pc_o(exe_pc_o),
    .inst_o(exe_inst_o),
    .imm_o(exe_imm_o),
    .instr_code_o(exe_instr_code_o),
    .mem_en_o(exe_mem_en_o),
    .rf_wen_o(exe_rf_wen_o),
    .mem_data_o(exe_mem_data_o),
    .mem_addr_o(exe_mem_addr_o),
    .alu_a_o(exe_alu_a_o),
    .alu_b_o(exe_alu_b_o),
    .alu_op_o(exe_alu_op_o),
    // Forwarding signals
    .mem_rf_wen_i(mem_rf_wen_i),
    .mem_rf_waddr_i(mem_rf_waddr_i),
    .mem_rf_wdata_i(mem_rf_wdata_o),
    .wb_rf_wen_i(wb_rf_wen_i),
    .wb_rf_waddr_i(wb_rf_waddr_i),
    .wb_rf_wdata_i(wb_rf_wdata_i),
    .exe_stall_o(exe_stall_o),
    .exe_flush_o(exe_flush_o),
    .rf_waddr_o(exe_rf_waddr_o),
    .jump_o(jump_i),
    .pc_jump_o(pc_jump_i),
    .icache_flush_o(icache_flush_o),
    // BTB update signals
    .pred_jump_i(exe_pred_jump),
    .btb_update_valid_o(btb_update_valid),
    .btb_update_pc_o(btb_update_pc),
    .btb_actual_taken_o(btb_actual_taken),
    .btb_actual_target_o(btb_actual_target)
);

ppl_alu sys_myalu(
    .reset(sys_rst),
    .alu_a(exe_alu_a_o),
    .alu_b(exe_alu_b_o),
    .alu_op(exe_alu_op_o),
    .alu_y(exe_alu_y_o) 
);

logic [31:0] mem_pc_i;
logic [31:0] mem_inst_i;
logic [31:0] mem_imm_i;
logic [31:0] mem_rf_wdata_i;

logic [31:0] mem_mem_addr_i, mem_mem_data_i;
logic mem_rf_wen_i, mem_mem_en_i;

logic [31:0] mem_alu_y_i;
logic [3:0] mem_imm_type_i;
logic [3:0] mem_instr_type_i;
logic [7:0] mem_instr_code_i;

ex_mem sys_ex_mem(
    .clk_i(sys_clk),
    .rst_i(sys_rst),

    .stall_i(exe_mem_stall_i),
    .bubble_i(exe_mem_bubble_i),

    .pc_i(exe_pc_o),
    .alu_result_i(exe_alu_y_o),
    .mem_addr_i(exe_mem_addr_o),
    .mem_data_i(exe_mem_data_o),
    .inst_i(exe_inst_o),
    .imm_i(exe_imm_o),
    .imm_type_i(exe_imm_type_i),
    .instr_type_i(exe_instr_type_i),
    .instr_code_i(exe_instr_code_o),
    .mem_en_i(exe_mem_en_o),
    .rf_wen_i(exe_rf_wen_o),
    .rf_waddr_i(exe_rf_waddr_o),

    .pc_o(mem_pc_i),
    .alu_result_o(mem_alu_y_i),
    .mem_addr_o(mem_mem_addr_i),
    .mem_data_o(mem_mem_data_i),
    .inst_o(mem_inst_i),
    .imm_o(mem_imm_i),
    .imm_type_o(mem_imm_type_i),
    .instr_type_o(mem_instr_type_i),
    .instr_code_o(mem_instr_code_i),
    .mem_en_o(mem_mem_en_i),
    .rf_wen_o(mem_rf_wen_i),
    .rf_waddr_o(mem_rf_waddr_i)
);

logic [31:0] mem_pc_o, mem_inst_o, mem_rf_wdata_o;
logic mem_rf_wen_o;

MEM_master #(
    .ADDR_WIDTH(32),
    .DATA_WIDTH(32)
)sys_MEM_master(
    .clk_i(sys_clk),
    .rst_i(sys_rst),

    .pc_i(mem_pc_i),
    .imm_i(mem_imm_i),  // imm generated in EXE stage
    .inst_i(mem_inst_i),
    .rf_waddr_i(mem_rf_waddr_i),
    .mem_addr_i(mem_mem_addr_i),
    .mem_data_i(mem_mem_data_i),
    .wb_data_i(mem_wb_dat_i),
    .imm_type_i(mem_imm_type_i),
    .instr_type_i(mem_instr_type_i),
    .instr_code_i(mem_instr_code_i),
    .mem_en_i(mem_mem_en_i),
    .rf_wen_i(mem_rf_wen_i),
    .stall_i(mem_stall_i),
    .wb_ack_i(mem_wb_ack_i),
    .alu_y_i(mem_alu_y_i),

    .pc_o(mem_pc_o),
    .inst_o(mem_inst_o),
    .rf_waddr_o(mem_rf_waddr_o),
    .wb_cyc_o(mem_wb_cyc_o),
    .wb_stb_o(mem_wb_stb_o),
    .wb_addr_o(mem_wb_adr_o),
    .wb_data_o(mem_wb_dat_o),
    .wb_sel_o(mem_wb_sel_o),
    .wb_we_o(mem_wb_we_o),
    .rf_wdata_o(mem_rf_wdata_o),
    .rf_wen_o(mem_rf_wen_o),
    .mem_stall_o(mem_stall_o),
    .mem_flush_o(mem_flush_o)
);

logic [31:0] wb_pc_i;
logic [31:0] wb_inst_i;
logic [31:0] wb_rf_wdata_i;
logic        wb_rf_wen_i;

mem_wb sys_mem_wb(
    .clk_i(sys_clk),
    .rst_i(sys_rst),

    .pc_i(mem_pc_o),
    .rf_waddr_i(mem_rf_waddr_o),
    .rf_wdata_i(mem_rf_wdata_o),
    .inst_i(mem_inst_o),
    .rf_wen_i(mem_rf_wen_o),

    .pc_o(wb_pc_i),
    .rf_waddr_o(wb_rf_waddr_i),
    .rf_wdata_o(wb_rf_wdata_i),
    .inst_o(wb_inst_i),
    .rf_wen_o(wb_rf_wen_i), 
    .stall_i(mem_wb_stall_i)
);

WB sys_WB(
    .clk_i(sys_clk),
    .rst_i(sys_rst),

    .rf_wdata_i(wb_rf_wdata_i),
    .rf_waddr_i(wb_rf_waddr_i),
    .rf_wen_i(wb_rf_wen_i),
    .pc_i(wb_pc_i),
    .inst_i(wb_inst_i),

    .rf_waddr_o(id_rf_waddr_i),
    .rf_wdata_o(id_rf_wdata_i),
    .rf_wen_o(id_rf_we_i)

);

pplmanager sys_pplmanager(

    .clk_i(sys_clk),
    .rst_i(sys_rst),

    .if_stall_i(if_stall_o),
    .if_flush_i(if_flush_o),
    .id_stall_i(id_stall_o),
    .id_flush_i(id_flush_o),
    .exe_stall_i(exe_stall_o),
    .exe_flush_i(exe_flush_o),
    .mem_stall_i(mem_stall_o),
    .mem_flush_i(mem_flush_o),

    .if_stall_o(if_stall_i),
    .mem_stall_o(mem_stall_i),
    .if_id_stall_o(if_id_stall_i),
    .if_id_bubble_o(if_id_bubble_i),
    .id_exe_stall_o(id_exe_stall_i),
    .id_exe_bubble_o(id_exe_bubble_i),
    .exe_mem_stall_o(exe_mem_stall_i),
    .exe_mem_bubble_o(exe_mem_bubble_i),
    .mem_wb_stall_o(mem_wb_stall_i),
    .mem_wb_bubble_o(mem_wb_bubble_i)

  
);


  logic        wbm_cyc_o;
  logic        wbm_stb_o;
  logic        wbm_ack_i;
  logic [31:0] wbm_adr_o;
  logic [31:0] wbm_dat_o;
  logic [31:0] wbm_dat_i;
  logic [ 3:0] wbm_sel_o;
  logic        wbm_we_o; 

wb_arbiter_2 #(
      .ADDR_WIDTH(32),
      .DATA_WIDTH(32),
      .SELECT_WIDTH(4),
      .ARB_TYPE_ROUND_ROBIN(0),
      .ARB_LSB_HIGH_PRIORITY(1)
  ) u_wb_arbiter_2 (
      .clk(sys_clk),
      .rst(sys_rst),
      .wbm0_adr_i(if_wb_adr_o),
      .wbm0_dat_i(if_wb_dat_o),
      .wbm0_dat_o(if_wb_dat_i),
      .wbm0_sel_i(if_wb_sel_o),
      .wbm0_we_i(if_wb_we_o),
      .wbm0_cyc_i(if_wb_cyc_o),
      .wbm0_stb_i(if_wb_stb_o),
      .wbm0_ack_o(if_wb_ack_i),
      
      .wbm1_adr_i(mem_wb_adr_o),
      .wbm1_dat_i(mem_wb_dat_o),
      .wbm1_dat_o(mem_wb_dat_i),
      .wbm1_sel_i(mem_wb_sel_o),
      .wbm1_we_i(mem_wb_we_o),
      .wbm1_cyc_i(mem_wb_cyc_o),
      .wbm1_stb_i(mem_wb_stb_o),
      .wbm1_ack_o(mem_wb_ack_i),
      
      .wbs_adr_o(wbm_adr_o),
      .wbs_dat_o(wbm_dat_o),
      .wbs_dat_i(wbm_dat_i),
      .wbs_sel_o(wbm_sel_o),
      .wbs_we_o(wbm_we_o),
      .wbs_cyc_o(wbm_cyc_o),
      .wbs_stb_o(wbm_stb_o),
      .wbs_ack_i(wbm_ack_i)
  );

  /* =========== Arbiter end =========== */
  
  /* =========== MUX begin =========== */
  // Wishbone MUX (Masters) => bus slaves
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

      // Master interface (to Lab5 master)
      .wbm_adr_i(wbm_adr_o),
      .wbm_dat_i(wbm_dat_o),
      .wbm_dat_o(wbm_dat_i),
      .wbm_we_i (wbm_we_o),
      .wbm_sel_i(wbm_sel_o),
      .wbm_stb_i(wbm_stb_o),
      .wbm_ack_o(wbm_ack_i),
      .wbm_err_o(),
      .wbm_rty_o(),
      .wbm_cyc_i(wbm_cyc_o),

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

  /* =========== MUX end =========== */

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
      .CLK_FREQ(50_000_000),
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