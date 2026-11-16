// ============================================================================
// defines.vh - shared constants for the Single-Cycle RV32I processor
// ============================================================================
`ifndef RV32I_DEFINES_VH
`define RV32I_DEFINES_VH

// ---- RV32I opcodes (instr[6:0]) used by the supported subset --------------
`define OP_RTYPE   7'b0110011   // ADD, SUB, AND, OR, XOR
`define OP_ITYPE   7'b0010011   // ADDI
`define OP_LOAD    7'b0000011   // LW
`define OP_STORE   7'b0100011   // SW
`define OP_BRANCH  7'b1100011   // BEQ, BNE

// ---- funct3 values --------------------------------------------------------
`define F3_ADD_SUB 3'b000
`define F3_XOR     3'b100
`define F3_OR      3'b110
`define F3_AND     3'b111
`define F3_LW_SW   3'b010
`define F3_BEQ     3'b000
`define F3_BNE     3'b001

// ---- ALUOp (main control -> ALU control) -----------------------------------
`define ALUOP_ADD    2'b00      // loads / stores : address = rs1 + imm
`define ALUOP_SUB    2'b01      // branches       : compare rs1 - rs2
`define ALUOP_RTYPE  2'b10      // decode funct3/funct7
`define ALUOP_ITYPE  2'b11      // decode funct3 (immediate ALU ops)

// ---- ALU control codes ----------------------------------------------------
`define ALU_ADD  4'b0000
`define ALU_SUB  4'b0001
`define ALU_AND  4'b0010
`define ALU_OR   4'b0011
`define ALU_XOR  4'b0100

// ---- Immediate formats ----------------------------------------------------
`define IMM_I  2'b00
`define IMM_S  2'b01
`define IMM_B  2'b10

// ---- Write-back source ----------------------------------------------------
`define WB_ALU  1'b0
`define WB_MEM  1'b1

`endif
