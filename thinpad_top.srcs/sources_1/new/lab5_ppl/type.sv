`ifndef TYPE
`define TYPE

// ALU operation encoding
typedef enum logic [3:0] {
    OP_NONE = 4'b0000,
    OP_ADD = 4'b0001,
    OP_SUB = 4'b0010,
    OP_AND = 4'b0011,
    OP_OR = 4'b0100,
    OP_XOR = 4'b0101,
    OP_NOT = 4'b0110,
    OP_SLL = 4'b0111,
    OP_SRL = 4'b1000,
    OP_SRA = 4'b1001,
    OP_ROL = 4'b1010,   // Rotate Left
    OP_SLT = 4'b1011,   // Set Less Than (signed)
    OP_SLTU = 4'b1100   // Set Less Than Unsigned
} alu_op_t;

// Immediate type encoding
typedef enum logic [3:0] {
    IMM_TYPE_NONE = 4'b0000,
    IMM_TYPE_I = 4'b0001,
    IMM_TYPE_S = 4'b0010,
    IMM_TYPE_B = 4'b0011,
    IMM_TYPE_U = 4'b0100,
    IMM_TYPE_J = 4'b0101
} imm_type_t;

// Instruction type encoding
typedef enum logic [3:0] {
    INSTR_TYPE_ERR = 4'b0000,
    INSTR_TYPE_R = 4'b0001,
    INSTR_TYPE_I = 4'b0010,
    INSTR_TYPE_S = 4'b0011,
    INSTR_TYPE_B = 4'b0100,
    INSTR_TYPE_U = 4'b0101,
    INSTR_TYPE_J = 4'b0110
} instr_type_t;

// Specific instruction code encoding
typedef enum logic [7:0] {
    INSTR_UNKNOWN = 8'h00,

    // 1. Integer Computation（整数计算）
    // 加减运算
    INSTR_ADD    = 8'h01,  // 寄存器加法
    INSTR_ADDI   = 8'h02,  // 立即数加法
    INSTR_SUB    = 8'h03,  // 寄存器减法
    // 逻辑运算
    INSTR_AND    = 8'h04,  // 寄存器与
    INSTR_ANDI   = 8'h05,  // 立即数与
    INSTR_OR     = 8'h06,  // 寄存器或
    INSTR_ORI    = 8'h07,  // 立即数或
    INSTR_XOR    = 8'h08,  // 寄存器异或（exclusive or）
    INSTR_XORI   = 8'h09,  // 立即数异或
    // 移位运算
    INSTR_SLL    = 8'h0A,  // 寄存器逻辑左移
    INSTR_SLLI   = 8'h0B,  // 立即数逻辑左移
    INSTR_SRA    = 8'h0C,  // 寄存器算术右移
    INSTR_SRAI   = 8'h0D,  // 立即数算术右移
    INSTR_SRL    = 8'h0E,  // 寄存器逻辑右移
    INSTR_SRLI   = 8'h0F,  // 立即数逻辑右移
    // 高位立即数
    INSTR_LUI    = 8'h10,  // 加载高位立即数
    INSTR_AUIPC  = 8'h11,  // 高位立即数加PC
    // 比较运算
    INSTR_SLT    = 8'h12,  // 寄存器小于（带符号）
    INSTR_SLTI   = 8'h13,  // 立即数小于（带符号）
    INSTR_SLTU   = 8'h14,  // 寄存器小于（无符号）
    INSTR_SLTIU  = 8'h15,  // 立即数小于（无符号）

    // 2. Control Transfer（控制转移）
    // 相等/不等分支
    INSTR_BEQ    = 8'h16,  // 相等则分支
    INSTR_BNE    = 8'h17,  // 不相等则分支
    // 带符号比较分支
    INSTR_BGE    = 8'h18,  // 大于等于则分支（带符号）
    INSTR_BLT    = 8'h19,  // 小于则分支（带符号）
    // 无符号比较分支
    INSTR_BGEU   = 8'h1A,  // 大于等于则分支（无符号）
    INSTR_BLTU   = 8'h1B,  // 小于则分支（无符号）
    // 跳转指令
    INSTR_JAL    = 8'h1C,  // 跳转并链接
    INSTR_JALR   = 8'h1D,  // 寄存器间接跳转并链接

    // 3. Loads and Stores（加载与存储）
    // 带符号加载
    INSTR_LB     = 8'h1E,  // 加载字节（带符号扩展）
    INSTR_LH     = 8'h1F,  // 加载半字（带符号扩展）
    INSTR_LW     = 8'h20,  // 加载字
    // 无符号加载
    INSTR_LBU    = 8'h21,  // 加载字节（无符号扩展）
    INSTR_LHU    = 8'h22,  // 加载半字（无符号扩展）
    // 存储指令
    INSTR_SB     = 8'h23,  // 存储字节
    INSTR_SH     = 8'h24,  // 存储半字
    INSTR_SW     = 8'h25,  // 存储字

    // 4. Miscellaneous instructions（杂项指令）
    // 内存屏障
    INSTR_FENCE  = 8'h26,  // 加载/存储屏障
    INSTR_FENCE_I= 8'h27,  // 指令/数据屏障
    // 环境指令
    INSTR_ECALL  = 8'h28,  // 环境调用
    INSTR_EBREAK = 8'h29,  // 环境中断
    // 控制状态寄存器（CSR）
    INSTR_CSRRW  = 8'h2A,  // CSR读写
    INSTR_CSRRS  = 8'h2B,  // CSR读置位
    INSTR_CSRRC  = 8'h2C,  // CSR读清除
    INSTR_CSRRWI = 8'h2D,  // CSR立即数读写
    INSTR_CSRRSI = 8'h2E,  // CSR立即数读置位
    INSTR_CSRRCI = 8'h2F   // CSR立即数读清除
} instr_code_t;

`endif