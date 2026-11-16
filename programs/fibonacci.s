# ============================================================================
# Benchmark 2 : Fibonacci series
# Computes the first 20 Fibonacci numbers and stores them at 0x080..0x0CC.
# Result: a0 (x10) = F(19) = 4181 (loaded back from memory).
# ============================================================================
        addi s0, x0, 128        # s0 = base address 0x80
        addi t0, x0, 0          # F(i)
        addi t1, x0, 1          # F(i+1)
        addi t2, x0, 20         # count
        addi s1, x0, 0          # i
loop:   sw   t0, 0(s0)          # mem[base + 4i] = F(i)
        add  t3, t0, t1         # t3 = F(i) + F(i+1)
        addi t0, t1, 0          # F(i)   <- F(i+1)
        addi t1, t3, 0          # F(i+1) <- t3
        addi s0, s0, 4
        addi s1, s1, 1
        bne  s1, t2, loop
        lw   a0, -4(s0)         # a0 = last value stored = F(19)
        halt
