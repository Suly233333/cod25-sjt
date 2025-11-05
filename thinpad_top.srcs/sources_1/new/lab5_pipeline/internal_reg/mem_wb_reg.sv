module mem_wb (
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] rf_wdata_i,
    input wire [4:0]  rf_waddr_i,
    input wire        rf_we_i,

    output logic [31:0] rf_wdata_o,
    output logic [4:0]  rf_waddr_o,
    output logic        rf_we_o,

    input wire stall_i,
    input wire bubble_i

);
always_ff @(posedge clk_i) begin
    if(rst_i) begin
        //reset logics
        rf_wdata_o <= 32'b0;
        rf_waddr_o <= 5'b0;
        rf_we_o <= 1'b0;
    end else if(stall_i) begin
        //do nothing
    end else if(bubble_i) begin
        //change regs to bubble
        rf_wdata_o <= 32'b0;
        rf_waddr_o <= 5'b0;
        rf_we_o <= 1'b0;
    end else begin
        //change regs to input
        rf_wdata_o <= rf_wdata_i;
        rf_waddr_o <= rf_waddr_i;
        rf_we_o <= rf_we_i;
    end 
end 

endmodule