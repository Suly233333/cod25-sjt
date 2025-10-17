module lab4_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk_i,
    input wire rst_i,

    // TODO: 添加需要的控制信号，例如按键开关？
    // 添加拨码开关作为起始地址输入
    input wire [31:0] switch_i,
    
    // wishbone master
    output reg wb_cyc_o,
    output reg wb_stb_o,
    input wire wb_ack_i,
    output reg [ADDR_WIDTH-1:0] wb_adr_o,
    output reg [DATA_WIDTH-1:0] wb_dat_o,
    input wire [DATA_WIDTH-1:0] wb_dat_i,
    output reg [DATA_WIDTH/8-1:0] wb_sel_o,
    output reg wb_we_o
);

  // TODO: 实现实验 5 的内存+串口 Master
  // 定义常量
  localparam UART_STATUS_ADDR = 32'h1000_0005;  // 串口状态寄存器地址
  localparam UART_DATA_ADDR = 32'h1000_0000;    // 串口数据寄存器地址
  localparam UART_STATUS_RX_MASK = 8'h01;       // 串口状态寄存器接收标志位掩码
  localparam UART_STATUS_TX_MASK = 8'h02;       // 串口状态寄存器发送标志位掩码

  // 内部寄存器
  reg wb_cyc_o_reg;
  reg wb_stb_o_reg;
  reg [ADDR_WIDTH-1:0] wb_adr_o_reg;
  reg [DATA_WIDTH-1:0] wb_dat_temp_reg;
  reg [DATA_WIDTH/8-1:0] wb_sel_o_reg;
  reg wb_we_o_reg;
  
  // 数据存储和计数器
  reg [3:0] data_counter;                  // 数据计数器
  reg [ADDR_WIDTH-1:0] base_addr;          // 从拨码开关获取的基地址

  // 状态机定义
  typedef enum logic [3:0] {
    STATE_IDLE = 0,
    
    // 读取串口状态和数据的状态
    STATE_READ_WAIT_ACTION = 1,
    STATE_READ_WAIT_CHECK = 2,
    STATE_READ_DATA_ACTION = 3,
    STATE_READ_DATA_DONE = 4,

    // 写入SRAM的状态
    STATE_WRITE_SRAM_ACTION = 5,
    STATE_WRITE_SRAM_DONE = 6,
    
    // 写入串口状态和数据的状态
    STATE_WRITE_WAIT_ACTION = 7,
    STATE_WRITE_WAIT_CHECK = 8,
    STATE_WRITE_DATA_ACTION = 9,
    STATE_WRITE_DATA_DONE = 10,

    STATE_ALL_DONE = 11
  } state_t;

  state_t state;

  // 状态机实现
  always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      // 复位状态
      data_counter <= 0;
      wb_cyc_o_reg <= 0;
      wb_stb_o_reg <= 0;
      wb_adr_o_reg <= 0;
      wb_dat_temp_reg <= 0;
      wb_sel_o_reg <= 0;
      wb_we_o_reg <= 0;
      // 记录拨码开关的值作为基地址，确保4字节对齐
      base_addr <= switch_i;
      state <= STATE_IDLE;
    end else begin
      case (state)
        STATE_IDLE: begin
          if (data_counter == 4'b1010) begin
            // 已经读取并写入10个数据，停止操作
            state <= STATE_ALL_DONE;
          end else begin
            // 开始读取串口状态寄存器
          wb_cyc_o_reg <= 1;
          wb_stb_o_reg <= 1;
          wb_adr_o_reg <= UART_STATUS_ADDR;
          wb_we_o_reg <= 0;
          wb_sel_o_reg <= 4'b0010;
          // 从空闲状态开始读取串口状态
          state <= STATE_READ_WAIT_ACTION;
          end
        end
        
        // 读取串口状态寄存器
        STATE_READ_WAIT_ACTION: begin
          // 发起读取串口状态寄存器的请求
          if (wb_ack_i) begin
            // 收到应答，进入检查状态
            wb_cyc_o_reg <= 0;
            wb_stb_o_reg <= 0;
            state <= STATE_READ_WAIT_CHECK;
          end
        end
        
        // 检查串口状态
        STATE_READ_WAIT_CHECK: begin
          if (wb_dat_i[0+8]) begin
            // 串口有数据可读，进入读取数据状态
            wb_cyc_o_reg <= 1;
            wb_stb_o_reg <= 1;
            wb_adr_o_reg <= UART_DATA_ADDR;
            wb_we_o_reg <= 0;
            wb_sel_o_reg <= 4'b0001;
            state <= STATE_READ_DATA_ACTION;
          end else begin
            // 串口无数据可读，继续查询状态
            wb_cyc_o_reg <= 1;
            wb_stb_o_reg <= 1;
            wb_adr_o_reg <= UART_STATUS_ADDR;
            wb_we_o_reg <= 0;
            wb_sel_o_reg <= 4'b0010;
            state <= STATE_READ_WAIT_ACTION;
          end
        end
        
        // 读取串口数据
        STATE_READ_DATA_ACTION: begin
          // 发起读取串口数据寄存器的请求
          if (wb_ack_i) begin
            // 收到应答，保存数据
            wb_dat_temp_reg <= wb_dat_i;
            wb_cyc_o_reg <= 0;
            wb_stb_o_reg <= 0;
            state <= STATE_READ_DATA_DONE;
          end
        end
        
        // 完成读取数据
        STATE_READ_DATA_DONE: begin
          // 进入写入SRAM的状态
          wb_cyc_o_reg <= 1;
          wb_stb_o_reg <= 1;
          wb_adr_o_reg <= base_addr + (data_counter << 2);  // 地址为base_addr + 4*i
          wb_we_o_reg <= 1;  // 写操作
          wb_sel_o_reg <= 4'b0001;  // 只写入最低字节
          state <= STATE_WRITE_SRAM_ACTION;
        end
        
        // 写入SRAM
        STATE_WRITE_SRAM_ACTION: begin
          // 发起写入SRAM的请求
          if (wb_ack_i) begin
            // 收到应答，完成写入
            wb_cyc_o_reg <= 0;
            wb_stb_o_reg <= 0;
            state <= STATE_WRITE_SRAM_DONE;
          end
        end
        
        // 完成写入SRAM
        STATE_WRITE_SRAM_DONE: begin
          // 进入写入串口状态
          wb_cyc_o_reg <= 1;
          wb_stb_o_reg <= 1;
          wb_adr_o_reg <= UART_STATUS_ADDR;
          wb_we_o_reg <= 0;  // 读操作
          wb_sel_o_reg <= 4'b0001;  // 只读取最低字节
          state <= STATE_WRITE_WAIT_ACTION;
        end
        
        // 读取串口状态寄存器（用于写入）
        STATE_WRITE_WAIT_ACTION: begin
          // 发起读取串口状态寄存器的请求
          if (wb_ack_i) begin
            // 收到应答，进入检查状态
            wb_cyc_o_reg <= 0;
            wb_stb_o_reg <= 0;
            state <= STATE_WRITE_WAIT_CHECK;
          end
        end
        
        // 检查串口状态（用于写入）
        STATE_WRITE_WAIT_CHECK: begin
          if (wb_dat_i[5+8]) begin
            // 串口可以写入数据，进入写入数据状态
            wb_cyc_o_reg <= 1;
            wb_stb_o_reg <= 1;
            wb_adr_o_reg <= UART_DATA_ADDR;
            wb_we_o_reg <= 1;
            wb_sel_o_reg <= 4'b0001;
            state <= STATE_WRITE_DATA_ACTION;
          end else begin
            // 串口不可写入，继续查询状态
            wb_cyc_o_reg <= 1;
            wb_stb_o_reg <= 1;
            wb_adr_o_reg <= UART_STATUS_ADDR;
            wb_we_o_reg <= 0;
            wb_sel_o_reg <= 4'b0010;
            state <= STATE_WRITE_WAIT_ACTION;
          end
        end
        
        // 写入串口数据
        STATE_WRITE_DATA_ACTION: begin
          // 发起写入串口数据寄存器的请求
          if (wb_ack_i) begin
            // 收到应答，完成写入
            wb_cyc_o_reg <= 0;
            wb_stb_o_reg <= 0;
            state <= STATE_WRITE_DATA_DONE;
          end
        end
        
        // 完成写入串口数据
        STATE_WRITE_DATA_DONE: begin
          // 增加计数器
          data_counter <= data_counter + 1;
          state <= STATE_IDLE;
        end

        STATE_ALL_DONE: begin
          // 所有操作完成，保持当前状态
          wb_cyc_o_reg <= 0;
          wb_stb_o_reg <= 0;
          state <= STATE_ALL_DONE;
        end
        
        default: begin
          // 未知状态，回到空闲状态
          state <= STATE_IDLE;
        end
      endcase
    end
  end

  // 输出赋值
  always_comb begin
    wb_cyc_o = wb_cyc_o_reg;
    wb_stb_o = wb_stb_o_reg;
    wb_adr_o = wb_adr_o_reg;
    wb_dat_o = wb_dat_temp_reg;
    wb_sel_o = wb_sel_o_reg;
    wb_we_o = wb_we_o_reg;
  end
  
endmodule
