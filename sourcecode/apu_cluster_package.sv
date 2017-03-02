////////////////////////////////////////////////////////////////////////////////
// Copyright (C) 2017 ETH Zurich, University of Bologna                       //
// All rights reserved.                                                       //
//                                                                            //
// This code is under development and not yet released to the public.         //
// Until it is released, the code is under the copyright of ETH Zurich        //
// and the University of Bologna, and may contain unpublished work.           //
// Any reuse/redistribution should only be under explicit permission.         //
//                                                                            //
// Bug fixes and contributions will eventually be released under the          //
// SolderPad open hardware license and under the copyright of ETH Zurich      //
// and the University of Bologna.                                             //
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
   parameter PRIVATE_FP_DIV    = 0;
   parameter PRIVATE_FP_SQRT   = 0;
   parameter PRIVATE_FP_DIVSQRT= 0;

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
   parameter NUSFLAGS_ADDSUB  = 8;
   parameter WOP_ADDSUB       = 1;
         
   // mult
   parameter NDSFLAGS_MULT = 3;
   parameter NUSFLAGS_MULT = 8;
   parameter WOP_MULT      = 1;
   
   // casts
   parameter NDSFLAGS_CAST = 3;
   parameter NUSFLAGS_CAST = 8;
   parameter WOP_CAST      = 1;
   
   // mac
   parameter NDSFLAGS_MAC = 3;
   parameter NUSFLAGS_MAC = 8;
   parameter WOP_MAC      = 2;
   
   // div
   parameter NDSFLAGS_DIV = 3;
   parameter NUSFLAGS_DIV = 8;
   parameter WOP_DIV      = 1;
   
   // sqrt
   parameter NDSFLAGS_SQRT = 3;
   parameter NUSFLAGS_SQRT = 8;
   parameter WOP_SQRT      = 1;
   
   // iter divsqrt
   parameter NDSFLAGS_DIVSQRT = 3;
   parameter NUSFLAGS_DIVSQRT = 8;
   parameter WOP_DIVSQRT      = 1;
   
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
