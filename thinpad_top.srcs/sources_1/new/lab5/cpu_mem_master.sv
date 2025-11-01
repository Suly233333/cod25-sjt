/**
 * @file cpu_mem_master.sv
 * @brief 五级流水线 CPU - MEM 阶段（访存）
 *
 * 功能：
 * 1. Wishbone 总线控制进行数据访存
 * 2. 字节级读写处理（LB/SB）
 * 3. 字级读写处理（LW/SW）
 * 4. 数据对齐和符号/零扩展
 */

`include "mytype.sv"

module cpu_mem_master (
    input  logic         clk,
    input  logic         rst,

    // Stall/Flush 控制信号
    input  stall_flush_in stall_flush_in_i,
    output stall_flush_out stall_flush_out_o,

    // EXE/MEM 流水线寄存器输入
    input  ex_mem_reg    ex_mem_i,

    // Wishbone 总线接口（Master）
    output logic [31:0]  wb_adr_o,
    input  logic [31:0]  wb_dat_i,
    output logic [31:0]  wb_dat_o,
    output logic         wb_we_o,
    output logic [3:0]   wb_sel_o,
    output logic         wb_stb_o,
    input  logic         wb_ack_i,
    output logic         wb_cyc_o,

    // MEM -> WB 流水线寄存器输出
    output mem_wb_reg    mem_wb_o
);

// ============================================================
// Wishbone 状态机
// ============================================================
typedef enum logic [1:0] {
    WB_IDLE = 2'd0,
    WB_REQ  = 2'd1,
    WB_WAIT = 2'd2
} wb_state_t;

wb_state_t wb_state, wb_state_next;

always_ff @(posedge clk) begin
    if (rst) begin
        wb_state <= WB_IDLE;
    end else if (stall_flush_in_i.stall_i) begin
        wb_state <= wb_state;
    end else if (stall_flush_in_i.bubble_i) begin
        wb_state <= WB_IDLE;
    end else begin
        wb_state <= wb_state_next;
    end
end

// ============================================================
// Wishbone 总线控制逻辑
// ============================================================
logic mem_access_done;

always_comb begin
    wb_adr_o = ex_mem_i.mem_addr;
    wb_dat_o = ex_mem_i.rf_rdata_b;
    wb_sel_o = ex_mem_i.mem_sel;
    wb_we_o = ex_mem_i.mem_wr;

    case (wb_state)
        WB_IDLE: begin
            wb_cyc_o = 1'b0;
            wb_stb_o = 1'b0;
            mem_access_done = 1'b0;

            if (ex_mem_i.mem_en && ex_mem_i.valid) begin
                wb_state_next = WB_REQ;
            end else begin
                wb_state_next = WB_IDLE;
            end
        end

        WB_REQ: begin
            wb_cyc_o = 1'b1;
            wb_stb_o = 1'b1;
            mem_access_done = 1'b0;
            wb_state_next = WB_WAIT;
        end

        WB_WAIT: begin
            wb_cyc_o = 1'b1;
            wb_stb_o = 1'b1;

            if (wb_ack_i) begin
                mem_access_done = 1'b1;
                wb_state_next = WB_IDLE;
            end else begin
                mem_access_done = 1'b0;
                wb_state_next = WB_WAIT;
            end
        end

        default: begin
            wb_cyc_o = 1'b0;
            wb_stb_o = 1'b0;
            mem_access_done = 1'b0;
            wb_state_next = WB_IDLE;
        end
    endcase
end

// ============================================================
// 字节数据提取和符号扩展（用于 Load 指令）
// ============================================================
logic [31:0] mem_read_data;
logic [6:0] opcode;
logic [2:0] funct3;

assign opcode = ex_mem_i.inst[6:0];
assign funct3 = ex_mem_i.inst[14:12];

always_comb begin
    if (ex_mem_i.mem_en && !ex_mem_i.mem_wr) begin
        // Load 指令
        case (funct3)
            3'b000: begin  // LB: 符号扩展字节
                case (ex_mem_i.mem_addr[1:0])
                    2'b00: mem_read_data = {{24{wb_dat_i[7]}}, wb_dat_i[7:0]};
                    2'b01: mem_read_data = {{24{wb_dat_i[15]}}, wb_dat_i[15:8]};
                    2'b10: mem_read_data = {{24{wb_dat_i[23]}}, wb_dat_i[23:16]};
                    2'b11: mem_read_data = {{24{wb_dat_i[31]}}, wb_dat_i[31:24]};
                endcase
            end

            3'b100: begin  // LBU: 零扩展字节
                case (ex_mem_i.mem_addr[1:0])
                    2'b00: mem_read_data = {24'b0, wb_dat_i[7:0]};
                    2'b01: mem_read_data = {24'b0, wb_dat_i[15:8]};
                    2'b10: mem_read_data = {24'b0, wb_dat_i[23:16]};
                    2'b11: mem_read_data = {24'b0, wb_dat_i[31:24]};
                endcase
            end

            3'b010: begin  // LW: 字访问
                mem_read_data = wb_dat_i;
            end

            default: begin
                mem_read_data = 32'b0;
            end
        endcase
    end else begin
        mem_read_data = 32'b0;
    end
end

// ============================================================
// MEM -> WB 流水线寄存器
// ============================================================
mem_wb_reg mem_wb_next;

always_comb begin
    mem_wb_next.alu_result = ex_mem_i.alu_result;
    mem_wb_next.mem_rdata = mem_read_data;
    mem_wb_next.rf_wen = ex_mem_i.rf_wen;
    mem_wb_next.rf_waddr = ex_mem_i.rf_waddr;
    mem_wb_next.valid = ex_mem_i.valid;

    // 选择写回数据
    if (ex_mem_i.mem_en && !ex_mem_i.mem_wr) begin
        // Load 指令：使用从内存读取的数据
        mem_wb_next.rf_wdata = mem_read_data;
    end else begin
        // 其他指令：使用 ALU 结果
        mem_wb_next.rf_wdata = ex_mem_i.alu_result;
    end
end

mem_wb_reg mem_wb_reg_r;

always_ff @(posedge clk) begin
    if (rst) begin
        mem_wb_reg_r.alu_result <= 32'b0;
        mem_wb_reg_r.mem_rdata <= 32'b0;
        mem_wb_reg_r.rf_wen <= 1'b0;
        mem_wb_reg_r.rf_waddr <= 5'b0;
        mem_wb_reg_r.rf_wdata <= 32'b0;
        mem_wb_reg_r.valid <= 1'b0;
    end else if (stall_flush_in_i.stall_i) begin
        // 暂停时维持输出
        mem_wb_reg_r <= mem_wb_reg_r;
    end else if (stall_flush_in_i.bubble_i) begin
        // 气泡
        mem_wb_reg_r.rf_wen <= 1'b0;
        mem_wb_reg_r.valid <= 1'b0;
    end else begin
        // 只有在访存完成或无需访存时才更新
        if (!ex_mem_i.mem_en || mem_access_done) begin
            mem_wb_reg_r <= mem_wb_next;
        end else begin
            mem_wb_reg_r <= mem_wb_reg_r;
        end
    end
end

assign mem_wb_o = mem_wb_reg_r;

// ============================================================
// stall_flush_out 输出
// ============================================================
// 当有内存访问且未完成时，产生 stall 信号
assign stall_flush_out_o.stall_o = ex_mem_i.mem_en && ex_mem_i.valid && !mem_access_done;
assign stall_flush_out_o.flush_o = 1'b0;  // MEM 阶段不产生 flush

endmodule
