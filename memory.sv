`include "consts.sv"


module memory #(parameter _SEED = 225526) (input clk, input wire [`ADDR2_BUS_SIZE - 1 : 0] a2, inout wire [`DATA2_BUS_SIZE - 1 : 0] d2, inout wire [`CTR2_BUS_SIZE - 1 : 0] c2, input dump_memory, input reset);
    integer SEED = _SEED;
    bit is_owning = 0;
    logic [`BYTE - 1 : 0] mem_data [(1 << `MEM_BYTE_SIZE) - 1 : 0];

    integer addr_to_work_with;

    logic [`CTR2_BUS_SIZE - 1 : 0] last_operation_from_cache = 'z;
    logic [`CTR2_BUS_SIZE - 1 : 0] inner_mem_c2 = 'z;  
    assign c2 = inner_mem_c2;
    logic [`DATA1_BUS_SIZE - 1 : 0] inner_mem_d2 = 'z;
    assign d2 = inner_mem_d2;

    task init_reset_memory;
        //$fdisplay(glob.fl,"Memory reset/init. t=%0t", $time);
        for (int i = 0; i < (1 << `MEM_BYTE_SIZE); i++)
            mem_data[i] = $random(SEED) >> 16;
        for (int i = 0; i < (1 << `MEM_BYTE_SIZE); i++) begin
                //$fdisplay(glob.fl,"[%d] %d", i, mem_data[i]);
        end
        //$fdisplay(glob.fl,"-------------------------------------------------------");
    endtask

    initial begin
        init_reset_memory();
    end

    always@(posedge dump_memory) begin
        $fdisplay(glob.fdm,"Memory dump. t=%0t", $time);
        for (i = 0; i < (1 << `MEM_BYTE_SIZE); i++ ) begin
                $fdisplay(glob.fdm, "[tag = %0d, set = %0d, offset = %0d] %0d", i[`CACHE_SET_SIZE + `CACHE_OFFSET_SIZE +: `CACHE_TAG_SIZE], i[`CACHE_OFFSET_SIZE +: `CACHE_SET_SIZE] ,i[0 +: `CACHE_OFFSET_SIZE], mem_data[i]);  
        end       
        $fdisplay(glob.fdm, "-------------------------------------------------------");
    end

    always@(posedge reset) begin
        init_reset_memory();
    end

    integer i = 0;

    always @(clk) begin
        if (clk == 1 && is_owning == 1) begin
            //$fdisplay(glob.fl,"Memory in deal. t=%0t", $time);              
            inner_mem_c2 = `C2_NOP;
            if (last_operation_from_cache == `C2_READ_LINE) 
                `delay(196,1)
            else if (last_operation_from_cache == `C2_WRITE_LINE)
                `delay(180,1)
            inner_mem_c2 = `C2_RESPONSE;
            if (last_operation_from_cache == `C2_READ_LINE) begin
                for ( i = 0; i < `MEM_LINE_SIZE/`DATA2_BUS_SIZE; i++) begin
                    inner_mem_d2[`BYTE - 1 : 0] = mem_data[addr_to_work_with * (`CACHE_LINE_SIZE / `BYTE) + i*2];
                    inner_mem_d2[2 * `BYTE - 1 : `BYTE] = mem_data[addr_to_work_with * (`CACHE_LINE_SIZE / `BYTE) + i*2 + 1];
                    last_operation_from_cache = c2;
                    //$fdisplay(glob.fl,"Memory giving 16 byte data, part %0d, data = %b. t=%0t", i + 1, mem_data[addr_to_work_with * `CACHE_LINE_SIZE + i*2],$time);
                    if (i != `MEM_LINE_SIZE/`DATA2_BUS_SIZE - 1) 
                        `delay(2,1)
                end
            end
            `delay(2,1)
            //$fdisplay(glob.fl,"Memory gave up. t=%0t", $time);
            inner_mem_d2 = 'z;
            inner_mem_c2 = 'z; 
            is_owning = 0;
        end
        else if (is_owning == 0 && clk == 0) begin
            case (c2)
                `C2_READ_LINE: begin
                    //$fdisplay(glob.fl,"Memory prepared to give out data. t=%0t", $time);
                    addr_to_work_with = a2;
                    last_operation_from_cache = c2;
                    is_owning = 1;
                end 
                `C2_WRITE_LINE: begin
                    for (int i = 0; i <  `MEM_LINE_SIZE/`DATA2_BUS_SIZE; i++) begin
                        //$fdisplay(glob.fl,"Memory writing the 16 byte data, part %0b. t=%0t, d2 = %0b", i + 1,$time, d2);
                        mem_data[a2 * (`CACHE_LINE_SIZE / `BYTE) + i*2] = d2[`BYTE - 1 : 0];
                        mem_data[a2 * (`CACHE_LINE_SIZE / `BYTE) + i*2 + 1] = d2[2 * `BYTE - 1 : `BYTE];
                        last_operation_from_cache = c2;
                        `delay(2,0)
                    end
                    is_owning = 1;
                end 
            endcase
        end
    end

endmodule
