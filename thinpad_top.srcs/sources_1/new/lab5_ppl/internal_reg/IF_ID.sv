module if_id (
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] pc_i,
    input wire [31:0] inst_i,
    input wire valid,

    output logic [31:0] pc_o,
    output logic [31:0] inst_o,

    input wire stall_i,
    input wire bubble_i

);

always_ff @(posedge clk_i) begin
    if(rst_i) begin
        //reset logics
        pc_o <= 32'h8000_0000;
        inst_o <= 32'b0;
    end else if(stall_i) begin
        //do nothing
    end else if(bubble_i || !valid) begin
        //change regs to bubble
        pc_o <= 32'b0;
        inst_o <= 32'h00000013;
    end else begin
        //change regs to input
        pc_o <= pc_i;
        inst_o <= inst_i;
    end
end




    
endmodule