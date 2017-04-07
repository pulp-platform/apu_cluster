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
// Engineer:       Andreas Traber - traber@iis.ee.ethz.ch                     //
//                                                                            //
// Additional contributions by:                                               //
//                 Michael Schaffner - schaffner@iis.ee.ethz.ch               //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                                                                            //
// Design Name:    Shared integer divider                                     //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:                                                               //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

import riscv_defines::*;
import apu_cluster_package::*;

module int_div 
#(
  parameter TAG_WIDTH = 0,
  parameter STAT_WIDTH = NUSFLAGS_INT_DIV
)
(
  input  logic                  clk_i,
  input  logic                  rst_ni,

  input  logic                  En_i,

  input logic [2:0]             Op_i,
  
  input logic [31:0]            OpA_i,
  input logic [31:0]            OpB_i,
  input logic [TAG_WIDTH-1:0]   Tag_i,
 
  output logic [STAT_WIDTH-1:0] Status_o,

  output logic [FP_WIDTH-1:0]   Res_o,
  output logic [TAG_WIDTH-1:0]  Tag_o,
  output logic                  Valid_o,
  output logic                  Ready_o

);

   // PIPE REG SIGNALS
   logic [TAG_WIDTH-1:0]        Tag_DP;

   logic                        enable;
   logic [ 2:0]                 Op, Op_DP;

   logic [31:0]                 OpA, OpA_DP;
   logic [31:0]                 OpB, OpB_DP;

   logic                        active;
   logic                        div_ready;
   
   assign Tag_o        = Tag_DP;
   assign Ready_o      = ~active;
   assign Valid_o      = active & div_ready;
   assign Status_o     = '0;

   assign OpA = En_i ? OpA_i : OpA_DP;
   assign OpB = En_i ? OpB_i : OpB_DP;
   assign Op  = En_i ? Op_i  : Op_DP;
   
   always_ff @(posedge clk_i or negedge rst_ni) 
     begin
        if(~rst_ni) begin
           enable          <= '0;
           Op_DP           <= '0;
           OpA_DP          <= '0;
           OpB_DP          <= '0;
           
           active          <= 1'b0;
           Tag_DP          <= '0;
        end else begin
           enable          <= En_i;

           if (En_i) begin
              $info("starting iterative APU div-operation");
              Op_DP         <= Op_i;
              OpA_DP        <= OpA_i;
              OpB_DP        <= OpB_i;
              
              active        <= 1'b1;
              Tag_DP        <= Tag_i;
           end

           if (Valid_o) begin
              active        <= 1'b0;
              $info("completed iterative APU div-operation");
           end
        end
     end

  //////////////////////////////////////////////////
  //  ____ _____     __   __  ____  _____ __  __  //
  // |  _ \_ _\ \   / /  / / |  _ \| ____|  \/  | //
  // | | | | | \ \ / /  / /  | |_) |  _| | |\/| | //
  // | |_| | |  \ V /  / /   |  _ <| |___| |  | | //
  // |____/___|  \_/  /_/    |_| \_\_____|_|  |_| //
  //                                              //
  //////////////////////////////////////////////////

  logic [31:0] div_result;

  logic [31:0] operand_a_rev;
  logic [31:0] operand_a_neg;
  logic [31:0] operand_a_neg_rev;

  // generate negated and reversed operands
  assign operand_a_neg = ~OpA;

  generate
    genvar k;
    for(k = 0; k < 32; k++)
    begin
      assign operand_a_rev[k] = OpA[31-k];
    end
  endgenerate

  generate
    genvar m;
    for(m = 0; m < 32; m++)
    begin
      assign operand_a_neg_rev[m] = operand_a_neg[31-m];
    end
  endgenerate


  // shift

  logic [5:0]  div_shift;
  logic        div_valid;

  logic [31:0] shift_left_result;

  assign shift_left_result = OpA << div_shift;

  // first one stuff
  logic [31:0] ff_input;
  logic [5:0]  clb_result; // count leading bits
  logic [4:0]  ff1_result; // holds the index of the first '1'
  logic        ff_no_one;  // if no ones are found
  logic [4:0]  fl1_result; // holds the index of the last '1'

  always_comb
  begin
    ff_input = 'x;

    case (Op[2:0])
      ALU_DIVU[2:0],
      ALU_REMU[2:0]: ff_input = operand_a_rev;

      ALU_DIV[2:0],
      ALU_REM[2:0]: begin
        if (OpA[31])
          ff_input = operand_a_neg_rev;
        else
          ff_input = operand_a_rev;
      end
    endcase
  end

  alu_ff alu_ff_i
  (
    .in_i        ( ff_input   ),
    .first_one_o ( ff1_result ),
    .no_ones_o   ( ff_no_one  )
  );

  // special case if ff1_res is 0 (no 1 found), then we keep the 0
  // this is done in the result mux
  assign fl1_result  = 5'd31 - ff1_result;
  assign clb_result  = ff1_result - 5'd1;


  logic        div_signed;
  logic        div_op_a_signed;
  logic        div_op_b_signed;
  logic [5:0]  div_shift_int;

  assign div_signed = Op[0];

  assign div_op_a_signed = OpA[31] & div_signed;
  assign div_op_b_signed = OpB[31] & div_signed;

  assign div_shift_int = ff_no_one ? 6'd31 : clb_result;
  assign div_shift = div_shift_int + (div_op_a_signed ? 6'd0 : 6'd1);

  assign div_valid = enable;

  /////////////////////////////////////////////////////////////////
  // actual divider module
  /////////////////////////////////////////////////////////////////

  // inputs A and B are swapped
  riscv_alu_div div_i
  (
    .Clk_CI       ( clk_i             ),
    .Rst_RBI      ( rst_ni            ),

    // input IF
    .OpA_DI       ( OpB               ),
    .OpB_DI       ( shift_left_result ),
    .OpBShift_DI  ( div_shift         ),
    .OpBIsZero_SI ( (OpA == 32'h0)    ),

    .OpBSign_SI   ( div_op_a_signed   ),
    .OpCode_SI    ( Op[1:0]           ),

    .Res_DO       ( div_result        ),

    // Hand-Shake
    .InVld_SI     ( div_valid         ),
    .OutRdy_SI    ( 1'b1              ),
    .OutVld_SO    ( div_ready         )
  );
   
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
        Res_o = '0;

        unique case (Op[2:0])

          ALU_DIV[2:0],  ALU_REM[2:0],
            ALU_DIVU[2:0], ALU_REMU[2:0]: Res_o = div_result;

          default: ;
        endcase
     end



endmodule