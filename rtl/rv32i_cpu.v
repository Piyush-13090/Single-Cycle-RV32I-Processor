// ============================================================================
// rv32i_cpu.v - Single-Cycle RV32I Processor (top level)
//
// Every instruction completes in ONE clock cycle (CPI = 1):
//   1. FETCH      : instr = IMEM[PC]
//   2. DECODE     : control unit + register read + immediate generation
//   3. EXECUTE    : ALU computes result / address / comparison
//   4. MEMORY     : LW reads / SW writes data memory
//   5. WRITE-BACK : result written to rd; PC <= PC+4 or branch target
// All of the above is combinational within the cycle; state (PC, registers,
// data memory) is updated together at the next rising clock edge.
//
// Supported instructions: ADD SUB AND OR XOR ADDI LW SW BEQ BNE
// ============================================================================
`default_nettype none
`include "defines.vh"
module rv32i_cpu #(
    parameter IMEM_DEPTH = 256,
    parameter DMEM_DEPTH = 256,
    parameter IMEM_FILE  = "program.hex"
) (
    input  wire        clk,
    input  wire        rst,          // synchronous active-high reset
    input  wire        en,           // clock enable (1 = execute one instr/cycle)
    // ---- debug / observation ports (used by testbench and FPGA top) -------
    output wire [31:0] dbg_pc,
    output wire [31:0] dbg_instr,
    output wire        dbg_reg_write,
    output wire [4:0]  dbg_rd,
    output wire [31:0] dbg_wb_data,
    output wire        dbg_mem_write,
    output wire [31:0] dbg_mem_addr,
    output wire [31:0] dbg_mem_wdata,
    output wire        dbg_illegal
);
    // ------------------------------------------------------------------ wires
    wire [31:0] pc_cur, pc_plus4, pc_branch, pc_next;
    wire [31:0] instr;
    wire [31:0] rs1_data, rs2_data, imm, alu_b, alu_result, mem_rdata, wb_data;
    wire [3:0]  alu_ctrl;
    wire        zero, pc_src;

    // control signals
    wire        reg_write, alu_src, mem_write, mem_read, mem_to_reg, branch, illegal;
    wire [1:0]  alu_op, imm_sel;

    // instruction fields
    wire [6:0]  opcode = instr[6:0];
    wire [4:0]  rd     = instr[11:7];
    wire [2:0]  funct3 = instr[14:12];
    wire [4:0]  rs1    = instr[19:15];
    wire [4:0]  rs2    = instr[24:20];
    wire [6:0]  funct7 = instr[31:25];

    // ================================================================ FETCH
    pc u_pc (
        .clk(clk), .rst(rst), .en(en),
        .next_pc(pc_next), .pc(pc_cur)
    );

    instr_mem #(.DEPTH(IMEM_DEPTH), .INIT_FILE(IMEM_FILE)) u_imem (
        .addr(pc_cur), .instr(instr)
    );

    adder u_pc_plus4 (.a(pc_cur), .b(32'd4), .y(pc_plus4));

    // =============================================================== DECODE
    control_unit u_ctrl (
        .opcode(opcode), .funct3(funct3), .funct7(funct7),
        .reg_write(reg_write), .alu_src(alu_src), .mem_write(mem_write),
        .mem_read(mem_read), .mem_to_reg(mem_to_reg), .branch(branch),
        .alu_op(alu_op), .imm_sel(imm_sel), .illegal(illegal)
    );

    reg_file u_rf (
        .clk(clk), .we(reg_write & en),
        .rs1_addr(rs1), .rs2_addr(rs2), .rd_addr(rd),
        .rd_data(wb_data),
        .rs1_data(rs1_data), .rs2_data(rs2_data)
    );

    imm_gen u_immgen (.instr(instr), .imm_sel(imm_sel), .imm(imm));

    // ============================================================== EXECUTE
    alu_control u_aluctrl (
        .alu_op(alu_op), .funct3(funct3), .funct7_b5(instr[30]),
        .alu_ctrl(alu_ctrl)
    );

    mux2 #(32) u_alusrc_mux (.d0(rs2_data), .d1(imm), .sel(alu_src), .y(alu_b));

    alu u_alu (
        .a(rs1_data), .b(alu_b), .alu_ctrl(alu_ctrl),
        .result(alu_result), .zero(zero)
    );

    adder u_branch_adder (.a(pc_cur), .b(imm), .y(pc_branch));

    branch_unit u_branch (
        .branch(branch), .funct3(funct3), .zero(zero), .pc_src(pc_src)
    );

    // =============================================================== MEMORY
    data_mem #(.DEPTH(DMEM_DEPTH)) u_dmem (
        .clk(clk), .we(mem_write & en), .re(mem_read),
        .addr(alu_result), .wdata(rs2_data), .rdata(mem_rdata)
    );

    // =========================================================== WRITE-BACK
    mux2 #(32) u_wb_mux (.d0(alu_result), .d1(mem_rdata), .sel(mem_to_reg), .y(wb_data));

    mux2 #(32) u_pc_mux (.d0(pc_plus4), .d1(pc_branch), .sel(pc_src), .y(pc_next));

    // ================================================================ debug
    assign dbg_pc        = pc_cur;
    assign dbg_instr     = instr;
    assign dbg_reg_write = reg_write & en;
    assign dbg_rd        = rd;
    assign dbg_wb_data   = wb_data;
    assign dbg_mem_write = mem_write & en;
    assign dbg_mem_addr  = alu_result;
    assign dbg_mem_wdata = rs2_data;
    assign dbg_illegal   = illegal;
endmodule
`default_nettype wire
