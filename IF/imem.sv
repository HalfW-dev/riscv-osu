// -------------------------------------------------------------
// Instruction Memory (IMEM) for RV32I
//  - Ports match IF_stage instantiation:
//      .clka  (clk)
//      .addra (pc_value)      // byte address from PC
//      .douta (inst_mem_dout) // 32-bit instruction
//  - Word-aligned: uses addra[ADDR_WIDTH-1:2] as index
//  - Synchronous read (1-cycle latency)
//  - Contents loaded from inst_mem.hex using $readmemh
// -------------------------------------------------------------
// module imem #(
//     parameter ADDR_WIDTH = 32,   // width of PC/address
//     parameter INST_WIDTH = 32,   // 32-bit RV32I instructions
//     //parameter MEM_DEPTH  = 1 << (ADDR_WIDTH-2) // number of 32-bit words
//     parameter MEM_DEPTH = 256
// )(
//     input  logic                   clka,
//     input  logic                   reseta,
//     input  logic [ADDR_WIDTH-1:0]  addra,   // byte address from IF_stage
//     output logic [INST_WIDTH-1:0]  douta
// );

//     // 32-bit wide instruction memory
//     logic [INST_WIDTH-1:0] mem [0:MEM_DEPTH-1];
//     logic just_reset;

//     // ---------------------------------------------------------
//     // Initialize memory from a hex file
//     // ---------------------------------------------------------
//     initial begin
//         // One 32-bit word per line, hex, no "0x" prefix
//         // Example file name; change to whatever you like
//         $readmemh("B:/dev/project/riscv/IF/inst_mem.hex", mem);
//     end

//     // ---------------------------------------------------------
//     // Synchronous read (like a block RAM)
//     // ---------------------------------------------------------
//     always_ff @(posedge clka or negedge reseta) begin
//         // Word-aligned: ignore lowest 2 bits of byte address
//         if(!reseta) douta <= '0;
//         else        douta <= mem[addra[ADDR_WIDTH-1:2]];
//     end

// endmodule

module imem (
    input  logic        clka,
    input  logic        reseta, // Usually unused in SRAM, but kept for your port map
    input  logic [31:0] addra,
    output logic [31:0] douta
);

    // 32 words x 32 bits = 128 Bytes
    logic [31:0] mem [0:31];

    // Word-aligned address indexing (bits 6 down to 2)
    wire [4:0] word_addr = addra[6:2];

    always_ff @(posedge clka) begin
        // Synchronous read
        douta <= mem[word_addr];
    end

endmodule
