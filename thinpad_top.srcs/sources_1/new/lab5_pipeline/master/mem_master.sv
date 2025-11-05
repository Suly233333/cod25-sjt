module mem_master (
    input wire clk_i,
    input wire rst_i,

    // from EXE/MEM Pipeline Register
    input wire [3:0]  instr_type_i,
    input wire [4:0]  rf_waddr_i,
    input wire [31:0] rf_wdata_i,//immediately from EXE stage
    input wire [31:0] alu_result_i,
    input wire        rf_we_i,
    input wire        mem_en_i,
    input wire [31:0] mem_addr_i,
    input wire [31:0] mem_data_i,//

    // to MEM/WB Pipeline Register
    output logic [4:0]  rf_waddr_o,
    output logic [31:0] rf_wdata_o,// alu_result_o or immediately from MEM stage
    output logic        rf_we_o,

    // Wishbone Master Interface
    output reg       wbm_cyc_o,
    output reg       wbm_stb_o,
    input  wire       wbm_ack_i,
    output logic [31:0] wbm_adr_o,
    output logic [31:0] wbm_dat_o,
    input  wire [31:0] wbm_dat_i,
    output logic [ 3:0] wbm_sel_o,
    output logic        wbm_we_o,

    input wire stall_o,
    input wire flush_o
);

typedef enum logic [1:0]{
    ST_IDLE = 0,
    ST_LOAD = 1,
    ST_STORE = 2
} state_t;
state_t state;

typedef enum logic [3:0] {
    LUI = 4'b0000,
    BEQ = 4'b0001,
    LB  = 4'b0010,
    SB  = 4'b0011,
    SW  = 4'b0100,
    ADDI = 4'b0101,
    ANDI = 4'b0110,
    ADD  = 4'b0111,
    ERR = 4'b1111
} instr_type_t;

always_ff @( posedge clk_i ) begin
    if (rst_i) begin
        state       <= ST_IDLE;
        wbm_cyc_o   <= 1'b0;
        wbm_stb_o   <= 1'b0;
        wbm_sel_o   <= 4'b1111;
    end else begin
        case ( state )
            ST_IDLE: begin
                if ( mem_en_i ) begin
                    case ( instr_type_i )
                        LB: begin
                            wbm_adr_o   <= mem_addr_i;
                            wbm_we_o    <= 1'b0;
                            wbm_cyc_o   <= 1'b1;
                            wbm_stb_o   <= 1'b1;
                            wbm_sel_o   <= 4'b1111;
                            state       <= ST_LOAD;
                        end
                        SB: begin
                            wbm_adr_o   <= mem_addr_i;
                            wbm_dat_o   <= mem_data_i;
                            wbm_we_o    <= 1'b1;
                            wbm_cyc_o   <= 1'b1;
                            wbm_stb_o   <= 1'b1;
                            wbm_sel_o   <= 4'b0011;
                            state       <= ST_STORE;
                        end
                        SW: begin
                            wbm_adr_o   <= mem_addr_i;
                            wbm_dat_o   <= mem_data_i;
                            wbm_we_o    <= 1'b1;
                            wbm_cyc_o   <= 1'b1;
                            wbm_stb_o   <= 1'b1;
                            wbm_sel_o   <= 4'b1111;
                            state       <= ST_STORE;
                        end
                    endcase
                end else begin
                        rf_waddr_o  <= rf_waddr_i;
                        rf_we_o     <= rf_we_i;
                    case (instr_type_i)
                        LUI: begin
                            rf_wdata_o  <= rf_wdata_i;
                        end
                        ADDI: begin
                            rf_wdata_o  <= alu_result_i;
                        end
                        ANDI: begin
                            rf_wdata_o  <= alu_result_i;
                        end
                        ADD: begin
                            rf_wdata_o  <= alu_result_i;
                        end
                        default: begin
                            rf_wdata_o  <= alu_result_i;
                        end
                    endcase
                end
            end
            ST_LOAD: begin
                if ( wbm_ack_i ) begin
                    rf_waddr_o  <= rf_waddr_i;
                    rf_wdata_o  <= wbm_dat_i;
                    rf_we_o     <= rf_we_i;
                    wbm_cyc_o   <= 1'b0;
                    wbm_stb_o   <= 1'b0;
                    wbm_we_o    <= 1'b1;
                    state       <= ST_IDLE;
                end
            end
            ST_STORE: begin
                if ( wbm_ack_i ) begin
                    rf_waddr_o  <= rf_waddr_i;
                    rf_wdata_o  <= 32'b0;
                    rf_we_o     <= rf_we_i;
                    wbm_cyc_o   <= 1'b0;
                    wbm_stb_o   <= 1'b0;
                    wbm_we_o    <= 1'b0;
                    state       <= ST_IDLE;
                end
            end
            default: begin
                state       <= ST_IDLE;
            end
        endcase
    end
end

endmodule