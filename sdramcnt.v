`include "inc.h"

//
//  SDRAMCNT.v
//
//  SDRAM controller.
//  This module can control Synchronous DRAMS such as
//  Samsumg's  KM416S1020/KM416S1120   1MB X 16
//  NEC's      uPD451616               1MB X 16
//  Oki's      MSM56V16160
//
//  The SDRAM's internal MODE REGISTER is also programmable.
//
//  


module sdramcnt(	
            // system level stuff
			sys_rst_l,
			sys_clk,
		
			// SDRAM connections
			sd_clke,
			sd_wr_l,
            sd_cs_l,
			sd_ras_l,
			sd_cas_l,
			sd_ldqm,
			sd_udqm,
			
			// Host Controller connections
	    	do_mode_set,
	  		do_read,
            do_write,
            doing_refresh,
            sd_addx_mux,
            sd_addx10_mux,
            sd_rd_ena,
            sd_data_ena,
            modereg_cas_latency,
            modereg_burst_length,
            mp_data_mux,

			// debug
            next_state,
			autorefresh_cntr,
			autorefresh_cntr_l,
			pwrup,
			cntr_limit

		);



// ****************************************
//
//   I/O  DEFINITION
//
// ****************************************


// System level stuff
input	        sys_rst_l;
input	        sys_clk;

// SDRAM connections
output	        sd_wr_l;
output	        sd_cs_l;
output	        sd_ras_l;
output	        sd_cas_l;
output	        sd_ldqm;
output	        sd_udqm;
output	        sd_clke;

// Host Controller connections
input           do_mode_set;
input           do_read;
input           do_write;
output          doing_refresh;
output  [1:0]   sd_addx_mux;
output  [1:0]   sd_addx10_mux;
output          sd_rd_ena;
output          sd_data_ena;
input   [2:0]   modereg_cas_latency;
input   [2:0]   modereg_burst_length;
output          mp_data_mux;

// Debug
output  [3:0]  next_state;
output	[12:0]	autorefresh_cntr;
output			autorefresh_cntr_l;
output			pwrup;
output	[12:0]	cntr_limit;

// ****************************************
//
// Memory Elements 
//
// ****************************************
//
reg     [3:0]	next_state;
reg     [7:0]   refresh_timer;
reg 	            sd_wr_l;
reg		            sd_cs_l;
reg		            sd_ras_l;
reg		            sd_cas_l;
reg                 sd_ldqm;
reg                 sd_udqm;
reg     [1:0]       sd_addx_mux;
reg     [1:0]       sd_addx10_mux;
reg                 sd_data_ena;
reg		            pwrup;			// this variable holds the power up condition
reg     [12:0]      refresh_cntr;   // this is the refresh counter
reg					refresh_cntr_l;	// this is the refresh counter reset signal
reg     [3:0]       burst_length_cntr;
reg                 burst_cntr_ena;
reg                 sd_rd_ena;      // read latch gate, active high
reg     [12:0]      cntr_limit;
reg     [3:0]       modereg_burst_count;
reg     [2:0]       refresh_state;
reg                 mp_data_mux;
wire                do_refresh;     // this bit indicates autorefresh is due
reg                 doing_refresh;  // this bit indicates that the state machine is 
                                    // doing refresh.
reg     [12:0]   autorefresh_cntr;
reg                 autorefresh_cntr_l;

assign sd_clke = `HI;		// clk always enabled

// State Machine
always @(posedge sys_clk or negedge sys_rst_l)
  if (~sys_rst_l) begin
    next_state	<= `state_powerup;
    autorefresh_cntr_l <= `LO;
	refresh_cntr_l  <= `LO;
    pwrup       <= `HI;
    sd_wr_l     <= `HI;
    sd_cs_l     <= `HI;
    sd_ras_l    <= `HI;
    sd_cas_l    <= `HI;
    sd_ldqm     <= `HI;
    sd_udqm     <= `HI;
    sd_data_ena <= `LO;
    sd_addx_mux <= 2'b10;           // select the mode reg default value
    sd_addx10_mux <= 2'b11;         // select 1 as default
    sd_rd_ena   <= `LO;
    mp_data_mux <= `LO;
//    refresh_cntr<= 13'h0000;
    burst_cntr_ena <= `LO;          // do not enable the burst counter
    doing_refresh  <= `LO;
  end 
  else case (next_state)
    // Power Up state
    `state_powerup:  begin
        next_state  <= `state_precharge;
        sd_wr_l     <= `HI;
        sd_cs_l     <= `HI;
    	sd_ras_l    <= `HI;
    	sd_cas_l    <= `HI;
    	sd_ldqm	    <= `HI;
    	sd_udqm     <= `HI;
        sd_data_ena <= `LO;
        sd_addx_mux <= 2'b10;
        sd_rd_ena   <= `LO;
        pwrup       <= `HI;         // this is the power up run
        burst_cntr_ena <= `LO;      // do not enable the burst counter
		refresh_cntr_l <= `HI;		// allow the refresh cycle counter to count
     end

    // PRECHARGE both banks        	
    `state_precharge:  begin
//        refresh_cntr<= refresh_cntr + 1;         // one less ref cycle to do   
        sd_wr_l     <= `LO;
        sd_cs_l     <= `LO;
    	sd_ras_l    <= `LO;
    	sd_cas_l    <= `HI;
    	sd_ldqm     <= `HI;
    	sd_udqm     <= `HI;
        sd_addx10_mux <= 2'b11;      // A10 = 1'b1   
         if ( (refresh_cntr == cntr_limit) & (pwrup == `HI) ) begin
             doing_refresh <= `LO;                // refresh cycle is done
//             refresh_cntr  <= 13'h000;             // ..reset refresh counter
             refresh_cntr_l  <= `LO;             // ..reset refresh counter
             next_state <= `state_modeset;      // if this was power-up, then go and set mode reg
             pwrup      <= `LO;                 // ..no more in power up mode
         end else begin
           doing_refresh <= `HI;        // indicate that we're doing refresh
           next_state	 <= `state_auto_refresh;
		 end
    end  

    // Autorefresh
    `state_auto_refresh: begin
        sd_wr_l     <= `HI;
        sd_cs_l     <= `LO;
    	sd_ras_l    <= `LO;
    	sd_cas_l    <= `LO;
    	sd_ldqm     <= `HI;
    	sd_udqm     <= `HI;
        sd_addx10_mux <= 2'b01;      // A10 = 0   
        next_state  <= `state_auto_refresh_dly;
        autorefresh_cntr_l  <= `HI;  //allow delay cntr to tick
     end    

    // Autor Refresh Delay -- extends the AutoRefresh CMD by   
    // AUTO_REFRESH_WIDTH counts
    `state_auto_refresh_dly:  begin
        if (autorefresh_cntr == `AUTO_REFRESH_WIDTH) begin  
          autorefresh_cntr_l <= `LO;
          sd_wr_l     <= `HI;
          sd_cs_l     <= `HI;
          sd_ras_l    <= `HI;
          sd_cas_l    <= `HI;
          sd_ldqm     <= `HI;
          sd_udqm     <= `HI;
          // If all refresh is done
          if ((refresh_cntr == cntr_limit) & (pwrup == `LO))   begin  
             doing_refresh <= `LO;                // refresh cycle is done
//             refresh_cntr  <= 13'h000;            // ..reset refresh counter
             refresh_cntr_l  <= `LO;            // ..reset refresh counter
             if (do_write | do_read)
                 next_state <= `state_set_ras;    // go service a pending read or write if any
             else
                 next_state <= `state_idle;       // if there are no peding RD or WR, then go to idle state
           end         
          // IF refresh cycles not done yet..
          else
             next_state <= `state_precharge; 
       end
   end

    // MODE SET state
    `state_modeset:  begin
        next_state  <= `state_idle;
        sd_wr_l     <= `LO;
        sd_cs_l     <= `LO;
        sd_ras_l    <= `LO;
        sd_cas_l    <= `LO;
        if (~pwrup) begin       // select a10-a0 to be the data from mode set reg
          sd_addx_mux <= 2'b10;
          sd_addx10_mux <= 2'b10;
        end
    end

    // IDLE state
    `state_idle:  begin
        sd_wr_l     <= `HI;
        sd_cs_l     <= `HI;
        sd_ras_l	<= `HI;
        sd_cas_l	<= `HI;
        sd_ldqm     <= `HI;
        sd_udqm     <= `HI;
        sd_data_ena <= `LO;         // turn off the data bus drivers
        sd_addx10_mux <= 2'b01;     // select low
        mp_data_mux <= `LO;         // drive the SD data bus with normal data
        if (do_write | do_read )        
            next_state <= `state_set_ras;
        else if (do_mode_set)
            next_state <= `state_modeset;
        else if (do_refresh) begin
            next_state <= `state_precharge;
			refresh_cntr_l <= `HI;		// allow refresh cycle counter to count up
		end
    end    

    // SET RAS state
    `state_set_ras:  begin
        sd_cs_l     <= `LO;     // enable SDRAM 
        sd_ras_l    <= `LO;     // enable the RAS
        sd_addx_mux <= 2'b00;   // send the low 10 bits of mp_addx to SDRAM
        next_state  <= `state_ras_dly;   // wait for a bit
    end

    // RAS delay state.  This state may not be necessary for most
    // cases.  Fow now, it is here to kill 1-cycle time
    `state_ras_dly:  begin
        sd_cs_l     <= `HI;     // disable SDRAM 
        sd_ras_l    <= `HI;     // disble the RAS
        if (do_write)
            next_state <= `state_write;      // if write, do the write      
        else 
            next_state <= `state_set_cas;    // if read, do the read
    end

    // WRITE state
    `state_write:  begin
        sd_cs_l     <= `LO;     // enable SDRAM 
        sd_cas_l    <= `LO;     // enable the CAS
        sd_addx_mux <= 2'b01;   // send the lower 8 bits of mp_addx to SDRAM (CAS addx)
                                // remember that the mp_addr[19] is the sd_ba
        sd_addx10_mux <= 2'b00; // set A10/AP = mp_addx[18] 
        sd_data_ena <= `HI;     // turn on  the data bus drivers
        sd_wr_l     <= `LO;     // enable the write
        sd_ldqm     <= `LO;     // do not mask
        sd_udqm     <= `LO;     // do not mask
        next_state  <= `state_cool_off;
    end

    // SET CAS state
    `state_set_cas:  begin
        sd_cs_l     <= `LO;
        sd_cas_l    <= `LO;
        sd_addx_mux <= 2'b01;
        sd_addx10_mux <= 2'b00;
        sd_ldqm     <= `LO;     // do not mask
        sd_udqm     <= `LO;     // do not mask
        next_state  <= `state_cas_latency1;        
    end

    `state_cas_latency1: begin
        sd_cs_l     <= `HI;     // disable CS
        sd_cas_l    <= `HI;     // disable CAS
        if (modereg_cas_latency==3'b010)  begin
           next_state <= `state_read;            // 2 cycles of lantency done.
           burst_cntr_ena <= `HI;                // enable he burst lenght counter
        end else
           next_state <= `state_cas_latency2;    // 3 cycles of latency      
    end

    `state_cas_latency2:  begin
        next_state <= `state_read;
        burst_cntr_ena <= `HI;      // enable the burst lenght counter
    end

    `state_read:  begin
        if (burst_length_cntr == modereg_burst_count) begin
            burst_cntr_ena <= `LO;  // done counting;
            sd_rd_ena      <= `LO;     // done with the reading
            next_state     <= `state_cool_off;
        end else
           sd_rd_ena  <= `HI;          // enable the read latch on the next state		
    end

    `state_cool_off:  begin
        sd_wr_l     <= `HI;
        sd_cs_l     <= `HI;
        sd_ras_l	<= `HI;
        sd_cas_l	<= `HI;
        sd_ldqm     <= `HI;
        sd_udqm     <= `HI;
        sd_addx10_mux <= 2'b01;     // select the mp_addx[10]
        mp_data_mux <= `HI;         // drive the SD data bus with all zeros
        next_state  <= `state_idle;
    end

  endcase
  

// This counter is used to extend the width of the Auto Refresh
// command.  It was found that if the AutoRefresh CMD set to be the default of 
// 1 SDRAM_CLK cycle, then an AutoRefresh CMD in the middle of a burst read
// would mess-up the remining burst reads.  By extending the Auto Refresh cycle
// to 2 or more, this burst read problem was solved.  As to why this happens
// I did not investigate further.
always @(posedge sys_clk or negedge autorefresh_cntr_l)
  if (~autorefresh_cntr_l)
    autorefresh_cntr <= 13'h0000;
  else
    autorefresh_cntr <= autorefresh_cntr + 1;



// This mux selects the cycle limit value for the 
// auto refresh counter
always @(pwrup)
  case (pwrup)
/*    `HI:      cntr_limit <= `power_up_ref_cntr_limit;
    default:  cntr_limit <= `auto_ref_cntr_limit;
*/
    1'b1:      cntr_limit <= 13'h000F;
    default:  cntr_limit <= 13'h0001;
  endcase


//
// BURST LENGHT COUNTER
//
// This is the burst length counter.  
always @(posedge sys_clk or negedge burst_cntr_ena)
  if (~burst_cntr_ena)
     burst_length_cntr <= 3'b000;   // reset whenever 'burst_cntr_ena' is low
  else
     burst_length_cntr <= burst_length_cntr + 1;

//
// REFRESH_CNTR
//
always @(posedge sys_clk or negedge refresh_cntr_l)
  if (~refresh_cntr_l)
     refresh_cntr <= 13'h0000;
  else if (next_state  == `state_auto_refresh)
	 refresh_cntr <= refresh_cntr + 1;

//
// BURST LENGTH SELECTOR
//
always @(modereg_burst_length)
   case (modereg_burst_length)
      3'b000:  modereg_burst_count <= 4'h1;
      3'b001:  modereg_burst_count <= 4'h2;
      3'b010:  modereg_burst_count <= 4'h4;
      default  modereg_burst_count <= 4'h8;
   endcase


//
// REFRESH Request generator
//
assign do_refresh = (refresh_state == `state_halt);


always @(posedge sys_clk or negedge sys_rst_l)
  if (~sys_rst_l) begin
     refresh_state <= `state_count;
     refresh_timer <= 8'h00;
  end 
  else case (refresh_state)
     // COUNT
     // count up the refresh interval counter. If the
     // timer reaches the refresh-expire time, then go next state
     `state_count:  
        if (refresh_timer != `RC)
           refresh_timer <= refresh_timer + 1;
        else 
           refresh_state <= `state_halt;
    
     // HALT
     // wait for the SDRAM to complete any ongoing reads or
     // writes.  If the SDRAM has acknowledged the do_refresh,
     // (i.e. it is now doing the refresh)
     // then go to next state 
     `state_halt: 
        if (next_state==`state_auto_refresh     | 
            next_state==`state_auto_refresh_dly |
            next_state==`state_precharge )  
           refresh_state <= `state_reset;
        

     // RESET
     // if the SDRAM refresh is completed, then reset the counter
     // and start counting up again.
     `state_reset:
        if (next_state==`state_idle) begin
           refresh_state <= `state_count;
           refresh_timer <= 8'h00;
        end
  endcase
           

endmodule

