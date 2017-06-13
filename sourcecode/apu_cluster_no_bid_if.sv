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
// Design Name:    apu_cluster                                                //
// Project Name:   shared APU                                                 //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Wrapper for all shared execution units, arbiters, and      //
//                 interconnect                                               //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

import apu_cluster_package::*;

module apu_cluster
  #(
    parameter C_NB_CORES         = 4,
    parameter NDSFLAGS_CPU       = 0,
    parameter NUSFLAGS_CPU       = 0,
    parameter WOP_CPU            = 0,
    parameter NARGS_CPU          = 0,
    parameter WAPUTYPE           = 0,
    parameter SHARED_FP          = 0,
    parameter SHARED_DSP_MULT    = 0,
    parameter SHARED_INT_MULT    = 0,
    parameter SHARED_INT_DIV     = 0,
    parameter SHARED_FP_DIVSQRT  = 0
    )
   (
    // Clock and Reset
    input  logic                  clk_i,
    input  logic                  rst_ni,

    cpu_marx_if.marx              cpus [C_NB_CORES-1:0]
   
    );

   localparam WAPUTAG = $clog2(C_NB_CORES);
   localparam WCPUTAG = 0;
   
   localparam integer NAPUS_DSP_MULT = (C_NB_CORES==2)      ? 1 : C_NB_CORES/2;
   localparam integer NAPUS_INT_MULT = (C_NB_CORES==2)      ? 1 : C_NB_CORES/2;
   localparam integer NAPUS_INT_DIV  = (C_NB_CORES==2)      ? 1 : C_NB_CORES/4;
   localparam integer NAPUS_ADDSUB   = (PRIVATE_FP_ADDSUB)  ? C_NB_CORES : (C_NB_CORES<=4) ? 1 : C_NB_CORES/8;
   localparam integer NAPUS_MULT     = (PRIVATE_FP_MULT)    ? C_NB_CORES : (C_NB_CORES<=4) ? 1 : C_NB_CORES/8;
   localparam integer NAPUS_CAST     = (PRIVATE_FP_CAST)    ? C_NB_CORES : (C_NB_CORES<=4) ? 1 : C_NB_CORES/8;
   localparam integer NAPUS_MAC      = (PRIVATE_FP_MAC)     ? C_NB_CORES : (C_NB_CORES<=4) ? 1 : C_NB_CORES/4;
   localparam integer NAPUS_DIV      = (PRIVATE_FP_DIV)     ? C_NB_CORES : 1;
   localparam integer NAPUS_SQRT     = (PRIVATE_FP_SQRT)    ? C_NB_CORES : 1;
   localparam integer NAPUS_DIVSQRT  = (PRIVATE_FP_DIVSQRT) ? C_NB_CORES : 1;


   // careful when modifying the following parameters. C_APUTYPES has to match with what is defined in apu_package.sv, and the individual types have to match what is defined in the core (riscv_decoder.sv)
   localparam APUTYPE_DSP_MULT   = (SHARED_DSP_MULT) ? 0 : 0;
   localparam APUTYPE_INT_MULT   = (SHARED_INT_MULT) ? SHARED_DSP_MULT : 0;
   localparam APUTYPE_INT_DIV    = (SHARED_INT_DIV) ? SHARED_DSP_MULT + SHARED_INT_MULT : 0;

   localparam APUTYPE_FP         = (SHARED_FP) ? SHARED_DSP_MULT + SHARED_INT_MULT + SHARED_INT_DIV : 0;

   localparam APUTYPE_ADDSUB     = (SHARED_FP) ? APUTYPE_FP   : 0;
   localparam APUTYPE_MULT       = (SHARED_FP) ? APUTYPE_FP+1  : 0;
   localparam APUTYPE_CAST       = (SHARED_FP) ? APUTYPE_FP+2  : 0;
   localparam APUTYPE_MAC        = (SHARED_FP) ? APUTYPE_FP+3  : 0;
   localparam APUTYPE_DIV        = (SHARED_FP_DIVSQRT==1) ? APUTYPE_FP+4 : 0;
   localparam APUTYPE_SQRT       = (SHARED_FP_DIVSQRT==1) ? APUTYPE_FP+5 : 0;
   localparam APUTYPE_DIVSQRT    = (SHARED_FP_DIVSQRT==2) ? APUTYPE_FP+4 : 0;

   localparam C_APUTYPES   = (SHARED_FP) ? (SHARED_FP_DIVSQRT==1) ? APUTYPE_FP+6 : (SHARED_FP_DIVSQRT==2) ? APUTYPE_FP+5 : APUTYPE_FP+4 : SHARED_DSP_MULT + SHARED_INT_DIV + SHARED_INT_MULT;

   cpu_marx_if
     #(
       .WOP_CPU(WOP_CPU),
       .WAPUTYPE(WAPUTYPE),
			 .NUSFLAGS_CPU(NUSFLAGS_CPU),
			 .NDSFLAGS_CPU(NDSFLAGS_CPU),
       .NARGS_CPU(NARGS_CPU)
       )
   marx_ifs [C_APUTYPES*C_NB_CORES-1:0] ();
   //marx_ifs [C_APUTYPES-1:0][C_NB_CORES-1:0] ();


   //////////////////////////
   // multi-marx splitter  //
   //////////////////////////

   logic                          cpus_ack_ds    [C_NB_CORES-1:0];
   
   logic [31:0]                   cpus_result_us [C_NB_CORES-1:0];
   logic [NDSFLAGS_CPU-1:0]       cpus_flags_us  [C_NB_CORES-1:0];
   logic [WCPUTAG-1:0]            cpus_tag_us    [C_NB_CORES-1:0];
   logic                          cpus_valid_us  [C_NB_CORES-1:0];
   
   logic                          marx_ack_ds    [C_APUTYPES-1:0][C_NB_CORES-1:0];
   
   logic [31:0]                   marx_result_us [C_APUTYPES-1:0][C_NB_CORES-1:0];
   logic [NUSFLAGS_CPU-1:0]       marx_flags_us  [C_APUTYPES-1:0][C_NB_CORES-1:0];
   logic [WCPUTAG-1:0]            marx_tag_us    [C_APUTYPES-1:0][C_NB_CORES-1:0];
   logic                          marx_valid_us  [C_APUTYPES-1:0][C_NB_CORES-1:0];

   // assign cpu -> marx signals, temp signals
   generate
      for (genvar i = 0; i < C_NB_CORES; i++) begin
         for (genvar j = 0; j < C_APUTYPES; j++) begin
            // downstream
            assign marx_ifs[i*C_APUTYPES+j].req_ds_s        = cpus[i].req_ds_s;
            assign marx_ifs[i*C_APUTYPES+j].type_ds_d       = cpus[i].type_ds_d;
            assign marx_ifs[i*C_APUTYPES+j].operands_ds_d   = cpus[i].operands_ds_d;
            assign marx_ifs[i*C_APUTYPES+j].op_ds_d         = cpus[i].op_ds_d;
            assign marx_ifs[i*C_APUTYPES+j].flags_ds_d      = cpus[i].flags_ds_d;
            assign marx_ifs[i*C_APUTYPES+j].tag_ds_d        = cpus[i].tag_ds_d;

            // ready signal from upstream interface
            assign marx_ifs[i*C_APUTYPES+j].ready_us_s      = cpus[i].ready_us_s;

            // temps
            assign marx_ack_ds[j][i]              = marx_ifs[i*C_APUTYPES+j].ack_ds_s;

            assign marx_result_us[j][i]           = marx_ifs[i*C_APUTYPES+j].result_us_d;
            assign marx_flags_us[j][i]            = marx_ifs[i*C_APUTYPES+j].flags_us_d;
            assign marx_tag_us[j][i]              = marx_ifs[i*C_APUTYPES+j].tag_us_d;
            assign marx_valid_us[j][i]            = marx_ifs[i*C_APUTYPES+j].valid_us_s;
         end

         assign cpus[i].ack_ds_s                 = cpus_ack_ds[i];

         assign cpus[i].result_us_d              = cpus_result_us[i];
         assign cpus[i].flags_us_d               = cpus_flags_us[i];
         assign cpus[i].tag_us_d                 = cpus_tag_us[i];
         assign cpus[i].valid_us_s               = cpus_valid_us[i];
      end
   endgenerate

   
   logic ack_temp [C_NB_CORES-1:0];
   logic valid_temp [C_NB_CORES-1:0];
   
   generate
      for (genvar i = 0; i < C_NB_CORES; i++) begin
         
         always_comb begin

            ack_temp[i]         = 1'b0;
            valid_temp[i]       = 1'b0;
            cpus_result_us[i]   = '0;
            cpus_flags_us[i]    = '0;
            cpus_tag_us[i]      = '0;
            
            for (int j = 0; j < C_APUTYPES; j++) begin
               // upstream interface
               if (marx_valid_us[j][i]) begin
                  valid_temp[i]       = 1'b1;
                  cpus_result_us[i]   = marx_result_us[j][i];
                  cpus_flags_us[i]    = marx_flags_us[j][i];
                  cpus_tag_us[i]      = marx_tag_us[j][i];
               end

               // ack for downstream request
               if (marx_ack_ds[j][i])
                 ack_temp[i]          = 1'b1;
               
            end
         end

         assign cpus_valid_us[i] = valid_temp[i];
         assign cpus_ack_ds[i]   = ack_temp[i];
         
      end
   endgenerate
   
   
   ///////////////////////////////////
   //     _    ____  _   _ ____     //
   //    / \  |  _ \| | | | ___|    //
   //   / _ \ | |_) | | | |___ \    //
   //  / ___ \|  __/| |_| |___) |   //
   // /_/   \_\_|    \___/_____/    //
   //                               //
   ///////////////////////////////////

   /////////////////////////////////////////////////////////////////
   // DSP - Units                                                    
   // --------------------------------------------------------------
   // DSP-mult, DSP-alu                                              
   /////////////////////////////////////////////////////////////////

   // DSP_MULT
   marx_apu_if
     #(
       .WOP(WOP_DSP_MULT),
       .NARGS(3),
       .NUSFLAGS(NUSFLAGS_DSP_MULT),
       .NDSFLAGS(NDSFLAGS_DSP_MULT),
       .WAPUTAG(WAPUTAG)
       )
   dsp_mult_ifs [NAPUS_DSP_MULT-1:0] ();

   generate
      if (SHARED_DSP_MULT == 1) begin : shared_dsp

   marx
     #(
       .NCPUS(C_NB_CORES),
       .NAPUS(NAPUS_DSP_MULT),
       .NARB(NAPUS_DSP_MULT),
       .APUTYPE(APUTYPE_DSP_MULT),

       .WOP(WOP_DSP_MULT),
       .WAPUTAG(WAPUTAG),
       .NARGS(3),
       .NUSFLAGS(NUSFLAGS_DSP_MULT),
       .NDSFLAGS(NDSFLAGS_DSP_MULT)
       )
   marx_dsp_mult_i
     (
      .clk_ci(clk_i),
      .rst_rbi(rst_ni),
      .cpus(marx_ifs[APUTYPE_DSP_MULT*C_NB_CORES+C_NB_CORES-1:APUTYPE_DSP_MULT*C_NB_CORES]),
      .apus(dsp_mult_ifs)
      );
   
   // DSP_MULT_WRAPPER
      for (genvar i = 0; i < NAPUS_DSP_MULT; i++)
        begin : dsp_mult_wrap
           dsp_mult_wrapper
             #(
               .C_DSP_MULT_PIPE_REGS(C_DSP_PIPE_REGS),
               .TAG_WIDTH(WAPUTAG)
               )
           dsp_mult_wrap_i
             (
              .clk_i            ( clk_i                            ),
              .rst_ni           ( rst_ni                           ),
              .En_i             ( dsp_mult_ifs[i].valid_ds_s       ),
              .Op_i             ( dsp_mult_ifs[i].op_ds_d          ),
              .OpA_i            ( dsp_mult_ifs[i].operands_ds_d[0] ),
              .OpB_i            ( dsp_mult_ifs[i].operands_ds_d[1] ),
              .OpC_i            ( dsp_mult_ifs[i].operands_ds_d[2] ),
              .Flag_i           ( dsp_mult_ifs[i].flags_ds_d       ),
              .Status_o         ( dsp_mult_ifs[i].flags_us_d       ),
              .Tag_i            ( dsp_mult_ifs[i].tag_ds_d         ),
              .Res_o            ( dsp_mult_ifs[i].result_us_d      ),
              .Tag_o            ( dsp_mult_ifs[i].tag_us_d         ),
              .Valid_o          ( dsp_mult_ifs[i].req_us_s         ),
              .Ready_o          ( dsp_mult_ifs[i].ready_ds_s       ),
              .Ack_i            ( dsp_mult_ifs[i].ack_us_s         )

              );
        end
      end
   endgenerate

   /////////////////////////////////////////////////////////////////
   // INT - Units                                                    
   // --------------------------------------------------------------
   // INT-mult, INT-Div, INT-alu (future)                                              
   /////////////////////////////////////////////////////////////////

   // INT_MULT
   marx_apu_if
     #(
       .WOP(WOP_INT_MULT),
       .NARGS(3),
       .NUSFLAGS(NUSFLAGS_INT_MULT),
       .NDSFLAGS(NDSFLAGS_INT_MULT),
       .WAPUTAG(WAPUTAG)
       )
   int_mult_ifs [NAPUS_INT_MULT-1:0] ();

   generate
      if (SHARED_INT_MULT == 1) begin : shared_int_mult
         
   marx
     #(
       .NCPUS(C_NB_CORES),
       .NAPUS(NAPUS_INT_MULT),
       .NARB(NAPUS_INT_MULT),
       .APUTYPE(APUTYPE_INT_MULT),

       .WOP(WOP_INT_MULT),
       .WAPUTAG(WAPUTAG),
       .NARGS(3),
       .NUSFLAGS(NUSFLAGS_INT_MULT),
       .NDSFLAGS(NDSFLAGS_INT_MULT)
       )
   marx_int_mult_i
     (
      .clk_ci(clk_i),
      .rst_rbi(rst_ni),
      .cpus(marx_ifs[APUTYPE_INT_MULT*C_NB_CORES+C_NB_CORES-1:APUTYPE_INT_MULT*C_NB_CORES]),
      .apus(int_mult_ifs)
      );
   
   // INT_MULT_WRAPPER
      for (genvar i = 0; i < NAPUS_INT_MULT; i++)
        begin : int_mult_wrap
           int_mult_wrapper
             #(
               .TAG_WIDTH(WAPUTAG)
               )  
           int_mult_wrap_i
             (
              .clk_i            ( clk_i                            ),
              .rst_ni           ( rst_ni                           ),
              .En_i             ( int_mult_ifs[i].valid_ds_s       ),
              .Op_i             ( int_mult_ifs[i].op_ds_d          ),
              .OpA_i            ( int_mult_ifs[i].operands_ds_d[0] ),
              .OpB_i            ( int_mult_ifs[i].operands_ds_d[1] ),
              .OpC_i            ( int_mult_ifs[i].operands_ds_d[2] ),
              .Flags_i          ( int_mult_ifs[i].flags_ds_d       ),
              .Status_o         ( int_mult_ifs[i].flags_us_d       ),
              .Tag_i            ( int_mult_ifs[i].tag_ds_d         ),
              .Res_o            ( int_mult_ifs[i].result_us_d      ),
              .Tag_o            ( int_mult_ifs[i].tag_us_d         ),
              .Valid_o          ( int_mult_ifs[i].req_us_s         ),
              .Ready_o          ( int_mult_ifs[i].ready_ds_s       ),
              .Ack_i            ( int_mult_ifs[i].ack_us_s         )

              );
        end
      end
   endgenerate

   // INT_DIV
   marx_apu_if
     #(
       .WOP(WOP_INT_DIV),
       .NARGS(3),
       .NUSFLAGS(NUSFLAGS_INT_DIV),
       .NDSFLAGS(NDSFLAGS_INT_DIV),
       .WAPUTAG(WAPUTAG)
       )
   int_div_ifs [NAPUS_INT_DIV-1:0] ();

   generate
      if (SHARED_INT_DIV == 1) begin : shared_int_div
         
   marx
     #(
       .NCPUS(C_NB_CORES),
       .NAPUS(NAPUS_INT_DIV),
       .NARB(NAPUS_INT_DIV),
       .APUTYPE(APUTYPE_INT_DIV),

       .WOP(WOP_INT_DIV),
       .WAPUTAG(WAPUTAG),
       .NARGS(2),
       .NUSFLAGS(NUSFLAGS_INT_DIV),
       .NDSFLAGS(NDSFLAGS_INT_DIV)
       )
   marx_int_div_i
     (
      .clk_ci(clk_i),
      .rst_rbi(rst_ni),
      .cpus(marx_ifs[APUTYPE_INT_DIV*C_NB_CORES+C_NB_CORES-1:APUTYPE_INT_DIV*C_NB_CORES]),
      .apus(int_div_ifs)
      );
   
   // INT_DIV_WRAPPER
      for (genvar i = 0; i < NAPUS_INT_DIV; i++)
        begin : int_div_wrap
           int_div
             #(
               .TAG_WIDTH(WAPUTAG)
               )  
           int_div_i
             (
              .clk_i            ( clk_i                           ),
              .rst_ni           ( rst_ni                          ),
              .En_i             ( int_div_ifs[i].valid_ds_s       ),
              .Op_i             ( int_div_ifs[i].op_ds_d          ),
              .OpA_i            ( int_div_ifs[i].operands_ds_d[0] ),
              .OpB_i            ( int_div_ifs[i].operands_ds_d[1] ),
              .Status_o         ( int_div_ifs[i].flags_us_d       ),
              .Tag_i            ( int_div_ifs[i].tag_ds_d         ),
              .Res_o            ( int_div_ifs[i].result_us_d      ),
              .Tag_o            ( int_div_ifs[i].tag_us_d         ),
              .Valid_o          ( int_div_ifs[i].req_us_s         ),
              .Ready_o          ( int_div_ifs[i].ready_ds_s       )

              );
        end
      end
   endgenerate
   
   /////////////////////////////////////////////////////////////////
   // FP - Units                                                     
   // --------------------------------------------------------------
   // FP-Addsub, FP-mul, FP-mac, FP-cast, FP-div, FP-sqrt            
   /////////////////////////////////////////////////////////////////

   // FP_SQRT
   marx_apu_if
     #(
       .WOP(WOP_SQRT),
       .NARGS(1),
       .NUSFLAGS(NUSFLAGS_SQRT),
       .NDSFLAGS(NDSFLAGS_SQRT),
       .WAPUTAG(WAPUTAG)
       )
   sqrt_ifs [NAPUS_SQRT-1:0] ();

   // FP_div
   marx_apu_if
     #(
       .WOP(WOP_DIV),
       .NARGS(2),
       .NUSFLAGS(NUSFLAGS_DIV),
       .NDSFLAGS(NDSFLAGS_DIV),
       .WAPUTAG(WAPUTAG)
       )
   div_ifs [NAPUS_DIV-1:0] ();
   
   // FP_DIVSQRT
   marx_apu_if
     #(
       .WOP(WOP_DIVSQRT),
       .NARGS(2),
       .NUSFLAGS(NUSFLAGS_DIVSQRT),
       .NDSFLAGS(NDSFLAGS_DIVSQRT),
       .WAPUTAG(WAPUTAG)
       )
   divsqrt_ifs [NAPUS_DIVSQRT-1:0] ();

   // FP_addsub
   marx_apu_if
     #(
       .WOP(WOP_ADDSUB),
       .NARGS(2),
       .NUSFLAGS(NUSFLAGS_ADDSUB),
       .NDSFLAGS(NDSFLAGS_ADDSUB),
       .WAPUTAG(WAPUTAG)
       )
   addsub_ifs [NAPUS_ADDSUB-1:0] ();

   // FP_mult
   marx_apu_if
     #(
       .WOP(WOP_MULT),
       .NARGS(2),
       .NUSFLAGS(NUSFLAGS_MULT),
       .NDSFLAGS(NDSFLAGS_MULT),
       .WAPUTAG(WAPUTAG)
       )
   mult_ifs [NAPUS_MULT-1:0] ();

   // FP_cast
   marx_apu_if
     #(
       .WOP(WOP_CAST),
       .NARGS(1),
       .NUSFLAGS(NUSFLAGS_CAST),
       .NDSFLAGS(NDSFLAGS_CAST),
       .WAPUTAG(WAPUTAG)
       )
   cast_ifs [NAPUS_CAST-1:0] ();

   // FP_mac
   marx_apu_if
     #(
       .WOP(WOP_MAC),
       .NARGS(3),
       .NUSFLAGS(NUSFLAGS_MAC),
       .NDSFLAGS(NDSFLAGS_MAC),
       .WAPUTAG(WAPUTAG)
       )
   mac_ifs [NAPUS_MAC-1:0] ();

   generate
      if (SHARED_FP == 1) begin : shared_fpu

         if (SHARED_FP_DIVSQRT == 1) begin : shared_fp_sqrt
            
            marx
              #(
                .NCPUS(C_NB_CORES),
                .NAPUS(NAPUS_SQRT),
                .NARB(1),
                .APUTYPE(APUTYPE_SQRT),

                .WOP(WOP_SQRT),
                .WAPUTAG(WAPUTAG),
                .NARGS(1),
                .NUSFLAGS(NUSFLAGS_SQRT),
                .NDSFLAGS(NDSFLAGS_SQRT)
                )
            marx_sqrt_i
              (
               .clk_ci(clk_i),
               .rst_rbi(rst_ni),
               .cpus(marx_ifs[APUTYPE_SQRT*C_NB_CORES+C_NB_CORES-1:APUTYPE_SQRT*C_NB_CORES]),
               .apus(sqrt_ifs)
               );
            
            // FP_SQRT_WRAPPER
            for (genvar i = 0; i < NAPUS_SQRT; i++)
              begin : fp_sqrt_wrap
                 fp_sqrt_wrapper
                   #(
                     .C_SQRT_PIPE_REGS(C_SQRT_PIPE_REGS),
                     .TAG_WIDTH(WAPUTAG)
                     )
                 fp_sqrt_wrap_i
                   (
                    .clk_i            ( clk_i                        ),
                    .rst_ni           ( rst_ni                       ),
                    .En_i             ( sqrt_ifs[i].valid_ds_s       ),
                    .OpA_i            ( sqrt_ifs[i].operands_ds_d[0] ),
                    .Rnd_i            ( sqrt_ifs[i].flags_ds_d       ),
                    .Status_o         ( sqrt_ifs[i].flags_us_d       ),
                    .Tag_i            ( sqrt_ifs[i].tag_ds_d         ),
                    .Res_o            ( sqrt_ifs[i].result_us_d      ),
                    .Tag_o            ( sqrt_ifs[i].tag_us_d         ),
                    .Valid_o          ( sqrt_ifs[i].req_us_s         ),
                    .Ready_o          ( sqrt_ifs[i].ready_ds_s       ) 
                    );
              end
         end

         // AddSub
         marx
           #(
             .NCPUS(C_NB_CORES),
             .NAPUS(NAPUS_ADDSUB),
             .NARB(NAPUS_ADDSUB),
             .APUTYPE(APUTYPE_ADDSUB),

             .WOP(WOP_ADDSUB),
             .WAPUTAG(WAPUTAG),
             .NARGS(2),
             .NUSFLAGS(NUSFLAGS_ADDSUB),
             .NDSFLAGS(NDSFLAGS_ADDSUB)
             )
         marx_addsub_i
           (
            .clk_ci(clk_i),
            .rst_rbi(rst_ni),
            .cpus(marx_ifs[APUTYPE_ADDSUB*C_NB_CORES+C_NB_CORES-1:APUTYPE_ADDSUB*C_NB_CORES]),
            .apus(addsub_ifs)
            );

         // FP_ADDSUB_WRAPPER
         for (genvar i = 0; i < NAPUS_ADDSUB; i++)
           begin : fp_addsub_wrap
              fp_addsub_wrapper
                #(
                  .C_ADDSUB_PIPE_REGS(C_ADDSUB_PIPE_REGS),
                  .TAG_WIDTH(WAPUTAG)
                  )
              fp_addsub_wrap_i
                (
                 .clk_i            ( clk_i                          ),
                 .rst_ni           ( rst_ni                         ),
                 .En_i             ( addsub_ifs[i].valid_ds_s       ),
                 .SubSel_i         ( addsub_ifs[i].op_ds_d          ),
                 .OpA_i            ( addsub_ifs[i].operands_ds_d[0] ),
                 .OpB_i            ( addsub_ifs[i].operands_ds_d[1] ),
                 .Rnd_i            ( addsub_ifs[i].flags_ds_d       ),
                 .Status_o         ( addsub_ifs[i].flags_us_d       ),
                 .Tag_i            ( addsub_ifs[i].tag_ds_d         ),
                 .Res_o            ( addsub_ifs[i].result_us_d      ),
                 .Tag_o            ( addsub_ifs[i].tag_us_d         ),
                 .Valid_o          ( addsub_ifs[i].req_us_s         ),
                 .Ready_o          ( addsub_ifs[i].ready_ds_s       ) 
                 );
           end

         if (SHARED_FP_DIVSQRT == 1) begin : shared_fp_div
 
            marx
              #(
                .NCPUS(C_NB_CORES),
                .NAPUS(NAPUS_DIV),
                .NARB(1),
                .APUTYPE(APUTYPE_DIV),

                .WOP(WOP_DIV),
                .WAPUTAG(WAPUTAG),
                .NARGS(2),
                .NUSFLAGS(NUSFLAGS_DIV),
                .NDSFLAGS(NDSFLAGS_DIV)
                )
            marx_div_i
              (
               .clk_ci(clk_i),
               .rst_rbi(rst_ni),
               .cpus(marx_ifs[APUTYPE_DIV*C_NB_CORES+C_NB_CORES-1:APUTYPE_DIV*C_NB_CORES]),
               .apus(div_ifs)
               );
            
            // FP_DIV_WRAPPER
            for (genvar i = 0; i < NAPUS_DIV; i++)
              begin : fp_div_wrap
                 fp_div_wrapper
                   #(
                     .C_DIV_PIPE_REGS(C_DIV_PIPE_REGS),
                     .TAG_WIDTH(WAPUTAG)
                     )
                 fp_div_wrap_i
                   (
                    .clk_i            ( clk_i                       ),
                    .rst_ni           ( rst_ni                      ),
                    .En_i             ( div_ifs[i].valid_ds_s       ),
                    .OpA_i            ( div_ifs[i].operands_ds_d[0] ),
                    .OpB_i            ( div_ifs[i].operands_ds_d[1] ),
                    .Rnd_i            ( div_ifs[i].flags_ds_d       ),
                    .Status_o         ( div_ifs[i].flags_us_d       ),
                    .Tag_i            ( div_ifs[i].tag_ds_d         ),
                    .Res_o            ( div_ifs[i].result_us_d      ),
                    .Tag_o            ( div_ifs[i].tag_us_d         ),
                    .Valid_o          ( div_ifs[i].req_us_s         ),
                    .Ready_o          ( div_ifs[i].ready_ds_s       ) 
                    );
              end
         end

         if (SHARED_FP_DIVSQRT == 2) begin : shared_fp_divsqrt
 
            marx
              #(
                .NCPUS(C_NB_CORES),
                .NAPUS(NAPUS_DIVSQRT),
                .NARB(1),
                .APUTYPE(APUTYPE_DIVSQRT),

                .WOP(WOP_DIVSQRT),
                .WAPUTAG(WAPUTAG),
                .NARGS(2),
                .NUSFLAGS(NUSFLAGS_DIVSQRT),
                .NDSFLAGS(NDSFLAGS_DIVSQRT)
                )
            marx_divsqrt_i
              (
               .clk_ci(clk_i),
               .rst_rbi(rst_ni),
               .cpus(marx_ifs[APUTYPE_DIVSQRT*C_NB_CORES+C_NB_CORES-1:APUTYPE_DIVSQRT*C_NB_CORES]),
               .apus(divsqrt_ifs)
               );
            
            // FP_DIV_WRAPPER
            for (genvar i = 0; i < NAPUS_DIVSQRT; i++)
              begin : fp_divsqrt_wrap
                 fp_iter_divsqrt_wrapper
                   #(
                     .TAG_WIDTH(WAPUTAG)
                     )
                 fp_iter_divsqrt_wrap_i
                   (
                    .clk_i            ( clk_i                           ),
                    .rst_ni           ( rst_ni                          ),
                    .En_i             ( divsqrt_ifs[i].valid_ds_s       ),
                    .OpA_i            ( divsqrt_ifs[i].operands_ds_d[0] ),
                    .OpB_i            ( divsqrt_ifs[i].operands_ds_d[1] ),
                    .sqrt_sel_i       ( divsqrt_ifs[i].op_ds_d[0]       ),
                    .Rnd_i            ( divsqrt_ifs[i].flags_ds_d       ),
                    .Status_o         ( divsqrt_ifs[i].flags_us_d       ),
                    .Tag_i            ( divsqrt_ifs[i].tag_ds_d         ),
                    .Res_o            ( divsqrt_ifs[i].result_us_d      ),
                    .Tag_o            ( divsqrt_ifs[i].tag_us_d         ),
                    .Valid_o          ( divsqrt_ifs[i].req_us_s         ),
                    .Ready_o          ( divsqrt_ifs[i].ready_ds_s       ) 
                    );
              end
         end
         
         // Mult
         marx
           #(
             .NCPUS(C_NB_CORES),
             .NAPUS(NAPUS_MULT),
             .NARB(NAPUS_MULT),
             .APUTYPE(APUTYPE_MULT),

             .WOP(WOP_MULT),
             .WAPUTAG(WAPUTAG),
             .NARGS(2),
             .NUSFLAGS(NUSFLAGS_MULT),
             .NDSFLAGS(NDSFLAGS_MULT)
             )
         marx_mult_i
           (
            .clk_ci(clk_i),
            .rst_rbi(rst_ni),
            .cpus(marx_ifs[APUTYPE_MULT*C_NB_CORES+C_NB_CORES-1:APUTYPE_MULT*C_NB_CORES]),
            .apus(mult_ifs)
            );
         
         // FP_MULT_WRAPPER
         for (genvar i = 0; i < NAPUS_MULT; i++)
           begin : fp_mult_wrap
              fp_mult_wrapper
                #(
                  .C_MULT_PIPE_REGS(C_MULT_PIPE_REGS),
                  .TAG_WIDTH(WAPUTAG)
                  )
              fp_mult_wrap_i
                (
                 .clk_i            ( clk_i                        ),
                 .rst_ni           ( rst_ni                       ),
                 .En_i             ( mult_ifs[i].valid_ds_s       ),
                 .OpA_i            ( mult_ifs[i].operands_ds_d[0] ),
                 .OpB_i            ( mult_ifs[i].operands_ds_d[1] ),
                 .Rnd_i            ( mult_ifs[i].flags_ds_d       ),
                 .Status_o         ( mult_ifs[i].flags_us_d       ),
                 .Tag_i            ( mult_ifs[i].tag_ds_d         ),
                 .Res_o            ( mult_ifs[i].result_us_d      ),
                 .Tag_o            ( mult_ifs[i].tag_us_d         ),
                 .Valid_o          ( mult_ifs[i].req_us_s         ),
                 .Ready_o          ( mult_ifs[i].ready_ds_s       ),
                 .Ack_i            ( mult_ifs[i].ack_us_s         )
                 );
           end
      
         // MAC
         marx
           #(
             .NCPUS(C_NB_CORES),
             .NAPUS(NAPUS_MAC),
             .NARB(NAPUS_MAC),
             .APUTYPE(APUTYPE_MAC),

             .WOP(WOP_MAC),
             .WAPUTAG(WAPUTAG),
             .NARGS(3),
             .NUSFLAGS(NUSFLAGS_MAC),
             .NDSFLAGS(NDSFLAGS_MAC)
             )
         marx_mac_i
           (
            .clk_ci(clk_i),
            .rst_rbi(rst_ni),
            .cpus(marx_ifs[APUTYPE_MAC*C_NB_CORES+C_NB_CORES-1:APUTYPE_MAC*C_NB_CORES]),
            .apus(mac_ifs)
            );
         
         // FP_MAC_WRAPPER
         for (genvar i = 0; i < NAPUS_MAC; i++)
           begin : fp_mac_wrap
              fp_mac_wrapper
                #(
                  .C_MAC_PIPE_REGS(C_MAC_PIPE_REGS),
                  .TAG_WIDTH(WAPUTAG)
                  )
              fp_mac_wrap_i
                (
                 .clk_i            ( clk_i                       ),
                 .rst_ni           ( rst_ni                      ),
                 .En_i             ( mac_ifs[i].valid_ds_s       ),
                 .OpA_i            ( mac_ifs[i].operands_ds_d[0] ),
                 .OpB_i            ( mac_ifs[i].operands_ds_d[1] ),
                 .OpC_i            ( mac_ifs[i].operands_ds_d[2] ),
                 .Op_i             ( mac_ifs[i].op_ds_d[1:0]     ),
                 .Rnd_i            ( mac_ifs[i].flags_ds_d       ),
                 .Status_o         ( mac_ifs[i].flags_us_d       ),
                 .Tag_i            ( mac_ifs[i].tag_ds_d         ),
                 .Res_o            ( mac_ifs[i].result_us_d      ),
                 .Tag_o            ( mac_ifs[i].tag_us_d         ),
                 .Valid_o          ( mac_ifs[i].req_us_s         ),
                 .Ready_o          ( mac_ifs[i].ready_ds_s       ),
                 .Ack_i            ( mac_ifs[i].ack_us_s         )
                 );
           end
         
         // CAST
         marx
           #(
             .NCPUS(C_NB_CORES),
             .NAPUS(NAPUS_CAST),
             .NARB(NAPUS_CAST),
             .APUTYPE(APUTYPE_CAST),

             .WOP(WOP_CAST),
             .WAPUTAG(WAPUTAG),
             .NARGS(1),
             .NUSFLAGS(NUSFLAGS_CAST),
             .NDSFLAGS(NDSFLAGS_CAST)
             )
         marx_cast_i
           (
            .clk_ci(clk_i),
            .rst_rbi(rst_ni),
            .cpus(marx_ifs[APUTYPE_CAST*C_NB_CORES+C_NB_CORES-1:APUTYPE_CAST*C_NB_CORES]),
            .apus(cast_ifs)
            );
         
         // FP_CAST_WRAPPER
         for (genvar i = 0; i < NAPUS_CAST; i++)
           begin : fp_cast_wrap
              fp_cast_wrapper
                #(
                  .C_CAST_PIPE_REGS(C_CAST_PIPE_REGS),
                  .TAG_WIDTH(WAPUTAG)
                  )
              fp_cast_wrap_i
                (
                 .clk_i            ( clk_i                        ),
                 .rst_ni           ( rst_ni                       ),
                 .En_i             ( cast_ifs[i].valid_ds_s       ),
                 .F2I_i            ( cast_ifs[i].op_ds_d          ),
                 .OpA_i            ( cast_ifs[i].operands_ds_d[0] ),
                 .Rnd_i            ( cast_ifs[i].flags_ds_d       ),
                 .Status_o         ( cast_ifs[i].flags_us_d       ),
                 .Tag_i            ( cast_ifs[i].tag_ds_d         ),
                 .Res_o            ( cast_ifs[i].result_us_d      ),
                 .Tag_o            ( cast_ifs[i].tag_us_d         ),
                 .Valid_o          ( cast_ifs[i].req_us_s         ),
                 .Ready_o          ( cast_ifs[i].ready_ds_s       ) 
                 );
           end
      end
   endgenerate

endmodule
