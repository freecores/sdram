//
//  Common Definition File for the SDRAM TEST
//
//


//******* Allow showing of debug signals
//`define do_debug

//******* Allow the micro bus model to have queues for read and write
//`define allow_queue

/*
** SELECT TEST TO PERFORM
** Select only one of the below comment
**
*/
// ***************************************************************
// This test repeats indefinitely, a write followed by a read.
// ***************************************************************
//`define do_read_write_test


// ***************************************************************
// This test does a burst write, followed by a delay (enough to
// fit a few refresh cycles) then burst read of the same memory
// areas.  This pattern of write-read repeats indefinitely
// ***************************************************************
//`define do_burst_write_read_test
			

// ***************************************************************
// This test does a one time  burst write, followed by a delay (enough to
// fit a few refresh cycles) then burst read of the same memory
// areas.  The burst reads are repeating.
// ***************************************************************
//`define do_single_burst_write_read_test


// ***************************************************************
// This test exercises the entire content of the SDRAM.
// A pseudo-random-number-generator is used to generate the data
// patern which is written to the SDRAM.  Then, the data is read
// back and compared to the psedo random number.
// ***************************************************************
`define do_full_test

//  C  O  M  M  O  N       S  T  U  F  F   
`define     HI                  1'b1
`define     LO                  1'b0

//  B  U  S    C  O  N  T  R  O  L  L  E  R  
// This defines the bit width of the bus controller State Machine
`define     MN                   3
`define     MNn                  `MN-1
// This defines the states of the state machine
`define     state_idle          `MN'b001
`define     state_assert_addx   `MN'b010
`define     state_wr_l          `MN'b011
`define     state_wr_h          `MN'b110
`define     state_rd_l          `MN'b111
`define     state_rd_h          `MN'b101
`define     state_deassert_addx `MN'b100
`define     xxxx                `MN'b000

