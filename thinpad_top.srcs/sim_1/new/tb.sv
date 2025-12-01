`timescale 1ns / 1ps
module lab5_tb;

  wire clk_50M, clk_11M0592;

  reg push_btn;   // BTN5 按钮开关，带消抖电路，按下时为 1
  reg reset_btn;  // BTN6 复位按钮，带消抖电路，按下时为 1

  reg [3:0] touch_btn; // BTN1~BTN4，按钮开关，按下时为 1
  reg [31:0] dip_sw;   // 32 位拨码开关，拨到“ON”时为 1

  wire [15:0] leds;  // 16 位 LED，输出时 1 点亮
  wire [7:0] dpy0;   // 数码管低位信号，包括小数点，输出 1 点亮
  wire [7:0] dpy1;   // 数码管高位信号，包括小数点，输出 1 点亮

  wire [31:0] base_ram_data;  // BaseRAM 数据，低 8 位与 CPLD 串口控制器共享
  wire [19:0] base_ram_addr;  // BaseRAM 地址
  wire[3:0] base_ram_be_n;    // BaseRAM 字节使能，低有效。如果不使用字节使能，请保持为 0
  wire base_ram_ce_n;  // BaseRAM 片选，低有效
  wire base_ram_oe_n;  // BaseRAM 读使能，低有效
  wire base_ram_we_n;  // BaseRAM 写使能，低有效

  wire [31:0] ext_ram_data;  // ExtRAM 数据
  wire [19:0] ext_ram_addr;  // ExtRAM 地址
  wire[3:0] ext_ram_be_n;    // ExtRAM 字节使能，低有效。如果不使用字节使能，请保持为 0
  wire ext_ram_ce_n;  // ExtRAM 片选，低有效
  wire ext_ram_oe_n;  // ExtRAM 读使能，低有效
  wire ext_ram_we_n;  // ExtRAM 写使能，低有效

  wire txd;  // 直连串口发送端
  reg rxd;  // 直连串口接收端

  // CPLD 串口
  wire uart_rdn;  // 读串口信号，低有效
  wire uart_wrn;  // 写串口信号，低有效
  wire uart_dataready;  // 串口数据准备好
  wire uart_tbre;  // 发送数据标志
  wire uart_tsre;  // 数据发送完毕标志

  // Windows 需要注意路径分隔符的转义，例如 "D:\\foo\\bar.bin"
//  parameter BASE_RAM_INIT_FILE = "C:\\Users\\user\\Downloads\\rv-2025\\rv-2025\\asmcode\\simple_uart_test.bin"; // BaseRAM 初始化文件，请修改为实际的绝对路径
  // parameter BASE_RAM_INIT_FILE = "C:\\Users\\user\\Downloads\\rv-2025\\rv-2025\\asmcode\\tb.bin"; // BaseRAM 初始化文件，请修改为实际的绝对路径
  // parameter BASE_RAM_INIT_FILE = "C:\\Users\\user\\Downloads\\rv-2025\\rv-2025\\asmcode\\test.bin"; // BaseRAM 初始化文件，请修改为实际的绝对路径
  parameter BASE_RAM_INIT_FILE = "C:\\Users\\user\\xwechat_files\\wxid_3dsbd2s4ysbp12_58d5\\msg\\file\\2025-11\\kernel-no16550.bin"; // BaseRAM 初始化文件，请修改为实际的绝对路径
  parameter EXT_RAM_INIT_FILE = "/tmp/eram.bin";  // ExtRAM 初始化文件，请修改为实际的绝对路径
  // =========================================================
  // 串口发送任务
  // =========================================================
  localparam UART_BIT_PERIOD = 8680; // 115200 bps

  // 发送 1 字节
  task uart_send_byte(input [7:0] data);
    integer i;
    begin
      rxd = 1'b0; // Start Bit
      #(UART_BIT_PERIOD);
      for (i = 0; i < 8; i++) begin
        rxd = data[i]; // LSB First
        #(UART_BIT_PERIOD);
      end
      rxd = 1'b1; // Stop Bit
      #(UART_BIT_PERIOD);
      #(UART_BIT_PERIOD); // Gap
    end
  endtask

  // 发送 4 字节 (小端序)
  task uart_send_word(input [31:0] word);
    begin
      uart_send_byte(word[7:0]);
      uart_send_byte(word[15:8]);
      uart_send_byte(word[23:16]);
      uart_send_byte(word[31:24]);
    end
  endtask

  // =========================================================
  // 用户程序数据准备
  // =========================================================

  
 reg [31:0] prog_instr [6]; // 5 条指令 (20 字节)

 initial begin
   // [0x80100000] li t0, 0xdeadbeef -> 需要两条指令
   // lui t0, 0xdeadc (因为 0xeef 是负数，高位要进位)
   prog_instr[0] = 32'h05a00513; 
   prog_instr[1] = 32'h80100337; 
   prog_instr[2] = 32'h10a30023; 
   prog_instr[3] = 32'h00008067;
   prog_instr[4] = 32'h100002b7; 
   prog_instr[5] = 32'h00a28023; 
 end

  // =========================================================
  // 主测试流程
  // =========================================================
  initial begin
    // 1. 初始化
    touch_btn = 0;
    reset_btn = 0;
    push_btn = 0;
    dip_sw = 0;
    rxd = 1'b1; // 空闲拉高

    #100;
    reset_btn = 1;
    #100;
    reset_btn = 0;

    $display("[Sim] System Reset. Waiting for Monitor to boot...");
    // 等待 Monitor 启动 (打印 Logo)
    repeat(150000) @(posedge clk_50M); 

    // -------------------------------------------------------------------------
    // 步骤 1: 发送 'A' (加载程序)
    // -------------------------------------------------------------------------
   $display("[Sim] Sending 'A' (Load Program)...");
   uart_send_byte("A"); // 0x41

   $display("[Sim] Sending Address: 0x80100000");
   uart_send_word(32'h80100000);

   $display("[Sim] Sending Length: 20 bytes (5 instructions)");
   uart_send_word(32'd16);

   $display("[Sim] Sending Instructions...");
   for (integer k = 0; k < 4; k = k + 1) begin
     uart_send_word(prog_instr[k]); // 注意这里调用的是 send_word (4字节)
   end

   // 等待 CPU 写内存
   $display("[Sim] Program loaded. Waiting...");

   $display("[Sim] Sending 'D' (Load Program)...");
   uart_send_byte("D"); // 0x41

   $display("[Sim] Loading Address: 0x80100000");
   uart_send_word(32'h80100000);

   $display("[Sim] Loading Length: 20 bytes (5 instructions)");
   uart_send_word(32'd16);
   repeat(100000) @(posedge clk_50M);

   // -------------------------------------------------------------------------
   // 步骤 2: 发送 'G' (运行程序)
   // -------------------------------------------------------------------------
   $display("[Sim] Sending 'G' (Execute Program)...");
   uart_send_byte("G"); // 0x47

   $display("[Sim] Sending Jump Address: 0x80100000");
   uart_send_word(32'h80100000);
   repeat(100000) @(posedge clk_50M);
   

    $display("[Sim] Sending 'D' (Load Program)...");
   uart_send_byte("D"); // 0x41

   $display("[Sim] Loading Address: 0x80100100");
   uart_send_word(32'h80100100);

   $display("[Sim] Loading Length: 4 bytes");
   uart_send_word(32'd4);
   repeat(100000) @(posedge clk_50M);
    
   // 让它跑一会儿，观察寄存器变化

   $display("[Sim] Test Finished.");
    $stop;
  end


  // 待测试用户设计
  lab5_top_ppl dut (
      .clk_50M(clk_50M),
      .clk_11M0592(clk_11M0592),
      .push_btn(push_btn),
      .reset_btn(reset_btn),
      .touch_btn(touch_btn),
      .dip_sw(dip_sw),
      .leds(leds),
      .dpy1(dpy1),
      .dpy0(dpy0),
      .txd(txd),
      .rxd(rxd),
      .uart_rdn(uart_rdn),
      .uart_wrn(uart_wrn),
      .uart_dataready(uart_dataready),
      .uart_tbre(uart_tbre),
      .uart_tsre(uart_tsre),
      .base_ram_data(base_ram_data),
      .base_ram_addr(base_ram_addr),
      .base_ram_ce_n(base_ram_ce_n),
      .base_ram_oe_n(base_ram_oe_n),
      .base_ram_we_n(base_ram_we_n),
      .base_ram_be_n(base_ram_be_n),
      .ext_ram_data(ext_ram_data),
      .ext_ram_addr(ext_ram_addr),
      .ext_ram_ce_n(ext_ram_ce_n),
      .ext_ram_oe_n(ext_ram_oe_n),
      .ext_ram_we_n(ext_ram_we_n),
      .ext_ram_be_n(ext_ram_be_n),
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

  // CPLD 串口仿真模型
  cpld_model cpld (
      .clk_uart(clk_11M0592),
      .uart_rdn(uart_rdn),
      .uart_wrn(uart_wrn),
      .uart_dataready(uart_dataready),
      .uart_tbre(uart_tbre),
      .uart_tsre(uart_tsre),
      .data(base_ram_data[7:0])
  );
  // 直连串口仿真模型
  uart_model uart (
    .rxd (txd),
    .txd (rxd)
  );
  // BaseRAM 仿真模型
  sram_model base1 (
      .DataIO(base_ram_data[15:0]),
      .Address(base_ram_addr[19:0]),
      .OE_n(base_ram_oe_n),
      .CE_n(base_ram_ce_n),
      .WE_n(base_ram_we_n),
      .LB_n(base_ram_be_n[0]),
      .UB_n(base_ram_be_n[1])
  );
  sram_model base2 (
      .DataIO(base_ram_data[31:16]),
      .Address(base_ram_addr[19:0]),
      .OE_n(base_ram_oe_n),
      .CE_n(base_ram_ce_n),
      .WE_n(base_ram_we_n),
      .LB_n(base_ram_be_n[2]),
      .UB_n(base_ram_be_n[3])
  );
  // ExtRAM 仿真模型
  sram_model ext1 (
      .DataIO(ext_ram_data[15:0]),
      .Address(ext_ram_addr[19:0]),
      .OE_n(ext_ram_oe_n),
      .CE_n(ext_ram_ce_n),
      .WE_n(ext_ram_we_n),
      .LB_n(ext_ram_be_n[0]),
      .UB_n(ext_ram_be_n[1])
  );
  sram_model ext2 (
      .DataIO(ext_ram_data[31:16]),
      .Address(ext_ram_addr[19:0]),
      .OE_n(ext_ram_oe_n),
      .CE_n(ext_ram_ce_n),
      .WE_n(ext_ram_we_n),
      .LB_n(ext_ram_be_n[2]),
      .UB_n(ext_ram_be_n[3])
  );

  // 从文件加载 BaseRAM
  initial begin
    reg [31:0] tmp_array[0:1048575];
    integer n_File_ID, n_Init_Size;
    n_File_ID = $fopen(BASE_RAM_INIT_FILE, "rb");
    if (!n_File_ID) begin
      n_Init_Size = 0;
      $display("Failed to open BaseRAM init file");
    end else begin
      n_Init_Size = $fread(tmp_array, n_File_ID);
      n_Init_Size /= 4;
      $fclose(n_File_ID);
    end
    $display("BaseRAM Init Size(words): %d", n_Init_Size);
    for (integer i = 0; i < n_Init_Size; i++) begin
      base1.mem_array0[i] = tmp_array[i][24+:8];
      base1.mem_array1[i] = tmp_array[i][16+:8];
      base2.mem_array0[i] = tmp_array[i][8+:8];
      base2.mem_array1[i] = tmp_array[i][0+:8];
    end
  end

  // 从文件加载 ExtRAM
  initial begin
    reg [31:0] tmp_array[0:1048575];
    integer n_File_ID, n_Init_Size;
    n_File_ID = $fopen(EXT_RAM_INIT_FILE, "rb");
    if (!n_File_ID) begin
      n_Init_Size = 0;
      $display("Failed to open ExtRAM init file");
    end else begin
      n_Init_Size = $fread(tmp_array, n_File_ID);
      n_Init_Size /= 4;
      $fclose(n_File_ID);
    end
    $display("ExtRAM Init Size(words): %d", n_Init_Size);
    for (integer i = 0; i < n_Init_Size; i++) begin
      ext1.mem_array0[i] = tmp_array[i][24+:8];
      ext1.mem_array1[i] = tmp_array[i][16+:8];
      ext2.mem_array0[i] = tmp_array[i][8+:8];
      ext2.mem_array1[i] = tmp_array[i][0+:8];
    end
  end
endmodule
