// ============================================================================
// data_mem.v - Data Memory (word-organised RAM)
//  * asynchronous read  (LW result available in the same cycle)
//  * synchronous write  (SW stored at the rising clock edge)
// Addresses are byte addresses; word index = addr[..:2] (word-aligned access).
// ============================================================================
`default_nettype none
module data_mem #(
    parameter DEPTH = 256                    // number of 32-bit words (1 KB)
) (
    input  wire        clk,
    input  wire        we,                   // MemWrite & clock-enable
    input  wire        re,                   // MemRead
    input  wire [31:0] addr,                 // byte address (from ALU)
    input  wire [31:0] wdata,                // rs2 data
    output wire [31:0] rdata
);
    localparam AW = $clog2(DEPTH);

    reg [31:0] mem [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h0000_0000;
    end

    always @(posedge clk) begin
        if (we)
            mem[addr[AW+1:2]] <= wdata;
    end

    assign rdata = re ? mem[addr[AW+1:2]] : 32'h0000_0000;
endmodule
`default_nettype wire
