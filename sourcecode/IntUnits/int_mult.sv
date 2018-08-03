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
// Engineer:      Michael Gautschi - gautschi@iis.ee.ethz.ch                  //
//                                                                            //
// Design Name:    Shared Multiplier                                          //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Shared integer multiplier                                  //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module int_mult
  import riscv_defines_apu::*;
(
  input  logic [ 2:0] operator_i,
 
  input  logic [31:0] op_a_i,
  input  logic [31:0] op_b_i,
  input  logic [31:0] op_c_i,
  input  logic [4:0]  imm_i,
  input  logic        short_subword_i,
  input  logic [1:0]  short_signed_i,
 
  output logic [31:0] result_o
);

   ///////////////////////////////////////////////////////////////
   //  ___ _  _ _____ ___ ___ ___ ___   __  __ _   _ _  _____   //
   // |_ _| \| |_   _| __/ __| __| _ \ |  \/  | | | | ||_   _|  //
   //  | || .  | | | | _| (_ | _||   / | |\/| | |_| | |__| |    //
   // |___|_|\_| |_| |___\___|___|_|_\ |_|  |_|\___/|____|_|    //
   //                                                           //
   ///////////////////////////////////////////////////////////////
  
   logic [31:0]       int_op_a_msu;
   logic [31:0]       int_op_b_msu;
   logic [31:0]       int_result;
   logic [33:0]       short_result;

   logic              int_is_msu;
   
   assign int_is_msu = (operator_i == MUL_MSU32);

   assign int_op_a_msu = op_a_i ^ {32{int_is_msu}};
   assign int_op_b_msu = op_b_i & {32{int_is_msu}};

   assign int_result = $signed(op_c_i) + $signed(int_op_b_msu) + $signed(int_op_a_msu) * $signed(op_b_i);


// short multiplier
   logic [16:0]       short_op_a;
   logic [16:0]       short_op_b;
   logic [32:0]       short_op_c;
   logic [33:0]       short_mac;
   logic              short_mac_msb;
   logic [31:0]       short_round, short_round_tmp;
   logic [ 4:0]       short_imm;
   logic [ 1:0]       short_subword;
   logic [ 1:0]       short_signed;
   logic              short_shift_arith;
   logic              short_shift_ext;

   assign short_imm         = imm_i;
   assign short_subword     = {2{short_subword_i}};
   assign short_signed      = short_signed_i;
   assign short_shift_arith = short_signed_i[0];
   assign short_shift_ext   = short_signed_i[0];

   // prepare the rounding value
   assign short_round_tmp   = (32'h00000001) << imm_i;
   assign short_round       = (operator_i == MUL_IR) ? {1'b0, short_round_tmp[31:1]} : '0;

   // perform subword selection and sign extensions
   assign short_op_a[15:0]  = short_subword[0] ? op_a_i[31:16] : op_a_i[15:0];
   assign short_op_b[15:0]  = short_subword[1] ? op_b_i[31:16] : op_b_i[15:0];

   assign short_op_a[16]    = short_signed[0] & short_op_a[15];
   assign short_op_b[16]    = short_signed[1] & short_op_b[15];

   assign short_op_c        = {1'b0, op_c_i};

   assign short_mac         = $signed(short_op_c) + $signed(short_op_a) * $signed(short_op_b) + $signed(short_round);
   assign short_mac_msb     = short_mac[31];

   assign short_result      = $signed({short_shift_arith & short_mac_msb, 
                                       short_shift_ext & short_mac_msb, short_mac[31:0]}) >>> short_imm;
   
   ////////////////////////////////////////////////////////
   //   ____                 _ _     __  __              //
   //  |  _ \ ___  ___ _   _| | |_  |  \/  |_   ___  __  //
   //  | |_) / _ \/ __| | | | | __| | |\/| | | | \ \/ /  //
   //  |  _ <  __/\__ \ |_| | | |_  | |  | | |_| |>  <   //
   //  |_| \_\___||___/\__,_|_|\__| |_|  |_|\__,_/_/\_\  //
   //                                                    //
   ////////////////////////////////////////////////////////

   logic              unsupported;

   always_comb
     begin
        result_o   = '0;
        unsupported = 1'b0;

        unique case (operator_i[2:0])
          MUL_I, MUL_IR:        result_o = short_result;
          
          MUL_MAC32, MUL_MSU32: result_o = int_result;
          
          default: unsupported = 1'b1;
        endcase
     end
   
endmodule
