// ============================================================================
// adder.v - 32-bit adder used for PC + 4 and the branch target (PC + imm)
// ============================================================================
`default_nettype none
module adder (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] y
);
    assign y = a + b;
endmodule
`default_nettype wire
