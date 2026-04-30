// =============================================================================
// core_config.svh — Build configuration for riscv-osu
// =============================================================================
`ifndef CORE_CONFIG_SVH
`define CORE_CONFIG_SVH
// This file is included by riscv_pkg.sv (the first file in every compile
// order), so defines set here are visible to all RTL files.
//
// When targeting a synthesis toolchain (Vivado, OpenLane, etc.):
//   1. Edit this file to select your memory interface.
//   2. Add ALL .sv source files to your project in the normal way.
//      No extra -D flags are required.
//
// For formal verification: formal/wrapper.sv is compiled first (it appears
// before riscv_pkg.sv in checks.cfg), so RISCV_FORMAL is already defined
// when this file is parsed.  The `ifndef RISCV_FORMAL guard on MEM_AXI4LITE
// (and any other MEM_* define) suppresses them automatically — no manual
// editing required when switching between synthesis and formal runs.
// =============================================================================

// ── Memory interface ──────────────────────────────────────────────────────────
// Uncomment exactly ONE block.

// Internal BRAM (simulation / debug / FPGA with on-chip memory)
//`define MEM_DEBUG

// Wishbone B4 Classic master (o_ibus_*, o_dbus_* ports on topmodule)
//`define MEM_WISHBONE

// AXI4-Lite master (o_ibus_ar/r_*, o_dbus_ar/r/aw/w/b_* ports on topmodule)
// Guard: formal/wrapper.sv defines RISCV_FORMAL before riscv_pkg.sv is parsed,
// so this is suppressed during formal runs (free-variable mode is used instead).
`ifndef RISCV_FORMAL
`define MEM_AXI4LITE
`endif

// ── RISC-V Formal Interface ───────────────────────────────────────────────────
// Adds RVFI output ports to topmodule_RISCV.
// Normally left commented out here — formal/wrapper.sv defines it for the
// formal flow. Enable manually only when you need RVFI outputs in a
// non-formal context (e.g. a simulation testbench that reads RVFI).

//`define RISCV_FORMAL

`endif // CORE_CONFIG_SVH
