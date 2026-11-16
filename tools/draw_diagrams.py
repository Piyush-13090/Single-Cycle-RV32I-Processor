#!/usr/bin/env python3
"""
draw_diagrams.py - draws the architecture figures for the report and slides.

  docs/diagrams/datapath.png          single-cycle datapath + control (block diagram)
  docs/diagrams/module_hierarchy.png  Verilog module hierarchy
  docs/diagrams/instr_formats.png     RV32I instruction formats used
  docs/diagrams/verification_flow.png verification methodology
"""
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Polygon

OUT = os.path.join(os.path.dirname(__file__), "..", "docs", "diagrams")
os.makedirs(OUT, exist_ok=True)

DATA = "#1d2733"
CTRL = "#1f6fd1"
FILL = {"fetch": "#e8f0fb", "dec": "#eaf6ee", "exe": "#fff4e2", "mem": "#f6ebf7", "wb": "#eef0f2"}


def box(ax, x0, y0, x1, y1, text, fill="#ffffff", fs=9, bold=True, ec=DATA, lw=1.4):
    ax.add_patch(FancyBboxPatch((x0, y0), x1 - x0, y1 - y0, boxstyle="round,pad=0.02,rounding_size=0.08",
                                fc=fill, ec=ec, lw=lw, zorder=3))
    ax.text((x0 + x1) / 2, (y0 + y1) / 2, text, ha="center", va="center", fontsize=fs,
            fontweight="bold" if bold else "normal", zorder=4)


def mux(ax, x0, y0, x1, y1, labels=("0", "1"), in_y=None):
    ax.add_patch(FancyBboxPatch((x0, y0), x1 - x0, y1 - y0, boxstyle="round,pad=0.0,rounding_size=0.18",
                                fc="#ffffff", ec=DATA, lw=1.4, zorder=3))
    ax.text((x0 + x1) / 2, (y0 + y1) / 2, "M\nU\nX", ha="center", va="center", fontsize=6.5,
            fontweight="bold", zorder=4, linespacing=0.9)
    if in_y:
        for lab, y in zip(labels, in_y):
            ax.text(x0 + 0.06, y, lab, ha="left", va="center", fontsize=6, zorder=5, color="#555")


def wire(ax, pts, color=DATA, lw=1.3, arrow=True, dashed=False, label=None, lpos=None, lfs=7, lcolor=None,
         ha="left", va="bottom"):
    xs, ys = zip(*pts)
    ax.plot(xs, ys, color=color, lw=lw, ls=(0, (4, 2.5)) if dashed else "-", zorder=2,
            solid_capstyle="butt")
    if arrow:
        (xa, ya), (xb, yb) = pts[-2], pts[-1]
        ax.annotate("", xy=(xb, yb), xytext=(xa + (xb - xa) * 0.6, ya + (yb - ya) * 0.6),
                    arrowprops=dict(arrowstyle="-|>", color=color, lw=lw, mutation_scale=9), zorder=2)
    if label:
        x, y = lpos if lpos else pts[0]
        ax.text(x, y, label, fontsize=lfs, color=lcolor or color, ha=ha, va=va, zorder=5)


def dot(ax, x, y, color=DATA):
    ax.plot([x], [y], "o", color=color, ms=3.6, zorder=4)


def datapath():
    fig, ax = plt.subplots(figsize=(15, 10), dpi=160)
    ax.set_xlim(0, 15.2)
    ax.set_ylim(0.4, 10.6)
    ax.axis("off")

    # stage bands
    bands = [("FETCH", 0.1, 4.35, "fetch"), ("DECODE / REGISTER READ", 4.35, 8.15, "dec"),
             ("EXECUTE", 8.15, 11.3, "exe"), ("MEMORY", 11.3, 13.4, "mem"), ("WRITE-BACK", 13.4, 15.1, "wb")]
    for name, x0, x1, k in bands:
        ax.add_patch(plt.Rectangle((x0, 0.5), x1 - x0, 9.9, fc=FILL[k], ec="none", zorder=0))
        ax.text((x0 + x1) / 2, 10.25, name, ha="center", va="center", fontsize=9, color="#4a5560",
                fontweight="bold")

    # ---------------- blocks
    box(ax, 0.6, 4.2, 1.6, 5.6, "PC", "#ffffff", 11)
    box(ax, 2.3, 3.5, 4.0, 6.1, "Instruction\nMemory\n\n256 x 32\n(ROM)", fs=8.5)
    box(ax, 2.3, 8.15, 3.2, 9.0, "Adder\n+4", fs=8)
    box(ax, 8.6, 8.15, 9.5, 9.0, "Branch\nAdder", fs=8)
    mux(ax, 10.8, 8.0, 11.2, 9.25, in_y=(8.85, 8.35))
    box(ax, 5.15, 6.65, 7.05, 7.85, "Control\nUnit", "#e3eefc", 10, ec=CTRL)
    box(ax, 6.0, 3.6, 7.6, 5.8, "", fs=9)
    ax.text(6.8, 5.55, "Register File", ha="center", fontsize=8.5, fontweight="bold", zorder=5)
    ax.text(6.8, 5.28, "32 x 32-bit", ha="center", fontsize=7, zorder=5, color="#444")
    for t, y in (("rs1", 5.0), ("rs2", 4.6), ("rd", 4.2), ("WD", 3.85)):
        ax.text(6.07, y, t, fontsize=6.5, va="center", zorder=5)
    for t, y in (("RD1", 5.0), ("RD2", 4.2)):
        ax.text(7.53, y, t, fontsize=6.5, va="center", ha="right", zorder=5)
    box(ax, 6.0, 2.0, 7.6, 2.85, "Immediate\nGenerator", fs=8)
    mux(ax, 8.4, 3.5, 8.8, 4.75, in_y=(4.2, 3.8))
    # ALU shape
    alu = Polygon([(9.2, 5.7), (10.4, 5.15), (10.4, 3.65), (9.2, 3.1), (9.2, 4.2), (9.45, 4.4), (9.2, 4.6)],
                  closed=True, fc="#ffffff", ec=DATA, lw=1.4, zorder=3)
    ax.add_patch(alu)
    ax.text(9.9, 4.4, "ALU", ha="center", va="center", fontsize=10, fontweight="bold", zorder=4)
    box(ax, 9.2, 2.0, 10.45, 2.65, "ALU\nControl", "#e3eefc", 7.5, ec=CTRL)
    box(ax, 9.85, 5.9, 10.75, 6.5, "Branch\nUnit", "#e3eefc", 7, ec=CTRL)
    box(ax, 11.45, 3.0, 13.0, 5.6, "", fs=9)
    ax.text(12.22, 5.3, "Data Memory", ha="center", fontsize=8.5, fontweight="bold", zorder=5)
    ax.text(12.22, 5.05, "256 x 32 (1 KB)", ha="center", fontsize=7, color="#444", zorder=5)
    ax.text(11.52, 4.4, "Addr", fontsize=6.5, va="center", zorder=5)
    ax.text(11.52, 3.4, "WD", fontsize=6.5, va="center", zorder=5)
    ax.text(12.93, 4.2, "RD", fontsize=6.5, va="center", ha="right", zorder=5)
    mux(ax, 13.8, 3.0, 14.2, 4.6, labels=("0", "1"), in_y=(3.4, 4.2))
    ax.text(14.0, 2.75, "Write-back\nMUX", ha="center", va="top", fontsize=6.5, color="#333")

    # ---------------- data wires
    wire(ax, [(1.6, 4.9), (2.3, 4.9)], label="PC", lpos=(1.7, 4.95))
    dot(ax, 1.9, 4.9)
    wire(ax, [(1.9, 4.9), (1.9, 8.8), (2.3, 8.8)])
    dot(ax, 1.9, 8.8)
    wire(ax, [(1.9, 8.8), (1.9, 9.2), (8.3, 9.2), (8.3, 8.85), (8.6, 8.85)])
    wire(ax, [(2.05, 8.35), (2.3, 8.35)], label="4", lpos=(1.98, 8.35), va="center", ha="right")
    wire(ax, [(3.2, 8.575), (3.5, 8.575), (3.5, 9.55), (10.6, 9.55), (10.6, 8.85), (10.8, 8.85)],
         label="PC + 4", lpos=(5.0, 9.6))
    wire(ax, [(9.5, 8.575), (10.3, 8.575), (10.3, 8.35), (10.8, 8.35)], label="PC + imm", lpos=(9.55, 8.62), lfs=6.5)
    wire(ax, [(11.2, 8.625), (11.6, 8.625), (11.6, 9.95), (0.3, 9.95), (0.3, 4.9), (0.6, 4.9)],
         label="next PC", lpos=(5.0, 10.0))

    # instruction bus
    wire(ax, [(4.0, 4.8), (4.6, 4.8)], arrow=False, label="instr[31:0]", lpos=(3.62, 6.18), lfs=7)
    ax.plot([4.6, 4.6], [1.7, 7.25], color=DATA, lw=2.6, zorder=2)
    for y in (4.8,):
        dot(ax, 4.6, y)
    wire(ax, [(4.6, 7.25), (5.15, 7.25)], label="opcode [6:0]\nfunct3 [14:12]\nfunct7 [31:25]", lpos=(4.52, 7.3), lfs=6, ha="right")
    wire(ax, [(4.6, 5.0), (6.0, 5.0)], label="[19:15]", lpos=(4.7, 5.04), lfs=6.5)
    wire(ax, [(4.6, 4.6), (6.0, 4.6)], label="[24:20]", lpos=(4.7, 4.64), lfs=6.5)
    wire(ax, [(4.6, 4.2), (6.0, 4.2)], label="[11:7]", lpos=(4.7, 4.24), lfs=6.5)
    wire(ax, [(4.6, 2.4), (6.0, 2.4)], label="[31:0]", lpos=(4.7, 2.44), lfs=6.5)
    wire(ax, [(4.6, 1.7), (9.8, 1.7), (9.8, 2.0)], label="funct3, funct7[30]", lpos=(6.3, 1.74), lfs=6.5)

    # register file outputs
    wire(ax, [(7.6, 5.0), (9.2, 5.0)], label="rs1 data", lpos=(8.0, 5.04), lfs=6.5)
    wire(ax, [(7.6, 4.2), (8.4, 4.2)])
    dot(ax, 8.25, 4.2)
    wire(ax, [(8.25, 4.2), (8.25, 1.35), (11.15, 1.35), (11.15, 3.4), (11.45, 3.4)],
         label="rs2 data (store data)", lpos=(8.35, 1.39), lfs=6.5)
    # immediate
    wire(ax, [(7.6, 2.4), (8.05, 2.4), (8.05, 3.8), (8.4, 3.8)])
    dot(ax, 7.85, 2.4)
    wire(ax, [(7.85, 2.4), (7.85, 8.4), (8.6, 8.4)], label="imm", lpos=(7.9, 6.2), lfs=6.5)
    # ALU
    wire(ax, [(8.8, 4.125), (9.2, 4.125)])
    wire(ax, [(9.8, 2.65), (9.8, 3.37)], color=CTRL, label="ALUctrl", lpos=(9.83, 2.8), lfs=6)
    wire(ax, [(10.4, 4.4), (11.45, 4.4)], label="ALU result", lpos=(10.42, 4.44), lfs=6.5)
    dot(ax, 10.95, 4.4)
    wire(ax, [(10.95, 4.4), (10.95, 2.5), (13.5, 2.5), (13.5, 3.4), (13.8, 3.4)])
    wire(ax, [(10.4, 5.3), (10.55, 5.3), (10.55, 5.9)], color=CTRL, label="zero", lpos=(10.6, 5.5), lfs=6.5)
    wire(ax, [(10.75, 6.2), (11.0, 6.2), (11.0, 8.0)], color=CTRL, label="PCSrc", lpos=(11.05, 6.3), lfs=6.5)
    # memory / write-back
    wire(ax, [(13.0, 4.2), (13.8, 4.2)], label="read data", lpos=(13.02, 4.25), lfs=6.5)
    wire(ax, [(14.2, 3.8), (14.65, 3.8), (14.65, 0.85), (5.6, 0.85), (5.6, 3.85), (6.0, 3.85)],
         label="write-back data", lpos=(9.5, 0.89))

    # ---------------- control wires (dashed)
    c = dict(color=CTRL, dashed=True, lw=1.1)
    wire(ax, [(6.8, 6.65), (6.8, 5.8)], label="RegWrite", lpos=(6.85, 6.15), lfs=6.5, **c)
    wire(ax, [(5.4, 6.65), (5.4, 2.65), (6.0, 2.65)], label="ImmSel", lpos=(5.05, 6.1), lfs=6.5, **c)
    wire(ax, [(7.05, 7.7), (10.1, 7.7), (10.1, 6.5)], label="Branch", lpos=(9.35, 7.73), lfs=6.5, **c)
    wire(ax, [(7.05, 7.5), (8.6, 7.5), (8.6, 4.75)], label="ALUSrc", lpos=(8.55, 6.3), ha="right", lfs=6.5, **c)
    wire(ax, [(7.05, 7.3), (9.0, 7.3), (9.0, 2.33), (9.2, 2.33)], label="ALUOp", lpos=(9.05, 6.3), lfs=6.5, **c)
    wire(ax, [(7.05, 7.1), (12.0, 7.1), (12.0, 5.6)], label="MemRead", lpos=(11.95, 6.2), ha="right", lfs=6.5, **c)
    wire(ax, [(7.05, 6.9), (12.6, 6.9), (12.6, 5.6)], label="MemWrite", lpos=(12.65, 6.2), lfs=6.5, **c)
    wire(ax, [(7.05, 6.75), (7.3, 6.75), (7.3, 6.62), (14.0, 6.62), (14.0, 4.6)], label="MemToReg",
         lpos=(14.05, 5.4), lfs=6.5, **c)

    ax.text(0.15, 0.62, "Solid = 32-bit data / address paths      Dashed blue = control signals      "
            "All paths settle within ONE clock cycle; PC, register file and data memory update on the rising edge.",
            fontsize=7.5, color="#333")
    ax.set_title("Single-Cycle RV32I Processor - Datapath and Control", fontsize=14, fontweight="bold", pad=4)
    plt.savefig(os.path.join(OUT, "datapath.png"), bbox_inches="tight")
    plt.close()


def hierarchy():
    fig, ax = plt.subplots(figsize=(12, 5.2), dpi=160)
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 5.2)
    ax.axis("off")
    box(ax, 4.6, 4.3, 7.4, 5.0, "fpga_top  (fpga/fpga_top.v)\nreset sync, slow-step, LED output", "#eef0f2", 8)
    box(ax, 4.6, 3.1, 7.4, 3.8, "rv32i_cpu  (rtl/rv32i_cpu.v)\ntop-level single-cycle CPU", "#e3eefc", 8.5)
    wire(ax, [(6.0, 4.3), (6.0, 3.8)])
    mods = [("pc.v", "u_pc", "Program\nCounter", "fetch"), ("instr_mem.v", "u_imem", "Instruction\nMemory", "fetch"),
            ("adder.v", "u_pc_plus4\nu_branch_adder", "Adders\n(x2)", "fetch"),
            ("control_unit.v", "u_ctrl", "Control\nUnit", "dec"), ("reg_file.v", "u_rf", "Register\nFile", "dec"),
            ("imm_gen.v", "u_immgen", "Immediate\nGenerator", "dec"), ("alu_control.v", "u_aluctrl", "ALU\nControl", "exe"),
            ("alu.v", "u_alu", "ALU", "exe"), ("branch_unit.v", "u_branch", "Branch\nUnit", "exe"),
            ("data_mem.v", "u_dmem", "Data\nMemory", "mem"),
            ("mux2.v", "u_alusrc_mux\nu_wb_mux\nu_pc_mux", "2:1 MUX\n(x3)", "wb")]
    n = len(mods)
    w = 12 / n
    ax.plot([w / 2, 12 - w / 2], [2.75, 2.75], color=DATA, lw=1.2)
    ax.plot([6.0, 6.0], [3.1, 2.75], color=DATA, lw=1.2)
    for i, (f, inst, name, st) in enumerate(mods):
        x = i * w + w / 2
        wire(ax, [(x, 2.75), (x, 2.45)])
        box(ax, x - w / 2 + 0.06, 1.35, x + w / 2 - 0.06, 2.45, name, FILL[st], 7.5)
        ax.text(x, 1.22, f, ha="center", va="top", fontsize=6.3, family="monospace")
        ax.text(x, 0.95, inst, ha="center", va="top", fontsize=5.6, family="monospace", color="#555")
    ax.text(0.05, 4.95, "Shared constants: rtl/defines.vh", fontsize=7, color="#333")
    ax.set_title("Verilog module hierarchy (synthesizable RTL)", fontsize=12, fontweight="bold")
    plt.savefig(os.path.join(OUT, "module_hierarchy.png"), bbox_inches="tight")
    plt.close()


def formats():
    fig, ax = plt.subplots(figsize=(12, 3.6), dpi=160)
    ax.set_xlim(-4.6, 32.4)
    ax.set_ylim(-0.4, 4.6)
    ax.axis("off")
    fmts = [("R-type", "ADD SUB AND OR XOR", [(31, 25, "funct7"), (24, 20, "rs2"), (19, 15, "rs1"), (14, 12, "funct3"), (11, 7, "rd"), (6, 0, "opcode")]),
            ("I-type", "ADDI LW", [(31, 20, "imm[11:0]"), (19, 15, "rs1"), (14, 12, "funct3"), (11, 7, "rd"), (6, 0, "opcode")]),
            ("S-type", "SW", [(31, 25, "imm[11:5]"), (24, 20, "rs2"), (19, 15, "rs1"), (14, 12, "funct3"), (11, 7, "imm[4:0]"), (6, 0, "opcode")]),
            ("B-type", "BEQ BNE", [(31, 25, "imm[12|10:5]"), (24, 20, "rs2"), (19, 15, "rs1"), (14, 12, "funct3"), (11, 7, "imm[4:1|11]"), (6, 0, "opcode")])]
    cols = {"opcode": "#e3eefc", "rd": "#eaf6ee", "rs1": "#fff4e2", "rs2": "#fff4e2", "funct3": "#f6ebf7", "funct7": "#f6ebf7"}
    for r, (name, ins, fields) in enumerate(fmts):
        y = 3.4 - r * 1.05
        ax.text(-4.5, y + 0.35, name, fontsize=9, fontweight="bold", va="center")
        ax.text(-4.5, y + 0.05, ins, fontsize=6.5, va="center", color="#555")
        for hi, lo, lab in fields:
            x0, x1 = 31 - hi, 32 - lo
            fc = cols.get(lab, "#fde9d9")
            ax.add_patch(plt.Rectangle((x0, y), x1 - x0, 0.7, fc=fc, ec=DATA, lw=1))
            ax.text((x0 + x1) / 2, y + 0.35, lab, ha="center", va="center", fontsize=7.5)
            if r == 0 or True:
                ax.text(x0 + 0.1, y + 0.78, str(hi), fontsize=5.5, color="#666")
                ax.text(x1 - 0.1, y + 0.78, str(lo), fontsize=5.5, color="#666", ha="right")
    ax.text(15.5, -0.35, "opcodes: R 0110011 | ADDI 0010011 | LW 0000011 | SW 0100011 | BEQ/BNE 1100011    "
            "funct3: ADD/SUB 000, XOR 100, OR 110, AND 111, LW/SW 010, BEQ 000, BNE 001    funct7: SUB 0100000",
            ha="center", fontsize=6.6, color="#333")
    ax.set_title("RV32I instruction formats used by the 10 supported instructions", fontsize=11, fontweight="bold")
    plt.savefig(os.path.join(OUT, "instr_formats.png"), bbox_inches="tight")
    plt.close()


def verif_flow():
    fig, ax = plt.subplots(figsize=(12, 3.4), dpi=160)
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 3.4)
    ax.axis("off")
    box(ax, 0.1, 2.2, 1.9, 3.1, "Test program\n(.s assembly)", "#eef0f2", 8)
    box(ax, 2.5, 2.2, 4.3, 3.1, "assembler.py\n-> .hex machine code", "#e3eefc", 7.5)
    box(ax, 5.0, 2.4, 7.0, 3.3, "Golden model\niss.py (Python)", "#fff4e2", 8)
    box(ax, 5.0, 0.4, 7.0, 1.3, "Verilog CPU\n(Icarus Verilog)", "#eaf6ee", 8)
    box(ax, 7.7, 2.4, 9.5, 3.3, "expected regs,\nmemory, PC, count", "#fff4e2", 7.5)
    box(ax, 7.7, 0.4, 9.5, 1.3, "actual regs,\nmemory, PC, count", "#eaf6ee", 7.5)
    box(ax, 10.1, 1.3, 11.9, 2.4, "compare\n-> PASS / FAIL\n+ coverage", "#f6ebf7", 8)
    wire(ax, [(1.9, 2.65), (2.5, 2.65)])
    wire(ax, [(4.3, 2.75), (5.0, 2.85)])
    wire(ax, [(4.3, 2.4), (4.6, 2.4), (4.6, 0.85), (5.0, 0.85)])
    wire(ax, [(7.0, 2.85), (7.7, 2.85)])
    wire(ax, [(7.0, 0.85), (7.7, 0.85)])
    wire(ax, [(9.5, 2.85), (9.8, 2.85), (9.8, 2.1), (10.1, 2.1)])
    wire(ax, [(9.5, 0.85), (9.8, 0.85), (9.8, 1.6), (10.1, 1.6)])
    ax.text(5.0, 1.55, "testbench: tb_rv32i_cpu.v  (+ VCD waveform, trace log,\n"
            "random clock-enable stall test, mutation test)", fontsize=6.8, color="#333")
    ax.text(0.1, 0.9, "Unit testbenches:\n tb_alu (5010 vectors)\n tb_reg_file, tb_imm_gen,\n tb_control_unit",
            fontsize=6.8, color="#333", va="center")
    ax.set_title("Verification methodology: self-checking testbench against a golden reference model",
                 fontsize=11, fontweight="bold")
    plt.savefig(os.path.join(OUT, "verification_flow.png"), bbox_inches="tight")
    plt.close()


if __name__ == "__main__":
    datapath()
    hierarchy()
    formats()
    verif_flow()
    print("diagrams written to", os.path.normpath(OUT))
