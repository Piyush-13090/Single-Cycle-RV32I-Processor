// ============================================================================
// tb_rv32i_cpu.v - self-checking system testbench for the Single-Cycle CPU
//
// Compile-time macros (set by scripts/run_all.sh):
//   PROG_HEX  program to load into instruction memory
//   EXP_REGS  expected final register values  (from the golden ISS)
//   EXP_DMEM  expected final data memory      (from the golden ISS)
//   VCD_FILE  waveform output file
//   LOG_FILE  execution trace output file
//
// The test:
//   1. resets the CPU and runs it until the HALT instruction (beq x0,x0,0)
//   2. logs every executed instruction (PC, instr, write-back, store)
//   3. compares all 32 registers, every data-memory word, the final PC and
//      the instruction count with the golden reference model -> PASS / FAIL
//   4. prints instruction coverage and the cycle count / CPI
// ============================================================================
`timescale 1ns/1ps
`ifndef PROG_HEX
  `define PROG_HEX "build/alu_test.hex"
`endif
`ifndef EXP_REGS
  `define EXP_REGS "build/alu_test_exp_regs.hex"
`endif
`ifndef EXP_DMEM
  `define EXP_DMEM "build/alu_test_exp_dmem.hex"
`endif
`ifndef EXP_PC
  `define EXP_PC "build/alu_test_exp_pc.hex"
`endif
`ifndef VCD_FILE
  `define VCD_FILE "sim/tb_rv32i_cpu.vcd"
`endif
`ifndef LOG_FILE
  `define LOG_FILE "sim/tb_rv32i_cpu.log"
`endif

module tb_rv32i_cpu;
    localparam CLK_PERIOD = 10;          // 100 MHz simulation clock
    localparam DMEM_DEPTH = 256;
    localparam MAX_CYCLES = 20000;
    localparam HALT_INSTR = 32'h0000_0063;   // beq x0, x0, 0

    reg clk = 0, rst = 1, en = 1;
    wire [31:0] pc, instr, wb_data, mem_addr, mem_wdata;
    wire        reg_write, mem_write, illegal;
    wire [4:0]  rd;

    rv32i_cpu #(.IMEM_DEPTH(256), .DMEM_DEPTH(DMEM_DEPTH), .IMEM_FILE(`PROG_HEX)) dut (
        .clk(clk), .rst(rst), .en(en),
        .dbg_pc(pc), .dbg_instr(instr), .dbg_reg_write(reg_write), .dbg_rd(rd),
        .dbg_wb_data(wb_data), .dbg_mem_write(mem_write), .dbg_mem_addr(mem_addr),
        .dbg_mem_wdata(mem_wdata), .dbg_illegal(illegal)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // ------------------------------------------------- optional stall test
    // With -DSTALL_TEST the clock-enable is pulled low on pseudo-random
    // cycles. While en = 0 the CPU must freeze (no PC / register / memory
    // change), so the final results must be identical to a normal run.
    integer stall_cycles = 0;
`ifdef STALL_TEST
    integer tick = 0;
    always @(negedge clk) begin
        tick = tick + 1;
        en   = !rst ? (((tick * 37) % 11) > 3) : 1'b1;
        if (!en) stall_cycles = stall_cycles + 1;
    end
`endif

    // ------------------------------------------------------------ coverage
    integer n_add=0, n_sub=0, n_and=0, n_or=0, n_xor=0, n_addi=0, n_lw=0, n_sw=0;
    integer n_beq_t=0, n_beq_nt=0, n_bne_t=0, n_bne_nt=0, n_ill=0;
    integer n_x0_write=0, n_neg_imm=0, n_back_br=0;
    integer cycles = 0, fd, errors = 0, i;

    wire [6:0] op = instr[6:0];
    wire [2:0] f3 = instr[14:12];
    wire       f7b5 = instr[30];
    wire       pc_src = dut.pc_src;

    always @(posedge clk) if (!rst && en && instr != HALT_INSTR) begin
        cycles = cycles + 1;
        case (op)
            7'b0110011: case (f3)
                3'b000: if (f7b5) n_sub = n_sub + 1; else n_add = n_add + 1;
                3'b111: n_and = n_and + 1;
                3'b110: n_or  = n_or  + 1;
                3'b100: n_xor = n_xor + 1;
            endcase
            7'b0010011: n_addi = n_addi + 1;
            7'b0000011: n_lw   = n_lw + 1;
            7'b0100011: n_sw   = n_sw + 1;
            7'b1100011: begin
                if (f3 == 3'b000) begin if (pc_src) n_beq_t = n_beq_t + 1; else n_beq_nt = n_beq_nt + 1; end
                else              begin if (pc_src) n_bne_t = n_bne_t + 1; else n_bne_nt = n_bne_nt + 1; end
                if (pc_src && instr[31]) n_back_br = n_back_br + 1;
            end
        endcase
        if (illegal) n_ill = n_ill + 1;
        if (reg_write && rd == 0) n_x0_write = n_x0_write + 1;
        if ((op == 7'b0010011 || op == 7'b0000011 || op == 7'b0100011) && instr[31])
            n_neg_imm = n_neg_imm + 1;

        // execution trace
        $fwrite(fd, "%6d  pc=%08h  instr=%08h", cycles, pc, instr);
        if (reg_write) $fwrite(fd, "  x%0d <= %08h", rd, wb_data);
        if (mem_write) $fwrite(fd, "  mem[%08h] <= %08h", mem_addr, mem_wdata);
        if (op == 7'b1100011) $fwrite(fd, "  branch %s", pc_src ? "TAKEN" : "not taken");
        if (illegal)   $fwrite(fd, "  ILLEGAL (nop)");
        $fwrite(fd, "\n");
    end

    // ------------------------------------------------------------ checking
    reg [31:0] exp_regs [0:31];
    reg [31:0] exp_dmem [0:DMEM_DEPTH-1];
    reg [31:0] exp_pc   [0:1];          // [0] = HALT pc, [1] = instruction count

    task print_cov(input [8*10-1:0] name, input integer n);
        $display("  %-10s : %0d", name, n);
    endtask

    initial begin
        $dumpfile(`VCD_FILE);
        $dumpvars(0, tb_rv32i_cpu);
        for (i = 1; i < 32; i = i + 1) $dumpvars(0, dut.u_rf.regs[i]);
        for (i = 0; i < 16; i = i + 1) $dumpvars(0, dut.u_dmem.mem[i]);
        fd = $fopen(`LOG_FILE, "w");
        $readmemh(`EXP_REGS, exp_regs);
        $readmemh(`EXP_DMEM, exp_dmem);
        $readmemh(`EXP_PC, exp_pc);

        $display("=====================================================");
        $display(" Single-Cycle RV32I CPU test : %s", `PROG_HEX);
        $display("=====================================================");

        // reset for 2 cycles
        repeat (2) @(posedge clk);
        #1 rst = 0;

        // run until HALT or timeout
        while (!(instr == HALT_INSTR && en) && cycles < MAX_CYCLES) @(posedge clk);
        #1;
        if (cycles >= MAX_CYCLES) begin
            $display("ERROR: timeout - HALT not reached after %0d cycles", MAX_CYCLES);
            errors = errors + 1;
        end

        // compare control flow: same HALT address and same number of instructions
        if (pc !== exp_pc[0]) begin
            $display("  MISMATCH final PC : cpu=%08h  expected=%08h", pc, exp_pc[0]);
            errors = errors + 1;
        end
        if (cycles !== exp_pc[1]) begin
            $display("  MISMATCH instruction count : cpu=%0d  expected=%0d", cycles, exp_pc[1]);
            errors = errors + 1;
        end
        // compare registers
        for (i = 0; i < 32; i = i + 1) begin
            if (((i == 0) ? 32'h0 : dut.u_rf.regs[i]) !== exp_regs[i]) begin
                $display("  MISMATCH x%0d : cpu=%08h  expected=%08h", i, dut.u_rf.regs[i], exp_regs[i]);
                errors = errors + 1;
            end
        end
        // compare data memory
        for (i = 0; i < DMEM_DEPTH; i = i + 1) begin
            if (dut.u_dmem.mem[i] !== exp_dmem[i]) begin
                $display("  MISMATCH mem[0x%03h] : cpu=%08h  expected=%08h", i*4, dut.u_dmem.mem[i], exp_dmem[i]);
                errors = errors + 1;
            end
        end

        // final register dump
        $display("Final register file (non-zero):");
        for (i = 1; i < 32; i = i + 1)
            if (dut.u_rf.regs[i] != 0)
                $display("  x%-2d = 0x%08h  (%0d)", i, dut.u_rf.regs[i], $signed(dut.u_rf.regs[i]));
        $display("Data memory (non-zero words):");
        for (i = 0; i < DMEM_DEPTH; i = i + 1)
            if (dut.u_dmem.mem[i] != 0)
                $display("  mem[0x%03h] = 0x%08h  (%0d)", i*4, dut.u_dmem.mem[i], $signed(dut.u_dmem.mem[i]));

        $display("Instruction coverage (dynamic counts):");
        print_cov("ADD", n_add);   print_cov("SUB", n_sub);   print_cov("AND", n_and);
        print_cov("OR", n_or);     print_cov("XOR", n_xor);   print_cov("ADDI", n_addi);
        print_cov("LW", n_lw);     print_cov("SW", n_sw);
        print_cov("BEQ taken", n_beq_t);  print_cov("BEQ not-t", n_beq_nt);
        print_cov("BNE taken", n_bne_t);  print_cov("BNE not-t", n_bne_nt);
        print_cov("back-br", n_back_br);  print_cov("neg-imm", n_neg_imm);
        print_cov("x0-write", n_x0_write); print_cov("illegal", n_ill);

        if (stall_cycles > 0)
            $display("Stall test : CPU frozen for %0d clock cycles (en = 0) - results unaffected", stall_cycles);
        $display("Performance: %0d instructions in %0d cycles -> CPI = 1.00", cycles, cycles);
        $display("             execution time @ %0d MHz sim clock = %0d ns",
                 1000 / CLK_PERIOD, cycles * CLK_PERIOD);
        $display("COVERAGE_CSV,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                 n_add, n_sub, n_and, n_or, n_xor, n_addi, n_lw, n_sw,
                 n_beq_t, n_beq_nt, n_bne_t, n_bne_nt, n_back_br, n_neg_imm, n_x0_write, n_ill, cycles);
        if (errors == 0) $display("RESULT: PASS  (%s)", `PROG_HEX);
        else             $display("RESULT: FAIL  (%0d errors, %s)", errors, `PROG_HEX);
        $fclose(fd);
        $finish;
    end
endmodule
