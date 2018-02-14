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
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ns


import apu_package::*;
import apu_tb_pkg::*;

module apu_testbench
  (
   );
   
   parameter C_N_STIM = 10000;
   parameter C_PROB = 50; // probability of each core issueing an operation [%]
   
   
// -----------------------------------------------------------------------------
// Reset and clock generation
// -----------------------------------------------------------------------------
   logic clk_i;
   logic rst_ni;

   // reset generator
   initial
     begin
        rst_ni = 1'b0;
        #RESET_DEL;
        rst_ni = 1'b1;
     end

   // clk generator
   initial
     begin
        clk_i = 1'b1;
        while(1) begin
           #CLK_PHASE_HI;
           clk_i = 1'b0;
           #CLK_PHASE_LO;
           clk_i = 1'b1;
        end
     end


// -----------------------------------------------------------------------------
// randomize enable signal for each core and operation for each stimuli
// -----------------------------------------------------------------------------
   int unsigned enable [C_NB_CORES-1:0];
   int unsigned operation [C_N_STIM-1:0];
   
   // random enable signals for 4 cores
   generate
      for (genvar k=0;k<C_NB_CORES;k++) begin
         initial begin
            int unsigned enable_random;
            enable[k] = 100;
            #RESET_DEL;
            while(1) begin
               assert(std::randomize(enable_random) with {enable_random<100;});
               enable[k] = enable_random;
               #CLK_PERIOD;
            end
         end
      end
   endgenerate

   // random enable signals for 4 cores
   initial begin
      int k;
      for (k=0;k<C_N_STIM;k++) begin
         int unsigned op_random;
         assert(std::randomize(op_random) with {op_random<2;});
         operation[k] = op_random;
      end
   end
   
               
// -----------------------------------------------------------------------------
// Device under test
// -----------------------------------------------------------------------------

   cpu_marx_if               cpus [C_NB_CORES-1:0] ();

   apu_cluster
     #(
      .C_NB_CORES(C_NB_CORES)
      )
     dut_i
     (
      .clk_i            ( clk_i                     ),
      .rst_ni           ( rst_ni                    ),
      .cpus             ( cpus                      )
      );   

// -----------------------------------------------------------------------------
// stimuli generation
// -----------------------------------------------------------------------------
   
   logic [31:0] check_result [C_N_STIM-1:0];
   logic [31:0] opa [C_N_STIM-1:0];
   logic [31:0] opb [C_N_STIM-1:0];
   logic [31:0] opc [C_N_STIM-1:0];
   
   int       ind_stim [C_NB_CORES-1:0];
   logic     incr_stim [C_NB_CORES-1:0];

   initial begin
      int k;
      for (k=0;k<C_N_STIM;k++) begin
         gen_stimuli(operation[k], opa[k],opb[k],opc[k],check_result[k]);
      end
   end
   
// -----------------------------------------------------------------------------
// stimuli application
// -----------------------------------------------------------------------------
   int                   latency_dn [C_NB_CORES-1:0];
   int                   latency_dp [C_NB_CORES-1:0];

   static int            C_LAT [C_N_OPS-1:0];
   
   assign  C_LAT[C_OP_ADD]  = PIPE_REG_ADDSUB;
   assign  C_LAT[C_OP_SUB]  = PIPE_REG_ADDSUB;
   assign  C_LAT[C_OP_MULT] = PIPE_REG_MULT;
   assign  C_LAT[C_OP_MAC]  = PIPE_REG_MAC;
   assign  C_LAT[C_OP_DIV]  = PIPE_REG_DIV;
   assign  C_LAT[C_OP_SQRT] = PIPE_REG_SQRT;
   assign  C_LAT[C_OP_ITF]  = PIPE_REG_CAST;
   assign  C_LAT[C_OP_FTI]  = PIPE_REG_CAST;
   
   generate
      for (genvar k=0;k<C_NB_CORES;k++) begin
         initial begin
            cpus[k].req_ds_s = '0;
            latency_dn[k] = 0;
            #STIM_APP_DEL;
            while (ind_stim[k]<C_N_STIM/C_NB_CORES) begin
               
               if ((enable[k]<C_PROB) & (latency_dp[k]<C_LAT[operation[ind_stim[k]*C_NB_CORES+k]])) begin
                  cpus[k].req_ds_s = '1;
                  cpus[k].op_ds_d = '0;
                  cpus[k].ready_us_s = 1;
                  cpus[k].flags_ds_d = 3'b0;
                  
                  case(operation[ind_stim[k]*C_NB_CORES+k])
                    C_OP_ADD:  begin
                       cpus[k].type_ds_d = APUTYPE_ADDSUB; //add
                       latency_dn[k] = PIPE_REG_ADDSUB;
                    end
                    C_OP_SUB:  begin
                       cpus[k].type_ds_d = APUTYPE_ADDSUB; //sub
                       cpus[k].op_ds_d[0] = 1;
                       latency_dn[k] = PIPE_REG_ADDSUB;
                    end
                    C_OP_MULT: begin
                       cpus[k].type_ds_d = APUTYPE_MULT;
                       latency_dn[k] = PIPE_REG_MULT;
                       end                      
                    C_OP_MAC:  begin
                       cpus[k].type_ds_d = APUTYPE_MAC;
                       latency_dn[k] = PIPE_REG_MAC;
                    end
                    C_OP_DIV:  begin
                       cpus[k].type_ds_d = APUTYPE_DIV;
                       latency_dn[k] = PIPE_REG_DIV;
                    end
                    C_OP_SQRT:  begin
                       cpus[k].type_ds_d = APUTYPE_SQRT;
                       latency_dn[k] = PIPE_REG_SQRT;
                    end
                    C_OP_ITF:  begin
                       cpus[k].type_ds_d = APUTYPE_CAST; //itf
                       latency_dn[k] = PIPE_REG_CAST;
                    end
                    C_OP_FTI:  begin
                       cpus[k].type_ds_d = APUTYPE_CAST; //fti
                       cpus[k].op_ds_d[0] = 1;
                       latency_dn[k] = PIPE_REG_CAST;
                       cpus[k].flags_ds_d = 3'b100;
                    end
                  endcase
                  
                  cpus[k].operands_ds_d[0] = opa[ind_stim[k]*C_NB_CORES+k];
                  cpus[k].operands_ds_d[1] = opb[ind_stim[k]*C_NB_CORES+k];
                  cpus[k].operands_ds_d[2] = opc[ind_stim[k]*C_NB_CORES+k];
               end
               else begin
                  cpus[k].req_ds_s = '0;
                  cpus[k].type_ds_d = '0;
                  cpus[k].operands_ds_d[0] = '0;
                  cpus[k].operands_ds_d[1] = '0;
                  cpus[k].operands_ds_d[2] = '0;
                  cpus[k].op_ds_d = '0;
                  cpus[k].flags_ds_d = '0;
                  latency_dn[k] = latency_dp[k];
               end
               #CLK_PERIOD;
            end
            cpus[k].req_ds_s = '0;
            cpus[k].type_ds_d = '0;
            cpus[k].operands_ds_d[0] = '0;
            cpus[k].operands_ds_d[1] = '0;
            cpus[k].operands_ds_d[2] = '0;
            cpus[k].op_ds_d = '0;
            cpus[k].flags_ds_d = '0;
         end
      end
   endgenerate

// -----------------------------------------------------------------------------
// response aquisition and checker
// -----------------------------------------------------------------------------
   
   integer   ind [C_NB_CORES-1:0];
   logic     incr [C_NB_CORES-1:0] ;

   // check acknowledge
   generate
      for (genvar k=0;k<C_NB_CORES;k++) begin
         initial begin
            incr_stim[k] = 1'b0;
            #RESP_ACQ_DEL;
            while (ind_stim[k]<C_N_STIM/C_NB_CORES) begin
               if (cpus[k].ack_ds_s)
                 incr_stim[k] = 1'b1;
               else
                 incr_stim[k] = 1'b0;
               #CLK_PERIOD;
            end
            incr_stim[k] = 1'b0;
         end
      end
   endgenerate
   

   int errors = 0;
      
   generate
      for (genvar k=0;k<C_NB_CORES;k++) begin
         initial begin
            incr[k] = 1'b0;
            #RESP_ACQ_DEL;
            while(ind[k]<C_N_STIM/C_NB_CORES) begin
               incr[k] = 1'b0;
               if (cpus[k].valid_us_s) begin
                  if (check_result[ind[k]*C_NB_CORES+k]!=cpus[k].result_us_d) begin
                     $error("wrong result: expected: %h, is: %h ; ind: %d; operation: %d",check_result[ind[k]*C_NB_CORES+k],cpus[k].result_us_d, ind[k]*C_NB_CORES+k, operation[ind[k]*C_NB_CORES+k]);
                     errors++;
                  end
//                  else
//                    $display("check passed!");
                  incr[k] = 1'b1;
                  
               end
               else
                 incr[k] = 1'b0;
               #CLK_PERIOD;
            end
            incr[k] = 1'b0;
         end
      end
   endgenerate

// -----------------------------------------------------------------------------
// index tracker for stimuli and responses
// -----------------------------------------------------------------------------

   generate
      for (genvar k=0;k<C_NB_CORES;k++) begin
         always_ff @(posedge clk_i or negedge rst_ni) begin
            if (~rst_ni) begin
               ind[k] = 0;
               ind_stim[k] = 0;
               latency_dp[k] = 0;
            end
            else begin
               if(incr[k]) begin
                  ind[k] = ind[k] + 1;
               end
               if(incr_stim[k]) begin
                  ind_stim[k] = ind_stim[k] + 1;
               end
               if (cpus[k].req_ds_s & cpus[k].ack_ds_s)
                 latency_dp[k] = latency_dn[k] - 1;
               else if (latency_dp[k]>0)
                 latency_dp[k] = latency_dp[k] - 1;
            end
         end
      end
   endgenerate

   
// -----------------------------------------------------------------------------
// end of simulation determination and final block
// -----------------------------------------------------------------------------
   
   always_comb begin
      int k;
      var automatic int total = 0;
      
      for (k=0;k<C_NB_CORES;k++)
        total+=ind[k];
      
      if(total==C_N_STIM)
        $finish;
   end
   
   final begin
      $display("verified %d stimuli; found %d errors!", C_N_STIM ,errors);
   end
      
endmodule
