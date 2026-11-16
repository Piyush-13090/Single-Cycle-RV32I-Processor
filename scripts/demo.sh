#!/usr/bin/env bash
# ============================================================================
# demo.sh - step-by-step live demo / video recording helper.
# Pauses before each step (press Enter) so you can explain on camera.
#   ./scripts/demo.sh            use existing synthesis reports (fast)
#   ./scripts/demo.sh --synth    re-run synthesis live (~1 minute)
# ============================================================================
cd "$(dirname "$0")/.."
B=$'\e[1;36m'; G=$'\e[1;32m'; N=$'\e[0m'

step() { echo; echo "${B}=== $1 ===${N}"; read -r -p "(press Enter) " _; }

clear
echo "${G}Single-Cycle RV32I Processor - live demo${N}"
echo "Instructions: ADD SUB AND OR XOR ADDI LW SW BEQ BNE   |   CPI = 1"

step "Step 1: build and run ALL tests (unit testbenches, 7 programs, stall test)"
./scripts/run_all.sh 2>&1 | grep -vE "^ISS|instructions ->|^$"

step "Step 2: result of the full test program (uses all 10 instructions)"
sed -n '/Final register file/,/^Performance/p' sim/cpu_full_test.log | grep -v COVERAGE_CSV
grep -E "^RESULT" sim/cpu_full_test.log

step "Step 3: execution trace - one line per clock cycle (first 15 cycles)"
head -15 sim/cpu_full_test_trace.log

step "Step 4: mutation test - 12 deliberate bugs, does the testbench catch them?"
./scripts/mutation_test.sh

step "Step 5: synthesis results"
if [ "$1" = "--synth" ]; then ./scripts/synth.sh; fi
echo "Artix-7 (Basys-3) resources:"
grep -E "^ +[0-9]+ +(LUT[1-6]|FDRE|CARRY4|RAM256X1S|RAM32M)$" synth/reports/xilinx_stat.txt
echo
echo "Lattice ECP5 after place & route:"
grep -E "TRELLIS_COMB|TRELLIS_FF|TRELLIS_RAMW" synth/reports/nextpnr_ecp5.log | tail -3
grep "Max frequency" synth/reports/nextpnr_ecp5.log | tail -1
echo
cat synth/reports/critical_path.txt

step "Step 6: performance vs multi-cycle baseline"
cat docs/perf/performance.md

step "Step 7: open the waveform viewer (Surfer)"
if command -v surfer >/dev/null; then
    (surfer sim/cpu_full_test.vcd >/dev/null 2>&1 &)
    echo "Surfer opened: expand tb_rv32i_cpu -> dut and add clk, pc, instr, reg_write,"
    echo "mem_read, mem_write, branch, pc_src, alu_result, wb_data"
else
    open docs/waveforms/wave_branch_test_2.png
fi
echo; echo "${G}Demo finished.${N}"
