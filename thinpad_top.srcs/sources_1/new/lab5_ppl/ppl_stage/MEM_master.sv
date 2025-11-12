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
    input wire [2:0] imm_type_i,
    input wire [3:0] instr_type_i,
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
    ST_LOAD = 1,
    ST_STORE = 2
} state_t;

typedef enum logic [3:0] {
    INSTR_TYPE_ERR = 4'b0000,
    INSTR_TYPE_R = 4'b0001,
    INSTR_TYPE_I = 4'b0010,
    INSTR_TYPE_S = 4'b0011,
    INSTR_TYPE_B = 4'b0100,
    INSTR_TYPE_U = 4'b0101
} instr_type_t;

state_t state;

logic [31:0] my_pc_o, my_inst_o;
logic [4:0] my_rf_waddr_o;
logic my_rf_wen_o;




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
    end else begin
            if(state == ST_IDLE)begin
                if(!stall_i && mem_en_i)begin
                    case(instr_type_i)
                        INSTR_TYPE_I: begin
                            // Load instruction
                            pc_o <= pc_i;
                            inst_o <= inst_i;
                            rf_wen_o <= 0;
                            rf_waddr_o <= rf_waddr_i;
                            wb_cyc_o <= 1;
                            wb_stb_o <= 1;
                            wb_we_o <= 0;
                            if (inst_i[14:12] == 3'b000) wb_sel_o <= 4'b0001;
                            else if (inst_i[14:12] == 3'b010) wb_sel_o <= 4'b1111;
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
                            // Store instruction
                            pc_o <= pc_i;
                            inst_o <= inst_i;
                            rf_wen_o <= 0;
                            rf_waddr_o <= rf_waddr_i;
                            wb_cyc_o <= 1;
                            wb_stb_o <= 1;
                            wb_we_o <= 1;
                            if (inst_i[14:12] == 3'b000) wb_sel_o <= 4'b0001;
                            else if (inst_i[14:12] == 3'b010) wb_sel_o <= 4'b1111;
                            wb_addr_o <= mem_addr_i;
                            wb_data_o <= mem_data_i;
                            state <= ST_STORE;
                            mem_stall_o <= 1'b1;
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
                        rf_wdata_o <= imm_i;
                    end else begin
                        rf_wdata_o <= alu_y_i;
                    end
                end
            end else begin
                case(state)
                    ST_LOAD: begin
                        if(wb_ack_i == 1)begin
                            pc_o <= my_pc_o;
                            inst_o <= my_inst_o;
                            rf_wen_o <= my_rf_wen_o;
                            rf_waddr_o <= my_rf_waddr_o;
                            rf_wdata_o <= wb_data_i;
                            state <= ST_IDLE;
                            wb_cyc_o <= 0;
                            wb_stb_o <= 0;
                            wb_we_o <= 1;
                            mem_stall_o <= 1'b0;
                            mem_flush_o <= 1'b0;
                        end
                    end
                    ST_STORE: begin
                        if(wb_ack_i == 1)begin
                            pc_o <= my_pc_o;
                            inst_o <= my_inst_o;
                            rf_wen_o <= my_rf_wen_o;
                            rf_waddr_o <= my_rf_waddr_o;
                            rf_wdata_o <= 32'b0;
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
    end
end





endmodule