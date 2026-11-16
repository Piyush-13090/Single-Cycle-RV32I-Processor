# Project Video – Script and Shot List (about 8–10 minutes)

Goal of the video: prove the project does what the PDF asked for —
**design → RTL → testbench → simulation/waveforms → synthesis → performance →
comparison → report** — and show that you understand it.

## Before recording

- Close other apps and notifications (Focus mode → Do Not Disturb).
- Terminal: big font (Cmd + several times), `cd` into `rv32i_single_cycle`.
- Open in advance: the slides (`docs/presentation/RV32I_Presentation.pptx`),
  VS Code (or any editor) on the `rtl/` folder, the report PDF.
- Run `./scripts/run_all.sh` once beforehand so `sim/*.vcd` files exist.
- Record with **Cmd + Shift + 5** (macOS screen recorder, choose "Options →
  Microphone") or QuickTime → File → New Screen Recording. OBS Studio if you
  want your face in a corner.
- Record scene by scene; join the clips afterwards in iMovie / CapCut.

---

## Scene 1 – Introduction (≈ 45 s) · show: title slide

> "Hello, I am [name], [roll no.]. My project is Project 1 from the Modern
> Computer Architecture list: a single-cycle RV32I processor in Verilog. The
> task was to design and verify a RISC-V CPU that runs ten instructions — ADD,
> SUB, AND, OR, XOR, ADDI, LW, SW, BEQ and BNE — then synthesize it and measure
> its performance."

Show slide 2 (the ten instructions) briefly.

## Scene 2 – What I had to do (≈ 45 s) · show: the PDF page of Project 1, then README checklist

> "The project document asked for these modules, a testbench, test programs,
> waveforms, a synthesis report, a performance metric, a comparison with a
> baseline and a final report. This table shows where each one is in my
> project."

Scroll the "Deliverables checklist" table in `README.md`.

## Scene 3 – Architecture (≈ 1.5 min) · show: datapath slide (slide 4)

Point with the mouse while explaining one instruction, e.g. **LW**:

> "The PC gives the address to instruction memory. The control unit decodes
> the opcode. The register file reads rs1, the immediate generator makes the
> offset, and the ALU adds them to get the address. Data memory is read and
> the write-back MUX writes the value into rd. Everything happens in one clock
> cycle, so CPI is one."

Then slide 6 (control truth table): explain one row.

## Scene 4 – The Verilog code (≈ 1.5 min) · show: editor

Open, in this order, and spend ~15 s on each:

1. `rtl/rv32i_cpu.v` – "the top level connects all modules" (scroll the instantiations).
2. `rtl/control_unit.v` – the case statement for opcodes.
3. `rtl/alu.v` – five operations and the zero flag.
4. `rtl/reg_file.v` – two read ports, one write port, x0 is always zero.
5. `programs/full_test.s` – "a test program in assembly; my assembler turns it into machine code".

## Scene 5 – Simulation and verification (≈ 2 min) · show: terminal

Run the demo script (it pauses between steps so you can talk):

```bash
./scripts/demo.sh
```

Step 1 – all tests:
> "This runs four unit testbenches and seven programs. The testbench compares
> every register, all of memory, the final PC and instruction count with a
> Python reference model. Everything says PASS."

Step 2 – one program's output:
> "Here is the final register file for the full test: a0 is 62, which is the
> expected answer. CPI is exactly one."

Step 3 – mutation test:
> "To prove the testbench really finds bugs, I inserted twelve deliberate bugs
> into copies of the design. The testbench caught all twelve."

## Scene 6 – Waveforms (≈ 1.5 min) · show: Surfer

The demo script opens `surfer sim/cpu_full_test.vcd`. Add signals:
`clk, pc, instr, reg_write, mem_read, mem_write, branch, pc_src, alu_result,
wb_data` (in `tb_rv32i_cpu → dut`). Zoom so 10–15 cycles are visible.

> "Each clock cycle is one instruction. Here is an LW: MemRead goes high and
> the loaded value appears on the write-back bus. Here is a BNE that is taken:
> PCSrc is one and the PC jumps back to the start of the loop."

(If Surfer is awkward on camera, show slides 11–12 instead – same waveforms.)

## Scene 7 – Synthesis and performance (≈ 1.5 min) · show: terminal + slides 7, 13, 14

Optionally run `./scripts/synth.sh` (takes about a minute – you can cut the wait).

> "Synthesis for the Artix-7 on the Basys-3 board uses about 638 LUTs, only 3%
> of the chip. After place and route on a Lattice ECP5 the maximum frequency is
> 44.4 MHz. The critical path is the load instruction — 22.5 ns — because it
> passes through both memories."

Slide 14:
> "Compared with a multi-cycle design, my single-cycle CPU is 1.02 to 1.27
> times faster on these programs. A pipeline, which is Project 3, would be the
> next improvement."

## Scene 8 – Report and conclusion (≈ 45 s) · show: report PDF, then conclusion slide

Scroll quickly through the report (contents, block diagram, results tables).

> "All of this is documented in the report. In conclusion, the processor runs
> all ten instructions correctly, is fully verified, small and runs at 44 MHz.
> Thank you."

---

## Checklist – the video must show

- [ ] Your name / project title
- [ ] The 10 instructions and the block diagram
- [ ] Verilog code of the main modules
- [ ] Test programs
- [ ] Tests running and printing PASS
- [ ] Waveforms with at least one LW, SW and branch
- [ ] Synthesis numbers (LUTs, Fmax)
- [ ] One performance metric (CPI / execution time) and the baseline comparison
- [ ] The report

## Tips

- Speak slowly; it is fine to re-record one scene.
- Keep the terminal font large enough to read on a phone.
- Don't read the slides word for word — explain in your own words.
- If you have a Basys-3 board, add a 30 s clip of the LEDs showing 62.
