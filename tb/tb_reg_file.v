// ============================================================================
// tb_reg_file.v - unit testbench for the 32x32 register file
// Checks: write/read of every register, x0 hard-wired to 0, write enable,
// two independent read ports, read-before-write timing (write at clock edge).
// ============================================================================
`timescale 1ns/1ps
module tb_reg_file;
    reg         clk = 0, we = 0;
    reg  [4:0]  rs1 = 0, rs2 = 0, rd = 0;
    reg  [31:0] wd = 0;
    wire [31:0] r1, r2;
    integer errors = 0, tests = 0, i;

    reg_file dut (.clk(clk), .we(we), .rs1_addr(rs1), .rs2_addr(rs2),
                  .rd_addr(rd), .rd_data(wd), .rs1_data(r1), .rs2_data(r2));

    always #5 clk = ~clk;

    task expect(input [31:0] got, input [31:0] exp, input [8*32-1:0] what);
        begin
            tests = tests + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("FAIL %0s: got %h expected %h", what, got, exp);
            end
        end
    endtask

    initial begin
        $dumpfile("sim/tb_reg_file.vcd");
        $dumpvars(0, tb_reg_file);

        // 1. write a unique value into every register x1..x31
        for (i = 1; i < 32; i = i + 1) begin
            @(negedge clk); we = 1; rd = i; wd = 32'hA5A5_0000 + i;
        end
        @(negedge clk); we = 0;

        // 2. read back on both ports
        for (i = 0; i < 32; i = i + 1) begin
            rs1 = i; rs2 = 31 - i; #1;
            expect(r1, (i == 0) ? 0 : 32'hA5A5_0000 + i, "port1 readback");
            expect(r2, (31 - i == 0) ? 0 : 32'hA5A5_0000 + (31 - i), "port2 readback");
        end

        // 3. write to x0 must be ignored
        @(negedge clk); we = 1; rd = 0; wd = 32'hDEAD_BEEF;
        @(negedge clk); we = 0; rs1 = 0; #1;
        expect(r1, 0, "x0 stays zero");

        // 4. write-enable low must not write
        @(negedge clk); we = 0; rd = 5; wd = 32'h1111_1111;
        @(negedge clk); rs1 = 5; #1;
        expect(r1, 32'hA5A5_0005, "we=0 no write");

        // 5. new value appears only after the clock edge
        @(negedge clk); we = 1; rd = 7; wd = 32'h7777_7777; rs1 = 7; #1;
        expect(r1, 32'hA5A5_0007, "old value before edge");
        @(posedge clk); #1;
        expect(r1, 32'h7777_7777, "new value after edge");
        we = 0;

        if (errors == 0) $display("tb_reg_file: PASS (%0d tests)", tests);
        else             $display("tb_reg_file: FAIL (%0d errors / %0d tests)", errors, tests);
        $finish;
    end
endmodule
