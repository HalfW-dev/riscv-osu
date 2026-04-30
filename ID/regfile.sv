// -------------------------------------------------------------
// RV32I Register File
//  - 32 registers x 32-bit
//  - x0 is hardwired to 0
//  - 2 read ports, 1 write port
//  - Combinational reads, synchronous write
// -------------------------------------------------------------
import riscv_pkg::*;
module regfile #(
    parameter DATA_WIDTH = 32,
    parameter NUM_REGS   = 32,
    parameter ADDR_WIDTH = $clog2(NUM_REGS)
)(
    input  logic                   clk,
    input  logic                   resetn,

    // Read port 1
    input  logic [ADDR_WIDTH-1:0]  i_rs1,
    output logic [DATA_WIDTH-1:0]  o_rs1_data,

    // Read port 2
    input  logic [ADDR_WIDTH-1:0]  i_rs2,
    output logic [DATA_WIDTH-1:0]  o_rs2_data,

    // Write port
    input  logic                   i_write_ena,
    input  logic [ADDR_WIDTH-1:0]  i_rd,
    input  logic [DATA_WIDTH-1:0]  i_rd_data
);

    logic [DATA_WIDTH-1:0] regs [0:NUM_REGS-1];

    //initial begin
    //    $readmemh("B:/dev/project/riscv/ID/regfile_init.hex", regs);
    //    regs[0] = 32'b0;   // enforce x0 = 0 (RV32I rule)
    //end


    // ---------------------------------------------------------
    // Synchronous write (on rising edge), x0 is always 0
    // ---------------------------------------------------------
    integer i;
//always_ff @(posedge clk or negedge resetn) begin
    always_ff @(posedge clk) begin
        if (!resetn) begin
             // Reset all registers to 0 (x0..x31)
             for (i = 0; i < NUM_REGS; i++) begin
                 regs[i] <= '0;
             end
        end else begin
            // Write-back stage: ignore writes to x0 (register 0)
            if (i_write_ena && (i_rd != '0)) begin
                regs[i_rd] <= i_rd_data;
            end else begin
                regs[0] <= '0;
            end
        end
    end

    // ---------------------------------------------------------
    // Combinational reads with simple bypass for same-cycle W/R
    // (Optional but nice to have in a single-cycle/short pipeline)
    // ---------------------------------------------------------
    always_comb begin
        // Read port 1
        if (i_rs1 == '0) begin
            o_rs1_data = '0;
        // UNCOMMENT THESE LINES:
        end else if (i_write_ena && (i_rd == i_rs1)) begin
            o_rs1_data = i_rd_data; // Forwarding (Bypass)
        end else begin
            o_rs1_data = regs[i_rs1];
        end

        // Read port 2
        if (i_rs2 == '0) begin
            o_rs2_data = '0;
        // UNCOMMENT THESE LINES:
        end else if (i_write_ena && (i_rd == i_rs2)) begin
            o_rs2_data = i_rd_data; // Forwarding (Bypass)
        end else begin
            o_rs2_data = regs[i_rs2];
        end
    end

endmodule
