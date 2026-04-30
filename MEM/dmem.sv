// -------------------------------------------------------------
// RISC-V Data Memory
//  - Standard Von Neumann / Harvard split (this is the Data side)
//  - Word-aligned internal storage (logic [31:0] mem [...])
//  - Supports Byte masking for sb/sh/sw instructions
//  - Combinational Read, Synchronous Write
// -------------------------------------------------------------
// module dmem #(
//     parameter DATA_WIDTH = 32,
//     parameter SIZE_IN_BYTES = 1024, // Total size in bytes
//     parameter ADDR_WIDTH = 32       // System Address Width
// )(
//     input  logic                  clk,
    
//     // Memory Interface
//     input  logic                  i_mem_ena,   // Chip Select / Enable
//     input  logic                  i_mem_write, // Write Enable (1=Write, 0=Read)
//     input  logic [3:0]            i_byte_sel,  // Byte Strobe/Mask (Critical for sb/sh)
    
//     input  logic [ADDR_WIDTH-1:0] i_addr,      // Byte address
//     input  logic [DATA_WIDTH-1:0] i_wdata,     // Write Data
    
//     output logic [DATA_WIDTH-1:0] o_rdata      // Read Data
// );

//     localparam NUM_WORDS = SIZE_IN_BYTES / 4;

//     logic [31:0] mem [0:NUM_WORDS-1];

//     //drop the bottom 2 bits because i_addr is a byte address
//     logic [$clog2(NUM_WORDS)-1:0] word_addr;
    
//     assign word_addr = i_addr[$clog2(NUM_WORDS)+1 : 2];

//     initial begin
//         $readmemh("B:/dev/project/riscv/MEM/dmem_init.hex", mem);
//     end

//     // Synchronous Write with Byte Masking
//     always_ff @(posedge clk) begin
//         if (i_mem_ena && i_mem_write) begin
//             // Byte 0 (Bits 7:0)
//             if (i_byte_sel[0]) 
//                 mem[word_addr][7:0]   <= i_wdata[7:0];

//             // Byte 1 (Bits 15:8)
//             if (i_byte_sel[1]) 
//                 mem[word_addr][15:8]  <= i_wdata[15:8];

//             // Byte 2 (Bits 23:16)
//             if (i_byte_sel[2]) 
//                 mem[word_addr][23:16] <= i_wdata[23:16];

//             // Byte 3 (Bits 31:24)
//             if (i_byte_sel[3]) 
//                 mem[word_addr][31:24] <= i_wdata[31:24];
//         end
//     end

//     // ---------------------------------------------------------
//     // Combinational Read
//     // Returns the full 32-bit word. The Load/Store Unit (LSU)
//     // or WB stage logic must handle Sign Extension (lb/lh)
//     // ---------------------------------------------------------
//     always_comb begin
//         if (i_mem_ena && !i_mem_write) begin
//             o_rdata = mem[word_addr];
//         end else begin
//             o_rdata = '0; // Optional: output 0 or 'x when not reading
//         end
//     end

// endmodule

////////
// Tiny Data Memory (128 Bytes)
// Safe for OpenLane standard-cell synthesis
///////

module dmem (
    input  logic        clk,
    input  logic        i_mem_ena,
    input  logic        i_mem_write,
    input  logic [3:0]  i_byte_sel,
    input  logic [31:0] i_addr,
    input  logic [31:0] i_wdata,
    output logic [31:0] o_rdata
);

    // 32 words x 32 bits = 128 Bytes
    logic [31:0] mem [0:31];

    // Word-aligned address indexing (bits 6 down to 2)
    wire [4:0] word_addr = i_addr[6:2];

    always_ff @(posedge clk) begin
        if (i_mem_ena) begin
            if (i_mem_write) begin
                // Byte-enable masking
                if (i_byte_sel[0]) mem[word_addr][7:0]   <= i_wdata[7:0];
                if (i_byte_sel[1]) mem[word_addr][15:8]  <= i_wdata[15:8];
                if (i_byte_sel[2]) mem[word_addr][23:16] <= i_wdata[23:16];
                if (i_byte_sel[3]) mem[word_addr][31:24] <= i_wdata[31:24];
            end
            
            // Synchronous read (always outputs requested address if enabled)
            o_rdata <= mem[word_addr];
        end
    end

endmodule