# ============================================================================
# Test 4 : Unsupported instructions
# Instructions outside the 10-instruction subset must behave as a NOP:
# no register write, no memory write, PC simply advances by 4.
# The destination registers are preloaded with marker values first, so any
# accidental write would change them and be caught by the testbench.
# ============================================================================
        addi x1, x0, 9          # x1 = 9
        addi x2, x0, 4          # x2 = 4
        addi x3, x0, 0x33       # markers: these must NOT change
        addi x4, x0, 0x44
        addi x5, x0, 0x55
        addi x7, x0, 0x77
        addi x8, x0, 0x88
        addi x9, x0, 0x99
        .word 0x0020a1b3        # slt  x3, x1, x2   (unsupported) -> NOP
        .word 0x00209233        # sll  x4, x1, x2   (unsupported) -> NOP
        .word 0x0050c293        # xori x5, x1, 5    (unsupported) -> NOP
        .word 0x00102023        # sw   with funct3=000 (sb) -> NOP, no store
        .word 0x004003ef        # jal  x7, 4        (unsupported) -> NOP
        .word 0x12345437        # lui  x8, 0x12345  (unsupported) -> NOP
        .word 0x00000497        # auipc x9, 0       (unsupported) -> NOP
        .word 0x00000000        # all-zero word     -> NOP
        add  x6, x1, x2         # x6 = 13 (execution continues normally)
        sw   x6, 0(x0)          # mem[0] = 13
        halt
