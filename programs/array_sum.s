# ============================================================================
# Benchmark 1 : Array sum
# Stores a 10-element array at 0x100 with SW, then sums it in a loop with LW.
# Result: a0 (x10) = 39, also stored at mem[0x200].
# Array: 3 1 4 1 5 9 2 6 5 3
# ============================================================================
        addi s0, x0, 256        # s0 = base address 0x100
        addi t0, x0, 3
        sw   t0, 0(s0)
        addi t0, x0, 1
        sw   t0, 4(s0)
        addi t0, x0, 4
        sw   t0, 8(s0)
        addi t0, x0, 1
        sw   t0, 12(s0)
        addi t0, x0, 5
        sw   t0, 16(s0)
        addi t0, x0, 9
        sw   t0, 20(s0)
        addi t0, x0, 2
        sw   t0, 24(s0)
        addi t0, x0, 6
        sw   t0, 28(s0)
        addi t0, x0, 5
        sw   t0, 32(s0)
        addi t0, x0, 3
        sw   t0, 36(s0)

        addi a1, x0, 10         # n = 10
        addi a0, x0, 0          # sum = 0
        addi a2, s0, 0          # ptr = base
        addi a3, x0, 0          # i = 0
loop:   lw   t1, 0(a2)          # t1 = A[i]
        add  a0, a0, t1         # sum += A[i]
        addi a2, a2, 4          # ptr++
        addi a3, a3, 1          # i++
        bne  a3, a1, loop       # while (i != n)
        sw   a0, 512(x0)        # mem[0x200] = sum
        halt
