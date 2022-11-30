`include "consts.sv"
`include "cpu.sv"
`include "cache.sv"
`include "memory.sv"

module testbench; 
    
    reg clk = 1;
    wire [`ADDR1_BUS_SIZE - 1 : 0] a1;
    wire [`DATA1_BUS_SIZE - 1 : 0] d1;
    wire [`CTR1_BUS_SIZE - 1 : 0] c1;
    wire [`ADDR2_BUS_SIZE - 1 : 0] a2;
    wire [`DATA2_BUS_SIZE - 1 : 0] d2;
    wire [`CTR2_BUS_SIZE - 1 : 0] c2;   
    integer i = 0;
    cpu my_cpu(clk, a1, d1, c1);
    cache my_cache(clk, a1, d1, c1, a2, d2, c2, glob.dump_c, glob.reset);
    memory my_memory(clk, a2, d2, c2, glob.dump_m, glob.reset);

    initial begin
        for (i = 1; i < 12000000; i++) begin
            #1;
            clk = ~clk;
        end
    end

endmodule
