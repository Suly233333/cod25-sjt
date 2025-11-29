module mem_wb(
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] pc_i,
    input wire [4:0] rf_waddr_i,
    input wire [31:0] rf_wdata_i,
    input wire [31:0] inst_i,
    input wire rf_wen_i,
    input wire stall_i,

    output logic [31:0] pc_o,
    output logic [4:0] rf_waddr_o,
    output logic [31:0] rf_wdata_o,
    output logic [31:0] inst_o,
    output logic rf_wen_o

);

always_ff @(posedge clk_i) begin
    if(rst_i) begin
        //reset logics
        pc_o <= 32'h8000_0000;
        inst_o <= 32'b0;
        rf_waddr_o <= 5'b0;
        rf_wdata_o <= 32'b0;
        rf_wen_o <= 0;
    end else if (stall_i) begin
        // do nothing
    end else begin
        // When stalled, keep previous outputs; otherwise latch inputs
            pc_o <= pc_i;
            inst_o <= inst_i;
            rf_waddr_o <= rf_waddr_i;
            rf_wdata_o <= rf_wdata_i;
            rf_wen_o <= rf_wen_i;
    end
end



endmodule