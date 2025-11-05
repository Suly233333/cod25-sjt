module if_master (
    input wire          clk,
    input wire          rst,

    // From Branch Prediction Unit
    input wire [31:0]    pc_branch,
    input logic          branch_taken,

    // To IF/ID Pipeline Register
    output logic [31:0]  pc_if,
    output logic [31:0]  instruction_if,

    // Wishbone Master Interface
    output reg       wbm_cyc_o,
    output reg       wbm_stb_o,
    input  wire       wbm_ack_i,
    output logic [31:0] wbm_adr_o,
    output logic [31:0] wbm_dat_o,
    input  wire [31:0] wbm_dat_i,
    output logic [ 3:0] wbm_sel_o,
    output logic        wbm_we_o,

    // To Control Unit
    output logic          stall_o,
    output logic          flush_o
);

typedef enum logic [1:0] {
    ST_IDLE = 2'b00,
    ST_READ = 2'b01
} state_t;

logic [31:0] pc_current;
state_t state;

always_ff @( clk ) begin
    if ( rst ) begin
        pc_current      <= 32'h8000_0000;
        pc_if           <= 32'h8000_0000;
        instruction_if  <= 32'b0;
        stall_o         <= 1'b0;
        flush_o         <= 1'b0;
        state           <= ST_IDLE;
        wbm_cyc_o       <= 1'b0;
        wbm_stb_o       <= 1'b0;
        wbm_sel_o       <= 4'b1111;
    end else begin
        case ( state )
            ST_IDLE: begin
                if ( branch_taken ) begin
                    pc_current <= pc_branch;
                    flush_o    <= 1'b1;
                end else begin
                    pc_current <= pc_current + 4;
                    flush_o    <= 1'b0;
                end

                wbm_adr_o   <= pc_current;
                wbm_cyc_o   <= 1'b1;
                wbm_stb_o   <= 1'b1;
                state       <= ST_READ;
                stall_o     <= 1'b1;
            end

            ST_READ: begin
                if ( wbm_ack_i ) begin
                    instruction_if <= wbm_dat_i;
                    pc_if          <= pc_current;
                    wbm_cyc_o      <= 1'b0;
                    wbm_stb_o      <= 1'b0;
                    state          <= ST_IDLE;
                    stall_o        <= 1'b0;
                end
            end

            default: state <= ST_IDLE;
        endcase
    end
    
end

endmodule