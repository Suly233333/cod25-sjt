module WB (
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] rf_wdata_i,
    input wire [4:0] rf_waddr_i,
    input wire rf_wen_i,
    input wire [31:0] pc_i,
    input wire [31:0] inst_i,

    output logic [4:0] rf_waddr_o,
    output logic [31:0] rf_wdata_o,
    output logic rf_wen_o


);


    always_comb begin
        rf_wen_o = rf_wen_i;
        rf_waddr_o = 5'b0;
        rf_wdata_o = 32'b0;
        if(rf_wen_i)begin
            rf_waddr_o = rf_waddr_i;
            rf_wdata_o = rf_wdata_i;
        end
    end



endmodule