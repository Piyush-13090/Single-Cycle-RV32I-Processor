// ============================================================================
// fpga_top.v - FPGA wrapper for the Single-Cycle RV32I CPU (demo board top)
//
//   clk        : board clock (100 MHz on Basys-3)
//   btn_rst    : push button -> reset (restarts the program)
//   sw_fast    : 1 = run at full clock speed, 0 = slow step (~6 instr/s)
//   sw_show_pc : 0 = LEDs show a0 (x10, the program's result), 1 = LEDs show PC
//   led[15:0]  : 16 LEDs
//
// The program in instruction memory is build/full_test.hex, which finishes
// with a0 = 62 (0b0000_0000_0011_1110) on the LEDs.
// ============================================================================
`default_nettype none
module fpga_top #(
    parameter IMEM_FILE = "program.hex",         // synth/program.hex (copied by synth.sh)
    parameter SLOW_BITS = 24                    // 100 MHz / 2^24 = ~6 Hz
) (
    input  wire        clk,
    input  wire        btn_rst,
    input  wire        sw_fast,
    input  wire        sw_show_pc,
    output wire [15:0] led
);
    // ---- reset synchroniser (button is asynchronous) -----------------------
    reg [1:0] rst_sync = 2'b11;
    always @(posedge clk) rst_sync <= {rst_sync[0], btn_rst};
    wire rst = rst_sync[1];

    // ---- slow-step clock enable (no derived clocks) -------------------------
    reg [SLOW_BITS-1:0] div = 0;
    always @(posedge clk) div <= div + 1'b1;
    wire slow_tick = (div == 0);
    wire en = sw_fast | slow_tick;

    // ---- CPU ----------------------------------------------------------------
    wire [31:0] pc, instr, wb_data, mem_addr, mem_wdata;
    wire        reg_write, mem_write, illegal;
    wire [4:0]  rd;

    rv32i_cpu #(.IMEM_DEPTH(256), .DMEM_DEPTH(256), .IMEM_FILE(IMEM_FILE)) u_cpu (
        .clk(clk), .rst(rst), .en(en),
        .dbg_pc(pc), .dbg_instr(instr), .dbg_reg_write(reg_write), .dbg_rd(rd),
        .dbg_wb_data(wb_data), .dbg_mem_write(mem_write), .dbg_mem_addr(mem_addr),
        .dbg_mem_wdata(mem_wdata), .dbg_illegal(illegal)
    );

    // ---- shadow copy of a0 (x10) for display ---------------------------------
    reg [31:0] a0_shadow = 0;
    always @(posedge clk) begin
        if (rst)
            a0_shadow <= 0;
        else if (reg_write && rd == 5'd10)
            a0_shadow <= wb_data;
    end

    assign led = sw_show_pc ? pc[15:0] : a0_shadow[15:0];
endmodule
`default_nettype wire
