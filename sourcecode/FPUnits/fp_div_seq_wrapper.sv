////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Copyright 2018 ETH Zurich and University of Bologna.                       //
// Copyright and related rights are licensed under the Solderpad Hardware     //
// License, Version 0.51 (the "License"); you may not use this file except in //
// compliance with the License.  You may obtain a copy of the License at      //
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law  //
// or agreed to in writing, software, hardware and materials distributed under//
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR     //
// CONDITIONS OF ANY KIND, either express or implied. See the License for the //
// specific language governing permissions and limitations under the License. //
//                                                                            //
// Engineer:       Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                                                                            //
// Design Name:    fp_div_seq_wrapper                                         //
// Project Name:   Shared APU                                                 //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Wraps the sequential DW fp-div unit                        //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

import apu_cluster_package::*;

`include "../apu_defines.sv"


module fp_div_seq_wrapper
#(
  parameter C_DIV_PIPE_REGS = 2,
  parameter TAG_WIDTH = 0,
  parameter RND_WIDTH = NDSFLAGS_DIV,
  parameter STAT_WIDTH = NUSFLAGS_DIV
)
 (
  // Clock and Reset
  input  logic                  clk_i,
  input  logic                  rst_ni,

  input  logic                  En_i,
  
  input logic [FP_WIDTH-1:0]    OpA_i,
  input logic [FP_WIDTH-1:0]    OpB_i,
  input logic [TAG_WIDTH-1:0]   Tag_i,
 
  input logic [RND_WIDTH-1:0]   Rnd_i,
  output logic [STAT_WIDTH-1:0] Status_o,

  output logic [FP_WIDTH-1:0]   Res_o,
  output logic [TAG_WIDTH-1:0]  Tag_o,
  output logic                  Valid_o,
  output logic                  Ready_o
 
);

   // PIPE REG SIGNALS
   logic                 En_SP      [C_DIV_PIPE_REGS+1];
   logic [TAG_WIDTH-1:0] Tag_DP     [C_DIV_PIPE_REGS+1];

   logic                 idle_dp, idle_dn;
   
   // assign input. note: index [0] is not a register here!
   assign En_SP[0]     = En_i;
   assign Tag_DP[0]    = Tag_i;
   
   assign Tag_o             = Tag_DP[C_DIV_PIPE_REGS];

   assign Ready_o           = Valid_o | idle_dp;
   
   always_comb begin
      idle_dn = 1'b1;

      if (En_i)
        idle_dn = 1'b0;
      if (Valid_o)
        if (En_i)
          idle_dn = 1'b0;
        else
          idle_dn = 1'b1;      
   end
   
   // Instance of DW_fp_div_seq
   DW_fp_div_seq
     #(
       .inst_sig_width(SIG_WIDTH),
       .inst_exp_width(EXP_WIDTH),
       .inst_ieee_compliance(IEEE_COMP),
       .inst_num_cyc(C_DIV_PIPE_REGS+2),
       .inst_rst_mode(0),
       .inst_input_mode(1),
       .inst_output_mode(0),
       .inst_early_start(1),
       .inst_internal_reg(1)
       )
   fp_div_i
     (
      .a(OpA_i),
      .b(OpB_i),
      .rnd(Rnd_i),
      .clk(clk_i),
      .rst_n(rst_ni),
      .start(En_i),
      .z(Res_o),
      .status(Status_o),
      .complete(Valid_o)
      );


   always_ff @(posedge clk_i or negedge rst_ni) begin
      if(~rst_ni)
        idle_dp        <= '0;
      else
        idle_dp        <= idle_dn;
   end
         
   // PIPE_REGS
   generate
    genvar i;
      for (i=1; i <= C_DIV_PIPE_REGS; i++)  begin: g_pre_regs

         always_ff @(posedge clk_i or negedge rst_ni) begin : p_pre_regs
            if(~rst_ni) begin
               En_SP[i]         <= '0;
               Tag_DP[i]        <= '0;
            end 
            else begin
               // this one has to be always enabled...
               En_SP[i]       <= En_SP[i-1];
               
               // enabled regs
               if(En_SP[i-1]) begin
                  Tag_DP[i]       <= Tag_DP[i-1];
               end
            end
         end
      end
   endgenerate
   
endmodule
