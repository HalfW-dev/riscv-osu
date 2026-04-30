import riscv_pkg::*;
module MEM_stage #(
    parameter ADDR_WIDTH = 32,
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter INST_COUNT = 37
)(
    input  logic                   clk,
    input  logic                   resetn,

    input  logic [DATA_WIDTH-1:0]  i_rs1_data,
    input  logic [DATA_WIDTH-1:0]  i_rs2_data,
    input  logic [DATA_WIDTH-1:0]  i_EX_rd_data, // ALU Result (Address)

    input  logic [$clog2(INST_COUNT)-1:0] i_ALUOp,
    input  logic                   i_MemRead,
    input  logic                   i_MemWrite,
    input  logic                   i_RegWrite,
    input  logic                   i_MemToReg,

    output logic [DATA_WIDTH-1:0]  o_EX_rd_data,
    output logic [DATA_WIDTH-1:0]  o_dmem_data,
    output logic                   o_RegWrite,
    output logic                   o_MemToReg

`ifdef MEM_WISHBONE
    , output logic                  o_dbus_cyc,
    output logic                   o_dbus_stb,
    output logic                   o_dbus_we,
    output logic [ADDR_WIDTH-1:0]  o_dbus_adr,
    output logic [DATA_WIDTH-1:0]  o_dbus_dat,
    output logic [3:0]             o_dbus_sel,
    input  logic [DATA_WIDTH-1:0]  i_dbus_dat,
    input  logic                   i_dbus_ack,
    output logic                   o_dmem_stall
`elsif MEM_AXI4LITE
    , output logic [ADDR_WIDTH-1:0] o_dbus_araddr,
    output logic                   o_dbus_arvalid,
    input  logic                   i_dbus_arready,
    input  logic [DATA_WIDTH-1:0]  i_dbus_rdata,
    input  logic [1:0]             i_dbus_rresp,
    input  logic                   i_dbus_rvalid,
    output logic                   o_dbus_rready,
    output logic [ADDR_WIDTH-1:0]  o_dbus_awaddr,
    output logic                   o_dbus_awvalid,
    input  logic                   i_dbus_awready,
    output logic [DATA_WIDTH-1:0]  o_dbus_wdata,
    output logic [3:0]             o_dbus_wstrb,
    output logic                   o_dbus_wvalid,
    input  logic                   i_dbus_wready,
    input  logic [1:0]             i_dbus_bresp,
    input  logic                   i_dbus_bvalid,
    output logic                   o_dbus_bready,
    output logic                   o_dmem_stall,
    // Needed to hold dmem_req_done high while a concurrent IMEM stall
    // prevents the pipeline from advancing past the completed transaction.
    input  logic                   i_imem_stall
`endif

`ifdef RISCV_FORMAL
    , output logic [DATA_WIDTH-1:0] o_dmem_rdata_raw
`endif
);

    logic dmem_ena;
    logic dmem_write;
    logic [3:0] dmem_byte_sel;
    logic [ADDR_WIDTH-1:0] dmem_address;
    logic [DATA_WIDTH-1:0] dmem_wdata;
    logic [DATA_WIDTH-1:0] dmem_rdata;

    logic [1:0] byte_offset;
    logic [7:0] extracted_byte;
    logic [15:0] extracted_half;

    assign o_MemToReg = i_MemToReg;
    assign o_RegWrite = i_RegWrite;
    assign o_EX_rd_data = i_EX_rd_data;

    // -----------------------------------------------------------------
    // 1. Address Calculation
    // -----------------------------------------------------------------
    always_comb begin
        if (i_ALUOp >= ALUOP_MEM_FIRST && i_ALUOp <= ALUOP_MEM_LAST)
            dmem_address = i_EX_rd_data;
        else
            dmem_address = '0;
    end

    assign byte_offset = dmem_address[1:0];

    // -----------------------------------------------------------------
    // 2. LSU Logic
    // -----------------------------------------------------------------
    always_comb begin : LSU
        dmem_ena      = 1'b0;
        dmem_write    = 1'b0;
        dmem_byte_sel = 4'b0000;
        dmem_wdata    = 32'b0;
        o_dmem_data   = 32'b0;

        extracted_byte = dmem_rdata[(byte_offset*8) +: 8];
        extracted_half = dmem_rdata[(byte_offset*8) +: 16];

        if (i_ALUOp >= ALUOP_MEM_FIRST && i_ALUOp <= ALUOP_MEM_LAST) begin
            dmem_ena = 1'b1;

            if (i_ALUOp <= ALUOP_LOAD_LAST) begin
                dmem_write = 1'b0;
                case (i_ALUOp)
                    ALUOP_LB:  o_dmem_data = {{24{extracted_byte[7]}}, extracted_byte};
                    ALUOP_LH:  o_dmem_data = {{16{extracted_half[15]}}, extracted_half};
                    ALUOP_LW:  o_dmem_data = dmem_rdata;
                    ALUOP_LBU: o_dmem_data = {24'b0, extracted_byte};
                    ALUOP_LHU: o_dmem_data = {16'b0, extracted_half};
                    default:   o_dmem_data = 32'b0;
                endcase
            end else begin
                dmem_write = 1'b1;
                case (i_ALUOp)
                    ALUOP_SB: begin
                        dmem_wdata    = i_rs2_data << (byte_offset * 8);
                        dmem_byte_sel = 4'b0001 << byte_offset;
                    end
                    ALUOP_SH: begin
                        dmem_wdata    = i_rs2_data << (byte_offset * 8);
                        dmem_byte_sel = 4'b0011 << byte_offset;
                    end
                    ALUOP_SW: begin
                        dmem_wdata    = i_rs2_data;
                        dmem_byte_sel = 4'b1111;
                    end
                    default: dmem_byte_sel = 4'b0000;
                endcase
            end
        end
    end

    // -----------------------------------------------------------------
    // 3. Data memory interface
    // -----------------------------------------------------------------

`ifdef MEM_WISHBONE
    logic wb_dbus_pending;
    logic wb_dbus_is_write;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            wb_dbus_pending  <= 1'b0;
            wb_dbus_is_write <= 1'b0;
            dmem_rdata       <= '0;
        end else begin
            if (wb_dbus_pending && i_dbus_ack) begin
                if (!wb_dbus_is_write)
                    dmem_rdata <= i_dbus_dat;
                wb_dbus_pending <= 1'b0;
            end else if (!wb_dbus_pending && dmem_ena) begin
                wb_dbus_pending  <= 1'b1;
                wb_dbus_is_write <= dmem_write;
            end
        end
    end

    assign o_dbus_cyc   = wb_dbus_pending;
    assign o_dbus_stb   = wb_dbus_pending;
    assign o_dbus_we    = wb_dbus_is_write;
    assign o_dbus_adr   = dmem_address;
    assign o_dbus_dat   = dmem_wdata;
    assign o_dbus_sel   = dmem_byte_sel;
    assign o_dmem_stall = wb_dbus_pending && !i_dbus_ack;

`elsif MEM_AXI4LITE
    typedef enum logic [2:0] {
        AXI_IDLE   = 3'b000,
        AXI_ARWAIT = 3'b001,
        AXI_RWAIT  = 3'b010,
        AXI_AWWWAIT = 3'b011,
        AXI_BWAIT  = 3'b100
    } axi_dbus_state_t;
    axi_dbus_state_t axi_dbus_state;

    // Pulses high for one cycle after an AXI transaction completes, then
    // clears only when the pipeline is actually able to advance (i.e. no
    // concurrent IMEM stall).  This prevents back-to-back memory ops from
    // re-launching a second AXI transaction before EXMEM has moved on.
    logic dmem_req_done;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            axi_dbus_state  <= AXI_IDLE;
            dmem_rdata      <= '0;
            dmem_req_done   <= 1'b0;
            o_dbus_arvalid  <= 1'b0;
            o_dbus_araddr   <= '0;
            o_dbus_rready   <= 1'b0;
            o_dbus_awvalid  <= 1'b0;
            o_dbus_awaddr   <= '0;
            o_dbus_wvalid   <= 1'b0;
            o_dbus_wdata    <= '0;
            o_dbus_wstrb    <= '0;
            o_dbus_bready   <= 1'b0;
        end else begin
            // Clear req_done only when the pipeline can actually advance so
            // EXMEM truly holds a new instruction the next cycle.
            // While an IMEM stall keeps everything frozen, hold req_done
            // high to suppress a spurious re-launch of the same transaction.
            if (axi_dbus_state == AXI_IDLE && !i_imem_stall)
                dmem_req_done <= 1'b0;

            case (axi_dbus_state)
                AXI_IDLE: begin
                    // Guard prevents re-launching while EXMEM is still
                    // frozen with the just-completed instruction.
                    if (dmem_ena && !dmem_write && !dmem_req_done) begin
                        o_dbus_araddr  <= dmem_address;
                        o_dbus_arvalid <= 1'b1;
                        axi_dbus_state <= AXI_ARWAIT;
                    end else if (dmem_ena && dmem_write && !dmem_req_done) begin
                        o_dbus_awaddr  <= dmem_address;
                        o_dbus_awvalid <= 1'b1;
                        o_dbus_wdata   <= dmem_wdata;
                        o_dbus_wstrb   <= dmem_byte_sel;
                        o_dbus_wvalid  <= 1'b1;
                        axi_dbus_state <= AXI_AWWWAIT;
                    end
                end
                AXI_ARWAIT: begin
                    if (i_dbus_arready) begin
                        o_dbus_arvalid <= 1'b0;
                        o_dbus_rready  <= 1'b1;
                        axi_dbus_state <= AXI_RWAIT;
                    end
                end
                AXI_RWAIT: begin
                    if (i_dbus_rvalid) begin
                        dmem_rdata    <= i_dbus_rdata;
                        dmem_req_done <= 1'b1; // overrides the clear above
                        o_dbus_rready <= 1'b0;
                        axi_dbus_state <= AXI_IDLE;
                    end
                end
                AXI_AWWWAIT: begin
                    if (i_dbus_awready) o_dbus_awvalid <= 1'b0;
                    if (i_dbus_wready)  o_dbus_wvalid  <= 1'b0;
                    if ((i_dbus_awready || !o_dbus_awvalid) &&
                        (i_dbus_wready  || !o_dbus_wvalid)) begin
                        o_dbus_bready  <= 1'b1;
                        axi_dbus_state <= AXI_BWAIT;
                    end
                end
                AXI_BWAIT: begin
                    if (i_dbus_bvalid) begin
                        dmem_req_done <= 1'b1; // overrides the clear above
                        o_dbus_bready <= 1'b0;
                        axi_dbus_state <= AXI_IDLE;
                    end
                end
            endcase
        end
    end

    // Stall fires immediately on the first cycle a memory op is in EXMEM
    // (before the AXI state machine can register the transition) and stays
    // high throughout the transaction.  Deasserts the cycle after completion
    // (dmem_req_done=1) so MEMWB can capture the result.
    assign o_dmem_stall = (axi_dbus_state != AXI_IDLE) ||
                          (dmem_ena && !dmem_req_done);

`elsif MEM_DEBUG
    `ifdef RISCV_FORMAL
        (* anyseq *) logic [DATA_WIDTH-1:0] dmem_rdata_free;
        assign dmem_rdata = dmem_rdata_free;
    `else
        dmem dmem_inst (
            .clk(clk),
            .i_mem_ena(dmem_ena),
            .i_mem_write(dmem_write),
            .i_byte_sel(dmem_byte_sel),
            .i_addr(dmem_address),
            .i_wdata(dmem_wdata),
            .o_rdata(dmem_rdata)
        );
    `endif

`else
    // Default: formal free-variable mode
    (* anyseq *) logic [DATA_WIDTH-1:0] dmem_rdata_free;
    assign dmem_rdata = dmem_rdata_free;
`endif

`ifdef RISCV_FORMAL
    assign o_dmem_rdata_raw = dmem_rdata;
`endif

endmodule
