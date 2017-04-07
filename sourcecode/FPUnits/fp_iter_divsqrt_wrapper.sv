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
// Design Name:    fp_iter_divsqrt_wrapper                                    //
// Project Name:   Shared APU                                                 //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Wraps the iterative shared fp-div-sqrt unit                //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

import apu_cluster_package::*;

`include "../apu_defines.sv"


module fp_iter_divsqrt_wrapper
#(
  parameter TAG_WIDTH = 0,
  parameter RND_WIDTH = NDSFLAGS_DIVSQRT,
  parameter STAT_WIDTH = NUSFLAGS_DIVSQRT
)
 (
  // Clock and Reset
  input  logic                  clk_i,
  input  logic                  rst_ni,

  input  logic                  En_i,
  
  input logic [FP_WIDTH-1:0]    OpA_i,
  input logic [FP_WIDTH-1:0]    OpB_i,

  input logic                   sqrt_sel_i,

  input logic [TAG_WIDTH-1:0]   Tag_i,
 
  input logic [RND_WIDTH-1:0]   Rnd_i,
  output logic [STAT_WIDTH-1:0] Status_o,

  output logic [FP_WIDTH-1:0]   Res_o,
  output logic [TAG_WIDTH-1:0]  Tag_o,
  output logic                  Valid_o,
  output logic                  Ready_o
 
);

   logic [TAG_WIDTH-1:0] Tag_DP;

   logic                 div_start;
   logic                 sqrt_start;
   logic                 divsqrt_ready;
   
   logic                 div_zero;
   logic                 exp_of;
   logic                 exp_uf;
   
   // generate inputs
   assign div_start = En_i & ~sqrt_sel_i;
   assign sqrt_start = En_i & sqrt_sel_i;
   
   
   // assign output
   assign Tag_o             = Tag_DP;
   assign Status_o          = {div_zero, exp_of, exp_uf, 1'b0};
   assign Ready_o           = divsqrt_ready;
   
   
   div_sqrt_top fp_divsqrt_i
     (
      .Clk_CI(clk_i),
      .Rst_RBI(rst_ni),
      .Div_start_SI(div_start),
      .Sqrt_start_SI(sqrt_start),
      .Operand_a_DI(OpA_i),
      .Operand_b_DI(OpB_i),
      .RM_SI(Rnd_i[1:0]),
      .Result_DO(Res_o),
      .Exp_OF_SO(exp_uf),
      .Exp_UF_SO(exp_of),
      .Div_zero_SO(div_zero),
      .Ready_SO(divsqrt_ready),
      .Done_SO(Valid_o)
      );

   // store Tag
   always_ff @(posedge clk_i or negedge rst_ni)
     if(~rst_ni) begin
        Tag_DP          <= '0;
     end 
     else begin
        if(En_i) begin
           Tag_DP       <= Tag_i;
        end
     end
   
endmodule
