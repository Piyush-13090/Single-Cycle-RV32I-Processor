// ============================================================================
// imm_gen.v - Immediate Generator
// Extracts the immediate field of the instruction and sign-extends it to
// 32 bits. Three formats are needed for the supported subset:
//
//  I-type (ADDI, LW): imm[11:0]  = instr[31:20]
//  S-type (SW)      : imm[11:5]  = instr[31:25], imm[4:0] = instr[11:7]
//  B-type (BEQ, BNE): imm[12|10:5|4:1|11] = instr[31|30:25|11:8|7], imm[0]=0
// ============================================================================
`default_nettype none
`include "defines.vh"
module imm_gen (
    input  wire [31:0] instr,
    input  wire [1:0]  imm_sel,
    output reg  [31:0] imm
);
    always @(*) begin
        case (imm_sel)
            `IMM_I:  imm = {{20{instr[31]}}, instr[31:20]};
            `IMM_S:  imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            `IMM_B:  imm = {{19{instr[31]}}, instr[31], instr[7],
                            instr[30:25], instr[11:8], 1'b0};
            default: imm = 32'h0000_0000;
        endcase
    end
endmodule
`default_nettype wire
