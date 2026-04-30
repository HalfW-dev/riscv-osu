module WB_stage #(
    parameter DATA_WIDTH = 32
)(
    // Inputs from MEM/WB Register
    input  logic [DATA_WIDTH-1:0] i_rd_data,  // (Your 'rd_data')
    input  logic [DATA_WIDTH-1:0] i_dmem_data,   // (Your 'dmem_data')
    input  logic [4:0]            i_rd,     // <--- THE MISSING SIGNAL
    
    // Control Signals
    input  logic                  i_MemToReg,
    input  logic                  i_RegWrite,

    // Outputs to Register File
    output logic                  o_RegWrite,
    output logic [4:0]            o_rd,
    output logic [DATA_WIDTH-1:0] o_rf_write_data
);

    // 1. Pass through the Write Enable and Address
    assign o_RegWrite = i_RegWrite;
    assign o_rd   = i_rd;

    // 2. Select the Data (MUX)
    // If MemToReg is 1, we write Memory Data. Otherwise, ALU Result.
    assign o_rf_write_data = (i_MemToReg) ? i_dmem_data : i_rd_data;

endmodule