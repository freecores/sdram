`include "inc.h"

/*
**  HOSTCONT.v
**
**  This module is the host controller whic sits between the host 
**  (usually a micro) and the sdramcnt.v
**
**
**
**
*/


module hostcont (
                    // system connections
                    sys_rst_l,            
                    sys_clk,

                    // microprocessor side connections
                    mp_addx,
                    mp_data_in,
                    mp_data_out,
                    mp_rd_l,
                    mp_wr_l,
                    mp_cs_l,
                    sdram_mode_set_l,
                    sdram_busy_l,

                    // SDRAM side connections
                    sd_addx,
                    sd_data,
                    sd_ba,
                    sd_wr_l,

                    // SDRAMCNT side
                    sd_addx10_mux,
                    sd_addx_mux,
                    sd_rd_ena,
                    sd_data_ena,
                    do_read,
                    do_write,
                    doing_refresh,
                    do_modeset,
                    next_state,
                    modereg_cas_latency,
                    modereg_burst_length,
                    mp_data_mux,

                    // bus type select
                    smart_h

                    // debug
//                    rd_wr_clk
                    ,dumb_busy_out
                    ,dumb_busy_clk,
					reg_mp_data_mux

             );


// ****************************************
//
//   I/O  DEFINITION
//
// ****************************************

// system connections
input           sys_rst_l;          // asynch active low reset
input           sys_clk;            // clock source to the SDRAM

// microprocessor side connections
input   [19:0]  mp_addx;            // 20 bits for the addx
input   [15:0]  mp_data_in;         // 16 bits of data bus input
output  [15:0]  mp_data_out;        // 16 bits of data bus output
input           mp_rd_l;            // micro bus read , active low
input           mp_wr_l;            // micro bus write, active low
input           mp_cs_l;
input           sdram_mode_set_l;   // acive low request for SDRAM mode set
output          sdram_busy_l;       // active low busy output

// SDRAM side connections
output  [10:0]  sd_addx;            // 11 bits of muxed SDRAM addx
inout   [15:0]  sd_data;            // 16 bits of bidirectional SDRAM data bus
output          sd_ba;              // bank select output to the SDRAM
input           sd_wr_l;

// SDRAMCNT side
input   [1:0]   sd_addx10_mux;
input   [1:0]   sd_addx_mux;
input           sd_rd_ena;
input           sd_data_ena;
output          do_write;
output          do_read;
input           doing_refresh;
output          do_modeset;
input   [3:0] next_state;
output  [2:0]   modereg_cas_latency;
output  [2:0]   modereg_burst_length;
input           mp_data_mux;

// other inputs
input           smart_h;            // If high, indicates that writes are non
                                    // blocking if SDRAM is not busy.  Else,
                                    // all IO are blocked

//debug
//output          rd_wr_clk;
output          dumb_busy_clk;
output          dumb_busy_out;
output	[15:0]	reg_mp_data_mux;

// ****************************************
//
// Memory Elements 
//
// ****************************************
//
reg     [19:0]  reg_mp_addx;
reg     [15:0]  reg_mp_data;
reg     [15:0]  reg_sd_data;
`ifdef simulate_mp
wire    [10:0]  reg_modeset;
`else
reg     [10:0]  reg_modeset; 
`endif
reg     [10:0]  sd_addx;
reg             do_read;
reg             do_write;
reg             do_modeset;
reg             sd_ba;
reg             rst_do_write;
wire	[15:0]	sd_data;
wire    [15:0]  sd_data_buff;
wire    [15:0]  reg_mp_data_mux;
wire    [15:0]  mp_data_out;
wire            mp_data_ena;
wire            do_read_clk;
wire            do_write_clk;
wire            clock_xx;
wire			modereg_ena;
wire            read_busy;
wire            write_busy;
wire            refresh_busy;
wire            do_write_rst;
wire            dumb_busy_clk;
wire            dumb_busy_rst;
reg             rst_dumb_busy;
reg             dumb_busy_out;
wire            dumb_busy;
            

assign mp_data_out = reg_sd_data;
assign mp_data_ena  = ~mp_rd_l;
assign modereg_cas_latency  =  reg_modeset[6:4];
assign modereg_burst_length =  reg_modeset[2:0];

assign read_busy    = do_read;
assign write_busy   = do_write;
assign refresh_busy = `LO; 

// SDRAM BUSY SIGNAL GENERATION
//
// The BUSY signal is NOR'd of READ_BUSY, WRITE_BUSY and DUMB_BUSY.
// READ_BUSY is generated while the SDRAM is performing a read.  This 
// does not necessarily have to he synchronous to the micro's read.  
// The WRITE_BUSY is generated while the SDRAM is performing WRITE.
// Again, due to the "dump-n-run" mode (only in SMART_H=1) the micro's
// write bus cycle does not necessarily align with SDRAM's write cycle.
// DUMB_BUSY is a signal which generates the BUSY at the falling edge of
// micro's SDRAM_CS.  This is used for those microprocessors which 
// require a device BUSY as soon as the address is placed on its bus.  For
// example, most Intel microcontrollers and small processors do have this
// requirement.  This means that one will fofeit on the dump-n-go feature.
// 
assign sdram_busy_l = ~(read_busy | write_busy | dumb_busy | doing_refresh);


// MP ADDRESS LATCH
// Transparent latch
// Used to hold the addx from the micro. Latch on the falling edge of
// mp_rd_l or mp_wr_l
always @(do_write or sys_rst_l or mp_addx)
  if (~sys_rst_l)
    reg_mp_addx <= 20'h00000;
  else if (~do_write)               // hold the addx if do_write==`HI
    reg_mp_addx <= mp_addx;
  else 
    reg_mp_addx <= reg_mp_addx;

// MP DATA LATCH
// Used to hold the data from the micro.  Latch on the rising edge
// of mp_wr_l
always @(posedge mp_wr_l or negedge sys_rst_l)
  if (~sys_rst_l)
    reg_mp_data <= 16'h0000;
  else if (~mp_cs_l)
    reg_mp_data <= mp_data_in;


// MODE REG LATCH
`ifdef simulate_mp
assign reg_modeset = 11'h0020;
`else
assign modereg_ena = ~mp_cs_l & ~sdram_mode_set_l;
always @(posedge mp_wr_l or negedge sys_rst_l)
  if (~sys_rst_l)
    reg_modeset <= 11'h0020;   // default modeset reg value has this settings:
                               // burst length=1, cas latency=2
  else if (modereg_ena)
    reg_modeset <= mp_data_in;
`endif


// SD DATA LATCH
always @(posedge sys_clk or negedge sys_rst_l)
  if (~sys_rst_l)
    reg_sd_data <= 16'h0000;
  else if (sd_rd_ena)
    reg_sd_data <= sd_data_buff;


// SDRAM SIDE ADDX
always @(sd_addx10_mux or reg_mp_data or reg_mp_addx)
  case (sd_addx10_mux)
//    2'b00:   sd_addx[10] <= 1'b0;
//    2'b01:   sd_addx[10] <= reg_mp_addx[10];
    2'b00:   sd_addx[10] <= reg_mp_addx[18];
    2'b01:   sd_addx[10] <= 1'b0;
    2'b10:   sd_addx[10] <= reg_mp_data[10];
    default: sd_addx[10] <= 1'b1;
  endcase

always @(sd_addx_mux or reg_modeset or reg_mp_addx)
  case (sd_addx_mux)
//    2'b00:   sd_addx[9:0] <= reg_mp_addx[9:0];
//    2'b01:   sd_addx[9:0] <= {2'b00, reg_mp_addx[18:11]};
    2'b00:   sd_addx[9:0] <= reg_mp_addx[17:8];                // ROW
    2'b01:   sd_addx[9:0] <= {2'b00, reg_mp_addx[7:0]};        // COLUMN
    2'b10:   sd_addx[9:0] <= reg_modeset[9:0];
    default: sd_addx[9:0] <= 10'h000;
  endcase


// SD_BA
always @(sd_addx_mux or reg_mp_addx)
  case (sd_addx_mux)
    2'b00:    sd_ba <= reg_mp_addx[19];     
    2'b01:    sd_ba <= reg_mp_addx[19]; 
    default:  sd_ba <= 1'b0;
  endcase


// SD SIDE DATA BUFFERS
assign sd_data      = sd_data_ena ? reg_mp_data_mux : 16'hzzzz;
assign sd_data_buff = sd_data;


// Micro data mux
assign reg_mp_data_mux = mp_data_mux ? 16'h0000 : reg_mp_data;


//
// DO_READ signal generation
//
// Set     by falling edge of mp_rd_l 
// cleared by the falling edge of next_state==`state_read
assign do_read_clk = ( mp_rd_l | (next_state==`state_read) );
always @(negedge do_read_clk or negedge sys_rst_l)
  if (~sys_rst_l)
     do_read <= `LO;
  else 
     do_read <= ~do_read;



// DO_WRITE signal generation logic
// This signal indicates that the SDRAM is performing a write
// this is a completely asynchronous logic which does the following:
// the do_write is
// set      at rising edge of mp_wr_l (at deassertion of micro write bus cycle)
// cleared  on the rising edge of sd_wr_l.  That is, at the termination of 
// current SDRAM write cycle.  This excludes the sd_wr_l generated during the 
// refresh cycle.
assign do_write_rst = ~sys_rst_l | rst_do_write;
always @(posedge mp_wr_l or posedge do_write_rst)
  if (do_write_rst)
    do_write <= `LO;
  else 
    do_write <= `HI;

always @(posedge sd_wr_l or posedge do_write_rst)
  if (do_write_rst)
    rst_do_write <= `LO;
  else if (~doing_refresh)   // reset only is we're not a refresh cycle
    rst_do_write <= `HI;


//
// DO_MODESET signal generation
//
// needs to be triggered by falling edge of  
always @(sys_clk or sys_rst_l)
  if (sys_rst_l)
    do_modeset <= `LO;
  else
    do_modeset <= `LO;



//
// DUMB BUSY SIGNAL GENERATION
//
// In the "dumb" mode (smart_h == 0), the SDRAM controller will
// not allow the micro to do another I/O until the 
// present one is finished.  The most notable difference is
// that it will not allow a "dump-&-run" writes.  
//
// The busy signal is asserted at the falling edge of mp_cs_l.
// In the case of writes, it is deasserted when mp_rw_l goes low.  This
// allows the micro to deassert its wr (i.e. finish the write bus cycle) 
// at which point the busy is again asserted (since the SDRAM is now being written)
// until the completion of the write into the SDRAM.
// During reads, the busy is asserted on the falling edge of mp_cs_l, and is not 
// deasserted until the completion of the read.
//
// The busy signal is the or of DO_WRITE , DO_READ as before, but
// in the smart_h=0 mode, an extra signal dumb_busy_out is also or'd.
// This signal is set at the falling edge of mp_cs_l.  It is cleared
// on the falling edge of mp_wr_l or on the rising edge of do_read.
// (mp_wr_l ^ do_read) 
//
// It is set      by the falling edge of MP_CS_L
// is is cleared  by the rising  edge of DO_READ or 
//                       falling edge of mp_WR_L
assign dumb_busy = (dumb_busy_out & ~smart_h);
always @(negedge mp_cs_l or posedge dumb_busy_rst)
  if (dumb_busy_rst)
     dumb_busy_out <= `LO;
  else
     dumb_busy_out <= `HI;

assign dumb_busy_rst = ~sys_rst_l | rst_dumb_busy;
assign dumb_busy_clk = do_read ^ mp_wr_l;
always @(negedge dumb_busy_clk or posedge dumb_busy_rst)
  if (dumb_busy_rst)
     rst_dumb_busy <= `LO;
  else
     rst_dumb_busy <= `HI;     

endmodule

