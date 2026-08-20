# riscv-osu
A formally verified 5-stage pipelined RISC-V core written in SystemVerilog, offering AXI4-Lite interface for external memory modules.

# Features
- Supports RV32I
- Instruction memory and Data Memory can be declared as SystemVerilog arrays or AXI4-Lite interfaces.
- Formally verified with riscv-formal (for both SystemVerilog arrays version and AXI4-Lite version).

# File Components
## Global files
- `topmodule_RISCV.sv`: The top module that represents the core.
- `riscv_core.v`: The Verilog wrapper for the core to be synthesized and implemented in tools such as Vivado or OpenLane. Customized so that the tools do not wipe out the core for the sake of optimization.
- `riscv_pkg.sv`: Contains essential RISC-V parameters for seamless customization and better code clarity.
- `core_config.svh`: Contains header for customization in RVFI signals definition or memory mode (DEBUG or AXI4_LITE)

## Top Module Level files
- `cu.sv`: The control unit.
- `forward.sv`: For resolving the Read After Write (RAW) hazard.
- `hazard_unit.sv`: For resolving Load-use hazard.

## IF files
- `IF_stage.sv`: Represents the IF stage.
- `imem.sv`: The Instruction Memory (DEBUG mode only).

## ID files
- `ID_stage.sv`: Represents the ID stage.
- `regfile.sv`: The register file.
- `immgen.sv`: The immediate generator.
- `regfile_init.hex`: Holds initial values for the register file.

## EX files
- `EX_stage.sv`: Represents the EX stage.
- `alu.sv`: The Arithmetic Logic Unit (ALU).
- `branch.sv`: Dispatch the branch taken signal when conditions are met.

## MEM files
- `MEM_stage.sv`: Represents the MEM stage.
- `dmem.sv`: The Data Memory (DEBUG mode only).
- `dmem_init.hex`: Holds initial values for the Data Memory.

## WB files
- `WB_stage.sv`: Represents the WB stage.

## sw folder
Contains 2 test programs (Swap and Bubble Sort) for initial testing.

## Script files
- `run_formal.sh`: Run the formal verification suite in DEBUG mode.
- `run_formal_axi.sh`: Run the formal verification suite in AXI4_LITE mode.

# What can you do with this repo?
You can do anything with this repo per the MIT License.

If you trust my work, you can start using it right away.

If you are still skeptical, you can rerun the formal verification scripts to be sure.

# Technicality Notes

- Remember to use `riscv_core.v` when working with EDA tools. The file exposes some outputs that purely serves the purpose of the core not being optimized away. Without the outputs, the EDA tools will think that the core does not do anything and will delete the core in synthesis and implementation.
- In AXI4_LITE mode, there is a 1-cycle delay for the first IMEM address (0x0). This is done because Vivado's AXI BRAM Controllers return stale data on the first cycle after reset. Adjust accordingly if you are using this design outside of Vivado, or using a read delay with a value other than 1.

# To be done
- Wishbone bus for memory.
- RV32M and F.
- Dynamic Branch Prediction.
- Cache.
- A RISC-V tutorial based on this work for beginners.
