#!/usr/bin/env python3
"""
vcd_plot.py - render a VCD waveform (from Icarus Verilog) to a PNG image in a
GTKWave-like style, for the project report and slides.

A special pseudo-signal "asm" shows each instruction disassembled, so the
waveform can be read instruction by instruction.

Usage:
    python3 vcd_plot.py sim/cpu_alu_test.vcd -o docs/waveforms/alu.png \
        --start-cycle 0 --cycles 24 --title "ALU test"
"""
import argparse
import os
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

sys.path.insert(0, os.path.dirname(__file__))
from iss import decode  # noqa: E402

ABI = ["zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "s1", "a0", "a1",
       "a2", "a3", "a4", "a5", "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
       "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"]


def disasm(w):
    if w is None:
        return "?"
    if w == 0x00000063:
        return "halt"
    n, rd, rs1, rs2, imm = decode(w)
    if n in ("add", "sub", "and", "or", "xor"):
        return f"{n} x{rd},x{rs1},x{rs2}"
    if n == "addi":
        return f"addi x{rd},x{rs1},{imm}"
    if n == "lw":
        return f"lw x{rd},{imm}(x{rs1})"
    if n == "sw":
        return f"sw x{rs2},{imm}(x{rs1})"
    if n in ("beq", "bne"):
        return f"{n} x{rs1},x{rs2},{imm:+d}"
    return "illegal"


def parse_vcd(path):
    ids, changes, widths = {}, {}, {}
    scope = []
    t = 0
    with open(path) as f:
        in_defs = True
        for line in f:
            s = line.strip()
            if not s:
                continue
            if in_defs:
                tok = s.split()
                if tok[0] == "$scope":
                    scope.append(tok[2])
                elif tok[0] == "$upscope":
                    scope.pop()
                elif tok[0] == "$var":
                    width, code, name = int(tok[2]), tok[3], tok[4].lstrip("\\")
                    full = ".".join(scope + [name])
                    ids.setdefault(code, []).append(full)
                    widths[code] = width
                    changes.setdefault(code, [])
                elif tok[0] == "$enddefinitions":
                    in_defs = False
                continue
            if s[0] == "#":
                t = int(s[1:])
            elif s[0] in "bB":
                val, code = s[1:].split()
                v = None if any(c in val for c in "xXzZ") else int(val, 2)
                changes[code].append((t, v))
            elif s[0] in "01xXzZ" and len(s) > 1:
                code = s[1:]
                v = None if s[0] in "xXzZ" else int(s[0])
                if code in changes:
                    changes[code].append((t, v))
    by_name = {}
    for code, names in ids.items():
        for n in names:
            by_name[n] = (widths[code], changes[code])
    return by_name


def value_at(chg, t):
    v = None
    for tt, vv in chg:
        if tt > t:
            break
        v = vv
    return v


def segments(chg, t0, t1):
    """list of (start, end, value) covering [t0, t1]."""
    segs = []
    cur = value_at(chg, t0)
    start = t0
    for tt, vv in chg:
        if t0 < tt < t1 and vv != cur:
            segs.append((start, tt, cur))
            start, cur = tt, vv
    segs.append((start, t1, cur))
    return segs


def fmt(v, width, style):
    if v is None:
        return "x"
    if style == "dec":
        return str(v - (1 << width) if v >> (width - 1) else v) if width > 1 else str(v)
    if style == "udec":
        return str(v)
    if style == "asm":
        return disasm(v)
    digits = (width + 3) // 4
    return f"{v:0{digits}x}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("vcd")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--start-cycle", type=int, default=0)
    ap.add_argument("--cycles", type=int, default=20)
    ap.add_argument("--period", type=int, default=10000, help="clock period in VCD time units (ps)")
    ap.add_argument("--reset-cycles", type=int, default=2)
    ap.add_argument("--title", default="")
    ap.add_argument("--signals", default="default",
                    help="comma list of name[:style] (style = hex|dec|udec|asm)")
    a = ap.parse_args()

    data = parse_vcd(a.vcd)
    top = "tb_rv32i_cpu"
    if a.signals == "default":
        sig = [("clk", f"{top}.clk", "bit"),
               ("PC", f"{top}.pc", "hex"),
               ("instr", f"{top}.instr", "hex"),
               ("assembly", f"{top}.instr", "asm"),
               ("RegWrite", f"{top}.dut.reg_write", "bit"),
               ("ALUSrc", f"{top}.dut.alu_src", "bit"),
               ("MemRead", f"{top}.dut.mem_read", "bit"),
               ("MemWrite", f"{top}.dut.mem_write", "bit"),
               ("MemToReg", f"{top}.dut.mem_to_reg", "bit"),
               ("Branch", f"{top}.dut.branch", "bit"),
               ("ALUctrl", f"{top}.dut.alu_ctrl", "hex"),
               ("rs1_data", f"{top}.dut.rs1_data", "dec"),
               ("ALU B", f"{top}.dut.alu_b", "dec"),
               ("imm", f"{top}.dut.imm", "dec"),
               ("ALU result", f"{top}.dut.alu_result", "dec"),
               ("zero", f"{top}.dut.zero", "bit"),
               ("PCSrc (taken)", f"{top}.dut.pc_src", "bit"),
               ("rd", f"{top}.rd", "udec"),
               ("wb_data", f"{top}.wb_data", "dec")]
    else:
        sig = []
        for item in a.signals.split(","):
            name, _, style = item.partition(":")
            full = name if name.startswith(top) else f"{top}.{name}"
            label = name.split(".")[-1]
            sig.append((label, full, style or "hex"))

    # Instruction k occupies [posedge_k, posedge_k+1). The clock starts low
    # with posedges at period/2 + n*period; the first instruction (PC = 0)
    # starts at the last reset posedge.
    half = a.period // 2
    t0 = half + (a.reset_cycles - 1 + a.start_cycle) * a.period
    t1 = t0 + a.cycles * a.period

    rows = len(sig)
    in_per_cycle = 1.15
    fig_w = in_per_cycle * a.cycles + 1.6
    fig, ax = plt.subplots(figsize=(fig_w, 0.36 * rows + 0.9), dpi=150)
    ax.set_xlim(t0, t1)
    ax.set_ylim(-0.6, rows - 0.4)
    ax.invert_yaxis()
    ax.set_facecolor("white")
    LINE, BUS, ASM, HI = "#1f6f3f", "#1f4e8c", "#9a5b00", "#cfe9d6"

    for r, (label, full, style) in enumerate(sig):
        if full not in data:
            print(f"warning: signal {full} not found", file=sys.stderr)
            continue
        width, chg = data[full]
        y = r
        if r % 2 == 0:
            ax.axhspan(y - 0.5, y + 0.5, color="#f4f6f8", zorder=0)
        if style == "bit" or width == 1:
            xs, ys = [], []
            for s0, s1, v in segments(chg, t0, t1):
                lv = 0.3 if v == 1 else -0.3
                if v == 1 and label != "clk":
                    ax.fill_between([s0, s1], y - 0.3, y + 0.3, color=HI, zorder=1)
                xs += [s0, s1]
                ys += [y - lv, y - lv]
            ax.plot(xs, ys, color="#333" if label == "clk" else LINE, lw=1.2, zorder=2)
        else:
            for s0, s1, v in segments(chg, t0, t1):
                d = min((s1 - s0) * 0.08, a.period * 0.06)
                xs = [s0, s0 + d, s1 - d, s1, s1 - d, s0 + d, s0]
                ys = [y, y - 0.3, y - 0.3, y, y + 0.3, y + 0.3, y]
                col = ASM if style == "asm" else BUS
                if v is None:
                    col = "#c0392b"
                ax.fill(xs, ys, color="white", zorder=1)
                ax.plot(xs, ys, color=col, lw=1.0, zorder=2)
                txt = fmt(v, width, style)
                fs = 6.6 if style == "asm" else 7.2
                span_in = (s1 - s0) / a.period * in_per_cycle
                maxch = int(span_in * 72 / (fs * 0.62))
                if len(txt) > maxch:
                    txt = txt[:max(maxch - 1, 0)] + "…" if maxch > 2 else ""
                ax.text((s0 + s1) / 2, y, txt, color="#111", ha="center",
                        va="center", fontsize=fs, family="monospace", zorder=3)
    ax.set_yticks(range(rows))
    ax.set_yticklabels([s[0] for s in sig], fontsize=8, family="monospace")
    ax.tick_params(axis="y", length=0)
    cyc = list(range(a.cycles))
    ax.set_xticks([t0 + (c + 0.5) * a.period for c in cyc])
    ax.set_xticklabels([str(a.start_cycle + c + 1) for c in cyc], fontsize=7)
    ax.tick_params(axis="x", length=0)
    ax.set_xlabel("instruction / clock cycle number (single-cycle CPU: one instruction per cycle)", fontsize=8)
    for c in range(a.cycles + 1):
        ax.axvline(t0 + c * a.period, color="#9aa5b1", lw=0.6, ls=":", zorder=0)
    if a.title:
        ax.set_title(a.title, fontsize=10, loc="left", fontweight="bold")
    for sp in ax.spines.values():
        sp.set_visible(False)
    plt.tight_layout()
    os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)
    plt.savefig(a.out)
    print(f"wrote {a.out}")


if __name__ == "__main__":
    main()
