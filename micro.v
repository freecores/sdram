`include "tst_inc.h"
`include "inc.h"
module micro(
                // system connections
                mp_clk,
                sys_rst_l,

                // Connections to the HOSTCONT.V
                sdram_busy_l,
                mp_addx,
                mp_data,
                mp_wr_l,
                mp_rd_l,
                mp_cs_l,

                next_state,

				// debug
				top_state,
				wr_cntr
                
);



// system connections
input           mp_clk;             // main system clock
input           sys_rst_l;          // main system reset

// connections to the SDRAM CONTROLLER
input           sdram_busy_l;       
output  [19:0]  mp_addx;
output          mp_wr_l;
output          mp_rd_l;
output          mp_cs_l;
input	[3:0]	next_state;
output  [15:0]  mp_data;

// debug
output	[2:0]	top_state;
output	[7:0]	wr_cntr;

// Intermodule connections
wire    [7:0] bus_state;
wire              data_ena;
wire    [15:0]  mp_data;
wire			mp_wr_l;
wire			mp_rd_l;
wire			mp_cs_l;


// Memory element definitions
reg             req_wr_l;
reg             req_rd_l;
reg             change_addx;
reg             data_addx_rst_l;

// INSTANTIATE THE MICRO BUS
sim_mp SIM_MP(
                // system connections
                .mp_clk(mp_clk),
                .sys_rst_l(sys_rst_l),

                // inputs 
                .req_wr_l(req_wr_l),
                .req_rd_l(req_rd_l),
                .sdram_busy_l(sdram_busy_l),
                .change_addx(change_addx),
                .data_addx_rst_l(data_addx_rst_l),

                // outputs 
                .mp_addx(mp_addx),
                .mp_data(mp_data),
                .mp_wr_l(mp_wr_l),
                .mp_rd_l(mp_rd_l),
                .mp_cs_l(mp_cs_l),
                .state(bus_state),
                .data_ena(data_ena)

            );


/*
** SINGLE WRITE FOLLOWED BY GAP THEN FOLLOWED BY SINGLE READ TEST
**
*/
`ifdef do_read_write_test
`define         NN              8
`define			NNn				`NN-1
`define			delay			`NN'h20
reg     [2:0]   	top_state;
reg     [`NNn:0]	cntr;
reg             	rst_cntr;
`define         do_read         3'h0
`define         do_write        3'h1
`define         do_read_wait    3'h2 
`define         do_write_wait   3'h3
`define         do_wait         3'h4
`define         powerup_wait    3'h5

// Top level state machie
always @(posedge mp_clk or negedge sys_rst_l)
  if (~sys_rst_l) begin
    req_wr_l  	<= `HI;         // do not request any writes
    req_rd_l  	<= `HI;         // do not request any reads
    change_addx <= `LO;			// do not change addx
    top_state 	<= `powerup_wait;
    rst_cntr    <= `HI;
    data_addx_rst_l <= `LO;		// reset the data and addx counters
	cntr		<= `NN'h00;		// initialize the counter			
  end
  else case (top_state)
     `powerup_wait: begin
          data_addx_rst_l <= `HI;   // allow the data and addx to count up
          if (next_state == `state_idle)
            top_state <= `do_write;
      end

     `do_write:  begin
          change_addx <= `HI;           // tell bus controller to increment addx/data
          req_wr_l    <= `LO;			// request a micro write
          top_state   <= `do_write_wait;
     end
 
     `do_write_wait:  begin
          change_addx <= `LO;           // done incrementing addx/data
          req_wr_l   <= `HI;			// done requesting the write
          if (bus_state == `state_deassert_addx) begin
            top_state  <= `do_wait;
            rst_cntr   <= `LO;
          end
     end

     `do_wait:  begin
          if (cntr == `delay)  begin
            top_state  <= `do_read;
            rst_cntr   <= `HI;
			cntr       <= `NN'h00;		// reset the counter
          end 
			cntr	<=  cntr + 1;		// increment the counter
      end

     `do_read:  begin
          req_rd_l   <= `LO;			// request a read from the micro simulator
          top_state  <= `do_read_wait;
     end

     `do_read_wait: begin
          req_rd_l   <= `HI;			// done requesting the read
          if (bus_state == `state_deassert_addx) begin
            top_state   <= `do_write;
          end
      end
  endcase        


// Counter to count the events
always @(posedge mp_clk or posedge rst_cntr)
  if (rst_cntr)
    cntr <= 8'h000;
  else 
    cntr <= cntr + 1;
 

`endif


/*
** BURST WRITE FOLLOWED BY GAP THEN FOLLOWED BY BURST READ TEST
**
*/
`ifdef do_burst_write_read_test
`define             MN                 8
`define				MNn				   `MN-1
`define             RW_COUNT           `MN'h20
`define             GAP_DELAY          `MN'h40
reg     [2:0]       top_state;
reg                 rst_cntr;
//reg     [`XY-1:0]   cntr;
reg     [`MNn:0]   wr_cntr;
`define         powerup_delay      3'h1
`define         burst_write        3'h2
`define         burst_write_wait   3'h3
`define         write_read_delay   3'h4
`define         burst_read         3'h5
`define         burst_read_wait    3'h6


always @(posedge mp_clk or negedge sys_rst_l)
  if (~sys_rst_l) begin
     top_state   <= `powerup_delay;
     req_wr_l  <= `HI;             // do not request any writes
     req_rd_l  <= `HI;             // do not request any reads
     change_addx <= `LO;           // do not change addx
     rst_cntr    <= `HI;           // reset counter 
     wr_cntr     <= `MN'h00;
     data_addx_rst_l <= `LO;       // reset the data and addx counter
  end
  else case (top_state)   
     `powerup_delay:  begin
          data_addx_rst_l <= `HI;  // allow the data and the addx couter to count up
          if (next_state == `state_idle)  begin
            top_state <= `burst_write; // go and do burst write
         end
      end
       
     `burst_write:  begin
         req_wr_l    <= `LO;    // request a write      
         top_state   <= `burst_write_wait;
         change_addx <= `LO;    // done changing addx
     end

     `burst_write_wait:  begin
         req_wr_l  <= `HI;      // done requesting a write
         if (bus_state == `state_deassert_addx) begin
            if (wr_cntr == `RW_COUNT) begin
              top_state <= `write_read_delay;  // go and do reads
              rst_cntr  <= `LO;                // allow counter to go up
              wr_cntr   <= `MN'h00;            // clear write counter
            end else begin
              wr_cntr <= wr_cntr + `MN'h1;          
              change_addx <= `HI;        // increment addx
              top_state   <= `burst_write;       
            end
         end
      end

     // Wait for a bit to allow several refrehes into the SDRAM
     `write_read_delay:  begin
         if (wr_cntr == `GAP_DELAY) begin
            data_addx_rst_l <= `HI;  // allow the data and the addx couter to count up
            rst_cntr  <= `HI;         // reset counter
            wr_cntr   <= `MN'h00;            // clear write counter
            top_state <= `burst_read;  
         end else begin
            wr_cntr <= wr_cntr + `MN'h1;  // count up by one          
            data_addx_rst_l <= `LO;       // reset the data and addx counters
	     end
      end     

     `burst_read: begin
         req_rd_l    <= `LO;    // request read
         top_state   <= `burst_read_wait;
         change_addx <= `LO;  // done changing addx
      end

      `burst_read_wait:  begin
         req_rd_l   <= `HI;    // done requesting a read
         if (bus_state == `state_deassert_addx)  begin
            if(wr_cntr == `RW_COUNT) begin
               data_addx_rst_l <= `LO;  // reset the addx and data couters 
               top_state <= `powerup_delay;
               wr_cntr     <= 5'h00;      // clear write counter
            end else begin
               top_state   <= `burst_read;
               change_addx <= `HI;   // inc addx
               wr_cntr <= wr_cntr + 1;
            end   
         end               
      end      
  endcase

`endif


/*
** A ONE-TIME BURST WRITE FOLLOWED BY GAP THEN FOLLOWED BY MANY BURST READ TEST
**
*/
`ifdef do_single_burst_write_read_test

`define         MN                 8
`define         RW_COUNT           8'h5
`define         GAP_DELAY          8'h10

reg     [2:0]   top_state;
reg             rst_cntr;
reg     [7:0]   wr_cntr;

`define         powerup_delay      3'h1
`define         burst_write        3'h2
`define         burst_write_wait   3'h3
`define         write_read_delay   3'h4
`define         burst_read         3'h5
`define         burst_read_wait    3'h6


always @(posedge mp_clk or negedge sys_rst_l)
  if (~sys_rst_l) begin
     top_state			<= `powerup_delay;
     req_wr_l			<= `HI;         // do not request any writes
     req_rd_l 			<= `HI;         // do not request any reads
     change_addx		<= `LO;         // do not change addx
     rst_cntr			<= `HI;         // reset counter 
	 wr_cntr			<= 8'h00;		// reset the cycle counter
     data_addx_rst_l	<= `LO;			// reset the data and addx counter
  end
  else case (top_state)   
     `powerup_delay:  begin
          if (next_state == `state_idle)  begin
            top_state		<= `burst_write;// go and do burst write
          end else
            data_addx_rst_l <= `HI;  		// allow the data and the addx couter to count up
      end
       
     `burst_write:  begin
         req_wr_l    <= `LO;    // request a write      
         top_state   <= `burst_write_wait;
         change_addx <= `LO;    // done changing addx
     end

     `burst_write_wait:  begin
         req_wr_l  <= `HI;      // done requesting a write
         if (bus_state == `state_deassert_addx) begin
            if (wr_cntr == `RW_COUNT) begin
              top_state <= `write_read_delay;    // go and do reads
              rst_cntr  <= `LO;                // allow counter to go up
              data_addx_rst_l <= `LO;			// reset the data and addx counters
              wr_cntr	<= 8'h00;          			  
            end else begin
              wr_cntr <= wr_cntr + 8'h1;          			  
              top_state   <= `burst_write;       
              change_addx <= `HI;        // increment addx
            end
         end
      end

     // Wait for a bit to allow several refrehes into the SDRAM
     `write_read_delay:  begin
         if (wr_cntr == `GAP_DELAY) begin
            data_addx_rst_l <= `HI;  // allow the data and the addx couter to count up
            rst_cntr  <= `HI;         // reset counter
            wr_cntr	<= 8'h00;          			  
            top_state <= `burst_read;  
         end else
            wr_cntr <= wr_cntr + 8'h1;          			  
      end     

     `burst_read: begin
         req_rd_l    <= `LO;    // request read
         top_state   <= `burst_read_wait;
         change_addx <= `LO;  // done changing addx
      end

      `burst_read_wait:  begin
         req_rd_l   <= `HI;    // done requesting a read
         if (bus_state == `state_deassert_addx)  begin
            if(wr_cntr == `RW_COUNT) begin
               data_addx_rst_l <= `LO;  // reset the addx and data couters 
               top_state <= `write_read_delay;
               wr_cntr	<= 8'h00;          			  
            end else begin
               wr_cntr <= wr_cntr + 1;
               top_state   <= `burst_read;
               change_addx <= `HI;   // inc addx
            end   
         end               
      end      
  endcase

  
`endif


endmodule

