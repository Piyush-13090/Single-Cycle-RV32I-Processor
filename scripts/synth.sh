#!/usr/bin/env bash
# ============================================================================
# synth.sh - open-source synthesis + place & route (works on macOS / Linux)
#
#   1. Yosys generic synthesis of the CPU core     -> gate count, logic depth
#   2. Yosys synth_xilinx for Artix-7 (Basys-3)    -> LUT / FF / LUTRAM estimate
#   3. Yosys synth_ecp5 + nextpnr-ecp5 (Lattice)   -> real placed & routed Fmax
#
# Needs: yosys (brew install yosys) and nextpnr-ecp5 (pip install yowasp-nextpnr-ecp5)
# Run ./scripts/run_all.sh first so build/full_test.hex exists.
# Usage: ./scripts/synth.sh [program-name]   (default: full_test)
# ============================================================================
set -e
cd "$(dirname "$0")/.."
PROG=${1:-full_test}                       # program to place in instruction memory
mkdir -p synth/reports
cp build/$PROG.hex synth/program.hex       # default IMEM_FILE = "program.hex"
cd synth                                   # Yosys runs inside synth/
OUT=reports
RTL="../rtl/pc.v ../rtl/adder.v ../rtl/mux2.v ../rtl/instr_mem.v ../rtl/control_unit.v \
     ../rtl/alu_control.v ../rtl/reg_file.v ../rtl/imm_gen.v ../rtl/alu.v ../rtl/data_mem.v \
     ../rtl/branch_unit.v ../rtl/rv32i_cpu.v"

NEXTPNR=$(command -v nextpnr-ecp5 || command -v yowasp-nextpnr-ecp5 || echo ../../.venv/bin/yowasp-nextpnr-ecp5)

echo "== 1. Generic synthesis (technology independent) =="
yosys -q -l $OUT/yosys_generic.log -p "
  read_verilog -I../rtl $RTL
  synth -top rv32i_cpu -flatten
  memory_map; opt -full; techmap; opt; abc -g AND,NAND,OR,NOR,XOR,XNOR,MUX; opt_clean
  tee -o $OUT/generic_stat.txt stat
  tee -o $OUT/generic_ltp.txt ltp -noff
"
grep -E "^ +[0-9]+ +(cells|\$_)" $OUT/generic_stat.txt | head -20

echo "== 2. Xilinx Artix-7 (Basys-3, xc7a35t) resource estimate =="
yosys -q -l $OUT/yosys_xilinx.log -p "
  read_verilog -I../rtl $RTL ../fpga/fpga_top.v
  synth_xilinx -family xc7 -top fpga_top -flatten
  tee -o $OUT/xilinx_stat.txt stat
"
grep -E "LUT|FD|RAM|CARRY|MUXF" $OUT/xilinx_stat.txt | head -30

echo "== 3. Lattice ECP5 (LFE5U-25F) synthesis + place & route =="
yosys -q -l $OUT/yosys_ecp5.log -p "
  read_verilog -I../rtl $RTL ../fpga/fpga_top.v
  synth_ecp5 -top fpga_top -json $OUT/fpga_top_ecp5.json
  tee -o $OUT/ecp5_stat.txt stat
"
$NEXTPNR --25k --package CABGA256 --json $OUT/fpga_top_ecp5.json \
    --lpf-allow-unconstrained --freq 40 --seed 1 \
    --report $OUT/ecp5_nextpnr_report.json > $OUT/nextpnr_ecp5.log 2>&1 || true
grep -E "Max frequency|Device utilisation|TRELLIS_SLICE|TRELLIS_FF|TRELLIS_COMB|TRELLIS_RAMW|DP16KD" $OUT/nextpnr_ecp5.log | tail -12
echo "Reports in synth/$OUT/"
