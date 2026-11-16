# ============================================================================
# Test 3 : Branch instructions  (BEQ BNE)
# Covers BEQ taken / not taken, BNE taken / not taken, forward and backward
# branches, loops, and an unconditional jump (beq x0,x0). x20 counts errors
# (any wrongly executed instruction adds to it) and must finish at 0.
# ============================================================================
        addi x1,  x0, 5
        addi x2,  x0, 5
        addi x3,  x0, 7
        addi x20, x0, 0         # error counter
        beq  x1,  x2, L1        # 5 == 5  -> TAKEN (forward)
        addi x20, x20, 1        # must be skipped
L1:     addi x21, x0, 1         # marker 1
        beq  x1,  x3, bad       # 5 == 7  -> NOT taken
        addi x22, x0, 2         # marker 2
        bne  x1,  x3, L2        # 5 != 7  -> TAKEN (forward)
        addi x20, x20, 1        # must be skipped
L2:     bne  x1,  x2, bad       # 5 != 5  -> NOT taken
        addi x23, x0, 3         # marker 3

        # backward BNE loop : x5 counts 1..5
        addi x5,  x0, 0
        addi x6,  x0, 5
loop1:  addi x5,  x5, 1
        bne  x5,  x6, loop1     # backward TAKEN 4x, not taken 1x

        # backward BEQ loop : x7 counts 3 -> 0
        addi x7,  x0, 3
loop2:  addi x7,  x7, -1
        beq  x7,  x0, done2     # forward, taken when x7 == 0
        beq  x0,  x0, loop2     # unconditional backward jump
done2:  addi x24, x0, 4         # marker 4
        j    end
bad:    addi x20, x20, 100      # only reached if a branch is wrong
end:    halt
