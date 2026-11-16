#!/usr/bin/env python3
"""
Golden reference model (Instruction Set Simulator) for the RV32I subset.

It executes a .hex program exactly as the architecture defines, and produces
the "correct answers" that the Verilog testbench compares the CPU against:

    <name>_exp_regs.hex   32 lines  : expected final value of x0..x31
    <name>_exp_dmem.hex   N lines   : expected final data-memory words
    <name>_exp_pc.hex     2 lines   : expected HALT PC and instruction count
    <name>_exp_info.txt             : instruction count, cycles, mix (for the report)
    <name>_trace.txt                : per-instruction execution trace

Usage:
    python3 iss.py program.hex --out-prefix build/program [--dmem-words 256]
"""
import argparse
import json

MASK = 0xFFFFFFFF


def sext(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


def decode(w):
    op = w & 0x7F
    rd = (w >> 7) & 0x1F
    f3 = (w >> 12) & 7
    rs1 = (w >> 15) & 0x1F
    rs2 = (w >> 20) & 0x1F
    f7 = w >> 25
    if op == 0b0110011:
        name = {(0, 0): "add", (0, 0x20): "sub", (4, 0): "xor",
                (6, 0): "or", (7, 0): "and"}.get((f3, f7), "illegal")
        return name, rd, rs1, rs2, 0
    if op == 0b0010011 and f3 == 0:
        return "addi", rd, rs1, rs2, sext(w >> 20, 12)
    if op == 0b0000011 and f3 == 2:
        return "lw", rd, rs1, rs2, sext(w >> 20, 12)
    if op == 0b0100011 and f3 == 2:
        return "sw", rd, rs1, rs2, sext(((w >> 25) << 5) | ((w >> 7) & 0x1F), 12)
    if op == 0b1100011 and f3 in (0, 1):
        imm = (((w >> 31) & 1) << 12) | (((w >> 7) & 1) << 11) | \
              (((w >> 25) & 0x3F) << 5) | (((w >> 8) & 0xF) << 1)
        return ("beq" if f3 == 0 else "bne"), rd, rs1, rs2, sext(imm, 13)
    return "illegal", rd, rs1, rs2, 0


def run(prog, dmem_words=256, max_steps=100000):
    x = [0] * 32
    dmem = [0] * dmem_words
    pc = 0
    mix = {}
    taken = {"beq": [0, 0], "bne": [0, 0]}   # [taken, not taken]
    trace = []
    steps = 0
    while steps < max_steps:
        idx = pc >> 2
        w = prog[idx] if idx < len(prog) else 0
        name, rd, rs1, rs2, imm = decode(w)
        if w == 0x00000063:                     # beq x0,x0,0  => halt
            trace.append(f"{pc:08x}: {w:08x} halt")
            break
        mix[name] = mix.get(name, 0) + 1
        a, b = x[rs1], x[rs2]
        next_pc = (pc + 4) & MASK
        note = ""
        if name in ("add", "sub", "xor", "or", "and", "addi"):
            r = {"add": a + b, "sub": a - b, "xor": a ^ b, "or": a | b,
                 "and": a & b, "addi": a + imm}[name] & MASK
            if rd:
                x[rd] = r
            note = f"x{rd} <= {r:08x}"
        elif name == "lw":
            addr = (a + imm) & MASK
            r = dmem[(addr >> 2) % dmem_words]
            if rd:
                x[rd] = r
            note = f"x{rd} <= mem[{addr:08x}] = {r:08x}"
        elif name == "sw":
            addr = (a + imm) & MASK
            dmem[(addr >> 2) % dmem_words] = b
            note = f"mem[{addr:08x}] <= {b:08x}"
        elif name in ("beq", "bne"):
            cond = (a == b) if name == "beq" else (a != b)
            taken[name][0 if cond else 1] += 1
            if cond:
                next_pc = (pc + imm) & MASK
            note = f"{'taken' if cond else 'not taken'} -> {next_pc:08x}"
        else:
            note = "illegal instruction (treated as NOP)"
        trace.append(f"{pc:08x}: {w:08x} {name:<5} {note}")
        pc = next_pc
        steps += 1
    else:
        raise RuntimeError("program did not halt")
    return x, dmem, mix, taken, steps, trace, pc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("hexfile")
    ap.add_argument("--out-prefix", required=True)
    ap.add_argument("--dmem-words", type=int, default=256)
    a = ap.parse_args()
    prog = [int(l, 16) for l in open(a.hexfile) if l.strip()]
    x, dmem, mix, taken, steps, trace, halt_pc = run(prog, a.dmem_words)
    p = a.out_prefix
    with open(p + "_exp_regs.hex", "w") as f:
        f.writelines(f"{v:08x}\n" for v in x)
    with open(p + "_exp_dmem.hex", "w") as f:
        f.writelines(f"{v:08x}\n" for v in dmem)
    # line 0: PC of the HALT instruction, line 1: instructions executed
    with open(p + "_exp_pc.hex", "w") as f:
        f.write(f"{halt_pc:08x}\n{steps:08x}\n")
    with open(p + "_trace.txt", "w") as f:
        f.write("\n".join(trace) + "\n")
    info = {"instructions_executed": steps,
            "cycles_single_cycle": steps,     # CPI = 1 (halt not counted)
            "mix": mix, "branches": taken,
            "static_instructions": len(prog)}
    with open(p + "_exp_info.json", "w") as f:
        json.dump(info, f, indent=2)
    print(f"ISS {a.hexfile}: {steps} instructions executed, mix={mix}")


if __name__ == "__main__":
    main()
