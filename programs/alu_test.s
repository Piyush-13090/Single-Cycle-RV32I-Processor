# ============================================================================
# Test 1 : ALU and immediate instructions  (ADD SUB AND OR XOR ADDI)
# Covers positive/negative values, wrap-around, 12-bit immediate limits and
# writes to x0 (must be ignored).
# ============================================================================
        addi x1,  x0, 15        # x1  = 15
        addi x2,  x0, 10        # x2  = 10
        add  x3,  x1, x2        # x3  = 25
        sub  x4,  x1, x2        # x4  = 5
        sub  x5,  x2, x1        # x5  = -5          (0xFFFFFFFB)
        and  x6,  x1, x2        # x6  = 1111 & 1010 = 10
        or   x7,  x1, x2        # x7  = 1111 | 1010 = 15
        xor  x8,  x1, x2        # x8  = 1111 ^ 1010 = 5
        addi x9,  x0, -1        # x9  = -1          (0xFFFFFFFF)
        addi x10, x9, -2047     # x10 = -2048       (min 12-bit imm)
        addi x11, x0, 2047      # x11 = 2047        (max 12-bit imm)
        add  x12, x11, x11      # x12 = 4094
        xor  x13, x9, x1        # x13 = ~15         (0xFFFFFFF0)
        and  x14, x9, x2        # x14 = 10
        or   x15, x0, x0        # x15 = 0
        add  x0,  x1, x2        # write to x0 -> ignored
        addi x0,  x0, 5         # write to x0 -> ignored
        add  x16, x0, x1        # x16 = 15          (proves x0 is still 0)
        sub  x17, x0, x1        # x17 = -15
        addi x18, x3, 0         # x18 = 25          (mv)
        add  x19, x9, x1        # x19 = 14          (-1 + 15, carry wraps)
        sub  x20, x10, x11      # x20 = -4095
        halt
