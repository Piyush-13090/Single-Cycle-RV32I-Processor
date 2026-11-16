// ============================================================================
// tb_alu.v - unit testbench for the ALU
// Directed corner cases + 1000 random vectors per operation, checked against
// a behavioural reference. Prints PASS/FAIL summary.
// ============================================================================
`timescale 1ns/1ps
`include "defines.vh"
module tb_alu;
    reg  [31:0] a, b;
    reg  [3:0]  ctrl;
    wire [31:0] result;
    wire        zero;
    integer errors = 0, tests = 0, i, k;

    alu dut (.a(a), .b(b), .alu_ctrl(ctrl), .result(result), .zero(zero));

    function [31:0] model(input [3:0] c, input [31:0] x, input [31:0] y);
        case (c)
            `ALU_ADD: model = x + y;
            `ALU_SUB: model = x - y;
            `ALU_AND: model = x & y;
            `ALU_OR:  model = x | y;
            `ALU_XOR: model = x ^ y;
            default:  model = 0;
        endcase
    endfunction

    task check(input [3:0] c, input [31:0] x, input [31:0] y);
        reg [31:0] exp;
        begin
            ctrl = c; a = x; b = y; #1;
            exp = model(c, x, y);
            tests = tests + 1;
            if (result !== exp || zero !== (exp == 0)) begin
                errors = errors + 1;
                $display("FAIL ctrl=%b a=%h b=%h : got %h (zero=%b) expected %h",
                         c, x, y, result, zero, exp);
            end
        end
    endtask

    reg [3:0] ops [0:4];
    initial begin
        $dumpfile("sim/tb_alu.vcd");
        $dumpvars(0, tb_alu);
        ops[0] = `ALU_ADD; ops[1] = `ALU_SUB; ops[2] = `ALU_AND;
        ops[3] = `ALU_OR;  ops[4] = `ALU_XOR;

        // directed corner cases
        check(`ALU_ADD, 32'd5, 32'd7);                 // 12
        check(`ALU_ADD, 32'hFFFF_FFFF, 32'd1);         // wrap-around -> 0, zero=1
        check(`ALU_ADD, 32'h7FFF_FFFF, 32'd1);         // signed overflow
        check(`ALU_SUB, 32'd10, 32'd10);               // 0, zero=1 (BEQ case)
        check(`ALU_SUB, 32'd3, 32'd5);                 // negative result
        check(`ALU_SUB, 32'h8000_0000, 32'd1);
        check(`ALU_AND, 32'hF0F0_F0F0, 32'h0FF0_0FF0);
        check(`ALU_OR,  32'hF0F0_F0F0, 32'h0F0F_0F0F); // all ones
        check(`ALU_XOR, 32'hAAAA_AAAA, 32'hAAAA_AAAA); // 0, zero=1
        check(`ALU_XOR, 32'h1234_5678, 32'hFFFF_FFFF); // bitwise NOT

        // random vectors
        for (k = 0; k < 5; k = k + 1)
            for (i = 0; i < 1000; i = i + 1)
                check(ops[k], $random, $random);

        if (errors == 0) $display("tb_alu: PASS (%0d tests)", tests);
        else             $display("tb_alu: FAIL (%0d errors / %0d tests)", errors, tests);
        $finish;
    end
endmodule
