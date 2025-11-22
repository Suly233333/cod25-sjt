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
    output reg wb_cyc_o,
    output reg wb_stb_o,
    output reg [ADDR_WIDTH-1:0] wb_addr_o,
    output reg [DATA_WIDTH-1:0] wb_data_o,
    output reg [DATA_WIDTH/8-1:0] wb_sel_o,
    output reg wb_we_o,
    output logic [31:0] rf_wdata_o,
    output logic rf_wen_o,
    output logic mem_stall_o,
    output logic mem_flush_o

);

typedef enum logic [1:0]{
    ST_IDLE = 0,
    ST_LOAD = 1
} state_t;

state_t state;

logic [31:0] my_pc_o, my_inst_o;
logic [4:0] my_rf_waddr_o;
logic my_rf_wen_o;

logic [7:0] instr_code_reg;

logic store_buf_valid;
logic [ADDR_WIDTH-1:0] store_buf_addr;
logic [DATA_WIDTH-1:0] store_buf_data;
logic [DATA_WIDTH/8-1:0] store_buf_sel;

always_ff @ (posedge clk_i) begin
    if(rst_i)begin
        state <= ST_IDLE;
        wb_cyc_o <= 0;
        wb_stb_o <= 0;
        wb_sel_o <= 'b0000;
        pc_o <= 32'h8000_0000;
        inst_o <= 32'b0;
        rf_wen_o <= 1'b0;
        rf_waddr_o <= 5'b0;
        mem_stall_o <= 1'b0;
        mem_flush_o <= 1'b0;
        wb_addr_o <= 32'b0;
        wb_data_o <= 32'b0;
        wb_we_o <= 1'b0;
        rf_wdata_o <= 32'b0;
        my_pc_o <= 32'b0;
        my_inst_o <= 32'b0;
        my_rf_wen_o <= 1'b0;
        my_rf_waddr_o <= 5'b0;
        instr_code_reg <= 8'b0;
        store_buf_valid <= 1'b0;
        store_buf_addr <= {ADDR_WIDTH{1'b0}};
        store_buf_data <= {DATA_WIDTH{1'b0}};
        store_buf_sel <= {DATA_WIDTH/8{1'b0}};
    end else begin
            if(state == ST_IDLE)begin
                instr_code_reg <= instr_code_i;
                wb_cyc_o <= 0;
                wb_stb_o <= 0;
                wb_we_o <= 0;
                wb_addr_o <= 0;
                wb_data_o <= 0;
                wb_sel_o <= 4'b0000;
                mem_stall_o <= (store_buf_valid && mem_en_i) ? 1'b1 : 1'b0;
                if(!stall_i && mem_en_i)begin
                    case(instr_type_i)
                        INSTR_TYPE_I: begin
                            // Load instruction
                            pc_o <= pc_i;
                            inst_o <= inst_i;
                            rf_wen_o <= 0;
                            rf_waddr_o <= rf_waddr_i;
                            rf_wdata_o <= 32'b0;
                            wb_cyc_o <= 1;
                            wb_stb_o <= 1;
                            wb_we_o <= 0;
                            // Use instr_code to determine sel based on load size
                            case (instr_code_i)
                                INSTR_LB, INSTR_LBU:   // Load Byte
                                    case (mem_addr_i[1:0])
                                        2'b00: wb_sel_o <= 4'b0001;
                                        2'b01: wb_sel_o <= 4'b0010;
                                        2'b10: wb_sel_o <= 4'b0100;
                                        2'b11: wb_sel_o <= 4'b1000;
                                        default: wb_sel_o <= 4'b0000;
                                    endcase
                                INSTR_LH, INSTR_LHU: 
                                    case (mem_addr_i[1:0])
                                        2'b00: wb_sel_o <= 4'b0011;
                                        2'b10: wb_sel_o <= 4'b1100;
                                        default: wb_sel_o <= 4'b0000;
                                    endcase
                                INSTR_LW: wb_sel_o <= 4'b1111;             // Load Word
                                default: wb_sel_o <= 4'b0000;
                            endcase
                            wb_addr_o <= mem_addr_i;
                            state <= ST_LOAD;
                            mem_stall_o <= 1'b1;
                            mem_flush_o <= 1'b0;
                            my_pc_o <= pc_i;
                            my_inst_o <= inst_i;
                            my_rf_wen_o <= rf_wen_i;
                            my_rf_waddr_o <= rf_waddr_i;
                        end
                        INSTR_TYPE_S: begin
                            pc_o <= pc_i;
                            inst_o <= inst_i;
                            rf_wen_o <= 0;
                            rf_waddr_o <= rf_waddr_i;
                            rf_wdata_o <= 32'b0;
                            store_buf_sel <= 4'b0000;
                            store_buf_data <= 32'b0;
                            if(!store_buf_valid) begin
                                store_buf_valid <= 1'b1;
                                store_buf_addr <= mem_addr_i;
                                case (instr_code_i)
                                    INSTR_SB: begin
                                        store_buf_sel <= (4'b0001 << mem_addr_i[1:0]);
                                        store_buf_data <= mem_data_i << (mem_addr_i[1:0] * 8);
                                    end
                                    INSTR_SH: begin
                                        case (mem_addr_i[1:0])
                                            2'b00: begin store_buf_sel <= 4'b0011; store_buf_data <= mem_data_i; end
                                            2'b10: begin store_buf_sel <= 4'b1100; store_buf_data <= mem_data_i << 16; end
                                            default: begin store_buf_sel <= 4'b0000; store_buf_data <= 32'b0; end
                                        endcase
                                    end
                                    INSTR_SW: begin
                                        store_buf_sel <= 4'b1111;
                                        store_buf_data <= mem_data_i;
                                    end
                                    default: begin
                                        store_buf_sel <= 4'b0000;
                                        store_buf_data <= 32'b0;
                                    end
                                endcase
                            end
                            mem_flush_o <= 1'b0;
                            my_pc_o <= pc_i;
                            my_inst_o <= inst_i;
                            my_rf_wen_o <= rf_wen_i;
                            my_rf_waddr_o <= rf_waddr_i;
                        end
                        default: begin
                            // Non-memory instruction, pass through
                            pc_o <= pc_i;
                            inst_o <= inst_i;
                            rf_wen_o <= rf_wen_i;
                            rf_waddr_o <= rf_waddr_i;
                            mem_stall_o <= 1'b0;
                            mem_flush_o <= 1'b0;
                            if(instr_type_i == INSTR_TYPE_U)begin
                                case(instr_code_i)
                                    INSTR_LUI: rf_wdata_o <= imm_i;
                                    default:   rf_wdata_o <= alu_y_i;
                                endcase
                            end else begin
                                rf_wdata_o <= alu_y_i;
                            end
                        end
                    endcase
                end else begin//跳过该阶段
                    pc_o <= pc_i;
                    inst_o <= inst_i;
                    rf_wen_o <= rf_wen_i;
                    rf_waddr_o <= rf_waddr_i;
                    mem_stall_o <= 1'b0;
                    mem_flush_o <= 1'b0;
                    if(instr_type_i == INSTR_TYPE_U)begin
                        case(instr_code_i)
                            INSTR_LUI: rf_wdata_o <= imm_i;
                            default:   rf_wdata_o <= alu_y_i;//AUIPC
                        endcase
                    end else begin
                        rf_wdata_o <= alu_y_i;
                    end
                end
                if(store_buf_valid) begin
                    wb_cyc_o <= 1;
                    wb_stb_o <= 1;
                    wb_we_o <= 1;
                    wb_addr_o <= store_buf_addr;
                    wb_data_o <= store_buf_data;
                    wb_sel_o <= store_buf_sel;
                end
            end else begin
                case(state)
                    ST_LOAD: begin
                        if(wb_ack_i == 1)begin
                            pc_o <= my_pc_o;
                            inst_o <= my_inst_o;
                            rf_wen_o <= my_rf_wen_o;
                            rf_waddr_o <= my_rf_waddr_o;
                            case (instr_code_reg)
                                INSTR_LW: rf_wdata_o <= wb_data_i;
                                INSTR_LH: begin
                                    case (wb_addr_o[1:0])
                                        2'b00: rf_wdata_o <= {{16{wb_data_i[15]}}, wb_data_i[15:0]};
                                        2'b10: rf_wdata_o <= {{16{wb_data_i[31]}}, wb_data_i[31:16]};
                                    endcase
                                end
                                INSTR_LHU: begin
                                    case (wb_addr_o[1:0])
                                        2'b00: rf_wdata_o <= {16'b0, wb_data_i[15:0]};
                                        2'b10: rf_wdata_o <= {16'b0, wb_data_i[31:16]};
                                    endcase
                                end
                                INSTR_LB: begin
                                    case (wb_addr_o[1:0])
                                        2'b00: rf_wdata_o <= {{24{wb_data_i[7]}}, wb_data_i[7:0]};
                                        2'b01: rf_wdata_o <= {{24{wb_data_i[15]}}, wb_data_i[15:8]};
                                        2'b10: rf_wdata_o <= {{24{wb_data_i[23]}}, wb_data_i[23:16]};
                                        2'b11: rf_wdata_o <= {{24{wb_data_i[31]}}, wb_data_i[31:24]};
                                    endcase
                                end
                                INSTR_LBU: begin
                                    case (wb_addr_o[1:0])
                                        2'b00: rf_wdata_o <= {24'b0, wb_data_i[7:0]};
                                        2'b01: rf_wdata_o <= {24'b0, wb_data_i[15:8]};
                                        2'b10: rf_wdata_o <= {24'b0, wb_data_i[23:16]};
                                        2'b11: rf_wdata_o <= {24'b0, wb_data_i[31:24]};
                                    endcase
                                end
                            endcase
                            state <= ST_IDLE;
                            wb_cyc_o <= 0;
                            wb_stb_o <= 0;
                            wb_we_o <= 0;
                            mem_stall_o <= 1'b0;
                            mem_flush_o <= 1'b0;
                        end
                    end
                endcase
            end
            if((store_buf_valid && state != ST_LOAD && wb_ack_i) || mem_flush_o) begin
                store_buf_valid <= 1'b0;
                store_buf_addr <= {ADDR_WIDTH{1'b0}};
                store_buf_data <= {DATA_WIDTH{1'b0}};
                store_buf_sel <= {DATA_WIDTH/8{1'b0}};
            end
    end
end





endmodule