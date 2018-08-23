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

   localparam integer NAPUS_DSP_MULT = (C_NB_CORES==2)      ? 1 : C_NB_CORES/2;
   localparam integer NAPUS_INT_MULT = (C_NB_CORES==2)      ? 1 : C_NB_CORES/2;
   localparam integer NAPUS_INT_DIV  = (C_NB_CORES==2)      ? 1 : C_NB_CORES/4;
   localparam integer NAPUS_ADDSUB   = (PRIVATE_FP_ADDSUB)  ? C_NB_CORES : (C_NB_CORES<=4) ? 1 : C_NB_CORES/8;
   localparam integer NAPUS_MULT     = (PRIVATE_FP_MULT)    ? C_NB_CORES : (C_NB_CORES<=4) ? 1 : C_NB_CORES/8;
   localparam integer NAPUS_CAST     = (PRIVATE_FP_CAST)    ? C_NB_CORES : (C_NB_CORES<=4) ? 1 : C_NB_CORES/8;
   localparam integer NAPUS_MAC      = (PRIVATE_FP_MAC)     ? C_NB_CORES : (C_NB_CORES<=4) ? 1 : C_NB_CORES/4;
   localparam integer NAPUS_DIV      = (PRIVATE_FP_DIV)     ? C_NB_CORES : 1; // this is also used for 'old' shared divsqrt
   localparam integer NAPUS_SQRT     = (PRIVATE_FP_SQRT)    ? C_NB_CORES : 1;
   localparam integer NAPUS_FPNEW    = (PRIVATE_FPNEW)      ? C_NB_CORES : (C_NB_CORES<=4) ? 1 : C_NB_CORES/4;
   localparam integer NAPUS_DIVSQRT  = (PRIVATE_FP_DIVSQRT) ? C_NB_CORES : 1; // PRIVATE_FPNEW


   // careful when modifying the following parameters. C_APUTYPES has to match with what is defined in apu_package.sv, and the individual types have to match what is defined in the core (riscv_decoder.sv)
   localparam APUTYPE_DSP_MULT   = (SHARED_DSP_MULT)       ? 0 : 0;
   localparam APUTYPE_INT_MULT   = (SHARED_INT_MULT)       ? SHARED_DSP_MULT : 0;
   localparam APUTYPE_INT_DIV    = (SHARED_INT_DIV)        ? SHARED_DSP_MULT + SHARED_INT_MULT : 0;

   localparam APUTYPE_FP         = (SHARED_FP)             ? SHARED_DSP_MULT + SHARED_INT_MULT + SHARED_INT_DIV : 0;

   localparam APUTYPE_ADDSUB     = (SHARED_FP)             ? ((SHARED_FP==1) ? APUTYPE_FP   : APUTYPE_FP)   : 0;
   localparam APUTYPE_MULT       = (SHARED_FP)             ? ((SHARED_FP==1) ? APUTYPE_FP+1 : APUTYPE_FP)   : 0;
   localparam APUTYPE_CAST       = (SHARED_FP)             ? ((SHARED_FP==1) ? APUTYPE_FP+2 : APUTYPE_FP)   : 0;
   localparam APUTYPE_MAC        = (SHARED_FP)             ? ((SHARED_FP==1) ? APUTYPE_FP+3 : APUTYPE_FP)   : 0;
   // SHARED_FP_DIVSQRT==1, SHARED_FP==1 (old config): separate div and sqrt units
   // SHARED_FP_DIVSQRT==1, SHARED_FP==2 (new config): divsqrt enabled within shared FPnew blocks
   // SHARED_FP_DIVSQRT==2, SHARED_FP==1 (old config): merged div/sqrt unit
   // SHARED_FP_DIVSQRT==2, SHARED_FP==2 (new config): separate shared divsqrt blocks (allows different share ratio)
   localparam APUTYPE_DIV        = (SHARED_FP_DIVSQRT==1)  ? ((SHARED_FP==1) ? APUTYPE_FP+4 : APUTYPE_FP)   :
                                  ((SHARED_FP_DIVSQRT==2)  ? ((SHARED_FP==1) ? APUTYPE_FP+4 : APUTYPE_FP+1) : 0);
   localparam APUTYPE_SQRT       = (SHARED_FP_DIVSQRT==1)  ? ((SHARED_FP==1) ? APUTYPE_FP+5 : APUTYPE_FP)   :
                                  ((SHARED_FP_DIVSQRT==2)  ? ((SHARED_FP==1) ? APUTYPE_FP+4 : APUTYPE_FP+1) : 0);

   localparam C_APUTYPES   = (SHARED_FP) ? (SHARED_FP_DIVSQRT) ? APUTYPE_SQRT+1 : APUTYPE_MAC+1 : SHARED_DSP_MULT + SHARED_INT_DIV + SHARED_INT_MULT;

   cpu_marx_if
     #(
       .WOP_CPU(WOP_CPU),
       .WAPUTYPE(WAPUTYPE),
			 .NUSFLAGS_CPU(NUSFLAGS_CPU),
			 .NDSFLAGS_CPU(NDSFLAGS_CPU),
       .NARGS_CPU(NARGS_CPU)
       )
   marx_ifs [C_APUTYPES-1:0][C_NB_CORES-1:0] ();

   //////////////////////////
   // multi-marx splitter  //
   //////////////////////////

   logic                          cpus_ack_ds    [C_NB_CORES-1:0];

   logic [31:0]                   cpus_result_us [C_NB_CORES-1:0];
   logic [NDSFLAGS_CPU-1:0]       cpus_flags_us  [C_NB_CORES-1:0];
   logic                          cpus_valid_us  [C_NB_CORES-1:0];

   logic                          marx_ack_ds    [C_APUTYPES-1:0][C_NB_CORES-1:0];

   logic [31:0]                   marx_result_us [C_APUTYPES-1:0][C_NB_CORES-1:0];
   logic [NUSFLAGS_CPU-1:0]       marx_flags_us  [C_APUTYPES-1:0][C_NB_CORES-1:0];
   logic                          marx_valid_us  [C_APUTYPES-1:0][C_NB_CORES-1:0];

   // assign cpu -> marx signals, temp signals
   generate
      for (genvar i = 0; i < C_NB_CORES; i++) begin
         for (genvar j = 0; j < C_APUTYPES; j++) begin
            // downstream
            assign marx_ifs[j][i].req_ds_s        = cpus[i].req_ds_s;
            assign marx_ifs[j][i].type_ds_d       = cpus[i].type_ds_d;
            assign marx_ifs[j][i].operands_ds_d   = cpus[i].operands_ds_d;
            assign marx_ifs[j][i].op_ds_d         = cpus[i].op_ds_d;
            assign marx_ifs[j][i].flags_ds_d      = cpus[i].flags_ds_d;

            // ready signal from upstream interface
            assign marx_ifs[j][i].ready_us_s      = cpus[i].ready_us_s;

            // temps
            assign marx_ack_ds[j][i]              = marx_ifs[j][i].ack_ds_s;

            assign marx_result_us[j][i]           = marx_ifs[j][i].result_us_d;
            assign marx_flags_us[j][i]            = marx_ifs[j][i].flags_us_d;
            assign marx_valid_us[j][i]            = marx_ifs[j][i].valid_us_s;
         end

         assign cpus[i].ack_ds_s                 = cpus_ack_ds[i];

         assign cpus[i].result_us_d              = cpus_result_us[i];
         assign cpus[i].flags_us_d               = cpus_flags_us[i];
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

            for (int j = 0; j < C_APUTYPES; j++) begin
               // upstream interface
               if (marx_valid_us[j][i]) begin
                  valid_temp[i]       = 1'b1;
                  cpus_result_us[i]   = marx_result_us[j][i];
                  cpus_flags_us[i]    = marx_flags_us[j][i];
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
      .cpus(marx_ifs[APUTYPE_DSP_MULT]),
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
      .cpus(marx_ifs[APUTYPE_INT_MULT]),
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
      .cpus(marx_ifs[APUTYPE_INT_DIV]),
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

   // FPnew
   marx_apu_if
     #(
       .WOP(WOP_FPNEW),
       .NARGS(3),
       .NUSFLAGS(NUSFLAGS_FPNEW),
       .NDSFLAGS(NDSFLAGS_FPNEW),
       .WAPUTAG(WAPUTAG)
       )
   fpnew_ifs [NAPUS_FPNEW-1:0] ();

   // FP_DIVSQRT - ONLY FOR FPNEW, OLD MODE USES DIV-INTERFACE
   marx_apu_if
     #(
       .WOP(WOP_DIVSQRT),
       .NARGS(2),
       .NUSFLAGS(NUSFLAGS_DIVSQRT),
       .NDSFLAGS(NDSFLAGS_DIVSQRT),
       .WAPUTAG(WAPUTAG)
       )
   divsqrt_ifs [NAPUS_DIVSQRT-1:0] ();



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
               .cpus(marx_ifs[APUTYPE_SQRT]),
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
            .cpus(marx_ifs[APUTYPE_ADDSUB]),
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
               .cpus(marx_ifs[APUTYPE_DIV]),
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
               .cpus(marx_ifs[APUTYPE_DIV]),
               .apus(div_ifs)
               );

            // FP_DIV_WRAPPER
            for (genvar i = 0; i < NAPUS_DIV; i++)
              begin : fp_divsqrt_wrap
                 fp_iter_divsqrt_wrapper
                   #(
                     .TAG_WIDTH(WAPUTAG)
                     )
                 fp_iter_divsqrt_wrap_i
                   (
                    .clk_i            ( clk_i                           ),
                    .rst_ni           ( rst_ni                          ),
                    .En_i             ( div_ifs[i].valid_ds_s       ),
                    .OpA_i            ( div_ifs[i].operands_ds_d[0] ),
                    .OpB_i            ( div_ifs[i].operands_ds_d[1] ),
                    .sqrt_sel_i       ( div_ifs[i].op_ds_d[0]       ),
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
            .cpus(marx_ifs[APUTYPE_MULT]),
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
            .cpus(marx_ifs[APUTYPE_MAC]),
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
            .cpus(marx_ifs[APUTYPE_CAST]),
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

      // FPNEW
      else if (SHARED_FP==2) begin : shared_fpnew

         // Bulk FPNEW
         marx
           #(
             .NCPUS(C_NB_CORES),
             .NAPUS(NAPUS_FPNEW),
             .NARB(NAPUS_FPNEW),
             .APUTYPE(APUTYPE_FP),

             .WOP(WOP_FPNEW),
             .WAPUTAG(WAPUTAG),
             .NARGS(3),
             .NUSFLAGS(NUSFLAGS_FPNEW),
             .NDSFLAGS(NDSFLAGS_FPNEW)
             )
         marx_fpnew_i
           (
            .clk_ci(clk_i),
            .rst_rbi(rst_ni),
            .cpus(marx_ifs[APUTYPE_FP]),
            .apus(fpnew_ifs)
            );

         // FPnew instances
         for (genvar i = 0; i < NAPUS_FPNEW; i++) begin : inst_fpnew

            logic [C_FPNEW_OPBITS-1:0]   fpu_op;
            logic                        fpu_op_mod;
            logic                        fpu_vec_op;

            logic [C_FPNEW_FMTBITS-1:0]  fpu_fmt;
            logic [C_FPNEW_FMTBITS-1:0]  fpu_fmt2;
            logic [C_FPNEW_IFMTBITS-1:0] fpu_ifmt;
            logic [C_RM-1:0]             fp_rnd_mode;

            assign {fpu_vec_op, fpu_op_mod, fpu_op} = fpnew_ifs[i].op_ds_d;
            assign {fpu_ifmt, fpu_fmt2, fpu_fmt, fp_rnd_mode} = fpnew_ifs[i].flags_ds_d;

            localparam C_DIV = (SHARED_FP_DIVSQRT==1) ? 2 : 0;

            fpnew_top #(
               .WIDTH                ( FP_WIDTH      ),
               .TAG_WIDTH            ( WAPUTAG       ),
               .RV64                 ( 1'b0          ), // this is an RV32 core
               .RVF                  ( C_RVF         ),
               .RVD                  ( C_RVD         ),
               .Xf16                 ( C_XF16        ),
               .Xf16alt              ( C_XF16ALT     ),
               .Xf8                  ( C_XF8         ),
               .Xfvec                ( C_XFVEC       ),
               .TYPE_DIVSQRT         ( C_DIV         ),
               .LATENCY_COMP_F       ( C_LAT_FP32    ),
               .LATENCY_COMP_D       ( C_LAT_FP64    ),
               .LATENCY_COMP_Xf16    ( C_LAT_FP16    ),
               .LATENCY_COMP_Xf16alt ( C_LAT_FP16ALT ),
               .LATENCY_COMP_Xf8     ( C_LAT_FP8     ),
               .LATENCY_DIVSQRT      ( C_LAT_DIVSQRT ),
               .LATENCY_NONCOMP      ( C_LAT_NONCOMP ),
               .LATENCY_CONV         ( C_LAT_CONV    )
            ) fpnew_top_i (
               .Clk_CI         ( clk_i                         ),
               .Reset_RBI      ( rst_ni                        ),
               .A_DI           ( fpnew_ifs[i].operands_ds_d[0] ),
               .B_DI           ( fpnew_ifs[i].operands_ds_d[1] ),
               .C_DI           ( fpnew_ifs[i].operands_ds_d[2] ),
               .RoundMode_SI   ( fp_rnd_mode                   ),
               .Op_SI          ( fpu_op                        ),
               .OpMod_SI       ( fpu_op_mod                    ),
               .VectorialOp_SI ( fpu_vec_op                    ),
               .FpFmt_SI       ( fpu_fmt                       ),
               .FpFmt2_SI      ( fpu_fmt2                      ),
               .IntFmt_SI      ( fpu_ifmt                      ),
               .Tag_DI         ( fpnew_ifs[i].tag_ds_d         ),
               .InValid_SI     ( fpnew_ifs[i].valid_ds_s       ),
               .InReady_SO     ( fpnew_ifs[i].ready_ds_s       ),
               .Flush_SI       ( '0                            ),
               .Z_DO           ( fpnew_ifs[i].result_us_d      ),
               .Status_DO      ( fpnew_ifs[i].flags_us_d       ),
               .Tag_DO         ( fpnew_ifs[i].tag_us_d         ),
               .OutValid_SO    ( fpnew_ifs[i].req_us_s         ),
               .OutReady_SI    ( fpnew_ifs[i].ack_us_s         )
            );

         end

         // Shared FPnew divsqrt
         if (SHARED_FP_DIVSQRT==2) begin : shared_fp_divsqrt
            marx
              #(
                .NCPUS(C_NB_CORES),
                .NAPUS(NAPUS_DIVSQRT),
                .NARB(NAPUS_DIVSQRT),
                .APUTYPE(APUTYPE_DIV),

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
               .cpus(marx_ifs[APUTYPE_DIV]),
               .apus(divsqrt_ifs)
               );

            // DivSqrt FPnew instances
            for (genvar i = 0; i < NAPUS_DIVSQRT; i++) begin : inst_divsqrt

               logic [C_FPNEW_OPBITS-1:0]   fpu_op;
               logic                        fpu_op_mod;
               logic                        fpu_vec_op;

               logic [C_FPNEW_FMTBITS-1:0]  fpu_fmt;
               logic [C_FPNEW_FMTBITS-1:0]  fpu_fmt2;
               logic [C_FPNEW_IFMTBITS-1:0] fpu_ifmt;
               logic [C_RM-1:0]             fp_rnd_mode;

               assign {fpu_vec_op, fpu_op_mod, fpu_op} = divsqrt_ifs[i].op_ds_d;
               assign {fpu_ifmt, fpu_fmt2, fpu_fmt, fp_rnd_mode} = divsqrt_ifs[i].flags_ds_d;

               fpnew_top #(
                  .WIDTH                ( FP_WIDTH      ),
                  .TAG_WIDTH            ( WAPUTAG       ),
                  .RV64                 ( 1'b0          ), // this is an RV32 core
                  .RVF                  ( C_RVF         ),
                  .RVD                  ( C_RVD         ),
                  .Xf16                 ( C_XF16        ),
                  .Xf16alt              ( C_XF16ALT     ),
                  .Xf8                  ( C_XF8         ),
                  .Xfvec                ( C_XFVEC       ),
                  .TYPE_ADDMUL          ( 0             ), // none
                  .TYPE_DIVSQRT         ( 2             ), // merged
                  .TYPE_NONCOMP         ( 0             ), // none
                  .TYPE_CONV            ( 0             ), // none
                  .LATENCY_COMP_F       ( C_LAT_FP32    ),
                  .LATENCY_COMP_D       ( C_LAT_FP64    ),
                  .LATENCY_COMP_Xf16    ( C_LAT_FP16    ),
                  .LATENCY_COMP_Xf16alt ( C_LAT_FP16ALT ),
                  .LATENCY_COMP_Xf8     ( C_LAT_FP8     ),
                  .LATENCY_DIVSQRT      ( C_LAT_DIVSQRT ),
                  .LATENCY_NONCOMP      ( C_LAT_NONCOMP ),
                  .LATENCY_CONV         ( C_LAT_CONV    )
               ) fpnew_top_i (
                  .Clk_CI         ( clk_i                           ),
                  .Reset_RBI      ( rst_ni                          ),
                  .A_DI           ( divsqrt_ifs[i].operands_ds_d[0] ),
                  .B_DI           ( divsqrt_ifs[i].operands_ds_d[1] ),
                  .C_DI           ( '0                              ),
                  .RoundMode_SI   ( fp_rnd_mode                     ),
                  .Op_SI          ( fpu_op                          ),
                  .OpMod_SI       ( fpu_op_mod                      ),
                  .VectorialOp_SI ( fpu_vec_op                      ),
                  .FpFmt_SI       ( fpu_fmt                         ),
                  .FpFmt2_SI      ( fpu_fmt2                        ),
                  .IntFmt_SI      ( fpu_ifmt                        ),
                  .Tag_DI         ( divsqrt_ifs[i].tag_ds_d         ),
                  .InValid_SI     ( divsqrt_ifs[i].valid_ds_s       ),
                  .InReady_SO     ( divsqrt_ifs[i].ready_ds_s       ),
                  .Flush_SI       ( '0                              ),
                  .Z_DO           ( divsqrt_ifs[i].result_us_d      ),
                  .Status_DO      ( divsqrt_ifs[i].flags_us_d       ),
                  .Tag_DO         ( divsqrt_ifs[i].tag_us_d         ),
                  .OutValid_SO    ( divsqrt_ifs[i].req_us_s         ),
                  .OutReady_SI    ( divsqrt_ifs[i].ack_us_s         )
               );
            end

         end // shared divsqrt
      end // shared fpnew


   endgenerate

endmodule
