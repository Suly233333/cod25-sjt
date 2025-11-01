`ifndef __MYTYPE_SV__
`define __MYTYPE_SV__

// 立即数类型枚举（最低位为 0 表示无立即数）
typedef enum logic [2:0] {
	IMM_NONE = 3'd0,
	IMM_I    = 3'd1,
	IMM_S    = 3'd2,
	IMM_B    = 3'd3,
	IMM_U    = 3'd4,
	IMM_J    = 3'd5
} imm_type_t;

// ALU 操作枚举
typedef enum logic [3:0] {
	ALU_NOP = 4'd0,
	ALU_ADD = 4'd1,
	ALU_SUB = 4'd2,
	ALU_AND = 4'd3,
	ALU_OR  = 4'd4,
	ALU_XOR = 4'd5,
    ALU_NOT = 4'd6,
	ALU_SLL = 4'd7,
	ALU_SRL = 4'd8,
    ALU_SRA = 4'd9,
    ALU_ROL = 4'd10
} alu_op_t;

// IF -> ID 寄存器：传递取指得到的指令和 PC，以及有效位
typedef struct packed {
	logic [31:0] inst;    // 指令编码
	logic [31:0] pc;      // 指令对应的 PC（便于调试/分支计算）
	logic        valid;   // 有效位（用于气泡/暂停/取指等待）
} if_id_reg;

// ID -> EXE 寄存器：包含寄存器读出数据、控制信号与目标寄存器等
typedef struct packed {
	logic [31:0]   inst;        // 原始指令（必要时用于 imm 生成等）
	logic [31:0]   pc;          // 传递 PC
	logic [4:0]    rf_raddr_a;  // rs1 地址（仅供记录/调试，可选）
	logic [4:0]    rf_raddr_b;  // rs2 地址
	logic [31:0]   rf_rdata_a;  // rs1 读取数据
	logic [31:0]   rf_rdata_b;  // rs2 读取数据
	imm_type_t imm_type;        // 立即数类型
	alu_op_t   alu_op;          // ALU 操作类型
	logic      use_rs2;         // 1：第二操作数来自 rs2；0：来自立即数
	logic      mem_en;          // 是否访问数据存储器
	logic      rf_wen;          // 是否写回寄存器
	logic [4:0]    rf_waddr;    // 写回寄存器地址 rd
	logic      valid;           // 有效位
} id_ex_reg;

// EXE -> MEM 寄存器：包含 ALU 结果、要写回的数据（或用于存储的数据）和控制
typedef struct packed {
	logic [31:0]   alu_result;  // ALU 计算结果
	logic [31:0]   rf_rdata_b;  // 如果要存内存，此字段为写内存的数据
	logic          mem_en;      // 是否访存
	logic          mem_wr;      // 1 = 写内存；0 = 读内存
	logic [31:0]   mem_addr;    // 访存地址
	logic          rf_wen;      // 是否写寄存器
	logic [4:0]    rf_waddr;    // 写回寄存器地址
	logic [31:0]   rf_wdata;    // 将要写回寄存器的数据
	logic [3:0]    mem_sel;     // 内存字节选择信号
	logic [31:0]   inst;        // 原始指令（用于 MEM 阶段的字节对齐处理）
	logic          valid;       // 有效位
} ex_mem_reg;

// MEM -> WB 寄存器：包含从内存读到的数据或 ALU 结果，供 WB 段写回寄存器
typedef struct packed {
	logic [31:0]   mem_rdata;   // 从内存读取的数据（若 mem_en 且为读）
	logic [31:0]   alu_result;  // 来自 EXE 的 ALU 结果（便于选择写回数据）
	logic          rf_wen;      // 是否写寄存器
	logic [4:0]    rf_waddr;    // 写回寄存器地址
	logic [31:0]   rf_wdata;    // 最终写回的数据（EXE 阶段可提前计算好）
	logic          valid;       // 有效位
} mem_wb_reg;

typedef struct packed {
    logic stall_i;       // 为 1 时，表示下个周期将忽略输入，维持输出不变
    logic bubble_i;      // 为 1 时，表示下个周期清空该寄存器（变为气泡），输出也为气泡
} stall_flush_in;

typedef struct packed {
	logic stall_o;       // 为 1 时，表示这个流水线段发出请求，要在这个阶段阻塞流水线
	logic flush_o;       // 为 1 时，表示这个流水线段发出请求，要将所有 之前 的流水线段清空
} stall_flush_out;

typedef struct packed {
    logic [31:0] data;
    logic ack;
} arbiter_out;

typedef struct packed {
    logic [31:0] addr;
    logic [31:0] data;
    logic [3:0] sel;
    logic we;
    logic cyc;
    logic stb;
} arbiter_input;

`endif  // __MYTYPE_SV__