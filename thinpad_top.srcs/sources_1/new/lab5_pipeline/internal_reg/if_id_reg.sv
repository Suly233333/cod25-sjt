module if_id (
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] pc_i,
    input wire [31:0] inst_i,

    output logic [31:0] pc_o,
    output logic [31:0] inst_o,

    input wire stall_i,
    input wire bubble_i

);
    // // note that outputs are always bound to the regs
    // always_ff @(posedge clk_i) begin
    //     if(rst_i) begin
    //         //reset logics
    //     end else if(stall_i) begin
    //         //do nothing
    //     end else if(bubble_i) begin
    //         //change regs to bubble
    //     end else begin
    //         //change regs to input
    //     end
    // end
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            pc_o <= 32'b0;
            inst_o <= 32'b0;
        end else if (stall_i) begin
            pc_o <= pc_o;
            inst_o <= inst_o;
        end else if (bubble_i) begin
            pc_o <= 32'b0;
            inst_o <= 32'h00000013; // NOP instruction
        end else begin
            pc_o <= pc_i;
            inst_o <= inst_i;
        end
    end

endmodule