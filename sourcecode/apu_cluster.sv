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
   // FPNEW
   // --------------------------------------------------------------
   // 
   /////////////////////////////////////////////////////////////////



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





      // FPNEW
      //else if (SHARED_FP==2) begin : shared_fpnew

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

       generate
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
               .Flush_SI       ( 1'b0                          ),
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
                  .C_DI           ( 32'b0                           ),
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
                  .Flush_SI       ( 1'b0                            ),
                  .Z_DO           ( divsqrt_ifs[i].result_us_d      ),
                  .Status_DO      ( divsqrt_ifs[i].flags_us_d       ),
                  .Tag_DO         ( divsqrt_ifs[i].tag_us_d         ),
                  .OutValid_SO    ( divsqrt_ifs[i].req_us_s         ),
                  .OutReady_SI    ( divsqrt_ifs[i].ack_us_s         )
               );
            //end

         end // shared divsqrt
      end // shared fpnew
	  

   endgenerate

endmodule
