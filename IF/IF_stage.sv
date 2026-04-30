////////
// The IF stage of the architecture
//  - Fetches instruction from memory
//  - Handles PC updates (Branch, Next, Stall)
//  - Shadow buffer only used with synchronous BRAM (MEM_DEBUG); not needed
//    for external bus modes where inst_mem_dout is already a register.
///////
import riscv_pkg::*;
module IF_stage #(
    parameter ADDR_WIDTH = 32,
    parameter INST_WIDTH = 32              // for RV32I
)(
    input  logic                  clk,
    input  logic                  resetn,

    input  logic [ADDR_WIDTH-1:0] i_branch_addr,   // branch target
    input  logic                  i_branch_inst,   // branch/jump taken (1-cycle pulse)

    input  logic                  i_pipeline_stall,

`ifdef MEM_WISHBONE
    output logic                  o_ibus_cyc,
    output logic                  o_ibus_stb,
    output logic [ADDR_WIDTH-1:0] o_ibus_adr,
    input  logic [INST_WIDTH-1:0] i_ibus_dat,
    input  logic                  i_ibus_ack,
    output logic                  o_imem_stall,
`elsif MEM_AXI4LITE
    output logic [ADDR_WIDTH-1:0] o_ibus_araddr,
    output logic                  o_ibus_arvalid,
    input  logic                  i_ibus_arready,
    input  logic [INST_WIDTH-1:0] i_ibus_rdata,
    input  logic [1:0]            i_ibus_rresp,
    input  logic                  i_ibus_rvalid,
    output logic                  o_ibus_rready,
    output logic                  o_imem_stall,
`endif

    output logic [ADDR_WIDTH-1:0] o_address,       // PC associated with o_instruction
    output logic [INST_WIDTH-1:0] o_instruction    // instruction at o_address
);

    logic [ADDR_WIDTH-1:0] pc_reg;
    logic [ADDR_WIDTH-1:0] pc_id_pc;
    logic [INST_WIDTH-1:0] inst_mem_dout;

    // ---------------------------------------------------------
    // Memory interface
    // ---------------------------------------------------------

`ifdef MEM_WISHBONE
    logic wb_ibus_pending;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            wb_ibus_pending <= 1'b0;
            inst_mem_dout   <= INST_NOP;
        end else begin
            if (wb_ibus_pending && i_ibus_ack) begin
                inst_mem_dout   <= i_ibus_dat;
                wb_ibus_pending <= 1'b0;
            end else if (!wb_ibus_pending && !i_pipeline_stall) begin
                wb_ibus_pending <= 1'b1;
            end
        end
    end

    assign o_ibus_cyc   = wb_ibus_pending;
    assign o_ibus_stb   = wb_ibus_pending;
    assign o_ibus_adr   = pc_reg;
    assign o_imem_stall = wb_ibus_pending && !i_ibus_ack;

`elsif MEM_AXI4LITE
    typedef enum logic [1:0] {
        AXI_IDLE   = 2'b00,
        AXI_ARWAIT = 2'b01,
        AXI_RWAIT  = 2'b10
    } axi_ibus_state_t;
    axi_ibus_state_t axi_state;

    // Set when a branch arrives while an AXI fetch is in-flight; the in-flight
    // result is stale and must be discarded when it arrives.
    logic branch_pending;

    // One-shot flag: holds the pipeline stalled for 1 cycle after reset so the
    // BRAM output register has time to present valid data before the first AXI
    // read transaction completes.  Without this, the BRAM (read latency = 1)
    // returns its reset-value (0x0) for the very first fetch.
    logic boot_delay;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            axi_state      <= AXI_IDLE;
            inst_mem_dout  <= INST_NOP;
            o_ibus_arvalid <= 1'b0;
            o_ibus_araddr  <= '0;
            o_ibus_rready  <= 1'b0;
            branch_pending <= 1'b0;
            boot_delay     <= 1'b1;
        end else begin
            // Latch any branch that arrives while a fetch is already in-flight.
            if (i_branch_inst && axi_state != AXI_IDLE)
                branch_pending <= 1'b1;

            case (axi_state)
                AXI_IDLE: begin
                    branch_pending <= 1'b0; // clear after completing any stale fetch
                    boot_delay     <= 1'b0; // clear one-shot boot delay
                    if (!i_pipeline_stall) begin
                        // When a branch just fired or was pending, use the branch
                        // address so the fresh fetch goes to the correct target.
                        o_ibus_araddr  <= i_branch_inst ? i_branch_addr : pc_reg;
                        o_ibus_arvalid <= 1'b1;
                        axi_state      <= AXI_ARWAIT;
                    end
                end
                AXI_ARWAIT: begin
                    if (i_ibus_arready) begin
                        o_ibus_arvalid <= 1'b0;
                        o_ibus_rready  <= 1'b1;
                        axi_state      <= AXI_RWAIT;
                    end
                end
                AXI_RWAIT: begin
                    if (i_ibus_rvalid) begin
                        // Discard the result if a branch redirected the PC while
                        // this transaction was in flight.
                        inst_mem_dout <= (branch_pending || i_branch_inst)
                                         ? INST_NOP : i_ibus_rdata;
                        o_ibus_rready <= 1'b0;
                        axi_state     <= AXI_IDLE;
                    end
                end
            endcase
        end
    end

    // Also stall during boot_delay so the PC and pipeline registers don't
    // advance before the first fetch is actually launched.
    assign o_imem_stall = (axi_state != AXI_IDLE) || boot_delay;

`elsif MEM_DEBUG
    `ifdef RISCV_FORMAL
        (* anyseq *) logic [INST_WIDTH-1:0] inst_mem_dout_free;
        assign inst_mem_dout = inst_mem_dout_free;
    `else
        imem imem (
            .clka  (clk),
            .reseta(resetn),
            .addra (pc_reg),
            .douta (inst_mem_dout)
        );
    `endif

`else
    // Default: formal free-variable mode
    (* anyseq *) logic [INST_WIDTH-1:0] inst_mem_dout_free;
    assign inst_mem_dout = inst_mem_dout_free;
`endif

    // ---------------------------------------------------------
    // Instruction output mux
    // Bus modes: inst_mem_dout is a register, valid after ACK — no shadow buffer.
    // BRAM/formal modes: shadow buffer compensates for 1-cycle BRAM read latency.
    // ---------------------------------------------------------

`ifdef MEM_WISHBONE
    always_comb begin
        if (i_branch_inst) begin
            o_address     = '0;
            o_instruction = INST_NOP;
        end else begin
            o_instruction = inst_mem_dout;
            o_address     = pc_id_pc;
        end
    end
`elsif MEM_AXI4LITE
    always_comb begin
        if (i_branch_inst || branch_pending) begin
            o_address     = '0;
            o_instruction = INST_NOP;
        end else begin
            o_instruction = inst_mem_dout;
            o_address     = pc_id_pc;
        end
    end
`else
    logic [INST_WIDTH-1:0] stall_inst_buffer;
    logic                  stall_active_prev;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            stall_inst_buffer <= INST_NOP;
            stall_active_prev <= 1'b0;
        end else begin
            if (i_pipeline_stall && !stall_active_prev)
                stall_inst_buffer <= inst_mem_dout;
            stall_active_prev <= i_pipeline_stall;
        end
    end

    always_comb begin
        if (i_branch_inst) begin
            o_address     = '0;
            o_instruction = INST_NOP;
        end else if (stall_active_prev) begin
            o_instruction = stall_inst_buffer;
            o_address     = pc_id_pc;
        end else begin
            o_instruction = inst_mem_dout;
            o_address     = pc_id_pc;
        end
    end
`endif

    // ---------------------------------------------------------
    // PC update
    // ---------------------------------------------------------
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            pc_reg   <= '0;
            pc_id_pc <= '0;
        end else begin
`ifdef MEM_AXI4LITE
            // Branch always wins over stall: a branch arriving while an AXI
            // fetch is in-flight must still update pc_reg so that after the
            // stale fetch completes the next request goes to the right target.
            if (i_branch_inst) begin
                pc_reg <= i_branch_addr;
            end else if (!i_pipeline_stall) begin
                pc_id_pc <= pc_reg;
                pc_reg   <= pc_reg + 32'd4;
            end
`else
            if (i_pipeline_stall) begin
                pc_reg   <= pc_reg;
                pc_id_pc <= pc_id_pc;
            end else begin
                pc_id_pc <= pc_reg;
                if (i_branch_inst)
                    pc_reg <= i_branch_addr;
                else
                    pc_reg <= pc_reg + 32'd4;
            end
`endif
        end
    end

endmodule
