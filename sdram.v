`include "inc.h"

//
//  SDRAM Controller.
//
//  Hierarchy:
//
//  SDRAM.V         Wrapper.
//  HOSTCONT.V      Controls the interfacing between the micro and the SDRAM
//  SDRAMCNT.V      This is the SDRAM controller.  All data passed to and from
//                  is with the HOSTCONT.
//  optional
//  MICRO.V         This is the built in SDRAM tester.  This module generates 
//                  a number of test logics which is used to test the SDRAM
//                  It is basically a Micro bus generator. 
//  
 



module sdram(
            // SYSTEM LEVEL CONNECTIONS
            sys_main_clk,
            sys_rst_l,
			sys_clk,

            // SDRAM CONNECTIONS
			sd_clke,
            sd_clk,
			sd_wr_l,
            sd_cs_l,
			sd_ras_l,
			sd_cas_l,
			sd_ldqm,
			sd_udqm,
            sd_addx,
            sd_data,
            sd_ba,

            // MICROPORCESSOR CONNECTION
            mp_addx,
            mp_data,
            mp_rd_l,
            mp_wr_l,
            mp_cs_l,
            sdram_mode_set_l,
            sdram_busy_l,
            smart_h,            
        

            // DEBUG
`ifdef show_debug
            ,
            next_state,
	    	do_modeset,
	  		do_read,
            do_write,
			autorefresh_cntr,
			autorefresh_cntr_l,
			pwrup,
			top_state,
			wr_cntr,
//			mp_data_micro,
			reg_mp_data_mux,
//			mp_data_mux,
			sd_data_ena,
			doing_refresh,
			mp_data_out,
//            sd_addx_mux,
//            sd_addx10_mux,
            sd_rd_ena,
//            dumb_busy_clk,
//            dumb_busy_out
 //           rd_wr_clk
`endif
            // simulated micro bus
`ifdef simulate_mp
            ,
            //mp_clk,
`endif


 );





// ****************************************
//
//   I/O  DEFINITION
//
// ****************************************
// SYSTEM LEVEL CONNECTIONS
input           sys_main_clk;
input           sys_rst_l;
output			sys_clk;

// SDRAM CONNECTIONS
output			sd_clke;
output          sd_clk;
output			sd_wr_l;
output          sd_cs_l;
output  		sd_ras_l;
output      	sd_cas_l;
output          sd_ldqm;
output          sd_udqm;
output  [10:0]  sd_addx;
inout   [15:0]  sd_data;
output          sd_ba;

// MICROPORCESSOR CONNECTION
`ifdef simulate_mp
output   [19:0] mp_addx;
output          mp_rd_l;
output          mp_wr_l;
output          mp_cs_l;
output  [15:0]	mp_data;
`else
input   [19:0]  mp_addx;
input           mp_rd_l;
input           mp_wr_l;
input           mp_cs_l;
inout	[15:0]  mp_data;
`endif
output           sdram_busy_l;
input            sdram_mode_set_l;
input           smart_h;

// DEBUG
`ifdef show_debug
output  [3:0]  next_state;
output	    	do_modeset;
output	  		do_read;
output          do_write;
output	[12:0]	autorefresh_cntr;
output			autorefresh_cntr_l;
output			pwrup;
output	[2:0]	top_state;
output	[7:0]	wr_cntr;
//output	[15:0]	mp_data_micro;
output	[15:0]	reg_mp_data_mux;
output	[15:0]	mp_data_out;
//output			mp_data_mux;
output			sd_data_ena;
output			doing_refresh;
//output          sd_addx_mux;
//output          sd_addx10_mux;
output          sd_rd_ena;
//output          rd_wr_clk;
//output          dumb_busy_clk;
//output          dumb_busy_out;
`endif

// simulated micro bus
`ifdef simulate_mp
//input           mp_clk;
`endif


// INTER-MODULE CONNECTIONS
wire            do_modeset;
wire            do_read;
wire            do_write;
wire            doing_refresh;
wire            sd_addx_ena;
wire    [1:0]   sd_addx_mux;
wire    [1:0]   sd_addx10_mux;
wire            sd_rd_ena;
wire            sd_data_ena;
wire    [2:0]   modereg_cas_latency;
wire    [2:0]   modereg_burst_length;
wire    [3:0]  next_state;
wire    [15:0]  mp_data_out;
wire	[15:0]	sd_data;
wire            mp_cs_l;
wire            mp_wr_l;
wire            mp_rd_l;
wire            mp_data_mux;
wire	[12:0]	autorefresh_cntr;
wire			autorefresh_cntr_l;
wire			pwrup;
wire	[2:0]	top_state;

`ifdef simulate_mp
wire    [19:0]  mp_addx;
wire    [15:0]  mp_data_inbus;
wire    [15:0]  mp_data_micro;
`endif
wire            sdram_mode_set_l;
wire            sys_clk;
//wire            rd_wr_clk;
wire            sdram_busy_l;

`ifdef simulate_mp
wire            mp_clk;
`endif


`ifdef simulate_mp
assign mp_data = ~(mp_rd_l | mp_cs_l) ? mp_data_out : mp_data_micro;
`else
assign mp_data = ~(mp_rd_l | mp_cs_l) ? mp_data_out : 16'hzzzz;
`endif


/*
*/
//
//   CLOCK GENERATOR
//
//

//   --divide by 2
//
`ifdef divide_by_2
reg             sd_clk;
always @(posedge sys_main_clk)
   sd_clk <= ~sd_clk;

assign sys_clk = sd_clk;
`endif

//   --divide by 4
//
`ifdef divide_by_4
reg     [1:0]   sd_clk;
always @(posedge sys_main_clk)
   sd_clk <= sd_clk + 2'b01;

assign sys_clk = sd_clk[1];
`endif

//   --divide by 8
//
`ifdef divide_by_8
reg     [2:0]   sd_clk;
always @(posedge sys_main_clk)
   sd_clk <= sd_clk + 3'b001;

assign sys_clk = sd_clk[2];
`endif

assign mp_clk = sys_clk;

sdramcnt SDRAMCNT(	
            // system level stuff
			.sys_rst_l(sys_rst_l),
			.sys_clk(sys_clk),
		
			// SDRAM connections
			.sd_clke(sd_clke),
			.sd_wr_l(sd_wr_l),
            .sd_cs_l(sd_cs_l),
			.sd_ras_l(sd_ras_l),
			.sd_cas_l(sd_cas_l),
			.sd_ldqm(sd_udqm),
			.sd_udqm(sd_ldqm),
			
			// Host Controller connections
	    	.do_mode_set(do_modeset),
	  		.do_read(do_read),
            .do_write(do_write),
            .doing_refresh(doing_refresh),
            .sd_addx_mux(sd_addx_mux),
            .sd_addx10_mux(sd_addx10_mux),
            .sd_rd_ena(sd_rd_ena),
            .sd_data_ena(sd_data_ena),
            .modereg_cas_latency(modereg_cas_latency),
            .modereg_burst_length(modereg_burst_length),
            .mp_data_mux(mp_data_mux),

			// debug
            .next_state(next_state),
			.autorefresh_cntr(autorefresh_cntr),
			.autorefresh_cntr_l(autorefresh_cntr_l),
			.pwrup(pwrup)
		);


hostcont HOSTCONTTT(
            // system connections
            .sys_rst_l(sys_rst_l),            
            .sys_clk(sys_clk),

            // microprocessor side connections
            .mp_addx(mp_addx),
`ifdef simulate_mp
			.mp_data_in(mp_data_micro),
`else
			.mp_data_in(mp_data),
`endif
            .mp_data_out(mp_data_out),
            .mp_rd_l(mp_rd_l),
            .mp_wr_l(mp_wr_l),
            .mp_cs_l(mp_cs_l),
            .sdram_mode_set_l(sdram_mode_set_l),
            .sdram_busy_l(sdram_busy_l),

            // SDRAM side connections
            .sd_addx(sd_addx),
            .sd_data(sd_data),
            .sd_ba(sd_ba),
            .sd_wr_l(sd_wr_l),

            // SDRAMCNT side
            .sd_addx10_mux(sd_addx10_mux),
            .sd_addx_mux(sd_addx_mux),
            .sd_rd_ena(sd_rd_ena),
            .sd_data_ena(sd_data_ena),
            .do_read(do_read),
            .do_write(do_write),
            .doing_refresh(doing_refresh),
            .do_modeset(do_modeset),
            .modereg_cas_latency(modereg_cas_latency),
            .modereg_burst_length(modereg_burst_length),
            .next_state(next_state),
            .mp_data_mux(mp_data_mux),

            // other inputs
            .smart_h(smart_h)

            // debug
//            .rd_wr_clk(rd_wr_clk)
            ,.dumb_busy_clk(dumb_busy_clk),
            .dumb_busy_out(dumb_busy_out),
			.reg_mp_data_mux(reg_mp_data_mux)
             );


`ifdef simulate_mp
micro MICRO (
                // system connections
                .mp_clk(mp_clk),
                .sys_rst_l(sys_rst_l),

                // Connections to the SDRAM CONTROLLER
                .sdram_busy_l(sdram_busy_l),
                .mp_addx(mp_addx),
                .mp_data(mp_data_micro),
                .mp_wr_l(mp_wr_l),
                .mp_rd_l(mp_rd_l),
                .mp_cs_l(mp_cs_l),
                .next_state(next_state),

				// debug
				.top_state(top_state),
				.wr_cntr(wr_cntr)
 
);

`endif

endmodule

//
//  REVISION LOG
//
//  7/31/99  
//  Added/tested/debugged support for interfacing to Intel type of 
//  Microprocessors, where it is required that the device "busy" be asserted 
//  when the chip_select decoded.  That is before it is known whether it is 
//  a read or a write cycle 
//  This is called the "non-smart" interface, where all bus request from the 
//  micro is blocked until it is completed.  It is enabled by pulling low
//  on the smart_h pin.
//
//
//  8/15/99
//  Made the width of the AutoRefresh Command to be 1+ CLKs.  By just having it
//  to be 1 CLK, the burst reads (back to back 1 word reads, not SDRAM "burst" reads)
//  would be all messed up if a refresh happened to coem in the middle.  By making
//  the refresh command to be more than 1 CLK (2 or more) this problem was 
//  eliminated.
//
