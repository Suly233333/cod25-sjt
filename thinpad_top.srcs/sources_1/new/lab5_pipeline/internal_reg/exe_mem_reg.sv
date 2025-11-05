module exe_mem (
    input wire clk_i,
    input wire rst_i,

    input wire [3:0]  instr_type_i,
    input wire [4:0]  rf_waddr_i,
    input wire [31:0] rf_wdata_i,//imm in U-type instruction
    input wire [31:0] alu_result_i,
    input wire        rf_we_i,
    input wire        mem_en_i,
    input wire [31:0] mem_addr_i,
    input wire [31:0] mem_data_i,

    output logic [3:0]  instr_type_o,
    output logic [4:0]  rf_waddr_o,
    output logic [31:0] rf_wdata_o,
    output logic [31:0] alu_result_o,
    output logic        rf_we_o,
    output logic        mem_en_o,
    output logic [31:0] mem_addr_o,
    output logic [31:0] mem_data_o,

    input wire stall_i,
    input wire bubble_i

);

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            instr_type_o <= 4'b1;
            rf_waddr_o   <= 5'b0;
            rf_wdata_o   <= 32'b0;
            alu_result_o <= 32'b0;
            rf_we_o      <= 1'b0;
            mem_en_o     <= 1'b0;
            mem_addr_o   <= 32'b0;
            mem_data_o   <= 32'b0;
        end else if (stall_i) begin
            // do nothing
        end else if (bubble_i) begin
            instr_type_o <= 4'b1;
            rf_waddr_o   <= 5'b0;
            rf_wdata_o   <= 32'b0;
            alu_result_o <= 32'b0;
            rf_we_o      <= 1'b0;
            mem_en_o     <= 1'b0;
            mem_addr_o   <= 32'b0;
            mem_data_o   <= 32'b0;
        end else begin
            instr_type_o <= instr_type_i;
            rf_waddr_o   <= rf_waddr_i;
            rf_wdata_o   <= rf_wdata_i;
            alu_result_o <= alu_result_i;
            rf_we_o      <= rf_we_i;
            mem_en_o     <= mem_en_i;
            mem_addr_o   <= mem_addr_i;
            mem_data_o   <= mem_data_i;
        end
    end

endmodule