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
// Design Name:    apu_cluster_package                                        //
// Project Name:   Shared APU                                                 //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    package for apu cluster                                    //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

package apu_cluster_package;

   // set this parameter to define 1 shared unit per core (private)
   parameter PRIVATE_FP_ADDSUB = 0;
   parameter PRIVATE_FP_MULT   = 0;
   parameter PRIVATE_FP_MAC    = 0;
   parameter PRIVATE_FP_CAST   = 0;
   parameter PRIVATE_FP_DIV    = 0;    // this is also used for 'old' shared divsqrt
   parameter PRIVATE_FP_SQRT   = 0;
   parameter PRIVATE_FPNEW     = 1;    // don't share fpnew by default
   parameter PRIVATE_FP_DIVSQRT= 0;    // use this for shared FPnew divsqrt


   // DSP-general
   parameter DSP_WIDTH    = 32;
   parameter DSP_OP_WIDTH = 3;

   // FP-general
   parameter FP_WIDTH     = 32;
   parameter SIG_WIDTH    = 23;
   parameter EXP_WIDTH    = 8;
   parameter IEEE_COMP    = 1;

   // number of pipeline registers for each unit.
   // if modified the core dispatcher might need adjustments!
   parameter C_SQRT_PIPE_REGS   = 5;
   parameter C_ADDSUB_PIPE_REGS = 1;
   parameter C_MULT_PIPE_REGS   = 1;
   parameter C_MAC_PIPE_REGS    = 2;
   parameter C_CAST_PIPE_REGS   = 1;
   parameter C_DIV_PIPE_REGS    = 3;
   parameter C_DSP_PIPE_REGS    = 1;

   // DSP-Mult
   parameter NDSFLAGS_DSP_MULT  = 2;
   parameter NUSFLAGS_DSP_MULT  = 0;
   parameter WOP_DSP_MULT       = 3;

   // Int-Mult
   parameter NDSFLAGS_INT_MULT  = 8;
   parameter NUSFLAGS_INT_MULT  = 0;
   parameter WOP_INT_MULT       = 3;

   // Int-div
   parameter NDSFLAGS_INT_DIV   = 0;
   parameter NUSFLAGS_INT_DIV   = 0;
   parameter WOP_INT_DIV        = 3;

   // addsub
   parameter NDSFLAGS_ADDSUB  = 3;
   parameter NUSFLAGS_ADDSUB  = 5;
   parameter WOP_ADDSUB       = 1;

   // mult
   parameter NDSFLAGS_MULT = 3;
   parameter NUSFLAGS_MULT = 5;
   parameter WOP_MULT      = 1;

   // casts
   parameter NDSFLAGS_CAST = 3;
   parameter NUSFLAGS_CAST = 5;
   parameter WOP_CAST      = 1;

   // mac
   parameter NDSFLAGS_MAC = 3;
   parameter NUSFLAGS_MAC = 5;
   parameter WOP_MAC      = 2;

   // div
   parameter NDSFLAGS_DIV = 3;
   parameter NUSFLAGS_DIV = 5;
   parameter WOP_DIV      = 1;

   // sqrt
   parameter NDSFLAGS_SQRT = 3;
   parameter NUSFLAGS_SQRT = 5;
   parameter WOP_SQRT      = 1;

   // FPnew - MATCH THESE TO THE ONES IN riscv_defines OR BETTER TAKE FROM THERE
   parameter bit C_RVF = 1'b1; // Is F extension enabled
   parameter bit C_RVD = 1'b0; // Is D extension enabled - NOT SUPPORTED CURRENTLY

   parameter bit C_XF16    = 1'b1; // Is half-precision float extension (Xf16) enabled
   parameter bit C_XF16ALT = 1'b1; // Is alternative half-precision float extension (Xf16alt) enabled
   parameter bit C_XF8     = 1'b1; // Is quarter-precision float extension (Xf8) enabled
   parameter bit C_XFVEC   = 1'b1; // Is vectorial float extension (Xfvec) enabled

   parameter C_FPNEW_OPBITS   = 4;
   parameter C_FPNEW_FMTBITS  = 3;
   parameter C_FPNEW_IFMTBITS = 2;

   parameter logic [30:0] C_LAT_FP64       = 'd0;
   parameter logic [30:0] C_LAT_FP32       = 'd1;
   parameter logic [30:0] C_LAT_FP16       = 'd1;
   parameter logic [30:0] C_LAT_FP16ALT    = 'd1;
   parameter logic [30:0] C_LAT_FP8        = 'd0;
   parameter logic [30:0] C_LAT_DIVSQRT    = 'd1; // divsqrt post-processing pipe
   parameter logic [30:0] C_LAT_CONV       = 'd0;
   parameter logic [30:0] C_LAT_NONCOMP    = 'd0;

   parameter C_RM = 3;

   parameter NDSFLAGS_FPNEW  = 11; // TODO TAKE THIS FROM VALUES IN riscv_defines
   parameter NUSFLAGS_FPNEW  = 5;
   parameter WOP_FPNEW       = 4; // TODO TAKE THIS FROM VALUES IN riscv_defines

   // iter divsqrt - used with FPnew
   parameter NDSFLAGS_DIVSQRT = NDSFLAGS_FPNEW;
   parameter NUSFLAGS_DIVSQRT = NUSFLAGS_FPNEW;
   parameter WOP_DIVSQRT      = WOP_FPNEW;

   // FP-defines
   parameter C_NAN_P     = 32'h7fc00000;
   parameter C_NAN_N     = 32'hffc00000;
   parameter C_ZERO_P    = 32'h00000000;
   parameter C_ZERO_N    = 32'h80000000;
   parameter C_INF_P     = 32'h7f800000;
   parameter C_INF_N     = 32'hff800000;
   parameter C_MAX_INT   = 32'h7fffffff;
   parameter C_MIN_INT   = 32'h80000000;
   parameter C_MAX_INT_F = (2**31)-1;
   parameter C_MIN_INT_F = -(2**31);


endpackage // apu_cluster_package
