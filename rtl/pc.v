// ============================================================================
// pc.v - Program Counter
// Holds the byte address of the instruction being executed. On every rising
// clock edge (when enabled) it loads next_pc. Reset sends it to address 0.
// ============================================================================
`default_nettype none
module pc #(
    parameter [31:0] RESET_ADDR = 32'h0000_0000
) (
    input  wire        clk,
    input  wire        rst,      // synchronous, active-high
    input  wire        en,       // clock enable (1 = run, 0 = hold)
    input  wire [31:0] next_pc,
    output reg  [31:0] pc
);
    always @(posedge clk) begin
        if (rst)
            pc <= RESET_ADDR;
        else if (en)
            pc <= next_pc;
    end
endmodule
`default_nettype wire
