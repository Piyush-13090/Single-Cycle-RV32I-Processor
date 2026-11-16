// ============================================================================
// alu_control.v - ALU Control
// Converts ALUOp (from the main control unit) plus funct3 / funct7[5] into
// the 4-bit operation code the ALU understands.
//
//  ALUOp | funct7[5] funct3 | operation
//  ------+------------------+----------
//   00   |    x       xxx   | ADD   (LW / SW address)
//   01   |    x       xxx   | SUB   (BEQ / BNE compare)
//   10   |    0       000   | ADD
//   10   |    1       000   | SUB
//   10   |    0       111   | AND
//   10   |    0       110   | OR
//   10   |    0       100   | XOR
//   11   |    x       000   | ADD   (ADDI)
// ============================================================================
`default_nettype none
`include "defines.vh"
module alu_control (
    input  wire [1:0] alu_op,
    input  wire [2:0] funct3,
    input  wire       funct7_b5,   // instr[30]
    output reg  [3:0] alu_ctrl
);
    always @(*) begin
        case (alu_op)
            `ALUOP_ADD: alu_ctrl = `ALU_ADD;
            `ALUOP_SUB: alu_ctrl = `ALU_SUB;
            `ALUOP_RTYPE: begin
                case (funct3)
                    `F3_ADD_SUB: alu_ctrl = funct7_b5 ? `ALU_SUB : `ALU_ADD;
                    `F3_AND:     alu_ctrl = `ALU_AND;
                    `F3_OR:      alu_ctrl = `ALU_OR;
                    `F3_XOR:     alu_ctrl = `ALU_XOR;
                    default:     alu_ctrl = `ALU_ADD;
                endcase
            end
            `ALUOP_ITYPE: begin
                // only ADDI is supported among immediate ALU instructions
                alu_ctrl = `ALU_ADD;
            end
            default: alu_ctrl = `ALU_ADD;
        endcase
    end
endmodule
`default_nettype wire
