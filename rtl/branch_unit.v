// ============================================================================
// branch_unit.v - Branch decision logic
// Decides whether the next PC is the branch target (pc_src = 1) or PC + 4.
//   BEQ (funct3 = 000) : taken when rs1 == rs2  (ALU zero = 1)
//   BNE (funct3 = 001) : taken when rs1 != rs2  (ALU zero = 0)
// ============================================================================
`default_nettype none
`include "defines.vh"
module branch_unit (
    input  wire       branch,     // from control unit
    input  wire [2:0] funct3,
    input  wire       zero,       // from ALU (rs1 - rs2 == 0)
    output wire       pc_src      // 1 = take branch
);
    assign pc_src = branch & ((funct3 == `F3_BEQ) ?  zero :
                              (funct3 == `F3_BNE) ? ~zero : 1'b0);
endmodule
`default_nettype wire
