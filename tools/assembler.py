#!/usr/bin/env python3
"""
Mini RV32I assembler for the Single-Cycle RV32I Processor project.

Supported instructions (the project subset):
    R-type : add, sub, and, or, xor          rd, rs1, rs2
    I-type : addi                            rd, rs1, imm12
             lw                              rd, imm12(rs1)
    S-type : sw                              rs2, imm12(rs1)
    B-type : beq, bne                        rs1, rs2, label|offset

Pseudo-instructions (expanded to the subset above):
    nop                -> addi x0, x0, 0
    li   rd, imm12     -> addi rd, x0, imm12
    mv   rd, rs        -> addi rd, rs, 0
    j    label         -> beq  x0, x0, label
    beqz rs, label     -> beq  rs, x0, label
    bnez rs, label     -> bne  rs, x0, label
    halt               -> beq  x0, x0, 0      (jump-to-self = end of program)

Directive:
    .word value        raw 32-bit word (used to test unsupported encodings)

Usage:
    python3 assembler.py program.s -o program.hex [-l program.lst]

Output .hex: one 32-bit instruction per line (for Verilog $readmemh).
Output .lst: listing with address, machine code, binary fields and source.
"""
import argparse
import re
import sys

REG_ABI = {
    "zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4,
    "t0": 5, "t1": 6, "t2": 7, "s0": 8, "fp": 8, "s1": 9,
    "a0": 10, "a1": 11, "a2": 12, "a3": 13, "a4": 14, "a5": 15,
    "a6": 16, "a7": 17, "s2": 18, "s3": 19, "s4": 20, "s5": 21,
    "s6": 22, "s7": 23, "s8": 24, "s9": 25, "s10": 26, "s11": 27,
    "t3": 28, "t4": 29, "t5": 30, "t6": 31,
}

OPCODE = {"R": 0b0110011, "I_ALU": 0b0010011, "LOAD": 0b0000011,
          "STORE": 0b0100011, "BRANCH": 0b1100011}

R_FUNCT = {  # name: (funct3, funct7)
    "add": (0b000, 0b0000000),
    "sub": (0b000, 0b0100000),
    "xor": (0b100, 0b0000000),
    "or":  (0b110, 0b0000000),
    "and": (0b111, 0b0000000),
}
B_FUNCT3 = {"beq": 0b000, "bne": 0b001}


class AsmError(Exception):
    pass


def reg(tok):
    tok = tok.strip().lower()
    if tok in REG_ABI:
        return REG_ABI[tok]
    m = re.fullmatch(r"x(\d+)", tok)
    if m and 0 <= int(m.group(1)) <= 31:
        return int(m.group(1))
    raise AsmError(f"bad register '{tok}'")


def num(tok):
    tok = tok.strip().lower()
    try:
        return int(tok, 0)
    except ValueError:
        raise AsmError(f"bad number '{tok}'")


def check_imm(val, bits, what):
    lo, hi = -(1 << (bits - 1)), (1 << (bits - 1)) - 1
    if not lo <= val <= hi:
        raise AsmError(f"{what} {val} out of range [{lo}, {hi}]")


def enc_r(name, rd, rs1, rs2):
    f3, f7 = R_FUNCT[name]
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | OPCODE["R"]


def enc_i(opcode, f3, rd, rs1, imm):
    check_imm(imm, 12, "I-immediate")
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opcode


def enc_s(rs2, rs1, imm):
    check_imm(imm, 12, "S-immediate")
    imm &= 0xFFF
    return (((imm >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) | (0b010 << 12) \
        | ((imm & 0x1F) << 7) | OPCODE["STORE"]


def enc_b(name, rs1, rs2, off):
    check_imm(off, 13, "branch offset")
    if off % 2:
        raise AsmError(f"branch offset {off} must be even")
    off &= 0x1FFF
    return (((off >> 12) & 1) << 31) | (((off >> 5) & 0x3F) << 25) | (rs2 << 20) \
        | (rs1 << 15) | (B_FUNCT3[name] << 12) | (((off >> 1) & 0xF) << 8) \
        | (((off >> 11) & 1) << 7) | OPCODE["BRANCH"]


def parse_mem(tok):
    m = re.fullmatch(r"\s*(-?\w*)\s*\(\s*(\w+)\s*\)\s*", tok)
    if not m:
        raise AsmError(f"bad memory operand '{tok}' (expected imm(reg))")
    imm = num(m.group(1)) if m.group(1) else 0
    return imm, reg(m.group(2))


def expand(mn, ops):
    """Expand pseudo-instructions into real ones."""
    if mn == "nop":
        return "addi", ["x0", "x0", "0"]
    if mn == "li":
        return "addi", [ops[0], "x0", ops[1]]
    if mn == "mv":
        return "addi", [ops[0], ops[1], "0"]
    if mn == "j":
        return "beq", ["x0", "x0", ops[0]]
    if mn == "beqz":
        return "beq", [ops[0], "x0", ops[1]]
    if mn == "bnez":
        return "bne", [ops[0], "x0", ops[1]]
    if mn == "halt":
        return "beq", ["x0", "x0", "0"]
    return mn, ops


def assemble(text):
    lines = []          # (addr, mnemonic, operands, source, lineno)
    labels = {}
    addr = 0
    for lineno, raw in enumerate(text.splitlines(), 1):
        src = raw.split("#")[0].strip()
        while True:
            m = re.match(r"^([A-Za-z_]\w*):\s*(.*)$", src)
            if not m:
                break
            if m.group(1) in labels:
                raise AsmError(f"line {lineno}: duplicate label {m.group(1)}")
            labels[m.group(1)] = addr
            src = m.group(2).strip()
        if not src:
            continue
        parts = src.split(None, 1)
        mn = parts[0].lower()
        ops = [o.strip() for o in parts[1].split(",")] if len(parts) > 1 else []
        lines.append((addr, mn, ops, raw.strip(), lineno))
        addr += 4

    words = []
    for addr, mn, ops, src, lineno in lines:
        try:
            mn2, ops2 = expand(mn, ops)
            if mn2 == ".word":                   # raw 32-bit word
                w = num(ops2[0]) & 0xFFFFFFFF
            elif mn2 in R_FUNCT:
                w = enc_r(mn2, reg(ops2[0]), reg(ops2[1]), reg(ops2[2]))
            elif mn2 == "addi":
                w = enc_i(OPCODE["I_ALU"], 0b000, reg(ops2[0]), reg(ops2[1]), num(ops2[2]))
            elif mn2 == "lw":
                imm, rs1 = parse_mem(ops2[1])
                w = enc_i(OPCODE["LOAD"], 0b010, reg(ops2[0]), rs1, imm)
            elif mn2 == "sw":
                imm, rs1 = parse_mem(ops2[1])
                w = enc_s(reg(ops2[0]), rs1, imm)
            elif mn2 in B_FUNCT3:
                tgt = ops2[2]
                off = labels[tgt] - addr if tgt in labels else num(tgt)
                w = enc_b(mn2, reg(ops2[0]), reg(ops2[1]), off)
            else:
                raise AsmError(f"unsupported instruction '{mn}'")
        except (AsmError, IndexError) as e:
            raise AsmError(f"line {lineno}: {src}: {e}")
        words.append((addr, w, src))
    return words, labels


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source")
    ap.add_argument("-o", "--out", required=True, help="output .hex file")
    ap.add_argument("-l", "--listing", help="output listing file")
    a = ap.parse_args()
    try:
        words, labels = assemble(open(a.source).read())
    except AsmError as e:
        sys.exit(f"assembler error: {e}")
    with open(a.out, "w") as f:
        for _, w, _ in words:
            f.write(f"{w:08x}\n")
    if a.listing:
        with open(a.listing, "w") as f:
            f.write(f"; listing of {a.source}\n; ADDR  MACHINE   SOURCE\n")
            for addr, w, src in words:
                f.write(f"{addr:04x}  {w:08x}  {src}\n")
            f.write("\n; labels\n")
            for k, v in labels.items():
                f.write(f";   {k:<12} = 0x{v:04x}\n")
    print(f"{a.source}: {len(words)} instructions -> {a.out}")


if __name__ == "__main__":
    main()
