# ============================================================================
# Full test : uses ALL 10 instructions in one program.
# Used for synthesis and for the FPGA / live demo (a0 is shown on the LEDs).
#
# Builds the array {12, 7, 12, -3, 12, 25} at 0x40 and computes in one loop:
#   a1 = sum            = 65
#   a2 = XOR of all     = 12^7^12^-3^12^25
#   a3 = count of 12s   = 3
#   a4 = OR  of all
#   a5 = AND of all
# Then a0 = sum - count = 62 if the count check passes (else a0 = -1).
# Results are stored at 0x80..0x94.
# ============================================================================
        addi s0, x0, 0x40       # base address
        addi t0, x0, 12
        sw   t0, 0(s0)
        addi t0, x0, 7
        sw   t0, 4(s0)
        addi t0, x0, 12
        sw   t0, 8(s0)
        addi t0, x0, -3
        sw   t0, 12(s0)
        addi t0, x0, 12
        sw   t0, 16(s0)
        addi t0, x0, 25
        sw   t0, 20(s0)

        addi s1, x0, 6          # n
        addi t1, x0, 0          # i
        addi a1, x0, 0          # sum
        addi a2, x0, 0          # xor
        addi a3, x0, 0          # count of key
        addi a4, x0, 0          # or
        addi a5, x0, -1         # and (all ones)
        addi t2, x0, 12         # key
        addi t3, s0, 0          # ptr
loop:   lw   t4, 0(t3)
        add  a1, a1, t4
        xor  a2, a2, t4
        or   a4, a4, t4
        and  a5, a5, t4
        bne  t4, t2, skip       # not the key -> skip count
        addi a3, a3, 1
skip:   addi t3, t3, 4
        addi t1, t1, 1
        bne  t1, s1, loop

        addi t5, x0, 3
        beq  a3, t5, good       # expected count = 3
        addi a0, x0, -1         # failure marker
        j    store
good:   sub  a0, a1, a3         # a0 = 65 - 3 = 62
store:  sw   a0, 128(x0)
        sw   a1, 132(x0)
        sw   a2, 136(x0)
        sw   a3, 140(x0)
        sw   a4, 144(x0)
        sw   a5, 148(x0)
        halt
