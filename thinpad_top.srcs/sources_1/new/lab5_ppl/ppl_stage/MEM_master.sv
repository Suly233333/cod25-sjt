`include "../type.sv"

module MEM_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] pc_i,
    input wire [31:0] imm_i,
    input wire [31:0] inst_i,
    input wire [4:0] rf_waddr_i,
    input wire [31:0] mem_addr_i,
    input wire [31:0] mem_data_i,
    input wire [DATA_WIDTH-1:0] wb_data_i,
    input wire [3:0] imm_type_i,
    input wire [3:0] instr_type_i,
    input wire [7:0] instr_code_i,
    input wire mem_en_i,
    input wire rf_wen_i,
    input wire stall_i,
    input wire wb_ack_i,
    input wire [31:0] alu_y_i,

    output logic [31:0] pc_o,
    output logic [31:0] inst_o,
    output logic [4:0] rf_waddr_o,
    output logic [31:0] rf_wdata_o,
    output logic rf_wen_o,
    output reg wb_cyc_o,
    output reg wb_stb_o,
    output reg [ADDR_WIDTH-1:0] wb_addr_o,
    output reg [DATA_WIDTH-1:0] wb_data_o,
    output reg [DATA_WIDTH/8-1:0] wb_sel_o,
    output reg wb_we_o,
    output logic mem_stall_o,
    output logic mem_flush_o

);

typedef enum logic {
    ST_IDLE,
    ST_WAIT_ACK
} state_t;

state_t state;

// Combinational Logic for Pipeline Outputs
always_comb begin
    // Default Pass-through
    pc_o = pc_i;
    inst_o = inst_i;
    rf_waddr_o = rf_waddr_i;
    rf_wen_o = rf_wen_i;
    mem_stall_o = 1'b0;
    mem_flush_o = 1'b0;
    
    // Default wdata (ALU result or Imm)
    if (instr_type_i == INSTR_TYPE_U && instr_code_i == INSTR_LUI)
        rf_wdata_o = imm_i;
    else
        rf_wdata_o = alu_y_i;
        
    // Memory Stall Logic
    // 这里代码如此狗屎是因为我做了个store的缓存机制，即第一个store不会立刻暂停整个流水线
    if (wb_we_o && mem_en_i && !wb_ack_i && state == ST_WAIT_ACK)
        mem_stall_o = 1'b1;
    else if (instr_type_i == INSTR_TYPE_I && ((!wb_ack_i && state == ST_WAIT_ACK) || (mem_en_i && state == ST_IDLE)))
        mem_stall_o = 1'b1;
    else
        mem_stall_o = 1'b0;

    if (instr_type_i == INSTR_TYPE_I) begin // LOAD
        rf_wen_o = 1'b1; // Load writes to RF
        if (state == ST_WAIT_ACK) begin
            if (wb_ack_i && !wb_we_o) begin // ACK for Read
                // Data processing
                case (instr_code_i)
                    INSTR_LW: rf_wdata_o = wb_data_i;
                    INSTR_LB: begin
                        case (mem_addr_i[1:0])
                            2'b00: rf_wdata_o = {{24{wb_data_i[7]}}, wb_data_i[7:0]};
                            2'b01: rf_wdata_o = {{24{wb_data_i[15]}}, wb_data_i[15:8]};
                            2'b10: rf_wdata_o = {{24{wb_data_i[23]}}, wb_data_i[23:16]};
                            2'b11: rf_wdata_o = {{24{wb_data_i[31]}}, wb_data_i[31:24]};
                        endcase
                    end
                    INSTR_LBU: begin
                            case (mem_addr_i[1:0])
                            2'b00: rf_wdata_o = {24'b0, wb_data_i[7:0]};
                            2'b01: rf_wdata_o = {24'b0, wb_data_i[15:8]};
                            2'b10: rf_wdata_o = {24'b0, wb_data_i[23:16]};
                            2'b11: rf_wdata_o = {24'b0, wb_data_i[31:24]};
                        endcase
                    end
                    INSTR_LH: begin
                        case (mem_addr_i[1:0])
                            2'b00: rf_wdata_o = {{16{wb_data_i[15]}}, wb_data_i[15:0]};
                            2'b10: rf_wdata_o = {{16{wb_data_i[31]}}, wb_data_i[31:16]};
                            default: rf_wdata_o = {{16{wb_data_i[15]}}, wb_data_i[15:0]};
                        endcase
                    end
                    INSTR_LHU: begin
                        case (mem_addr_i[1:0])
                            2'b00: rf_wdata_o = {16'b0, wb_data_i[15:0]};
                            2'b10: rf_wdata_o = {16'b0, wb_data_i[31:16]};
                            default: rf_wdata_o = {16'b0, wb_data_i[15:0]};
                        endcase
                    end
                endcase
            end
        end
    end else if (instr_type_i == INSTR_TYPE_S) begin // STORE
        rf_wen_o = 1'b0;
    end
end

// Sequential Logic for Wishbone Control
always_ff @(posedge clk_i) begin
    if (rst_i) begin
        state <= ST_IDLE;
        wb_cyc_o <= 0;
        wb_stb_o <= 0;
        wb_we_o <= 0;
        wb_addr_o <= 0;
        wb_data_o <= 0;
        wb_sel_o <= 0;
    end else begin
        if (mem_en_i && (state == ST_IDLE || wb_ack_i && wb_we_o)) begin
            wb_cyc_o <= 1;
            wb_stb_o <= 1;
            wb_addr_o <= mem_addr_i;
            wb_we_o <= (instr_type_i == INSTR_TYPE_S);
            
            // Set SEL and DATA
            if (instr_type_i == INSTR_TYPE_S) begin
                case (instr_code_i)
                    INSTR_SB: begin
                        case (mem_addr_i[1:0])
                            2'b00: begin wb_sel_o <= 4'b0001; wb_data_o <= mem_data_i; end
                            2'b01: begin wb_sel_o <= 4'b0010; wb_data_o <= mem_data_i << 8; end
                            2'b10: begin wb_sel_o <= 4'b0100; wb_data_o <= mem_data_i << 16; end
                            2'b11: begin wb_sel_o <= 4'b1000; wb_data_o <= mem_data_i << 24; end
                        endcase
                    end
                    INSTR_SH: begin
                        case (mem_addr_i[1:0])
                            2'b00: begin wb_sel_o <= 4'b0011; wb_data_o <= mem_data_i; end
                            2'b10: begin wb_sel_o <= 4'b1100; wb_data_o <= mem_data_i << 16; end
                            default: begin wb_sel_o <= 4'b0000; wb_data_o <= 32'b0; end
                        endcase
                    end
                    INSTR_SW: begin wb_sel_o <= 4'b1111; wb_data_o <= mem_data_i; end
                    default: begin wb_sel_o <= 4'b0000; wb_data_o <= 32'b0; end
                endcase
            end else begin // LOAD
                case (instr_code_i)
                    INSTR_LB, INSTR_LBU:   // Load Byte
                        case (mem_addr_i[1:0])
                            2'b00: wb_sel_o <= 4'b0001;
                            2'b01: wb_sel_o <= 4'b0010;
                            2'b10: wb_sel_o <= 4'b0100;
                            2'b11: wb_sel_o <= 4'b1000;
                        endcase
                    INSTR_LH, INSTR_LHU: 
                        case (mem_addr_i[1:0])
                            2'b00: wb_sel_o <= 4'b0011;
                            2'b10: wb_sel_o <= 4'b1100;
                            default: wb_sel_o <= 4'b0000;
                        endcase
                    INSTR_LW: wb_sel_o <= 4'b1111;
                    default: wb_sel_o <= 4'b0000;
                endcase
                wb_data_o <= 32'b0;
            end
            state <= ST_WAIT_ACK;
        end else if (wb_ack_i) begin
            wb_cyc_o <= 0;
            wb_stb_o <= 0;
            wb_we_o <= 0;
            state <= ST_IDLE;
        end
    end
end

endmodule