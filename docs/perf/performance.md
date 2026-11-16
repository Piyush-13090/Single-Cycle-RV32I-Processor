Single-cycle clock period (measured Fmax 44.39 MHz): 22.53 ns
Multi-cycle baseline clock period (slowest stage + 0.6 ns): 6.46 ns

| Program | Instr | SC cycles | SC CPI | SC time (ns) | MC cycles | MC CPI | MC time (ns) | SC speed-up |
|---|---|---|---|---|---|---|---|---|
| alu_test | 22 | 22 | 1.00 | 495.6 | 88 | 4.0 | 568.5 | 1.15x |
| mem_test | 23 | 23 | 1.00 | 518.1 | 102 | 4.43 | 658.9 | 1.27x |
| branch_test | 34 | 34 | 1.00 | 765.9 | 121 | 3.56 | 781.7 | 1.02x |
| illegal_test | 18 | 18 | 1.00 | 405.5 | 65 | 3.61 | 419.9 | 1.04x |
| array_sum | 76 | 76 | 1.00 | 1712.1 | 304 | 4.0 | 1963.8 | 1.15x |
| fibonacci | 146 | 146 | 1.00 | 3289.0 | 565 | 3.87 | 3649.9 | 1.11x |
| full_test | 88 | 88 | 1.00 | 1982.4 | 345 | 3.92 | 2228.7 | 1.12x |
