// =============================================================================
// riscv_core.v — Verilog 2001 wrapper for topmodule_RISCV
// =============================================================================
`include "core_config.svh"
// How to use in Vivado
// --------------------
// 1. Add ALL .sv files and core_config.svh to your project as design sources.
// 2. Right-click core_config.svh in the Sources panel and choose
//    "Set as Global Include" — this makes the `define macros available to
//    every file in the project without extra -D flags.
// 3. Add this file as a design source and set it as the top module.
// 4. To switch memory interfaces, edit core_config.svh and re-synthesise.
//
// The AXI4-Lite port names follow the Vivado IP naming convention so that
// the block-design AXI wizard can connect them automatically.
// =============================================================================

module riscv_core #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   resetn,

    // ------------------------------------------------------------------
    // Debug / anchor outputs (connect to ILA probes or leave unconnected)
    // ------------------------------------------------------------------
    output wire [DATA_WIDTH-1:0]  o_dbg_wb_data,
    output wire [4:0]             o_dbg_wb_rd,
    output wire                   o_dbg_wb_regwrite,

    // ------------------------------------------------------------------
    // AXI4-Lite Instruction Bus — Master
    // Write channels are present but permanently driven to 0 so that
    // Vivado recognises this as a complete AXI4-Lite interface and
    // groups it in the Address Editor. The core never issues writes
    // on the instruction bus.
    // ------------------------------------------------------------------
    // Read address channel
    output wire [ADDR_WIDTH-1:0]  m_ibus_araddr,
    output wire                   m_ibus_arvalid,
    input  wire                   m_ibus_arready,
    // Read data channel
    input  wire [31:0]            m_ibus_rdata,
    input  wire [1:0]             m_ibus_rresp,
    input  wire                   m_ibus_rvalid,
    output wire                   m_ibus_rready,
    // Write address channel (tied to 0 — instruction bus never writes)
    output wire [ADDR_WIDTH-1:0]  m_ibus_awaddr,
    output wire                   m_ibus_awvalid,
    input  wire                   m_ibus_awready,
    // Write data channel (tied to 0)
    output wire [31:0]            m_ibus_wdata,
    output wire [3:0]             m_ibus_wstrb,
    output wire                   m_ibus_wvalid,
    input  wire                   m_ibus_wready,
    // Write response channel (tied to 0)
    input  wire [1:0]             m_ibus_bresp,
    input  wire                   m_ibus_bvalid,
    output wire                   m_ibus_bready,

    // ------------------------------------------------------------------
    // AXI4-Lite Data Bus — Master, read + write
    // ------------------------------------------------------------------
    // Read address channel
    output wire [ADDR_WIDTH-1:0]  m_dbus_araddr,
    output wire                   m_dbus_arvalid,
    input  wire                   m_dbus_arready,
    // Read data channel
    input  wire [DATA_WIDTH-1:0]  m_dbus_rdata,
    input  wire [1:0]             m_dbus_rresp,
    input  wire                   m_dbus_rvalid,
    output wire                   m_dbus_rready,
    // Write address channel
    output wire [ADDR_WIDTH-1:0]  m_dbus_awaddr,
    output wire                   m_dbus_awvalid,
    input  wire                   m_dbus_awready,
    // Write data channel
    output wire [DATA_WIDTH-1:0]  m_dbus_wdata,
    output wire [3:0]             m_dbus_wstrb,
    output wire                   m_dbus_wvalid,
    input  wire                   m_dbus_wready,
    // Write response channel
    input  wire [1:0]             m_dbus_bresp,
    input  wire                   m_dbus_bvalid,
    output wire                   m_dbus_bready
);

    topmodule_RISCV #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .INST_WIDTH (32),
        .DATA_WIDTH (DATA_WIDTH),
        .INST_COUNT (37)
    ) core (
        .clk                (clk),
        .resetn             (resetn),

        .o_dbg_wb_data      (o_dbg_wb_data),
        .o_dbg_wb_rd        (o_dbg_wb_rd),
        .o_dbg_wb_regwrite  (o_dbg_wb_regwrite),

        // Instruction bus
        .o_ibus_araddr      (m_ibus_araddr),
        .o_ibus_arvalid     (m_ibus_arvalid),
        .i_ibus_arready     (m_ibus_arready),
        .i_ibus_rdata       (m_ibus_rdata),
        .i_ibus_rresp       (m_ibus_rresp),
        .i_ibus_rvalid      (m_ibus_rvalid),
        .o_ibus_rready      (m_ibus_rready),

        // Data bus
        .o_dbus_araddr      (m_dbus_araddr),
        .o_dbus_arvalid     (m_dbus_arvalid),
        .i_dbus_arready     (m_dbus_arready),
        .i_dbus_rdata       (m_dbus_rdata),
        .i_dbus_rresp       (m_dbus_rresp),
        .i_dbus_rvalid      (m_dbus_rvalid),
        .o_dbus_rready      (m_dbus_rready),
        .o_dbus_awaddr      (m_dbus_awaddr),
        .o_dbus_awvalid     (m_dbus_awvalid),
        .i_dbus_awready     (m_dbus_awready),
        .o_dbus_wdata       (m_dbus_wdata),
        .o_dbus_wstrb       (m_dbus_wstrb),
        .o_dbus_wvalid      (m_dbus_wvalid),
        .i_dbus_wready      (m_dbus_wready),
        .i_dbus_bresp       (m_dbus_bresp),
        .i_dbus_bvalid      (m_dbus_bvalid),
        .o_dbus_bready      (m_dbus_bready)
    );


    // Tie off instruction-bus write channels — core never writes instructions
    assign m_ibus_awaddr  = {ADDR_WIDTH{1'b0}};
    assign m_ibus_awvalid = 1'b0;
    assign m_ibus_wdata   = 32'b0;
    assign m_ibus_wstrb   = 4'b0;
    assign m_ibus_wvalid  = 1'b0;
    assign m_ibus_bready  = 1'b0;

endmodule
