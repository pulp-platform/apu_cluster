////////////////////////////////////////////////////////////////////////////////
// Copyright (C) 2017 ETH Zurich, University of Bologna                       //
// All rights reserved.                                                       //
//                                                                            //
// This code is under development and not yet released to the public.         //
// Until it is released, the code is under the copyright of ETH Zurich and    //
// the University of Bologna, and may contain confidential and/or unpublished //
// work. Any reuse/redistribution is strictly forbidden without written       //
// permission from ETH Zurich.                                                //
//                                                                            //
// Bug fixes and contributions will eventually be released under the          //
// SolderPad open hardware license in the context of the PULP platform        //
// (http://www.pulp-platform.org), under the copyright of ETH Zurich and the  //
// University of Bologna.                                                     //
//                                                                            //
// Engineer:       Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                                                                            //
// Design Name:    int_mult_wrappper                                          //
// Project Name:   Shared APU                                                 //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Wraps the integer multiplier in the shared unit            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

import apu_cluster_package::*;

module int_mult_wrapper
#(
  parameter TAG_WIDTH = 0
)
 (
  // Clock and Reset
  input  logic                   clk_i,
  input  logic                   rst_ni,

  input  logic                   En_i,
  
  input logic [WOP_INT_MULT-1:0] Op_i,
  input logic [DSP_WIDTH-1:0]    OpA_i,
  input logic [DSP_WIDTH-1:0]    OpB_i,
  input logic [DSP_WIDTH-1:0]    OpC_i,
  input logic [TAG_WIDTH-1:0]    Tag_i,

  input  logic [NDSFLAGS_INT_MULT-1:0] Flags_i,
  output logic [1:0]             Status_o,
  
  output logic [DSP_WIDTH-1:0]   Res_o,
  output logic [TAG_WIDTH-1:0]   Tag_o,
  output logic                   Valid_o,
  output logic                   Ready_o,
  input  logic                   Ack_i
 
);

   logic [DSP_WIDTH-1:0]         OpA, OpB, OpC;
   logic [DSP_OP_WIDTH-1:0]      Op;
   
   assign OpA    = En_i ? OpA_i  : '0;
   assign OpB    = En_i ? OpB_i  : '0;
   assign OpC    = En_i ? OpC_i  : '0;
   assign Op     = En_i ? Op_i   : '0;
   
   int_mult int_mult_i
     (
      .op_a_i(OpA),
      .op_b_i(OpB),
      .op_c_i(OpC),
      
      .short_subword_i(Flags_i[0]),
      .short_signed_i(Flags_i[2:1]),
      .imm_i(Flags_i[7:3]),
      
      .operator_i(Op),
      .result_o(Res_o)
      );
   
   assign Tag_o = Tag_i;
   assign Status_o = '0;
   assign Valid_o = En_i;
   assign Ready_o = 1'b1;
   
endmodule