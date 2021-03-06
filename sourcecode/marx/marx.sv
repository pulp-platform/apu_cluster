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
// Engineer:       Fabian Schuiki - fschuiki@student.ethz.ch                  //
//                                                                            //
// Additional contributions by:                                               //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                                                                            //
// Design Name:    marx.sv                                                    //
// Project Name:   shared APU                                                 //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Marx arbiter and interconnect                              //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////


import apu_cluster_package::*;

module marx 
  #(
    parameter NCPUS    = 4, // interconnect params
    parameter NAPUS    = 1, // valid 1:NCPUS
    parameter NARB     = 1, // valid 1:NAPUS
    parameter APUTYPE  = -1,
  
    parameter WOP      = 0,      // APU params
    parameter WAPUTAG  = 0,
    parameter NARGS    = 0,
    parameter NUSFLAGS = 0,
    parameter NDSFLAGS = 0
    )
   (
    input clk_ci,
    input rst_rbi,
    cpu_marx_if.marx cpus [NCPUS-1:0],
    marx_apu_if.marx apus [NAPUS-1:0]
    );
      
   marx_arbiter_if #(.NIN(NCPUS/NARB),.NOUT(NAPUS/NARB)) arb [NARB-1:0] ();
         
   generate
      // private configuration
      if (NCPUS==NAPUS) begin : private
         for (genvar i=0;i<NCPUS;i++) begin
            assign apus[i].valid_ds_s    = cpus[i].req_ds_s & (cpus[i].type_ds_d == APUTYPE);
            for (genvar k=0;k<NARGS;k++) begin
               assign apus[i].operands_ds_d[k] = cpus[i].operands_ds_d[k];
            end
            assign apus[i].op_ds_d       = cpus[i].op_ds_d;
            assign apus[i].flags_ds_d    = cpus[i].flags_ds_d;
            assign apus[i].tag_ds_d      = '0;
            assign apus[i].ack_us_s      = cpus[i].ready_us_s;
            assign cpus[i].ack_ds_s      = apus[i].ready_ds_s & apus[i].valid_ds_s;
            assign cpus[i].valid_us_s    = apus[i].req_us_s;
            assign cpus[i].result_us_d   = apus[i].result_us_d;
            assign cpus[i].flags_us_d    = apus[i].flags_us_d;
         end
      end
      else begin : shared
         // Instantiate the arbiters (per default only one. but for timing
         // reasons and multi-core implementations it is possible to
         // instantiate multiple arbiters.
         // For 8 cores and 2 APUs this allows to change the
         // 8:2 arbitration into two 4:1 arbitrations
         
         for (genvar j = 0; j < NARB; ++j) begin : arbiter
            arbiter
              #(
                .NIN(NCPUS/NARB),
                .NOUT(NAPUS/NARB)
                )
            arbiter_i
              (
               .clk_ci(clk_ci),
               .rst_rbi(rst_rbi),
               .io(arb[j].arbiter)
               );
         end
         // Attach the CPUs to the arbiter, namely the request signal that informs
         // the arbiter which CPUs require a resource, and the acknowledge signal
         // that informs the CPUs whether they were assigned a resource.
         logic [NCPUS-1:0] type_match;

         for (genvar j = 0; j < NARB; ++j) begin
            for (genvar i = 0; i < NCPUS/NARB; ++i) begin
               assign type_match[i+j*(NCPUS/NARB)]      = cpus[i+j*(NCPUS/NARB)].type_ds_d == APUTYPE;
               assign arb[j].req_d[i]                   = cpus[i+j*(NCPUS/NARB)].req_ds_s && type_match[i+j*(NCPUS/NARB)];
               assign cpus[i+j*(NCPUS/NARB)].ack_ds_s   = arb[j].ack_d[i];
            end
         end

         // Attach the APUs to the arbiter, namely the ready signal that informs the
         // arbiter which APUs are available, and the alloc signal that informs the
         // APUs whether they have been selected by the arbiter.
         for (genvar j = 0; j < NARB; ++j) begin
            for (genvar i = 0; i < NAPUS/NARB; ++i) begin
               assign arb[j].avail_d[i]               = apus[i+j*NAPUS/NARB].ready_ds_s;
               assign apus[i+j*NAPUS/NARB].valid_ds_s = arb[j].alloc_d[i];
            end
         end


         logic [31:0]         cpus_operands_ds_d [NCPUS-1:0][NARGS-1:0];
         logic [WOP-1:0]      cpus_op_ds_d       [NCPUS-1:0];
         logic [NDSFLAGS-1:0] cpus_flags_ds_d    [NCPUS-1:0];
         logic [$clog2(NCPUS)-1:0] routing       [NAPUS-1:0];
         

         for (genvar i = 0; i < NCPUS; ++i) begin
            for (genvar j = 0; j < NARGS; j++) begin
               assign cpus_operands_ds_d[i][j] = cpus[i].operands_ds_d[j];
            end
            assign cpus_op_ds_d[i]    = cpus[i].op_ds_d;
            assign cpus_flags_ds_d[i] = cpus[i].flags_ds_d;
         end

         // Multiplexer that routes the downstream signals from the CPUs to the APUs.
         // Each APU is attached to the CPU it was assigned to by the arbiter, as
         // indicated in the arb.assid_d signal.

         for (genvar j = 0; j < NARB; ++j) begin
            for (genvar i = 0; i < NAPUS/NARB; ++i) begin
               always_comb begin
                  routing[i+j*NAPUS/NARB] = arb[j].assid_d[i]+j*(NCPUS/NARB);
                  if (arb[j].alloc_d[i]) begin
                     var int unsigned n;
                     n = arb[j].assid_d[i];
                     for (int k = 0; k < NARGS; k++) begin
                        apus[i+j*NAPUS/NARB].operands_ds_d[k]   = cpus_operands_ds_d[n+j*NCPUS/NARB][k];
                     end
                     apus[i+j*NAPUS/NARB].op_ds_d                  = cpus_op_ds_d[n+j*NCPUS/NARB];
                     apus[i+j*NAPUS/NARB].flags_ds_d[NDSFLAGS-1:0] = cpus_flags_ds_d[n+j*NCPUS/NARB];
                  end else begin
                     for (int k = 0; k < NARGS; k++) begin
                        apus[i+j*NAPUS/NARB].operands_ds_d[k]      = '0;
                     end
                     apus[i+j*NAPUS/NARB].op_ds_d                  = '0;
                     apus[i+j*NAPUS/NARB].flags_ds_d[NDSFLAGS-1:0] = '0;
                  end
               end
            end
         end

         for (genvar i = 0; i < NAPUS; ++i) begin
            assign apus[i].tag_ds_d[WAPUTAG-1:0] = {routing[i]};
         end
         
         // Again to avoid iteration over unpacked arrays in combinatorial blocks, we
         // use a generated process to assign the upstream APU signals to local
         // temporary ones. Also, the tag reported by each APU is interpreted as the
         // CPU index and is used to set the corresponding line in apu_target_s to
         // high.
         //
         // Thus the apu_target_s signal implements a connection map, where
         // apu_target_s[APU][CPU] is 1 if the given APU is presenting a result for
         // the given CPU.
         //
         // The apu_ack_s signal works in a similar fashion. It implements a
         // connection map, where apu_ack_s[CPU][APU] is 1 if the given CPU
         // acknowledges the result of the given APU.
         logic                             apu_req_s     [NAPUS-1:0];
         logic [31:0]                      apu_result_d  [NAPUS-1:0];
         logic [NUSFLAGS-1:0]              apu_flags_d   [NAPUS-1:0];
         logic [NAPUS-1:0] [NCPUS-1:0]     apu_target_s;
         logic [NCPUS-1:0] [NAPUS-1:0]     apu_ack_s;

         for (genvar i = 0; i < NAPUS; ++i) begin
            always_comb begin
               var int unsigned id;
               id = apus[i].tag_us_d[WAPUTAG-1:0];
               apu_req_s[i] = apus[i].req_us_s;
               apu_result_d[i] = apus[i].result_us_d;
               apu_flags_d[i] = apus[i].flags_us_d;
               apu_target_s[i] = '0;
               apu_target_s[i][id] = 1;
               apus[i].ack_us_s = apu_ack_s[id][i];
            end
         end


         // Multiplexer that routes the results presented by the APUs back to the CPU
         // that issued the instruction, as indicated in the presented tag. In case
         // two APUs have a result for the same CPU, the APU with the lower index
         // takes precedence and is routed to its CPU, with the other APU being
         // stalled.
         for (genvar j = 0; j < NARB; ++j) begin
            for (genvar i = 0; i < NCPUS/NARB; ++i) begin
               always_comb begin
                  logic valid; valid = 0;
                  cpus[i+j*NCPUS/NARB].result_us_d = '0;
                  cpus[i+j*NCPUS/NARB].flags_us_d = '0;
                  for (int n = 0; n < NAPUS/NARB; ++n) begin
                     if (~valid && apu_target_s[n+j*NAPUS/NARB][i+j*NCPUS/NARB] && apu_req_s[n+j*NAPUS/NARB]) begin
                        apu_ack_s[i+j*NCPUS/NARB][n+j*NAPUS/NARB]     = cpus[i+j*NCPUS/NARB].ready_us_s;
                        cpus[i+j*NCPUS/NARB].result_us_d              = apu_result_d[n+j*NAPUS/NARB];
                        cpus[i+j*NCPUS/NARB].flags_us_d               = apu_flags_d[n+j*NAPUS/NARB];
                        valid = 1;
                     end else begin
                        apu_ack_s[i+j*NCPUS/NARB][n+j*NAPUS/NARB]     = 0;
                     end
                  end
                  cpus[i+j*NCPUS/NARB].valid_us_s = valid;
               end
            end
         end
      end

   endgenerate
endmodule
