`timescale 1ns / 1ps
module tb;

  wire clk_50M, clk_11M0592;

  reg push_btn;   // BTN5
  reg reset_btn;  // BTN6

  reg [3:0] touch_btn; // BTN1~BTN4
  reg [31:0] dip_sw;   // 32 位拨码开关

  wire [15:0] leds;
  wire [7:0] dpy0;
  wire [7:0] dpy1;

  wire txd;  // Monitor 发回来的数据
  reg rxd;   // 我们发给 Monitor 的数据

  // ... (保留原有的 wire 定义) ...
  wire [31:0] base_ram_data;
  wire [19:0] base_ram_addr;
  wire [3:0] base_ram_be_n;
  wire base_ram_ce_n;
  wire base_ram_oe_n;
  wire base_ram_we_n;

  wire [31:0] ext_ram_data;
  wire [19:0] ext_ram_addr;
  wire [3:0] ext_ram_be_n;
  wire ext_ram_ce_n;
  wire ext_ram_oe_n;
  wire ext_ram_we_n;

  wire [22:0] flash_a;
  wire [15:0] flash_d;
  wire flash_rp_n;
  wire flash_vpen;
  wire flash_ce_n;
  wire flash_oe_n;
  wire flash_we_n;
  wire flash_byte_n;

  wire uart_rdn;
  wire uart_wrn;
  wire uart_dataready;
  wire uart_tbre;
  wire uart_tsre;

  // 【务必修改路径】指向你的 Monitor 程序 (kernel.bin)
  parameter BASE_RAM_INIT_FILE = "F:\\Vivado_files\\cod25-grp61\\test\\kernel.bin"; 
  parameter EXT_RAM_INIT_FILE = "/tmp/eram.bin";  
  parameter FLASH_INIT_FILE = "/tmp/kernel.elf";  

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
  // 你的汇编代码：
  // 1. li t0, 0xdeadbeef
  //    (拆解为: lui t0, 0xdeadc; addi t0, t0, 0xeef)
  // 2. csrrw t1, mscratch, t0
  // 3. csrrw t2, mscratch, t0
  // 4. jr ra
  
  reg [31:0] prog_instr [0:4]; // 5 条指令 (20 字节)

  initial begin
    // [0x80100000] li t0, 0xdeadbeef -> 需要两条指令
    // lui t0, 0xdeadc (因为 0xeef 是负数，高位要进位)
    prog_instr[0] = 32'hdeadc2b7; 
    // addi t0, t0, 0xeef (-273)
    prog_instr[1] = 32'heef28293; 

    // [0x80100008] csrrw t1, mscratch, t0
    // mscratch = 0x340, t1=x6, t0=x5
    prog_instr[2] = 32'h34029373; 

    // [0x8010000c] csrrw t2, mscratch, t0
    // t2=x7
    prog_instr[3] = 32'h340293f3; 

    // [0x80100010] jr ra (ret)
    // jalr x0, 0(ra)
    prog_instr[4] = 32'h00008067;
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
    repeat(400000) @(posedge clk_50M); 

    // -------------------------------------------------------------------------
    // 步骤 1: 发送 'A' (加载程序)
    // -------------------------------------------------------------------------
    $display("[Sim] Sending 'A' (Load Program)...");
    uart_send_byte("A"); // 0x41

    $display("[Sim] Sending Address: 0x80100000");
    uart_send_word(32'h80100000);

    $display("[Sim] Sending Length: 20 bytes (5 instructions)");
    uart_send_word(32'd20);

    $display("[Sim] Sending Instructions...");
    for (integer k = 0; k < 5; k = k + 1) begin
      uart_send_word(prog_instr[k]); // 注意这里调用的是 send_word (4字节)
    end

    // 等待 CPU 写内存
    $display("[Sim] Program loaded. Waiting...");
    repeat(20000) @(posedge clk_50M);

    // -------------------------------------------------------------------------
    // 步骤 2: 发送 'G' (运行程序)
    // -------------------------------------------------------------------------
    $display("[Sim] Sending 'G' (Execute Program)...");
    uart_send_byte("G"); // 0x47

    $display("[Sim] Sending Jump Address: 0x80100000");
    uart_send_word(32'h80100000);

    // -------------------------------------------------------------------------
    // 观察结果
    // -------------------------------------------------------------------------
    $display("[Sim] Execution started! Please check signals:");
    $display("      - pc: Should jump to 80100000");
    $display("      - reg[5] (t0): Should be deadbeef");
    $display("      - mscratch CSR: Should update");
    
    // 让它跑一会儿，观察寄存器变化
    repeat(100000) @(posedge clk_50M);

    $display("[Sim] Test Finished.");
    $stop;
  end

  // ... (下方的 dut 实例化部分保持不变，直接粘贴原来的即可) ...
  // 待测试用户设计
  thinpad_top dut (
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
      .flash_d(flash_d),
      .flash_a(flash_a),
      .flash_rp_n(flash_rp_n),
      .flash_vpen(flash_vpen),
      .flash_oe_n(flash_oe_n),
      .flash_ce_n(flash_ce_n),
      .flash_byte_n(flash_byte_n),
      .flash_we_n(flash_we_n)
  );

  clock osc (
      .clk_11M0592(clk_11M0592),
      .clk_50M    (clk_50M)
  );

  cpld_model cpld (
      .clk_uart(clk_11M0592),
      .uart_rdn(uart_rdn),
      .uart_wrn(uart_wrn),
      .uart_dataready(uart_dataready),
      .uart_tbre(uart_tbre),
      .uart_tsre(uart_tsre),
      .data(base_ram_data[7:0])
  );

  /*
  uart_model uart (
    .rxd (txd),
    .txd (rxd)
  );
  */

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
  
  x28fxxxp30 #(
      .FILENAME_MEM(FLASH_INIT_FILE)
  ) flash (
      .A   (flash_a[1+:22]),
      .DQ  (flash_d),
      .W_N (flash_we_n),      
      .G_N (flash_oe_n),      
      .E_N (flash_ce_n),      
      .L_N (1'b0),            
      .K   (1'b0),            
      .WP_N(flash_vpen),      
      .RP_N(flash_rp_n),      
      .VDD ('d3300),
      .VDDQ('d3300),
      .VPP ('d1800),
      .Info(1'b1)
  );

  initial begin
    wait (flash_byte_n == 1'b0);
    $display("8-bit Flash interface is not supported in simulation!");
    $display("Please tie flash_byte_n to high");
    $stop;
  end

  // 从文件加载 BaseRAM (保持不变)
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

  initial begin
      // ExtRAM 加载部分保持不变，省略以节省空间
  end

endmodule