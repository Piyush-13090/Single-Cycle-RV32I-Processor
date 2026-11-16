# ============================================================================
# Test 2 : Memory instructions  (LW SW)
# Covers positive / negative / zero offsets, first and last word of the 1 KB
# data memory, load of an unwritten location, load into x0, and a load whose
# result is used by the very next instruction.
# ============================================================================
        addi x1,  x0, 100       # x1 = 100
        addi x2,  x0, -200      # x2 = -200
        addi x3,  x0, 0x7AB     # x3 = 1963
        addi x10, x0, 64        # base address 0x40
        sw   x1,  0(x10)        # mem[0x40] = 100
        sw   x2,  4(x10)        # mem[0x44] = -200
        sw   x3,  8(x10)        # mem[0x48] = 1963
        sw   x2,  -4(x10)       # mem[0x3C] = -200   (negative offset)
        lw   x4,  0(x10)        # x4 = 100
        lw   x5,  4(x10)        # x5 = -200
        lw   x6,  8(x10)        # x6 = 1963
        lw   x7,  -4(x10)       # x7 = -200
        add  x8,  x4, x5        # x8 = -100
        sw   x8,  12(x10)       # mem[0x4C] = -100
        lw   x9,  12(x10)       # x9 = -100
        sw   x3,  0(x0)         # mem[0x000] = 1963  (first word)
        sw   x9,  1020(x0)      # mem[0x3FC] = -100  (last word of 1 KB)
        lw   x11, 1020(x0)      # x11 = -100
        lw   x12, 0(x0)         # x12 = 1963
        lw   x13, 100(x0)       # x13 = 0            (never written)
        lw   x0,  0(x10)        # load into x0 -> ignored
        lw   x14, 4(x10)        # x14 = -200
        add  x15, x14, x14      # x15 = -400  (uses load result next cycle)
        halt
