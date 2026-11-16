// ============================================================================
// reg_file.v - 32 x 32-bit Register File
//  * two asynchronous (combinational) read ports  : rs1, rs2
//  * one synchronous write port (rising clock edge): rd
//  * x0 is hard-wired to zero (writes to x0 are ignored, reads return 0)
// ============================================================================
`default_nettype none
module reg_file (
    input  wire        clk,
    input  wire        we,          // write enable (RegWrite & clock-enable)
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] rd_data,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data
);
    reg [31:0] regs [0:31];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 32'h0000_0000;
    end

    always @(posedge clk) begin
        if (we && rd_addr != 5'd0)
            regs[rd_addr] <= rd_data;
    end

    assign rs1_data = (rs1_addr == 5'd0) ? 32'h0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'h0 : regs[rs2_addr];
endmodule
`default_nettype wire
