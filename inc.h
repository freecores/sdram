// Uncomment below to use the microprocessor bus simulator
// ====================
`define simulate_mp    

// Uncomment the below to enable the debug pins
// ====================
//`define show_debug


// Common definition stuff
`define     HI          1'b1
`define     LO          1'b0
`define X		                        1'bx

//***********************************************************
//  U  S  E  R    M  O  D  I  F  I  A  B  L  E  S
//***********************************************************

// The number of refreshses done at power up. 16 by default 
`define power_up_ref_cntr_limit         16       

// The number of refreshes done during normal refresh cycle.
// Set this to be 2048 for "burst"   refreshes, and 
// set this to be 1    for "regular" refreshes
`define auto_ref_cntr_limit             1       

// Refresh Frequency in Hz.
//   For burst  refresh use 33Hz    (30mS)
//   For normal refresh use 66666Hz (15uS)
`define Frefresh                        85000       

// SDRAM clock frequency in Hz.  
//  Set this to whatever the clock rate is
//`define Fsystem                         12500000      
`define Fsystem                         6250000      


// Clock divider
// Only choose one of these
//`define divide_by_2
`define divide_by_4
//`define divide_by_8

//***********************************************************
//  D O    N  O  T      M  O  D  I  F  Y
//***********************************************************
// Interval between refreshes in SDRAM clk ticks
`define RC                              `Fsystem/`Frefresh

// Width of the refresh counter. Default 20.  log2(`RC)/log2
// use 8 bits for 15uS interval with 12.5MHz clock
`define BW                              8
//`define BW 				20

// The refresh delay counter width
`define		RD			3

// This sets the number of delay cycles right after the refresh command
`define         AUTO_REFRESH_WIDTH	1

// MAin SDRAM controller state machine definition
`define     TS          4
`define     TSn         `TS-1

`define	state_idle	               `TS'b0001
`define	state_set_ras		       `TS'b0011
`define	state_ras_dly   	       `TS'b0010
`define	state_set_cas		       `TS'b0110
`define	state_cas_latency1	       `TS'b0111
`define	state_cas_latency2	       `TS'b0101
`define	state_write		       `TS'b0100
`define	state_read		       `TS'b1100
`define	state_auto_refresh	       `TS'b1101
`define	state_auto_refresh_dly	       `TS'b1111
`define	state_precharge		       `TS'b1110
`define	state_powerup		       `TS'b1010
`define	state_modeset		       `TS'b1011
`define state_cool_off		       `TS'b1001
`define state_x1                       `TS'b0000
`define state_x2                       `TS'b1000
//`define state_x3                       `TS'h10
//`define state_x4                       `TS'h11


// Fresh timer states
`define   state_count                3'b001
`define   state_halt                 3'b010
`define   state_reset                3'b100

