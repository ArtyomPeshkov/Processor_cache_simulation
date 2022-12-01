`include "consts.sv"

module cpu(input clk, output wire [`ADDR1_BUS_SIZE - 1 : 0] a1, inout wire [`DATA1_BUS_SIZE - 1 : 0] d1, inout wire [`CTR1_BUS_SIZE - 1 : 0] c1);
    reg [31:0] inner_data [7:0];
    reg finished_query = 0;
    integer reg_number_to_write;
    bit is_owning = 1;

    integer command = 0;
    integer data_to_send = 'z; 
    integer addr_to_send = 0; // отправляется в байтах

    reg [14 : 0] addr_tagset = 'z;
    reg [3 : 0] addr_offset = 'z;

    logic [`ADDR1_BUS_SIZE - 1 : 0] inner_cpu_a1 = 'z;
    assign a1 = inner_cpu_a1;
    logic [`CTR1_BUS_SIZE - 1 : 0] last_operation = `C2_NOP;
    logic [`CTR1_BUS_SIZE - 1 : 0] inner_cpu_c1 = `C2_NOP;
    assign c1 = inner_cpu_c1;
    logic [`DATA1_BUS_SIZE - 1 : 0] inner_cpu_d1 = 'z;
    assign d1 = inner_cpu_d1;

    integer i = 0;

    //simulation
    int M = 64;
    int N = 60;
    int K = 32;
    int a = 0;
    int b = a + M * K * 1;
    int c = b + K * N * 2;
    int pa = 0;
    int pb = 0;
    int pc = 0;
    integer ticks_in_sample = 0;
    integer s;
    initial begin
        for (i = 0; i < 8; i++) begin
            inner_data[i] = '0;
        end
        glob.fl = $fopen("logger.txt", "w");
        glob.fdm = $fopen("memory.txt", "w");
        glob.fdc = $fopen("cache.txt", "w");
        pa = a;
        `delay(2,1); //init
        pc = c;
        `delay(2,1);//init
        `delay(2,1);//init y
        for (int y = 0; y < M; y++) begin
            `delay(2,1);//init x
            for (int x = 0; x < N; x++) begin
                pb = b;
                `delay(2,1); //init
                s = 0;
                `delay(2,1);//init
                `delay(2,1);//init k
                for (int k = 0; k < K; k++) begin
                    finished_query = 0;
                    addr_to_send = pa + k * 1;
                    command = 1;
                    reg_number_to_write = 0;                   
                    wait(finished_query == 1 && clk == 1);
                    `delay(10,1); // mul
                    finished_query = 0;
                    addr_to_send = pb + x * 2;
                    command = 2;
                    reg_number_to_write = 1;                   
                    wait(finished_query == 1 && clk == 1);
                    finished_query = 0;
                    s += inner_data[0] * inner_data[1];
                    `delay(2,1); // add
                    pb += N * 2;
                    `delay(2,1); // add

                    `delay(2,1); // k++
                    `delay(2,1); // loop iteratrion
                end
                //$fdisplay(glob.fl,"y = %0d, x = %0d, t = %0t", y, x, $time);
                data_to_send = s;
                addr_to_send = pc + x * 4;
                command = 7;
                wait(finished_query == 1 && clk == 1);
                finished_query = 0;
                `delay(2,1); // x++
                `delay(2,1); // loop iteratrion
            end
            pa += K * 1;
            `delay(2,1); // add
            pc = pc + N * 4;
            `delay(2,1); // add

            `delay(2,1); // y++
            `delay(2,1); // loop iteratrion
        end
        `delay(2,1); // exit function
        //$fdisplay(glob.fl, "Total ticks: %0d", ($time)/2);
        //$fdisplay(glob.fl, "Total memory accesses: %0d", glob.hits + glob.miss);
        //$fdisplay(glob.fl, "Cache hits: %0d", glob.hits);
        //$fdisplay(glob.fl, "Success hits (percent): %0f", glob.hits / (glob.hits + glob.miss));

        $display("Total ticks: %0d", ($time)/2);
        $display("Total memory accesses: %0d", glob.hits + glob.miss);
        $display("Cache hits: %0d", glob.hits);
        $display("Success hits (percent): %0f", glob.hits * 100 / (glob.hits + glob.miss));

        `delay(2, 1);
        $fclose(glob.fl);
        $fclose(glob.fdm);
        $fclose(glob.fdc);
    end

    task drop_leading;
        inner_cpu_a1 = 'z;
        inner_cpu_d1 = 'z;
        inner_cpu_c1 = 'z;
        is_owning = 0;
        command = -1;
    endtask

    task split_addr;
        addr_tagset = addr_to_send[`TAG_SIZE + `SET_SIZE + `OFFSET_SIZE - 1 : `OFFSET_SIZE];
        addr_offset = addr_to_send[`OFFSET_SIZE - 1 : 0];
        //$fdisplay(glob.fl,"INIT t=%0t, tagset = %b, offset = %b, sent addr = %0d", $time, addr_tagset, addr_offset, addr_to_send);
    endtask

    task take_leading;
        command = 0;
        is_owning = 1;
    endtask

    always @(clk) begin
        if (clk == 1 && is_owning == 1) begin
            case (command) 
                0: begin // C1_NOP
                    //$fdisplay(glob.fl,"Cpu in deal. t=%0t", $time);
                    inner_cpu_a1 = 'z;
                    last_operation = `C1_NOP;
                    inner_cpu_c1 = `C1_NOP;
                    inner_cpu_d1 = 'z;
                    is_owning = 1;
                    command = -1;
                    finished_query = 1;
                end
                1: begin // C1_READ8
                    //$fdisplay(glob.fl,"Cpu wants to read 8. addr part 1t=%0t", $time);
                    split_addr();
                    last_operation = `C1_READ8;
                    inner_cpu_a1 = addr_tagset;
                    inner_cpu_d1 = 'z;                    
                    inner_cpu_c1 = `C1_READ8;
                    `delay(2,1)
                    //$fdisplay(glob.fl,"Cpu wants to read 8. addr part 2 t=%0t", $time);
                    inner_cpu_a1 = addr_offset;
                    `delay(2,1)
                    //$fdisplay(glob.fl,"Cpu gave up after asking to read 8. t=%0t", $time);
                    drop_leading();
                                           
                end
                2: begin // C1_READ16                    
                    //$fdisplay(glob.fl,"Cpu wants to read 16. addr part 2 t=%0t", $time);
                    split_addr();
                    last_operation = `C1_READ16;
                    inner_cpu_a1 = addr_tagset;
                    inner_cpu_d1 = 'z;                    
                    inner_cpu_c1 = `C1_READ16;
                    `delay(2,1)
                    //$fdisplay(glob.fl,"Cpu wants to read 16. addr part 2 t=%0t", $time);
                    inner_cpu_a1 = addr_offset;
                    `delay(2,1)                
                    //$fdisplay(glob.fl,"Cpu gave up after asking to read 16. t=%0t", $time);
                    drop_leading();
                end
                3: begin // C1_READ32
                    //$fdisplay(glob.fl,"Cpu wants to read 32. addr part 1 t=%0t", $time);
                    split_addr();
                    last_operation = `C1_READ32;
                    inner_cpu_a1 = addr_tagset;
                    inner_cpu_d1 = 'z;                    
                    inner_cpu_c1 = `C1_READ32;                    
                    `delay(2,1)
                    //$fdisplay(glob.fl,"Cpu wants to read 32. addr part 2 t=%0t", $time);
                    inner_cpu_a1 = addr_offset;
                    `delay(2,1)
                    //$fdisplay(glob.fl,"Cpu gave up after asking to read 32. t=%0t", $time);
                    drop_leading();

                end
                4: begin // C1_INVALIDATE_LINE
                    //$fdisplay(glob.fl,"Cpu wants to invalidate some line. t=%0t", $time);
                    split_addr();
                    last_operation = `C1_INVALIDATE_LINE;
                    inner_cpu_a1 = addr_tagset;
                    inner_cpu_d1 = 'z;                    
                    inner_cpu_c1 = `C1_INVALIDATE_LINE;                    
                    `delay(2,1)
                    //$fdisplay(glob.fl,"Cpu gave up after asking to invalidate some line. t=%0t", $time);
                    drop_leading();

                end
                5: begin // C1_WRITE8
                    //$fdisplay(glob.fl,"Cpu wants to write 8. addr part 1 t=%0t", $time);
                    split_addr();
                    last_operation = `C1_WRITE8;
                    inner_cpu_a1 = addr_tagset;
                    inner_cpu_d1 = data_to_send & 255;                    
                    inner_cpu_c1 = `C1_WRITE8;                      
                    `delay(2,1)
                    //$fdisplay(glob.fl,"Cpu wants to write 8. addr part 2 t=%0t", $time);
                    inner_cpu_a1 = addr_offset;
                    `delay(2,1)
                    //$fdisplay(glob.fl,"Cpu gave up after asking to write 8. t=%0t", $time);
                    drop_leading();
                end
                6: begin // C1_WRITE16
                    //$fdisplay(glob.fl,"Cpu wants to write 16. addr part 1 t=%0t", $time);
                    split_addr();
                    last_operation = `C1_WRITE16;
                    inner_cpu_a1 = addr_tagset;
                    inner_cpu_d1 = data_to_send & 65535;                    
                    inner_cpu_c1 = `C1_WRITE16;                    
                    `delay(2,1)
                    //$fdisplay(glob.fl,"Cpu wants to write 16. addr part 2 t=%0t", $time);
                    inner_cpu_a1 = addr_offset;
                    `delay(2,1)
                    //$fdisplay(glob.fl,"Cpu gave up after asking to write 16. t=%0t", $time);
                    drop_leading();                     

                end
                7: begin // C1_WRITE32
                    split_addr();
                    last_operation = `C1_WRITE32;
                    inner_cpu_a1 = addr_tagset;
                    inner_cpu_d1 = data_to_send & 65535;                    
                    inner_cpu_c1 = `C1_WRITE32;
                    //$fdisplay(glob.fl,"Cpu wants to write 32. addr part 1 data = %b t=%0t",inner_cpu_d1, $time);
                    `delay(2,1)
                    inner_cpu_a1 = addr_offset;
                    inner_cpu_d1 = (data_to_send >> 16) & 65535;  
                    //$fdisplay(glob.fl,"Cpu wants to write 32 addr part 2 data = %b. t=%0t", inner_cpu_d1, $time);                                       
                    `delay(2,1)
                    //$fdisplay(glob.fl,"Cpu gave up after asking to write 32. t=%0t", $time);
                    drop_leading();
                end
                default: begin
                end
            endcase
        end
        else if (is_owning == 0 && clk == 0) begin
            case (c1)
                `C1_RESPONSE: begin
                    //$fdisplay(glob.fl,"Cpu got the result. t=%0t, clk = %0b", $time, clk);
                    case (last_operation)
                        `C1_READ8: begin
                            inner_data[reg_number_to_write] = d1 & 255;
                            //$fdisplay(glob.fl,"Cpu saved 8 bit number to read. t=%0t num=%0b", $time,  d1);
                        end
                        `C1_READ16: begin
                            inner_data[reg_number_to_write] = d1;
                            //$fdisplay(glob.fl,"Cpu saved 16 bit number to read. t=%0t num=%0b", $time,  d1);
                        end
                        `C1_READ32: begin
                            inner_data[reg_number_to_write][15:0] = d1;
                            //$fdisplay(glob.fl,"Cpu saved 32 bit number to read. t=%0t num=%0b", $time,  d1); 
                            `delay(2,0)
                            inner_data[reg_number_to_write][31:16] = d1;
                            //$fdisplay(glob.fl,"Cpu saved 32 bit number to read part 2. t=%0t num=%0b", $time, d1);                        
                        end
                        default: begin
                        end
                    endcase
                take_leading();
                end
                default: begin
                end
            endcase   
        end    
    end  

endmodule
