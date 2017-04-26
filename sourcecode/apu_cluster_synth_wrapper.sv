import apu_package::*;

module apu_cluster_synth_wrapper
  #(
    parameter NB_CORES       = 4,
    parameter WAPUTYPE       = 6,
    parameter SHARED_FP_DIVSQRT = 2
    )
   (
    input logic                              clk_i,
    input logic                              rst_ni,
    
    input logic apu_master_req_ds_s,
    input logic apu_master_ready_us_s,
    output logic apu_master_ack_ds_s,

    input logic                         apu_master_req_i [NB_CORES-1:0],
    input logic                         apu_master_ready_i [NB_CORES-1:0],
    output logic                        apu_master_gnt_o [NB_CORES-1:0],
    // request channel
    input logic [31:0]                  apu_master_operands_i [NARGS_CPU-1:0] [NB_CORES-1:0],
    input logic [WOP_CPU-1:0]           apu_master_op_i [NB_CORES-1:0],
    input logic [WAPUTYPE-1:0]          apu_master_type_i [NB_CORES-1:0],
    input logic [NDSFLAGS_CPU-1:0]      apu_master_flags_i [NB_CORES-1:0],
    // response channel
    output logic                        apu_master_valid_o [NB_CORES-1:0],
    output logic [31:0]                 apu_master_result_o [NB_CORES-1:0],
    output logic [NUSFLAGS_CPU-1:0]     apu_master_flags_o [NB_CORES-1:0]
   
    );
   
   cpu_marx_if
     #(
       .WOP_CPU(WOP_CPU),
       .WAPUTYPE(WAPUTYPE),
		   .NUSFLAGS_CPU(NUSFLAGS_CPU),
		   .NDSFLAGS_CPU(NDSFLAGS_CPU),
       .NARGS_CPU(NARGS_CPU)
       )
   apu_cluster_bus [NB_CORES-1:0] ();

   for (genvar i=0; i<NB_CORES;i++)
     begin
        assign apu_cluster_bus[i].tag_ds_d = '0;
        assign apu_cluster_bus[i].req_ds_s = apu_master_req_i[i];
        
        
        assign apu_cluster_bus[i].ready_us_s   = apu_master_ready_i[i];
        assign apu_master_gnt_o[i] = apu_cluster_bus[i].ack_ds_s;

        for (genvar j=0;j<3;j++)
          assign apu_cluster_bus[i].operands_ds_d[j] = apu_master_operands_i[j][i];
        
        assign apu_cluster_bus[i].op_ds_d      = apu_master_op_i[i];
        assign apu_cluster_bus[i].type_ds_d    = apu_master_type_i[i];
        assign apu_cluster_bus[i].flags_ds_d   = apu_master_flags_i[i];
        
        assign apu_master_valid_o[i] = apu_cluster_bus[i].valid_us_s;
        assign apu_master_result_o[i] = apu_cluster_bus[i].result_us_d;
        assign apu_master_flags_o[i] = apu_cluster_bus[i].flags_us_d;
     end
   
   apu_cluster
     #(
       .C_NB_CORES         ( NB_CORES          ),
       .NDSFLAGS_CPU       ( NDSFLAGS_CPU      ),
       .NUSFLAGS_CPU       ( NUSFLAGS_CPU      ),
       .WOP_CPU            ( WOP_CPU           ),
       .NARGS_CPU          ( NARGS_CPU         ),
       .WAPUTYPE           ( WAPUTYPE          ),
       .SHARED_FP          ( SHARED_FP         ),
       .SHARED_DSP_MULT    ( 0   ),
       .SHARED_INT_MULT    ( 0   ),
       .SHARED_INT_DIV     ( 0   ),
       .SHARED_FP_DIVSQRT  ( SHARED_FP_DIVSQRT )
       )
   apu_cluster_i
     (
      .clk_i            ( clk_i                     ),
      .rst_ni           ( rst_ni                    ),
      .cpus             ( apu_cluster_bus           )
      );


endmodule // apu_cluster
    