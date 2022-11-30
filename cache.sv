`include "consts.sv"

module cache(input clk, input wire [`ADDR1_BUS_SIZE - 1 : 0] a1, inout wire [`DATA1_BUS_SIZE - 1 : 0] d1, inout wire [`CTR1_BUS_SIZE - 1 : 0] c1, output wire [`ADDR2_BUS_SIZE - 1 : 0] a2, inout wire [`DATA2_BUS_SIZE - 1 : 0] d2, inout wire [`CTR2_BUS_SIZE - 1 : 0] c2, input dump_cache, input reset);
// CPU side
    bit is_owning_cpu = 0;
    bit last_used [`CACHE_LINE_COUNT/`CACHE_WAY - 1 : 0];
    //V + D + TAG_SIZE + CACHE_LINE_SIZE = 1 + 1 + 10 + 16*8 = 1 + 1 + 10 + 128
    reg [(`V + `D + `TAG_SIZE + `CACHE_LINE_SIZE) - 1 : 0] inner_cache_data [`CACHE_LINE_COUNT/`CACHE_WAY - 1 : 0][`CACHE_WAY - 1 : 0];
    integer i = 0;
    reg[`CACHE_LINE_SIZE/4 - 1 : 0] data1;
    reg[`CACHE_LINE_SIZE/4 - 1 : 0] data2;
    reg[`CACHE_LINE_SIZE/4 - 1 : 0] data3;
    reg[`CACHE_LINE_SIZE/4 - 1 : 0] data4;    

    logic [`CTR1_BUS_SIZE - 1 : 0] last_operation_from_cpu = 'z;
    logic [`CTR1_BUS_SIZE - 1 : 0] inner_cache_c1 = 'z;  
    assign c1 = inner_cache_c1;
    logic [`DATA1_BUS_SIZE - 1 : 0] inner_cache_d1 = 'z;
    assign d1 = inner_cache_d1;

// Memory side
    bit is_owning_memory = 1;
    integer data_from_memory = 'z;
    integer command_for_mem = 0; // команду посылает кэш
    integer finished_query_in_mem = 0; 

    logic [`ADDR2_BUS_SIZE - 1 : 0] inner_cache_a2 = 'z;
    assign a2 = inner_cache_a2;
    logic [`CTR2_BUS_SIZE - 1 : 0] last_operation_for_memory = 'z;
    logic [`CTR2_BUS_SIZE - 1 : 0] inner_cache_c2 = 'z;  
    assign c2 = inner_cache_c2;
    logic [`DATA2_BUS_SIZE - 1 : 0] inner_cache_d2 = 'z;
    assign d2 = inner_cache_d2;

    integer sutable_line = -1;
// Inner data

    reg [`TAG_SIZE - 1 : 0] resived_tag = 'z;
    reg [`SET_SIZE - 1 : 0] resived_set = 'z;
    reg [`TAG_SIZE - 1 : 0] inner_tag = 'z;
    reg inner_v = 'z;
    reg inner_d = 'z;

    reg [`TAG_SIZE + `SET_SIZE - 1 : 0] addr_tagset;
    reg [`OFFSET_SIZE - 1 : 0] addr_offset;
    reg [`CACHE_LINE_SIZE : 0] data_to_read;
    reg [2 * `DATA1_BUS_SIZE : 0] data_to_write;

    task init_reset_cache;
        //$fdisplay(glob.fl,"Cache init/reset. t=%0t", $time);
        for (int l = 0; l < `CACHE_LINE_COUNT/`CACHE_WAY; l++) begin
            for (int j = 0; j < `CACHE_WAY; j++)
                inner_cache_data[l][j] = 0;
            last_used[i] = 0;
        end   
        //$fdisplay(glob.fl,"-------------------------------------------------------");
    endtask

    task dump_cache_task;
        $fdisplay(glob.fdc,"Cache dump. t = %0t", $time);
        for (int l = 0; l < `CACHE_LINE_COUNT/`CACHE_WAY; l++) begin
            for (int j = 0; j < `CACHE_WAY; j++)begin
                inner_tag = inner_cache_data[l][j][(`TAG_SIZE + `CACHE_LINE_SIZE) - 1 : `CACHE_LINE_SIZE];
                inner_v = inner_cache_data[l][j][`D + `TAG_SIZE + `CACHE_LINE_SIZE]; 
                inner_d = inner_cache_data[l][j][`TAG_SIZE + `CACHE_LINE_SIZE];      
                data1 = inner_cache_data[l][j][`CACHE_LINE_SIZE/4 - 1 : 0];
                data2 = inner_cache_data[l][j][`CACHE_LINE_SIZE/2 - 1: `CACHE_LINE_SIZE/4];
                data3 = inner_cache_data[l][j][`CACHE_LINE_SIZE * 3 / 4 - 1 : `CACHE_LINE_SIZE/2];
                data4 = inner_cache_data[l][j][`CACHE_LINE_SIZE - 1 : `CACHE_LINE_SIZE * 3 / 4 ];
 
                $fdisplay(glob.fdc,"[set = %0d][way = %0d]  v = %0d, d = %0d, tag = %0d, data = %0d %0d %0d %0d", l, j, inner_v, inner_d, inner_tag, data4, data3, data2, data1);
            end
            $fdisplay(glob.fdc,"for set: %0d,last used = %0d", l, last_used[l]);
        end
        $fdisplay(glob.fdc, "-------------------------------------------------------");
    endtask

    initial begin
        init_reset_cache();
    end

    task drop_leading;
        //$fdisplay(glob.fl,"Cache gave up. t=%0t", $time);
        inner_cache_d1 = 'z;
        inner_cache_c1 = 'z; 
        is_owning_cpu = 0;
    endtask

    always@(posedge dump_cache) begin
        dump_cache_task();
    end

    always@(posedge reset) begin
        init_reset_cache();
    end

    always @(clk) begin
        if (clk == 1 && is_owning_cpu == 1) begin  
            inner_cache_c1 = `C1_NOP;
            //$fdisplay(glob.fl,"Cache in deal last_op = %b. t=%0t", last_operation_from_cpu, $time);
            if (last_operation_from_cpu == `C1_READ8 || last_operation_from_cpu == `C1_READ16 || last_operation_from_cpu == `C1_READ32 || last_operation_from_cpu == `C1_WRITE8 || last_operation_from_cpu == `C1_WRITE16 || last_operation_from_cpu == `C1_WRITE32) begin
                sutable_line = -1;
                resived_tag = addr_tagset[(`TAG_SIZE + `SET_SIZE) - 1 : `SET_SIZE];
                resived_set = addr_tagset[`SET_SIZE - 1 : 0];
                for (int j = 0; j < `CACHE_WAY; j++) begin
                    inner_tag = inner_cache_data[resived_set][j][(`TAG_SIZE + `CACHE_LINE_SIZE) - 1 : `CACHE_LINE_SIZE];
                    inner_v = inner_cache_data[resived_set][j][`D + `TAG_SIZE + `CACHE_LINE_SIZE];                     
                    if (inner_tag == resived_tag && inner_v == 1) begin
                        `delay(8,1)
                        //$fdisplay(glob.fl,"Cache hit j = %b. t=%0t", j,$time);
                        glob.hits += 1;
                        sutable_line = j;
                        last_used[resived_set] = j;
                    end
                end
                if (sutable_line == -1) begin
                    glob.miss += 1;
                    sutable_line = (last_used[resived_set] + 1) % 2; // отрицание last_used для integer
                    inner_v = inner_cache_data[resived_set][sutable_line][`D + `TAG_SIZE + `CACHE_LINE_SIZE];
                    inner_d = inner_cache_data[resived_set][sutable_line][`TAG_SIZE + `CACHE_LINE_SIZE];
                    //$fdisplay(glob.fl,"Cache miss, valid = %0b, dirty = %0b, set = %b, sutable_line = %b, . t=%0t\n", inner_v,inner_d, resived_set, sutable_line,$time);                   
                    `delay(4,1)
                    if (inner_v == 1 && inner_d == 1) begin
                        finished_query_in_mem = 0;                    
                        command_for_mem = 2;
                        wait(clk == 1 && finished_query_in_mem == 1);
                    end
                    finished_query_in_mem = 0;                    
                    command_for_mem = 1;
                    wait(clk == 1 && finished_query_in_mem == 1);
                    //$fdisplay(glob.fl,"Cache miss finished. t = %0t", $time);
                    inner_cache_data[resived_set][sutable_line][`TAG_SIZE + `CACHE_LINE_SIZE - 1 : `CACHE_LINE_SIZE] = resived_tag;
                    inner_cache_data[resived_set][sutable_line][`TAG_SIZE + `CACHE_LINE_SIZE] = 0; //dirty
                    inner_cache_data[resived_set][sutable_line][`D + `TAG_SIZE + `CACHE_LINE_SIZE] = 1; //valid
                    finished_query_in_mem = 0;
                    last_used[resived_set] = ~last_used[resived_set];

                end
                 if (last_operation_from_cpu == `C1_READ8) begin
                    //$fdisplay(glob.fl,"Cache sent 8 bit data. t=%0t", $time);
                    inner_cache_d1 = inner_cache_data[resived_set][sutable_line][addr_offset*`BYTE +: `BYTE]; 
                    inner_cache_c1 = `C1_RESPONSE;                
                end else if (last_operation_from_cpu == `C1_READ16) begin
                    //$fdisplay(glob.fl,"Cache sent 16 bit data. t=%0t", $time);                    
                    inner_cache_d1 = inner_cache_data[resived_set][sutable_line][addr_offset * `BYTE +: `BYTE * 2];
                    inner_cache_c1 = `C1_RESPONSE;                  
                end else if (last_operation_from_cpu == `C1_READ32) begin 
                    //$fdisplay(glob.fl,"Cache sent 1 pack data = %0b. t=%0t, clk = %0b",inner_cache_data[resived_set][sutable_line][addr_offset*8 +: 16], $time, clk);
                    inner_cache_d1 = inner_cache_data[resived_set][sutable_line][addr_offset*8 +: 16];
                    inner_cache_c1 = `C1_RESPONSE;                      
                    `delay(2,1)     
                    //$fdisplay(glob.fl,"Cache sent 2 pack data = %0b. t=%0t",inner_cache_data[resived_set][sutable_line][addr_offset*8 + 16 +: 16], $time);
                    inner_cache_d1 = inner_cache_data[resived_set][sutable_line][addr_offset*8 + 16 +: 16];
                end else if (last_operation_from_cpu == `C1_WRITE8) begin
                    //$fdisplay(glob.fl,"Cache wrote 8 bit data. t=%0t", $time);
                    inner_cache_data[resived_set][sutable_line][addr_offset*8 +: 8] = data_to_write;
                    inner_cache_data[resived_set][sutable_line][`TAG_SIZE + `CACHE_LINE_SIZE] = 1;    
                    inner_cache_c1 = `C1_RESPONSE;                                   
                end else if (last_operation_from_cpu == `C1_WRITE16) begin
                    //$fdisplay(glob.fl,"Cache wrote 16 bit data. t=%0t", $time);                    
                    inner_cache_data[resived_set][sutable_line][addr_offset*8 +: 16] = data_to_write;
                    inner_cache_data[resived_set][sutable_line][`TAG_SIZE + `CACHE_LINE_SIZE] = 1;
                    inner_cache_c1 = `C1_RESPONSE;   
                end else if (last_operation_from_cpu == `C1_WRITE32) begin 
                    inner_cache_data[resived_set][sutable_line][addr_offset*8 +: 16] = data_to_write[15 : 0];
                    //$fdisplay(glob.fl,"Cache wrote 1 pack data = %0b. t=%0t",inner_cache_data[resived_set][sutable_line][addr_offset*8 +: 16], $time);                         
                    inner_cache_data[resived_set][sutable_line][addr_offset*8 + 16 +: 16] = data_to_write[31 : 16];
                    //$fdisplay(glob.fl,"Cache wrote 2 pack data = %0b. t=%0t",inner_cache_data[resived_set][sutable_line][addr_offset*8 + 16 +: 16], $time);
                    inner_cache_data[resived_set][sutable_line][`TAG_SIZE + `CACHE_LINE_SIZE] = 1;
                    inner_cache_c1 = `C1_RESPONSE;  
                end 
            end else if (last_operation_from_cpu == `C1_INVALIDATE_LINE) begin
                resived_tag = addr_tagset[(`TAG_SIZE + `SET_SIZE) - 1 : `SET_SIZE];
                resived_set = addr_tagset[`SET_SIZE - 1 : 0];
                for (int j = 0; j < `CACHE_WAY; j++) begin
                    inner_tag = inner_cache_data[resived_set][j][(`TAG_SIZE + `CACHE_LINE_SIZE) - 1 : `CACHE_LINE_SIZE];
                    inner_v = inner_cache_data[resived_set][j][`D + `TAG_SIZE + `CACHE_LINE_SIZE];           
                    inner_d = inner_cache_data[resived_set][j][`TAG_SIZE + `CACHE_LINE_SIZE];          
                    if (inner_tag == resived_tag && inner_v == 1) begin
                        //$fdisplay(glob.fl,"Cache found what to invalidate j = %b. t=%0t", j,$time);
                        sutable_line = j;
                        if (inner_d == 1) begin
                            //$fdisplay(glob.fl,"The line was dirty. t=%0t", j,$time);
                            finished_query_in_mem = 0;                    
                            command_for_mem = 2;
                            wait(clk == 1 && finished_query_in_mem == 1);
                        end
                        inner_cache_data[resived_set][sutable_line][`D + `TAG_SIZE + `CACHE_LINE_SIZE] = 0;
                        inner_cache_data[resived_set][j][`TAG_SIZE + `CACHE_LINE_SIZE] = 0; 
                        last_used[resived_set] = (sutable_line + 1) % 2;
                    end
                end
                inner_cache_c1 = `C1_RESPONSE;  
            end
            `delay(2,1)
            drop_leading();
        end
        else if (is_owning_cpu == 0 && clk == 0) begin
            case (c1)
                `C1_READ8: begin
                    //$fdisplay(glob.fl,"Cache prepared to give out 8 bit data. addr part 1 t=%0t", $time);
                    addr_tagset = a1;
                    last_operation_from_cpu = c1;
                    `delay(2,0)
                    //$fdisplay(glob.fl,"Cache prepared to give out 8 bit data. addr part 2 t=%0t", $time);
                    addr_offset = a1;
                    is_owning_cpu = 1;
                end 
                `C1_READ16: begin
                    //$fdisplay(glob.fl,"Cache prepared to give out 16 bit data. addr part 1 t=%0t", $time);
                    addr_tagset = a1;
                    last_operation_from_cpu = c1;
                    `delay(2,0)
                    //$fdisplay(glob.fl,"Cache prepared to give out 16 bit data. addr part 2 t=%0t", $time);
                    addr_offset = a1;
                    is_owning_cpu = 1;
                end 
                `C1_READ32: begin
                    //$fdisplay(glob.fl,"Cache prepared to give out 32 bit data. addr part 1 t=%0t", $time);
                    addr_tagset = a1;
                    last_operation_from_cpu = c1;
                    `delay(2,0)
                    //$fdisplay(glob.fl,"Cache prepared to give out 32 bit data. addr part 2 t=%0t", $time);
                    addr_offset = a1;
                    is_owning_cpu = 1;
                end 
                `C1_INVALIDATE_LINE: begin
                    //$fdisplay(glob.fl,"Cache prepared to invalidate line.t=%0t", $time);
                    addr_tagset = a1;
                    last_operation_from_cpu = c1;
                    is_owning_cpu = 1;
                end 
                `C1_WRITE8: begin
                    data_to_write = d1; 
                    last_operation_from_cpu = c1;
                    addr_tagset = a1;
                    //$fdisplay(glob.fl,"Cache got the 8 bit data. addr part 2 t=%0t, tagset = %b, offset = %b", $time, addr_tagset, addr_offset);                    
                    `delay(2,0)
                    addr_offset = a1;
                    is_owning_cpu = 1;
                    //$fdisplay(glob.fl,"Cache got the 8 bit data. addr part 2 t=%0t, tagset = %b, offset = %b", $time, addr_tagset, addr_offset);
                end 
                `C1_WRITE16: begin
                    //$fdisplay(glob.fl,"Cache got the 16 bit data. addr part 1 t=%0t", $time);
                    data_to_write = d1; 
                    last_operation_from_cpu = c1;
                    addr_tagset = a1;
                    `delay(2,0)
                    //$fdisplay(glob.fl,"Cache got the 16 bit data. addr part 2 t=%0t", $time);
                    addr_offset = a1;
                    is_owning_cpu = 1;
                end 
                `C1_WRITE32: begin
                    //$fdisplay(glob.fl,"Cache got the 32 bit data. t=%0t", $time);
                    last_operation_from_cpu = c1;
                    addr_tagset = a1;
                    data_to_write[`DATA1_BUS_SIZE - 1 : 0] = d1;
                    `delay(2,0)
                    //$fdisplay(glob.fl,"Cache got the 32 bit data part 2. t=%0t", $time);
                    addr_offset = a1;
                    data_to_write[2*`DATA1_BUS_SIZE - 1 : `DATA1_BUS_SIZE] = d1;
                    is_owning_cpu = 1;
                end 
                default: begin
                end
            endcase
        end
    end

    always @(clk) begin
        if (clk == 1 && is_owning_memory == 1) begin  
            case (command_for_mem) 
                0: begin
                    //$fdisplay(glob.fl,"Cache in deal(memory part). t=%0t", $time);
                    inner_cache_a2 = 'z;
                    last_operation_for_memory = `C2_NOP;
                    inner_cache_c2 = `C2_NOP;
                    inner_cache_d2 = 'z;
                    is_owning_memory = 1;
                    command_for_mem = -1;
                    finished_query_in_mem = 1;
                end
                1: begin
                    //$fdisplay(glob.fl,"Cache wants to read line.(memory part) t=%0t", $time);
                    last_operation_for_memory = `C2_READ_LINE;
                    inner_cache_a2 = addr_tagset;
                    inner_cache_d2 = 'z;                    
                    inner_cache_c2 = `C2_READ_LINE;
                    `delay(2,1)
                    //$fdisplay(glob.fl,"Cache gave up after asking to read line.(memory part) t=%0t", $time);
                    inner_cache_a2 = 'z;
                    inner_cache_d2 = 'z;
                    inner_cache_c2 = 'z;
                    is_owning_memory = 0;                       
                end
                2: begin
                    //$fdisplay(glob.fl,"Cache wants to write line, last_op = %0d. t=%0t", last_operation_from_cpu,$time);
                    last_operation_for_memory = `C2_WRITE_LINE;
                    inner_cache_a2 = inner_cache_data[resived_set][sutable_line][`CACHE_LINE_SIZE +: `TAG_SIZE] * (1 << `SET_SIZE) + resived_set;
                    inner_cache_c2 = `C2_WRITE_LINE;                                    
                    for ( i = 0; i < `MEM_LINE_SIZE/`DATA2_BUS_SIZE; i++) begin
                        //$fdisplay(glob.fl,"Cache writing 16 byte data, part %0b. t=%0t", i + 1,$time);
                        inner_cache_d2[0 +: `BYTE] = inner_cache_data[resived_set][sutable_line][2*i*`BYTE +: `BYTE];
                        inner_cache_d2[`BYTE +: `BYTE] = inner_cache_data[resived_set][sutable_line][(2*i + 1) * `BYTE +: `BYTE];
                        `delay(2,1)
                    end
                    //$fdisplay(glob.fl,"Cpu gave up after asking to write line. t=%0t", $time);
                    inner_cache_a2 = 'z;
                    inner_cache_d2 = 'z;
                    inner_cache_c2 = 'z;
                    is_owning_memory = 0;

                end
                default: begin
                end
                endcase
        end
        else if (is_owning_memory == 0 && clk == 0) begin
            case (c2)
                `C2_RESPONSE: begin
                    //$fdisplay(glob.fl,"Cache getting the result. t=%0t", $time);
                    case (last_operation_for_memory)
                        `C2_READ_LINE: begin
                        for ( i = 0; i < `MEM_LINE_SIZE/`DATA2_BUS_SIZE; i++) begin
                            inner_cache_data[resived_set][sutable_line][2*i*`BYTE +: `BYTE] = d2[0 +: `BYTE];
                            inner_cache_data[resived_set][sutable_line][(2*i + 1) * `BYTE +: `BYTE] = d2[`BYTE +: `BYTE];
                            //$fdisplay(glob.fl,"Cache getting 16 byte data, part %0d, data = %b. t=%0t", i + 1,d2[0 +: `BYTE],$time);
                            if (i != `MEM_LINE_SIZE/`DATA2_BUS_SIZE - 1) 
                                `delay(2,0)
                        end
                        end
                        default: begin
                        end
                    endcase
                   // finished_query_in_mem = 1;
                    command_for_mem = 0;
                    is_owning_memory = 1;
                end
                default: begin
                end
            endcase               
        end
    end
endmodule