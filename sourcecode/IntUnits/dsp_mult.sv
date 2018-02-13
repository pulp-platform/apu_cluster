////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Copyright 2018 ETH Zurich and University of Bologna.                       //
// Copyright and related rights are licensed under the Solderpad Hardware     //
// License, Version 0.51 (the “License”); you may not use this file except in //
// compliance with the License.  You may obtain a copy of the License at      //
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law  //
// or agreed to in writing, software, hardware and materials distributed under//
// this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR     //
// CONDITIONS OF ANY KIND, either express or implied. See the License for the //
// specific language governing permissions and limitations under the License. //
//                                                                            //
// Engineer:      Michael Gautschi - gautschi@iis.ee.ethz.ch                  //
//                                                                            //
// Design Name:    Shared Multiplier                                          //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Shared multiplier for dot-products, and integer            //
//                 multiplications                                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

import riscv_defines_apu::*;

module dsp_mult
(
  input  logic [ 2:0] operator_i,

  // integer multiplier

  input  logic [31:0] op_a_i,
  input  logic [31:0] op_b_i,
  input  logic [31:0] op_c_i,

  // dot multiplier
  input  logic [ 1:0] dot_signed_i,

  output logic [31:0] result_o
);

  ///////////////////////////////////////////////////////////////
  //  ___ _  _ _____ ___ ___ ___ ___   __  __ _   _ _  _____   //
  // |_ _| \| |_   _| __/ __| __| _ \ |  \/  | | | | ||_   _|  //
  //  | || .  | | | | _| (_ | _||   / | |\/| | |_| | |__| |    //
  // |___|_|\_| |_| |___\___|___|_|_\ |_|  |_|\___/|____|_|    //
  //                                                           //
  ///////////////////////////////////////////////////////////////
  
  logic [31:0]        int_op_a;
  logic [31:0]        int_op_b;
  logic [31:0]        int_op_c;
   
  logic [31:0] int_op_a_msu;
  logic [31:0] int_op_b_msu;
  logic [31:0] int_result;

  logic        int_is_msu;
  logic        int_mul_active;

  assign int_mul_active = ((operator_i == MUL_MSU32) || (operator_i == MUL_MAC32));
   
  assign int_op_a = int_mul_active ? op_a_i : '0;
  assign int_op_b = int_mul_active ? op_b_i : '0;
  assign int_op_c = int_mul_active ? op_c_i : '0;
  
  assign int_is_msu = (operator_i == MUL_MSU32);

  assign int_op_a_msu = int_op_a ^ {32{int_is_msu}};
  assign int_op_b_msu = int_op_b & {32{int_is_msu}};

  assign int_result = $signed(int_op_c) + $signed(int_op_b_msu) + $signed(int_op_a_msu) * $signed(int_op_b);

  ///////////////////////////////////////////////
  //  ___   ___ _____   __  __ _   _ _  _____  //
  // |   \ / _ \_   _| |  \/  | | | | ||_   _| //
  // | |) | (_) || |   | |\/| | |_| | |__| |   //
  // |___/ \___/ |_|   |_|  |_|\___/|____|_|   //
  //                                           //
  ///////////////////////////////////////////////

  logic [3:0][ 8:0] dot_char_op_a;
  logic [3:0][ 8:0] dot_char_op_b;
  logic [3:0][17:0] dot_char_mul;
  logic [31:0]      dot_char_result;

  logic [1:0][16:0] dot_short_op_a;
  logic [1:0][16:0] dot_short_op_b;
  logic [1:0][33:0] dot_short_mul;
  logic [31:0]      dot_short_result;

  // sign extension
  assign dot_char_op_a[0] = {dot_signed_i[1] & op_a_i[ 7], op_a_i[ 7: 0]};
  assign dot_char_op_a[1] = {dot_signed_i[1] & op_a_i[15], op_a_i[15: 8]};
  assign dot_char_op_a[2] = {dot_signed_i[1] & op_a_i[23], op_a_i[23:16]};
  assign dot_char_op_a[3] = {dot_signed_i[1] & op_a_i[31], op_a_i[31:24]};

  assign dot_char_op_b[0] = {dot_signed_i[0] & op_b_i[ 7], op_b_i[ 7: 0]};
  assign dot_char_op_b[1] = {dot_signed_i[0] & op_b_i[15], op_b_i[15: 8]};
  assign dot_char_op_b[2] = {dot_signed_i[0] & op_b_i[23], op_b_i[23:16]};
  assign dot_char_op_b[3] = {dot_signed_i[0] & op_b_i[31], op_b_i[31:24]};

  // dot-product multiplication
  assign dot_char_mul[0]  = $signed(dot_char_op_a[0]) * $signed(dot_char_op_b[0]);
  assign dot_char_mul[1]  = $signed(dot_char_op_a[1]) * $signed(dot_char_op_b[1]);
  assign dot_char_mul[2]  = $signed(dot_char_op_a[2]) * $signed(dot_char_op_b[2]);
  assign dot_char_mul[3]  = $signed(dot_char_op_a[3]) * $signed(dot_char_op_b[3]);

  assign dot_char_result  = $signed(dot_char_mul[0]) + $signed(dot_char_mul[1]) +
                            $signed(dot_char_mul[2]) + $signed(dot_char_mul[3]) +
                            $signed(op_c_i);


  // sign extension
  assign dot_short_op_a[0] = {dot_signed_i[1] & op_a_i[15], op_a_i[15: 0]};
  assign dot_short_op_a[1] = {dot_signed_i[1] & op_a_i[31], op_a_i[31:16]};

  assign dot_short_op_b[0] = {dot_signed_i[0] & op_b_i[15], op_b_i[15: 0]};
  assign dot_short_op_b[1] = {dot_signed_i[0] & op_b_i[31], op_b_i[31:16]};

  // dot-product multiplication
  assign dot_short_mul[0]  = $signed(dot_short_op_a[0]) * $signed(dot_short_op_b[0]);
  assign dot_short_mul[1]  = $signed(dot_short_op_a[1]) * $signed(dot_short_op_b[1]);

  assign dot_short_result  = $signed(dot_short_mul[0][31:0]) + $signed(dot_short_mul[1][31:0]) + $signed(op_c_i);


  ////////////////////////////////////////////////////////
  //   ____                 _ _     __  __              //
  //  |  _ \ ___  ___ _   _| | |_  |  \/  |_   ___  __  //
  //  | |_) / _ \/ __| | | | | __| | |\/| | | | \ \/ /  //
  //  |  _ <  __/\__ \ |_| | | |_  | |  | | |_| |>  <   //
  //  |_| \_\___||___/\__,_|_|\__| |_|  |_|\__,_/_/\_\  //
  //                                                    //
  ////////////////////////////////////////////////////////

  always_comb
  begin
    result_o   = '0;

    unique case (operator_i)

      MUL_DOT8:  result_o = dot_char_result[31:0];
      MUL_DOT16: result_o = dot_short_result[31:0];

      default: ;
    endcase
  end
endmodule
