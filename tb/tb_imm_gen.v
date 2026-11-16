// ============================================================================
// tb_imm_gen.v - unit testbench for the Immediate Generator
// Uses real instruction encodings (from the assembler) with positive and
// negative immediates for the I, S and B formats.
// ============================================================================
`timescale 1ns/1ps
`include "defines.vh"
module tb_imm_gen;
    reg  [31:0] instr;
    reg  [1:0]  sel;
    wire [31:0] imm;
    integer errors = 0, tests = 0;

    imm_gen dut (.instr(instr), .imm_sel(sel), .imm(imm));

    task check(input [31:0] ins, input [1:0] s, input [31:0] exp, input [8*24-1:0] txt);
        begin
            instr = ins; sel = s; #1;
            tests = tests + 1;
            if (imm !== exp) begin
                errors = errors + 1;
                $display("FAIL %0s: instr=%h got %h expected %h", txt, ins, imm, exp);
            end else
                $display("  ok  %-22s instr=%h imm=%h (%0d)", txt, ins, imm, $signed(imm));
        end
    endtask

    initial begin
        check(32'h00500093, `IMM_I, 32'd5,            "addi x1,x0,5");
        check(32'hFFF00093, `IMM_I, 32'hFFFF_FFFF,    "addi x1,x0,-1");
        check(32'h7FF00093, `IMM_I, 32'd2047,         "addi x1,x0,2047");
        check(32'h80000093, `IMM_I, -32'sd2048,       "addi x1,x0,-2048");
        check(32'h00812183, `IMM_I, 32'd8,            "lw x3,8(x2)");
        check(32'h00312423, `IMM_S, 32'd8,            "sw x3,8(x2)");
        check(32'hFE312E23, `IMM_S, -32'sd4,          "sw x3,-4(x2)");
        check(32'h7E312FA3, `IMM_S, 32'd2047,         "sw x3,2047(x2)");
        check(32'h00208463, `IMM_B, 32'd8,            "beq x1,x2,+8");
        check(32'hFE209EE3, `IMM_B, -32'sd4,          "bne x1,x2,-4");
        check(32'h7E208FE3, `IMM_B, 32'd4094,         "beq x1,x2,+4094");
        check(32'h80208063, `IMM_B, -32'sd4096,       "beq x1,x2,-4096");
        check(32'h00000063, `IMM_B, 32'd0,            "beq x0,x0,0 (halt)");

        if (errors == 0) $display("tb_imm_gen: PASS (%0d tests)", tests);
        else             $display("tb_imm_gen: FAIL (%0d errors / %0d tests)", errors, tests);
        $finish;
    end
endmodule
