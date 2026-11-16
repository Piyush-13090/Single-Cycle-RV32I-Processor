// ============================================================================
// mux2.v - parameterised 2-to-1 multiplexer
// Used three times in the datapath:
//   * ALU source MUX    : rs2 data  or  immediate
//   * Write-back MUX    : ALU result or data-memory read data
//   * Next-PC MUX       : PC + 4    or  branch target
// ============================================================================
`default_nettype none
module mux2 #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] d0,
    input  wire [WIDTH-1:0] d1,
    input  wire             sel,
    output wire [WIDTH-1:0] y
);
    assign y = sel ? d1 : d0;
endmodule
`default_nettype wire
