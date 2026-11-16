// ============================================================================
// tb_control_unit.v - unit testbench for Control Unit + ALU Control
// Checks the full control-signal truth table for all 10 instructions and
// that unsupported encodings are flagged illegal with no writes enabled.
// ============================================================================
`timescale 1ns/1ps
`include "defines.vh"
module tb_control_unit;
    reg  [6:0] opcode;
    reg  [2:0] funct3;
    reg  [6:0] funct7;
    wire reg_write, alu_src, mem_write, mem_read, mem_to_reg, branch, illegal;
    wire [1:0] alu_op, imm_sel;
    wire [3:0] alu_ctrl;
    integer errors = 0, tests = 0;

    control_unit dut (.opcode(opcode), .funct3(funct3), .funct7(funct7),
        .reg_write(reg_write), .alu_src(alu_src), .mem_write(mem_write),
        .mem_read(mem_read), .mem_to_reg(mem_to_reg), .branch(branch),
        .alu_op(alu_op), .imm_sel(imm_sel), .illegal(illegal));

    alu_control dut2 (.alu_op(alu_op), .funct3(funct3), .funct7_b5(funct7[5]),
                      .alu_ctrl(alu_ctrl));

    // expected: {reg_write, alu_src, mem_write, mem_read, mem_to_reg, branch, illegal}
    task check(input [8*6-1:0] name, input [6:0] op, input [2:0] f3, input [6:0] f7,
               input [6:0] exp_sig, input [3:0] exp_alu, input [1:0] exp_imm, input chk_imm);
        reg [6:0] got;
        begin
            opcode = op; funct3 = f3; funct7 = f7; #1;
            got = {reg_write, alu_src, mem_write, mem_read, mem_to_reg, branch, illegal};
            tests = tests + 1;
            if (got !== exp_sig || (!illegal && alu_ctrl !== exp_alu) ||
                (chk_imm && imm_sel !== exp_imm)) begin
                errors = errors + 1;
                $display("FAIL %-6s : sig=%b (exp %b) alu=%b (exp %b) imm=%b (exp %b)",
                         name, got, exp_sig, alu_ctrl, exp_alu, imm_sel, exp_imm);
            end else
                $display("  ok  %-6s RegW=%b ALUSrc=%b MemW=%b MemR=%b Mem2Reg=%b Br=%b Ill=%b ALUOp=%b ALUctrl=%b ImmSel=%b",
                         name, reg_write, alu_src, mem_write, mem_read, mem_to_reg,
                         branch, illegal, alu_op, alu_ctrl, imm_sel);
        end
    endtask

    initial begin
        //            name     opcode      f3      f7          RAMMMBI     ALU       IMM   chk
        check("ADD",  `OP_RTYPE, 3'b000, 7'b0000000, 7'b1000000, `ALU_ADD, 2'b00, 0);
        check("SUB",  `OP_RTYPE, 3'b000, 7'b0100000, 7'b1000000, `ALU_SUB, 2'b00, 0);
        check("AND",  `OP_RTYPE, 3'b111, 7'b0000000, 7'b1000000, `ALU_AND, 2'b00, 0);
        check("OR",   `OP_RTYPE, 3'b110, 7'b0000000, 7'b1000000, `ALU_OR,  2'b00, 0);
        check("XOR",  `OP_RTYPE, 3'b100, 7'b0000000, 7'b1000000, `ALU_XOR, 2'b00, 0);
        check("ADDI", `OP_ITYPE, 3'b000, 7'b0100000, 7'b1100000, `ALU_ADD, `IMM_I, 1); // f7 bits are imm here
        check("LW",   `OP_LOAD,  3'b010, 7'b0000000, 7'b1101100, `ALU_ADD, `IMM_I, 1);
        check("SW",   `OP_STORE, 3'b010, 7'b0000000, 7'b0110000, `ALU_ADD, `IMM_S, 1);
        check("BEQ",  `OP_BRANCH,3'b000, 7'b0000000, 7'b0000010, `ALU_SUB, `IMM_B, 1);
        check("BNE",  `OP_BRANCH,3'b001, 7'b0000000, 7'b0000010, `ALU_SUB, `IMM_B, 1);
        // unsupported encodings -> illegal, all writes disabled
        check("SLT",  `OP_RTYPE, 3'b010, 7'b0000000, 7'b0000001, 4'b0000, 2'b00, 0);
        check("SRA",  `OP_RTYPE, 3'b101, 7'b0100000, 7'b0000001, 4'b0000, 2'b00, 0);
        check("XORI", `OP_ITYPE, 3'b100, 7'b0000000, 7'b0000001, 4'b0000, 2'b00, 0);
        check("LB",   `OP_LOAD,  3'b000, 7'b0000000, 7'b0000001, 4'b0000, 2'b00, 0);
        check("SB",   `OP_STORE, 3'b000, 7'b0000000, 7'b0000001, 4'b0000, 2'b00, 0);
        check("BLT",  `OP_BRANCH,3'b100, 7'b0000000, 7'b0000001, 4'b0000, 2'b00, 0);
        check("JAL",  7'b1101111,3'b000, 7'b0000000, 7'b0000001, 4'b0000, 2'b00, 0);
        check("ZERO", 7'b0000000,3'b000, 7'b0000000, 7'b0000001, 4'b0000, 2'b00, 0);

        if (errors == 0) $display("tb_control_unit: PASS (%0d tests)", tests);
        else             $display("tb_control_unit: FAIL (%0d errors / %0d tests)", errors, tests);
        $finish;
    end
endmodule
