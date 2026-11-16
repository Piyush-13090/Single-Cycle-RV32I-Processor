#!/usr/bin/env bash
# ============================================================================
# make_waveforms.sh - render waveform PNGs for the report / slides
# Run ./scripts/run_all.sh first (it creates the sim/cpu_*.vcd files).
# Needs python3 with matplotlib (the project's .venv has it).
# ============================================================================
set -e
cd "$(dirname "$0")/.."
PY=${PY:-../.venv/bin/python}
[ -x "$PY" ] || PY=python3
W=docs/waveforms
mkdir -p $W

MEM="clk:bit,pc,instr:asm,dut.alu_src:bit,dut.mem_read:bit,dut.mem_write:bit,dut.mem_to_reg:bit,dut.rs1_data:dec,dut.imm:dec,dut.alu_result:hex,dut.rs2_data:dec,dut.mem_rdata:dec,dut.reg_write:bit,rd:udec,wb_data:dec"
BR="clk:bit,pc,instr:asm,dut.branch:bit,dut.rs1_data:dec,dut.rs2_data:dec,dut.alu_ctrl:hex,dut.alu_result:dec,dut.zero:bit,dut.pc_src:bit,dut.imm:dec,dut.pc_plus4,dut.pc_branch,dut.pc_next,dut.reg_write:bit"
LOOP="clk:bit,pc,instr:asm,dut.reg_write:bit,dut.mem_read:bit,dut.mem_write:bit,dut.branch:bit,dut.pc_src:bit,dut.alu_result:dec,rd:udec,wb_data:dec,dut.u_rf.regs[10]:dec,dut.u_rf.regs[13]:dec,dut.pc_next"
ILL="clk:bit,pc,instr,instr:asm,dut.illegal:bit,dut.reg_write:bit,dut.mem_write:bit,dut.branch:bit,dut.pc_next,rd:udec"

$PY tools/vcd_plot.py sim/cpu_alu_test.vcd   -o $W/wave_alu_test_1.png --cycles 12 --title "ALU test (1/2): ADDI, ADD, SUB, AND, OR, XOR"
$PY tools/vcd_plot.py sim/cpu_alu_test.vcd   -o $W/wave_alu_test_2.png --start-cycle 12 --cycles 10 --title "ALU test (2/2): XOR, AND, OR, writes to x0 ignored, negative results"
$PY tools/vcd_plot.py sim/cpu_mem_test.vcd   -o $W/wave_mem_test_1.png --cycles 12 --signals "$MEM" --title "Memory test (1/2): SW with positive / negative offsets, LW read-back"
$PY tools/vcd_plot.py sim/cpu_mem_test.vcd   -o $W/wave_mem_test_2.png --start-cycle 12 --cycles 11 --signals "$MEM" --title "Memory test (2/2): first/last word, unwritten word, load into x0, load-use"
$PY tools/vcd_plot.py sim/cpu_branch_test.vcd -o $W/wave_branch_test_1.png --cycles 12 --signals "$BR" --title "Branch test (1/2): BEQ/BNE taken and not taken (forward)"
$PY tools/vcd_plot.py sim/cpu_branch_test.vcd -o $W/wave_branch_test_2.png --start-cycle 12 --cycles 14 --signals "$BR" --title "Branch test (2/2): backward loops (BNE / BEQ) and unconditional jump"
$PY tools/vcd_plot.py sim/cpu_illegal_test.vcd -o $W/wave_illegal_test.png --start-cycle 6 --cycles 12 --signals "$ILL" --title "Unsupported instructions are executed as NOPs (illegal = 1, no writes)"
$PY tools/vcd_plot.py sim/cpu_array_sum.vcd   -o $W/wave_array_sum_loop.png --start-cycle 24 --cycles 15 --signals "$LOOP" --title "Array-sum benchmark: loop body (LW, ADD, ADDI, ADDI, BNE) - a0 accumulates the sum"
$PY tools/vcd_plot.py sim/cpu_fibonacci.vcd   -o $W/wave_fibonacci.png --cycles 19 --signals "clk:bit,pc,instr:asm,dut.mem_write:bit,dut.alu_result:hex,dut.rs2_data:dec,dut.pc_src:bit,rd:udec,wb_data:dec" --title "Fibonacci benchmark: SW stores F(i) every iteration"
$PY tools/vcd_plot.py sim/cpu_full_test.vcd   -o $W/wave_full_test_end.png --start-cycle 74 --cycles 14 --title "Full test: final BNE exit, BEQ check, SUB and result stores (a0 = 62)"
echo "waveforms written to $W/"
