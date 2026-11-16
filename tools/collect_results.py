#!/usr/bin/env python3
"""
collect_results.py - gathers every measured number (simulation, coverage,
mutation test, synthesis, timing, performance) into docs/results.json, which
the report and slide generators read. Nothing in the report is typed by hand.
"""
import json
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
P = lambda *a: os.path.join(ROOT, *a)  # noqa: E731

PROGRAMS = ["alu_test", "mem_test", "branch_test", "illegal_test", "array_sum", "fibonacci", "full_test"]
COV_KEYS = ["add", "sub", "and", "or", "xor", "addi", "lw", "sw", "beq_taken", "beq_not_taken",
            "bne_taken", "bne_not_taken", "backward_branch", "negative_imm", "x0_write", "illegal", "cycles"]

res = {"unit": [], "cpu": [], "stall": [], "coverage": {}, "programs": {}}

for tb in ["tb_alu", "tb_reg_file", "tb_imm_gen", "tb_control_unit"]:
    m = re.search(rf"{tb}: (PASS|FAIL) \((\d+)", open(P("sim", f"{tb}.log")).read())
    res["unit"].append({"name": tb, "result": m.group(1), "tests": int(m.group(2))})

total = {k: 0 for k in COV_KEYS}
for p in PROGRAMS:
    log = open(P("sim", f"cpu_{p}.log")).read()
    cov = dict(zip(COV_KEYS, map(int, re.search(r"COVERAGE_CSV,([\d,]+)", log).group(1).split(","))))
    res["coverage"][p] = cov
    for k in COV_KEYS:
        total[k] += cov[k]
    res["cpu"].append({"program": p, "result": "PASS" if "RESULT: PASS" in log else "FAIL",
                       "instructions": cov["cycles"]})
    slog = open(P("sim", f"stall_{p}.log")).read()
    st = re.search(r"frozen for (\d+)", slog)
    res["stall"].append({"program": p, "result": "PASS" if "RESULT: PASS" in slog else "FAIL",
                         "stall_cycles": int(st.group(1)) if st else 0})
    src = open(P("programs", f"{p}.s")).read()
    static = len(open(P("build", f"{p}.hex")).read().split())
    regs = re.findall(r"x(\d+)\s+= (0x[0-9a-f]+)\s+\((-?\d+)\)", log)
    mem = re.findall(r"mem\[(0x[0-9a-f]+)\] = (0x[0-9a-f]+)\s+\((-?\d+)\)", log)
    desc = [l.strip("# ").strip() for l in src.splitlines()[1:4] if l.startswith("#") and "====" not in l]
    res["programs"][p] = {"static": static, "dynamic": cov["cycles"], "regs": regs, "mem": mem,
                          "desc": " ".join(desc)}
res["coverage_total"] = total

# mutation test
mut = []
for line in open(P("sim", "mutation_results.txt")):
    m = re.match(r"\s*\[\s*(\d+)\]\s+(.+?)\s{2,}(KILLED|SURVIVED)\s*(?:\(detected by: ?(.*)\))?", line)
    if m:
        mut.append({"id": int(m.group(1)), "bug": m.group(2).strip(), "status": m.group(3),
                    "detected_by": (m.group(4) or "").strip()})
res["mutation"] = mut

# synthesis
xs = open(P("synth", "reports", "xilinx_stat.txt")).read()
sec = xs[xs.index("=== fpga_top ==="):]
cells = {m.group(2): int(m.group(1)) for m in re.finditer(r"^\s+(\d+)\s+([A-Z][A-Z0-9_]+)\s*$", sec, re.M)}
luts = sum(v for k, v in cells.items() if re.fullmatch(r"LUT[1-6]", k))
lutram = 4 * cells.get("RAM256X1S", 0) + 4 * cells.get("RAM32M", 0)
res["xilinx"] = {"cells": cells, "logic_luts": luts, "lutram_luts": lutram, "total_luts": luts + lutram,
                 "ffs": cells.get("FDRE", 0) + cells.get("FDSE", 0), "carry4": cells.get("CARRY4", 0),
                 "io": cells.get("IBUF", 0) + cells.get("OBUF", 0) + 1,
                 "device": "XC7A35T (Basys-3)", "lut_avail": 20800, "ff_avail": 41600, "io_avail": 106}

nl = open(P("synth", "reports", "nextpnr_ecp5.log")).read()
util = {m.group(1): (int(m.group(2)), int(m.group(3)))
        for m in re.finditer(r"Info:\s+(\w+):\s+(\d+)/\s*(\d+)", nl)}
res["ecp5"] = {k: util[k] for k in ["TRELLIS_COMB", "TRELLIS_FF", "TRELLIS_RAMW", "DP16KD", "TRELLIS_IO"] if k in util}
res["ecp5"]["fmax_mhz"] = float(re.findall(r"Max frequency for clock '[^']*': ([\d.]+) MHz", nl)[-1])
gs = open(P("synth", "reports", "generic_stat.txt")).read()
res["generic"] = {m.group(2): int(m.group(1)) for m in re.finditer(r"^\s+(\d+)\s+(\$_\w+_|cells)\s*$", gs, re.M)}

res["perf"] = json.load(open(P("docs", "perf", "performance.json")))

json.dump(res, open(P("docs", "results.json"), "w"), indent=1)
print("wrote docs/results.json")
print("coverage total:", total)
print("xilinx:", res["xilinx"]["total_luts"], "LUTs,", res["xilinx"]["ffs"], "FFs; ecp5:", res["ecp5"])
