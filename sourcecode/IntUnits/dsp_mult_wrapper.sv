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
// Design Name:    dsp_mult_wrappper                                          //
// Project Name:   Shared APU                                                 //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Wraps the dot-product multiplier in the shared unit        //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

import apu_cluster_package::*;

module dsp_mult_wrapper
#(
  parameter C_DSP_MULT_PIPE_REGS = 0,
  parameter TAG_WIDTH = 0
)
 (
  // Clock and Reset
  input  logic                   clk_i,
  input  logic                   rst_ni,

  input  logic                   En_i,
  
  input logic [DSP_OP_WIDTH-1:0] Op_i,
  input logic [DSP_WIDTH-1:0]    OpA_i,
  input logic [DSP_WIDTH-1:0]    OpB_i,
  input logic [DSP_WIDTH-1:0]    OpC_i,
  input logic [TAG_WIDTH-1:0]    Tag_i,

  input logic [1:0]              Flag_i,
  output logic [1:0]             Status_o,
  
  output logic [DSP_WIDTH-1:0]   Res_o,
  output logic [TAG_WIDTH-1:0]   Tag_o,
  output logic                   Valid_o,
  output logic                   Ready_o,
  input  logic                   Ack_i
 
);

   generate
      if (C_DSP_MULT_PIPE_REGS == 0) begin

         logic [DSP_WIDTH-1:0]    OpA, OpB, OpC;
         logic [DSP_OP_WIDTH-1:0] Op;
         logic [1:0]              Flag;
                                           
         assign OpA    = En_i ? OpA_i  : '0;
         assign OpB    = En_i ? OpB_i  : '0;
         assign OpC    = En_i ? OpC_i  : '0;
         assign Op     = En_i ? Op_i   : '0;
         assign Flag   = En_i ? Flag_i : '0;
        
         dsp_mult dsp_mult_i
           (
            .op_a_i(OpA),
            .op_b_i(OpB),
            .op_c_i(OpC),
            .dot_signed_i(Flag),
            .operator_i(Op),
            .result_o(Res_o)
            );
         
         assign Tag_o = Tag_i;
         assign Status_o = '0;
         assign Valid_o = En_i;
         assign Ready_o = 1'b1;
         
      end
      else begin
         
         // DISTRIBUTE PIPE REGS
         parameter C_PRE_PIPE_REGS   = C_DSP_MULT_PIPE_REGS;
         parameter C_POST_PIPE_REGS  = 0;

         // PRE PIPE REG SIGNALS
         logic [DSP_WIDTH-1:0]    OpA_DP     [C_PRE_PIPE_REGS+1];
         logic [DSP_WIDTH-1:0]    OpB_DP     [C_PRE_PIPE_REGS+1];
         logic [DSP_WIDTH-1:0]    OpC_DP     [C_PRE_PIPE_REGS+1];
         logic [1:0]              Flag_DP    [C_PRE_PIPE_REGS+1];
         logic [DSP_OP_WIDTH-1:0] Op_DP      [C_PRE_PIPE_REGS+1];
         logic                    En_SP      [C_PRE_PIPE_REGS+1];
         logic [TAG_WIDTH-1:0]    Tag_DP     [C_PRE_PIPE_REGS+1];
         
         // POST PIPE REG SIGNALS
         logic                    EnPost_SP       [C_POST_PIPE_REGS+1];
         logic [TAG_WIDTH-1:0]    TagPost_DP      [C_POST_PIPE_REGS+1];
         logic [DSP_WIDTH-1:0]    Res_DP          [C_POST_PIPE_REGS+1];
         
         // assign input. note: index [0] is not a register here!
         assign OpA_DP[0]    = En_i ? OpA_i :'0;
         assign OpB_DP[0]    = En_i ? OpB_i :'0;
         assign OpC_DP[0]    = En_i ? OpC_i :'0;
         assign Op_DP[0]     = En_i ? Op_i : '0;
         assign Flag_DP[0]   = En_i ? Flag_i : '0;
         assign En_SP[0]     = En_i;
         assign Tag_DP[0]    = Tag_i;
         
         // propagate states
         assign EnPost_SP[0]      = En_SP[C_PRE_PIPE_REGS]; 
         assign TagPost_DP[0]     = Tag_DP[C_PRE_PIPE_REGS];  

         // assign output
         assign Res_o             = Res_DP[C_POST_PIPE_REGS];
         assign Status_o          = '0;
         assign Valid_o           = EnPost_SP[C_POST_PIPE_REGS];
         assign Tag_o             = TagPost_DP[C_POST_PIPE_REGS];
         assign Ready_o           = 1'b1;

         dsp_mult dsp_mult_i
           (
            .op_a_i(OpA_DP[C_PRE_PIPE_REGS]),
            .op_b_i(OpB_DP[C_PRE_PIPE_REGS]),
            .op_c_i(OpC_DP[C_PRE_PIPE_REGS]),
            .dot_signed_i(Flag_DP[C_PRE_PIPE_REGS]),
            .operator_i(Op_DP[C_PRE_PIPE_REGS]),
            .result_o(Res_DP[0])
            );
         
         // PRE_PIPE_REGS
         for (genvar i=1; i <= C_PRE_PIPE_REGS; i++)  begin: g_pre_regs

            always_ff @(posedge clk_i or negedge rst_ni) begin : p_pre_regs
               if(~rst_ni) begin
                  En_SP[i]         <= '0;
                  OpA_DP[i]        <= '0;
                  OpB_DP[i]        <= '0;
                  OpC_DP[i]        <= '0;
                  Flag_DP[i]       <= '0;
                  Op_DP[i]         <= '0;
                  Tag_DP[i]        <= '0;
               end 
               else begin
                  // this one has to be always enabled...
                  En_SP[i]       <= En_SP[i-1];
                  
                  // enabled regs
                  if(En_SP[i-1]) begin
                     OpA_DP[i]       <= OpA_DP[i-1];
                     OpB_DP[i]       <= OpB_DP[i-1];
                     OpC_DP[i]       <= OpC_DP[i-1];
                     Flag_DP[i]      <= Flag_DP[i-1];
                     Op_DP[i]        <= Op_DP[i-1];
                     Tag_DP[i]       <= Tag_DP[i-1];
                  end
               end
            end
         end

         
         // POST_PIPE_REGS
         for (genvar j=1; j <= C_POST_PIPE_REGS; j++)  begin: g_post_regs

            always_ff @(posedge clk_i or negedge rst_ni) begin : p_post_regs
               if(~rst_ni) begin
                  EnPost_SP[j]     <= '0;
                  Res_DP[j]        <= '0;
                  TagPost_DP[j]    <= '0;
               end 
               else begin
                  // this one has to be always enabled...
                  EnPost_SP[j]       <= EnPost_SP[j-1];
                  
                  // enabled regs
                  if(EnPost_SP[j-1]) begin
                     Res_DP[j]       <= Res_DP[j-1];
                     TagPost_DP[j]   <= TagPost_DP[j-1];
                  end
               end
            end
         end

         
      end      
   endgenerate
   
endmodule
/* -----\/----- EXCLUDED -----\/-----

`define FASTDSP

`ifndef FASTDSP
   
   dsp_mult dsp_mult_i
     (
      
      .op_a_i(OpA_i),
      .op_b_i(OpB_i),
      .op_c_i(OpC_i),
      .dot_signed_i(Flag_i),
      .operator_i(Op_i),
      .result_o(Res_o)
      );
   
   assign Tag_o = Tag_i;
   assign Status_o = '0;
   assign Valid_o = En_i;
   assign Ready_o = 1'b1;
`else
   
   // DISTRIBUTE PIPE REGS
   parameter C_PRE_PIPE_REGS   = C_DSP_MULT_PIPE_REGS;
   parameter C_POST_PIPE_REGS  = 0;

   // PRE PIPE REG SIGNALS
   logic [DSP_WIDTH-1:0]    OpA_DP     [C_PRE_PIPE_REGS+1];
   logic [DSP_WIDTH-1:0]    OpB_DP     [C_PRE_PIPE_REGS+1];
   logic [DSP_WIDTH-1:0]    OpC_DP     [C_PRE_PIPE_REGS+1];
   logic [1:0]              Flag_DP    [C_PRE_PIPE_REGS+1];
   logic [DSP_OP_WIDTH-1:0] Op_DP      [C_PRE_PIPE_REGS+1];
   logic                    En_SP      [C_PRE_PIPE_REGS+1];
   logic [TAG_WIDTH-1:0]    Tag_DP     [C_PRE_PIPE_REGS+1];
   
   // POST PIPE REG SIGNALS
   logic                  EnPost_SP       [C_POST_PIPE_REGS+1];
   logic [TAG_WIDTH-1:0]  TagPost_DP      [C_POST_PIPE_REGS+1];
   logic [DSP_WIDTH-1:0]  Res_DP          [C_POST_PIPE_REGS+1];
   
   // assign input. note: index [0] is not a register here!
   assign OpA_DP[0]    = En_i ? OpA_i :'0;
   assign OpB_DP[0]    = En_i ? OpB_i :'0;
   assign OpC_DP[0]    = En_i ? OpC_i :'0;
   assign Op_DP[0]     = En_i ? Op_i : '0;
   assign Flag_DP[0]   = En_i ? Flag_i : '0;
   assign En_SP[0]     = En_i;
   assign Tag_DP[0]    = Tag_i;
   
   // propagate states
   assign EnPost_SP[0]      = En_SP[C_PRE_PIPE_REGS]; 
   assign TagPost_DP[0]     = Tag_DP[C_PRE_PIPE_REGS];  

   // assign output
   assign Res_o             = Res_DP[C_POST_PIPE_REGS];
   assign Status_o          = '0;
   assign Valid_o           = EnPost_SP[C_POST_PIPE_REGS];
   assign Tag_o             = TagPost_DP[C_POST_PIPE_REGS];
   assign Ready_o           = 1'b1;

   dsp_mult dsp_mult_i
     (
      .op_a_i(OpA_DP[C_PRE_PIPE_REGS]),
      .op_b_i(OpB_DP[C_PRE_PIPE_REGS]),
      .op_c_i(OpC_DP[C_PRE_PIPE_REGS]),
      .dot_signed_i(Flag_DP[C_PRE_PIPE_REGS]),
      .operator_i(Op_DP[C_PRE_PIPE_REGS]),
      .result_o(Res_DP[0])
      );
   
   // PRE_PIPE_REGS
   generate
    genvar i;
      for (i=1; i <= C_PRE_PIPE_REGS; i++)  begin: g_pre_regs

         always_ff @(posedge clk_i or negedge rst_ni) begin : p_pre_regs
            if(~rst_ni) begin
               En_SP[i]         <= '0;
               OpA_DP[i]        <= '0;
               OpB_DP[i]        <= '0;
               OpC_DP[i]        <= '0;
               Flag_DP[i]       <= '0;
               Op_DP[i]         <= '0;
               Tag_DP[i]        <= '0;
            end 
            else begin
               // this one has to be always enabled...
               En_SP[i]       <= En_SP[i-1];
               
               // enabled regs
               if(En_SP[i-1]) begin
                  OpA_DP[i]       <= OpA_DP[i-1];
                  OpB_DP[i]       <= OpB_DP[i-1];
                  OpC_DP[i]       <= OpC_DP[i-1];
                  Flag_DP[i]      <= Flag_DP[i-1];
                  Op_DP[i]        <= Op_DP[i-1];
                  Tag_DP[i]       <= Tag_DP[i-1];
               end
            end
         end
      end
   endgenerate

   
   // POST_PIPE_REGS
   generate
    genvar j;
      for (j=1; j <= C_POST_PIPE_REGS; j++)  begin: g_post_regs

         always_ff @(posedge clk_i or negedge rst_ni) begin : p_post_regs
            if(~rst_ni) begin
               EnPost_SP[j]     <= '0;
               Res_DP[j]        <= '0;
               TagPost_DP[j]    <= '0;
            end 
            else begin
               // this one has to be always enabled...
               EnPost_SP[j]       <= EnPost_SP[j-1];
               
               // enabled regs
               if(EnPost_SP[j-1]) begin
                  Res_DP[j]       <= Res_DP[j-1];
                  TagPost_DP[j]   <= TagPost_DP[j-1];
               end
            end
         end
      end
   endgenerate
`endif   
endmodule
 -----/\----- EXCLUDED -----/\----- */
