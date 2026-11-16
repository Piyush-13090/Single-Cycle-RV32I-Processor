// ============================================================================
// instr_mem.v - Instruction Memory (read-only, asynchronous read)
// Word-organised ROM. The program is loaded from a hex file with $readmemh
// (one 32-bit instruction per line). The PC is a byte address, so the word
// index is addr[..:2]. Locations not filled by the program read as 0
// (an illegal encoding, which the control unit turns into a NOP).
// ============================================================================
`default_nettype none
module instr_mem #(
    parameter DEPTH     = 256,                 // number of 32-bit words
    parameter INIT_FILE = "program.hex"
) (
    input  wire [31:0] addr,                   // byte address from PC
    output wire [31:0] instr
);
    localparam AW = $clog2(DEPTH);

    reg [31:0] rom [0:DEPTH-1];

    integer i;
    initial begin
`ifndef SYNTHESIS
        // simulation only: clear unused locations so they read as 0, not X.
        // (Skipped in synthesis: some tools give this loop priority over
        //  $readmemh and would build an all-zero ROM.)
        for (i = 0; i < DEPTH; i = i + 1)
            rom[i] = 32'h0000_0000;
`endif
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, rom);
    end

    assign instr = rom[addr[AW+1:2]];
endmodule
`default_nettype wire
