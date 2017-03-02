/* Copyright (C) 2017 ETH Zurich, University of Bologna
 * All rights reserved.
 *
 * This code is under development and not yet released to the public.
 * Until it is released, the code is under the copyright of ETH Zurich
 * and the University of Bologna, and may contain unpublished work.
 * Any reuse/redistribution should only be under explicit permission.
 *
 * Bug fixes and contributions will eventually be released under the
 * SolderPad open hardware license and under the copyright of ETH Zurich
 * and the University of Bologna.
 */

package apu_tb_pkg;
import apu_package::*;
   
	 // --------------------------------------------------------------------------
	 // Timing of clock and simulation events.
	 // --------------------------------------------------------------------------
	 const time CLK_PHASE_HI       = 5ns;                         // Clock high time
	 const time CLK_PHASE_LO       = 5ns;                         // Clock low time
	 const time CLK_PERIOD         = CLK_PHASE_HI + CLK_PHASE_LO; // Clock period
	 const time STIM_APP_DEL       = CLK_PERIOD*0.1;              // Stimuli application delay
	 const time RESP_ACQ_DEL       = CLK_PERIOD*0.9;              // Response aquisition delay
	 const time RESET_DEL          = 50ns + STIM_APP_DEL;         // Delay of the reset


   parameter C_OP_ADD  = 0;
   parameter C_OP_SUB  = 1;
   parameter C_OP_MULT = 2;
   parameter C_OP_MAC  = 3;
   parameter C_OP_DIV  = 4;
   parameter C_OP_SQRT = 5;
   parameter C_OP_ITF  = 6;
   parameter C_OP_FTI  = 7;

   parameter C_N_OPS    = 8;
	 
	 // --------------------------------------------------------------------------
   //
   //            CLK_PERIOD
	 //   <------------------------->
	 //   --------------            --------------
	 //   |  A         |        T   |            |
	 // ---            --------------            --------------
	 //   <-->
	 //   STIM_APP_DEL
	 //   <--------------------->
	 //   RESP_ACQ_DEL
	 //
	 // --------------------------------------------------------------------------  

   function automatic void gen_stimuli(
                             input int unsigned operation,
                             output logic [31:0] opa_out,
                             output logic [31:0] opb_out,
                             output logic [31:0] opc_out,
                             output logic [31:0] check_result);
      begin
         logic [31:0] opa_in_bit;
         logic [31:0] opb_in_bit;
         logic [31:0] opc_in_bit;
         integer      fti_result;
         integer      opa_int;

         shortreal opa_float;
         shortreal opb_float;
         shortreal opc_float;
         shortreal opa_abs_float;
         shortreal itf_result;
         
         // randomize inputs with constraints
         assert(std::randomize(opa_in_bit) with {((opa_in_bit&C_INF_P)!=C_INF_P);});
         assert(std::randomize(opb_in_bit) with {((opb_in_bit&C_INF_P)!=C_INF_P);});
         assert(std::randomize(opc_in_bit) with {((opc_in_bit&C_INF_P)!=C_INF_P);});

         opa_float = $bitstoshortreal(opa_in_bit);
         opb_float = $bitstoshortreal(opb_in_bit);
         opc_float = $bitstoshortreal(opc_in_bit);

         opa_out = opa_in_bit;
         opb_out = opb_in_bit;
         opc_out = opc_in_bit;

         case (operation)
           C_OP_ADD:  check_result = $shortrealtobits(opa_float+opb_float); // addition
           C_OP_SUB:  check_result = $shortrealtobits(opa_float-opb_float); // subtraction
           C_OP_MULT: check_result = $shortrealtobits(opa_float*opb_float); // multiplication
           C_OP_MAC:  check_result = $shortrealtobits(opa_float*opb_float+opc_float); // multiply-accumulate
           C_OP_DIV:  check_result = $shortrealtobits(opa_float/opb_float); // division
           C_OP_SQRT: begin
              opa_abs_float = $bitstoshortreal(opa_in_bit&32'h7fffffff);
              check_result = $shortrealtobits(opa_abs_float**(0.5)); // square root
              opa_out = $shortrealtobits(opa_abs_float);
           end
           C_OP_ITF: begin // int to float
              $cast(opa_int, opa_in_bit); // cast to integer
              $cast(itf_result, opa_int); // cast int to float
              // special cases..
              check_result = $shortrealtobits(itf_result);
              opa_out = opa_in_bit;
           end
           C_OP_FTI: begin // float to int
              $cast(fti_result, opa_float); // cast to integer
              if (opa_float>=C_MAX_INT_F) // int to high -> maximum
                fti_result = C_MAX_INT;
              if (opa_float<=C_MIN_INT_F) // int to low -> minimum
                fti_result = C_MIN_INT;
              if (($shortrealtobits(opa_float) & C_NAN_P) == C_NAN_P) // input is NaN -> 
                fti_result = C_MAX_INT;
              if (($shortrealtobits(opa_float) & C_NAN_N) == C_NAN_N) // input is NaN -> 
                fti_result = C_MIN_INT;
              check_result = fti_result;
           end
         endcase
      end
   endfunction
      
endpackage
