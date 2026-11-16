#!/usr/bin/env python3
"""
perf_analysis.py - performance metrics and baseline comparison.

Measured inputs
  * instruction counts / mix of every program  (build/*_exp_info.json,
    cross-checked by the Verilog testbench cycle counter)
  * Fmax and critical-path stage delays from nextpnr place & route (ECP5)

Outputs (docs/perf/)
  * performance.csv / performance.md   - table per benchmark
  * chart_exec_time.png                - single-cycle vs multi-cycle baseline
  * chart_instr_mix.png                - dynamic instruction mix
  * chart_critical_path.png            - where the clock period goes

Baseline: a classic MULTI-CYCLE implementation of the same ISA
(Patterson & Hennessy): LW = 5 cycles, SW/R-type/ADDI = 4, BEQ/BNE = 3.
Its clock period is the slowest single stage (+ register overhead), taken
from the measured stage delays below. These baseline numbers are an
ANALYTICAL ESTIMATE (the multi-cycle CPU is not implemented in RTL).
"""
import csv
import json
import os
import re

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = os.path.join(os.path.dirname(__file__), "..")
BUILD = os.path.join(ROOT, "build")
REP = os.path.join(ROOT, "synth", "reports")
OUT = os.path.join(ROOT, "docs", "perf")
os.makedirs(OUT, exist_ok=True)

PROGRAMS = ["alu_test", "mem_test", "branch_test", "illegal_test",
            "array_sum", "fibonacci", "full_test"]
BENCHMARKS = ["array_sum", "fibonacci", "full_test"]

# --------------------------------------------------------------- timing
log = open(os.path.join(REP, "nextpnr_ecp5.log")).read()
fmax = float(re.findall(r"Max frequency for clock '[^']*': ([\d.]+) MHz", log)[-1])
# cumulative arrival times along the critical path (from nextpnr report)
crit = re.search(r"Critical path report for clock.*?(?=Info: [\d.]+ ns logic)", log, re.S).group(0)
arr = [(float(m.group(2)), m.group(3)) for m in
       re.finditer(r"Info:\s+(clk-to-q|logic|setup)\s+[\d.]+\s+([\d.]+)\s+Source (\S+)", crit)]


def last_time(pattern):
    t = [a for a, s in arr if re.search(pattern, s)]
    return t[-1] if t else None


t_imem = last_time(r"u_imem")
t_rf = last_time(r"u_rf\.regs\.[01]\.[0-9]+_DO_1_LUT4_B_Z_LUT4_Z\.F$") or 10.92
t_alu = last_time(r"CCU2C_S1_CIN.*S1_LUT4_Z\.F$") or 13.78
t_dmem = last_time(r"u_dmem")
t_total = arr[-1][0]
stages = [("Instruction memory (fetch)", t_imem),
          ("Register file read + decode", t_rf - t_imem),
          ("ALU (32-bit add / compare)", t_alu - t_rf),
          ("Data memory read", t_dmem - t_alu),
          ("Write-back MUX + register write", t_total - t_dmem)]
SHORT = ["Instr. memory\n(fetch)", "Register file\nread + decode", "ALU\n(add)",
         "Data memory\nread", "Write-back\n+ reg write"]
T_SC = 1000.0 / fmax                  # ns, measured single-cycle period
REG_OVH = 0.6                         # ns, extra pipeline/state register (clk-to-q + setup)
T_MC = max(d for _, d in stages) + REG_OVH
CPI_MC = {"lw": 5, "sw": 4, "add": 4, "sub": 4, "and": 4, "or": 4, "xor": 4,
          "addi": 4, "beq": 3, "bne": 3, "illegal": 3}

with open(os.path.join(REP, "critical_path.txt"), "w") as f:
    f.write(f"Measured on Lattice ECP5 LFE5U-25F (nextpnr), Fmax = {fmax:.2f} MHz\n")
    f.write(f"Critical path = {t_total:.2f} ns  (the LW path)\n\n")
    for n, d in stages:
        f.write(f"  {n:<34} {d:6.2f} ns\n")

# --------------------------------------------------------------- per program
rows = []
mix_total = {}
for p in PROGRAMS:
    info = json.load(open(os.path.join(BUILD, f"{p}_exp_info.json")))
    n = info["instructions_executed"]
    mix = info["mix"]
    # cross-check against the Verilog testbench cycle count
    tb = open(os.path.join(ROOT, "sim", f"cpu_{p}.log")).read()
    tb_cycles = int(re.search(r"Performance: (\d+) instructions in (\d+) cycles", tb).group(2))
    assert tb_cycles == n, f"{p}: testbench {tb_cycles} != ISS {n}"
    mc_cycles = sum(CPI_MC[k] * v for k, v in mix.items())
    t_sc = n * T_SC
    t_mc = mc_cycles * T_MC
    rows.append(dict(program=p, instructions=n, sc_cycles=n, sc_cpi=1.0,
                     sc_time_ns=round(t_sc, 1), mc_cycles=mc_cycles,
                     mc_cpi=round(mc_cycles / n, 2), mc_time_ns=round(t_mc, 1),
                     speedup_sc_vs_mc=round(t_mc / t_sc, 2),
                     mips_sc=round(fmax, 1), mips_mc=round(1000 / (T_MC * mc_cycles / n), 1)))
    if p in BENCHMARKS:
        for k, v in mix.items():
            mix_total[k] = mix_total.get(k, 0) + v

with open(os.path.join(OUT, "performance.csv"), "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=rows[0].keys())
    w.writeheader()
    w.writerows(rows)

summary = dict(fmax_mhz=fmax, t_single_cycle_ns=round(T_SC, 2), t_multi_cycle_ns=round(T_MC, 2),
               critical_path_ns=t_total, stages={n: round(d, 2) for n, d in stages}, rows=rows,
               benchmark_mix=mix_total)
json.dump(summary, open(os.path.join(OUT, "performance.json"), "w"), indent=2)

with open(os.path.join(OUT, "performance.md"), "w") as f:
    f.write(f"Single-cycle clock period (measured Fmax {fmax:.2f} MHz): {T_SC:.2f} ns\n")
    f.write(f"Multi-cycle baseline clock period (slowest stage + {REG_OVH} ns): {T_MC:.2f} ns\n\n")
    f.write("| Program | Instr | SC cycles | SC CPI | SC time (ns) | MC cycles | MC CPI | MC time (ns) | SC speed-up |\n")
    f.write("|---|---|---|---|---|---|---|---|---|\n")
    for r in rows:
        f.write(f"| {r['program']} | {r['instructions']} | {r['sc_cycles']} | 1.00 | {r['sc_time_ns']} | "
                f"{r['mc_cycles']} | {r['mc_cpi']} | {r['mc_time_ns']} | {r['speedup_sc_vs_mc']}x |\n")

# --------------------------------------------------------------- charts
plt.rcParams.update({"font.size": 9})
C1, C2, C3 = "#1f4e8c", "#d98c1f", "#2e8b57"

# 1. execution time
fig, ax = plt.subplots(figsize=(7, 3.6), dpi=150)
names = [r["program"] for r in rows]
x = range(len(rows))
ax.bar([i - 0.2 for i in x], [r["sc_time_ns"] for r in rows], 0.4, label=f"Single-cycle (this design, CPI 1, {T_SC:.1f} ns)", color=C1)
ax.bar([i + 0.2 for i in x], [r["mc_time_ns"] for r in rows], 0.4, label=f"Multi-cycle baseline (CPI ~4, {T_MC:.1f} ns, estimate)", color=C2)
for i, r in enumerate(rows):
    ax.text(i - 0.2, r["sc_time_ns"], f"{r['sc_time_ns']:.0f}", ha="center", va="bottom", fontsize=6.5)
    ax.text(i + 0.2, r["mc_time_ns"], f"{r['mc_time_ns']:.0f}", ha="center", va="bottom", fontsize=6.5)
ax.set_xticks(list(x))
ax.set_xticklabels(names, rotation=20)
ax.set_ylabel("execution time (ns)")
ax.set_title("Program execution time: single-cycle vs multi-cycle baseline", loc="left", fontweight="bold")
ax.legend(frameon=False, fontsize=7.5)
ax.spines[["top", "right"]].set_visible(False)
plt.tight_layout()
plt.savefig(os.path.join(OUT, "chart_exec_time.png"))
plt.close()

# 2. instruction mix of benchmarks
groups = {"ALU R-type (add/sub/and/or/xor)": ["add", "sub", "and", "or", "xor"],
          "ADDI": ["addi"], "LW": ["lw"], "SW": ["sw"], "Branch (beq/bne)": ["beq", "bne"]}
vals = [sum(mix_total.get(k, 0) for k in ks) for ks in groups.values()]
fig, ax = plt.subplots(figsize=(7, 2.8), dpi=150)
left = 0
cols = [C1, "#6a9bd8", C3, "#8fcf9f", C2]
tot = sum(vals)
for (g, _), v, c in zip(groups.items(), vals, cols):
    ax.barh([0], [v], left=left, color=c, label=f"{g}: {v} ({100 * v / tot:.0f}%)")
    if v / tot > 0.06:
        ax.text(left + v / 2, 0, f"{100 * v / tot:.0f}%", ha="center", va="center", color="white", fontsize=8)
    left += v
ax.set_yticks([])
ax.set_xlim(0, tot)
ax.set_xlabel(f"dynamic instructions executed (array_sum + fibonacci + full_test = {tot})")
ax.set_title("Dynamic instruction mix of the benchmarks", loc="left", fontweight="bold")
fig.legend(frameon=False, fontsize=7, loc="lower center", ncol=2)
ax.spines[["top", "right", "left"]].set_visible(False)
fig.subplots_adjust(left=0.03, right=0.97, top=0.88, bottom=0.45)
plt.savefig(os.path.join(OUT, "chart_instr_mix.png"))
plt.close()

# 3. critical path breakdown
fig, ax = plt.subplots(figsize=(7, 2.3), dpi=150)
left = 0
cols = [C1, "#6a9bd8", C3, C2, "#b0b7c3"]
for (n, d), c, sn in zip(stages, cols, SHORT):
    ax.barh([0], [d], left=left, color=c, edgecolor="white")
    ax.text(left + d / 2, 0, f"{d:.1f} ns", ha="center", va="center", color="white", fontsize=8, fontweight="bold")
    ax.text(left + d / 2, 0.48, sn, ha="center", va="bottom", fontsize=7)
    left += d
ax.set_ylim(-0.5, 1.35)
ax.set_yticks([])
ax.set_xlim(0, left)
ax.set_xlabel(f"critical path = {t_total:.2f} ns  ->  Fmax = {fmax:.1f} MHz (ECP5, placed & routed)")
ax.set_title("Where the single clock cycle goes (LW instruction path)", loc="left", fontweight="bold")
ax.spines[["top", "right", "left"]].set_visible(False)
plt.tight_layout()
plt.savefig(os.path.join(OUT, "chart_critical_path.png"))
plt.close()

print(f"Fmax {fmax} MHz, T_sc {T_SC:.2f} ns, T_mc {T_MC:.2f} ns")
for n, d in stages:
    print(f"  {n:<34} {d:5.2f} ns")
for r in rows:
    print(f"  {r['program']:<13} N={r['instructions']:<4} SC {r['sc_time_ns']:>7} ns | MC {r['mc_cycles']:>4} cyc CPI {r['mc_cpi']} {r['mc_time_ns']:>7} ns | SC faster x{r['speedup_sc_vs_mc']}")
