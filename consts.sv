`ifndef CONSTANTS
`define CONSTANTS

// Разработано совместно с Тимофеем Маловым
`define delay(TIME, CLOCK) \
    for (int i = 0; i < TIME; i++) \
        wait(clk == (i + !CLOCK) % 2); 

`define C1_NOP 3'b000
`define C1_READ8 3'b001
`define C1_READ16 3'b010
`define C1_READ32 3'b011
`define C1_INVALIDATE_LINE 3'b100
`define C1_WRITE8 3'b101
`define C1_WRITE16 3'b110
`define C1_WRITE32 3'b111
`define C1_RESPONSE 3'b111

`define C2_NOP 2'b00
`define C2_READ_LINE 2'b10
`define C2_WRITE_LINE 2'b11
`define C2_RESPONSE 2'b01

`define MEM_LINE_SIZE (1 << 7)
`define MEM_LINE_COUNT (1 << 15)

`define CACHE_LINE_SIZE (1 << 7)
`define CACHE_LINE_COUNT 64
`define CACHE_WAY 2

`define CACHE_TAG_SIZE 10
`define CACHE_SET_SIZE 5
`define CACHE_OFFSET_SIZE 4
`define V 1
`define D 1

`define ADDR1_BUS_SIZE 15
`define ADDR2_BUS_SIZE 15

`define DATA1_BUS_SIZE 16
`define DATA2_BUS_SIZE 16

`define CTR1_BUS_SIZE 3
`define CTR2_BUS_SIZE 2

`define BYTE 8
`define MEM_BYTE_SIZE 19


module glob;
    real  hits = 0;
    integer miss = 0;
    integer fl, fdm, fdc;
    reg reset;
    reg dump_m;
    reg dump_c; 
endmodule

`endif
