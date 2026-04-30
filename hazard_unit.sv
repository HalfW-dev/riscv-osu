module hazard_unit (
    input  logic [4:0] i_rs1_id,
    input  logic [4:0] i_rs2_id,
    input  logic [4:0] i_rd_ex,
    input  logic       i_mem_read_ex,
    output logic       o_stall
);
    always_comb begin
        if (i_mem_read_ex && (i_rd_ex != 0) && 
           ((i_rd_ex == i_rs1_id) || (i_rd_ex == i_rs2_id))) 
            o_stall = 1'b1;
        else 
            o_stall = 1'b0;
    end
endmodule