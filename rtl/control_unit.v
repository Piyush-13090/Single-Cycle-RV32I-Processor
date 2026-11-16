// ============================================================================
// control_unit.v - Main Control Unit / Instruction Decoder
// Looks at the opcode (and funct3/funct7 to reject unsupported encodings)
// and generates the datapath control signals for one instruction.
//
//  Instr | RegWrite ALUSrc MemWrite MemRead MemToReg Branch ALUOp ImmSel
//  ------+--------------------------------------------------------------
//  R-type|    1       0       0        0       0       0     10     --
//  ADDI  |    1       1       0        0       0       0     11     I
//  LW    |    1       1       0        1       1       0     00     I
//  SW    |    0       1       1        0       -       0     00     S
//  BEQ/NE|    0       0       0        0       -       1     01     B
//  other |    0       0       0        0       0       0     00     -   (illegal -> NOP)
// ============================================================================
`default_nettype none
`include "defines.vh"
module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg        reg_write,   // write rd in the register file
    output reg        alu_src,     // 0: ALU B = rs2,  1: ALU B = immediate
    output reg        mem_write,   // store to data memory
    output reg        mem_read,    // load from data memory
    output reg        mem_to_reg,  // write-back select: 0 = ALU, 1 = memory
    output reg        branch,      // instruction is a conditional branch
    output reg  [1:0] alu_op,      // to ALU control
    output reg  [1:0] imm_sel,     // immediate format for immediate generator
    output reg        illegal      // unsupported instruction (executed as NOP)
);
    always @(*) begin
        // safe defaults = NOP (nothing written anywhere)
        reg_write  = 1'b0;
        alu_src    = 1'b0;
        mem_write  = 1'b0;
        mem_read   = 1'b0;
        mem_to_reg = `WB_ALU;
        branch     = 1'b0;
        alu_op     = `ALUOP_ADD;
        imm_sel    = `IMM_I;
        illegal    = 1'b0;

        case (opcode)
            `OP_RTYPE: begin
                // ADD/SUB need funct7 = 0000000/0100000, XOR/OR/AND need 0000000
                if ((funct3 == `F3_ADD_SUB && (funct7 == 7'b0000000 || funct7 == 7'b0100000)) ||
                    ((funct3 == `F3_XOR || funct3 == `F3_OR || funct3 == `F3_AND) && funct7 == 7'b0000000)) begin
                    reg_write = 1'b1;
                    alu_op    = `ALUOP_RTYPE;
                end else
                    illegal = 1'b1;
            end
            `OP_ITYPE: begin
                if (funct3 == `F3_ADD_SUB) begin          // ADDI
                    reg_write = 1'b1;
                    alu_src   = 1'b1;
                    alu_op    = `ALUOP_ITYPE;
                    imm_sel   = `IMM_I;
                end else
                    illegal = 1'b1;
            end
            `OP_LOAD: begin
                if (funct3 == `F3_LW_SW) begin            // LW
                    reg_write  = 1'b1;
                    alu_src    = 1'b1;
                    mem_read   = 1'b1;
                    mem_to_reg = `WB_MEM;
                    alu_op     = `ALUOP_ADD;
                    imm_sel    = `IMM_I;
                end else
                    illegal = 1'b1;
            end
            `OP_STORE: begin
                if (funct3 == `F3_LW_SW) begin            // SW
                    alu_src   = 1'b1;
                    mem_write = 1'b1;
                    alu_op    = `ALUOP_ADD;
                    imm_sel   = `IMM_S;
                end else
                    illegal = 1'b1;
            end
            `OP_BRANCH: begin
                if (funct3 == `F3_BEQ || funct3 == `F3_BNE) begin
                    branch  = 1'b1;
                    alu_op  = `ALUOP_SUB;
                    imm_sel = `IMM_B;
                end else
                    illegal = 1'b1;
            end
            default: illegal = 1'b1;
        endcase
    end
endmodule
`default_nettype wire
