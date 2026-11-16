// ============================================================================
// alu.v - Arithmetic Logic Unit
// Performs ADD, SUB, AND, OR, XOR on two 32-bit operands.
// 'zero' is 1 when the result is 0; branches use it (rs1 - rs2 == 0 => equal).
// ============================================================================
`default_nettype none
`include "defines.vh"
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_ctrl,
    output reg  [31:0] result,
    output wire        zero
);
    always @(*) begin
        case (alu_ctrl)
            `ALU_ADD: result = a + b;
            `ALU_SUB: result = a - b;
            `ALU_AND: result = a & b;
            `ALU_OR:  result = a | b;
            `ALU_XOR: result = a ^ b;
            default:  result = 32'h0000_0000;
        endcase
    end

    assign zero = (result == 32'h0000_0000);
endmodule
`default_nettype wire
