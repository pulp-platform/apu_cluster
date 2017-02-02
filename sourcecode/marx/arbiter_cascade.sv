////////////////////////////////////////////////////////////////////////////////
// Copyright (C) 2017 ETH Zurich, University of Bologna                       //
// All rights reserved.                                                       //
//                                                                            //
// This code is under development and not yet released to the public.         //
// Until it is released, the code is under the copyright of ETH Zurich        //
// and the University of Bologna, and may contain unpublished work.           //
// Any reuse/redistribution should only be under explicit permission.         //
//                                                                            //
// Bug fixes and contributions will eventually be released under the          //
// SolderPad open hardware license and under the copyright of ETH Zurich      //
// and the University of Bologna.                                             //
//                                                                            //
// Engineer:       Mario Burger - marioburger@student.ethz.ch                 //
//                                                                            //
//                                                                            //
// Design Name:    arbiter_cascade.sv                                         //
// Project Name:   shared APU                                                 //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:                                                               //
//                                                                            //
// HISTORY                                                                    //
// - [2014-10-13] file created                                                //
// - [2014-10-16] changed naming convention and added functionality           //
// - [2014-10-17] added arbiter stage                                         //
// - [2014-10-20] changed some SysVerilog related issues                      //
// - [2014-10-24] changed <= to = in all always_comb processes                //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////


/// Allocates the \c NOUT resources at the output to the \c NIN requesters at
/// the input. It is done with a cascade of round robin schedulers.
module arbiter #(
		parameter NIN = 4, // number of request inputs
		parameter NOUT = 2 // number of allocatable resources
	)(
		input clk_ci,
		input rst_rbi,
		marx_arbiter_if.arbiter io
	);

	// Array of masked request signals after each arbiter stage
	logic [NOUT-1:0] [NIN-1:0] req_masked_d;

	// Grant bitmasks for masking request signals, there are just NOUT-1
	// bitmasks, because the first request signal doesn't have to be masked.
	logic [NOUT-2:0] [NIN-1:0] assid_bitmask_d;

	// Instantiate one arbiter stage for each allocatable resource, provide the
	// masked request array
	generate for (genvar i = 0; i < NOUT; i++) begin : g_arb_stages
		arbiter_stage #(.NIN(NIN)) arbiter_stage_i (
			.clk_ci(clk_ci),
			.rst_rbi(rst_rbi),
			.req_di(req_masked_d[i]),
			.avail_di(io.avail_d[i]),
			.assid_do(io.assid_d[i]),
			.alloc_do(io.alloc_d[i])
		);
		end
	endgenerate

	// // Read the inital request signals into the array
	// assign req_masked_d [0] = io.req_d;

	// Generate masked request signal
	always_comb begin : p_delegator
		// Read the inital request signals into the array
		req_masked_d [0] = io.req_d;

		// Translates the assignement IDs into bitmasks
		for (int i = 0; i < NOUT-1; i++) begin
				assid_bitmask_d[i] = '0;
				assid_bitmask_d[i][io.assid_d[i]] = 1;
		end

		// Mask the request signals, if the resource is not available, it does
		// not mask the request
		for (int i = 1; i < NOUT; i++) begin
			if (io.avail_d[i-1]) begin
				req_masked_d[i] = req_masked_d[i-1] & ~assid_bitmask_d[i-1];
			end else begin
				req_masked_d[i] = req_masked_d[i-1];
			end
		end

		// Acks the requests that were allocated
		io.ack_d = '0;
		for (int i = 0; i < NOUT; ++i) begin
			if (io.avail_d[i] & io.alloc_d[i]) begin
				io.ack_d[io.assid_d[i]] = 1;
			end
		end
	end

endmodule


/// For each allocatable resource there is one arbiter stage, which allocates
/// the corresponding resource to a CPU.
module arbiter_stage #(
		parameter NIN = 4, // number of request inputs
		parameter NIN2 = $clog2(NIN)
	)(
		input clk_ci,
		input rst_rbi,
		input logic [NIN-1:0] req_di,
		input logic avail_di,
		output logic unsigned [NIN2-1:0] assid_do,
		output logic alloc_do
	);

	// Variables for stage state register
	logic unsigned [NIN2-1:0] selidx_dp;
	logic unsigned [NIN2-1:0] selidx_dn;

	// Vectors for lower and upper bits
	logic [NIN-1:0] lomask_d;
	logic [NIN-1:0] loreqmasked_d;
	logic [NIN-1:0] upreqmasked_d;

	// Index of first one in lower or upper masked request vector
	logic unsigned [NIN2-1:0] lofoneidx_d;
	logic unsigned [NIN2-1:0] upfoneidx_d;

	// Signals for no ones found
	logic noloone_s;
	logic noupone_s;
	logic noone_s;

	// Scheduling process
	always_comb begin : p_schedule
		// Generate mask for lower and upper bits
		for (int i = 0; i < NIN; ++i) begin
			if (i < selidx_dp+1) begin
				lomask_d[i] = 0;
			end else begin
				lomask_d[i] = 1;
			end
		end

		// Jump to next one found
		if (noone_s) begin
			selidx_dn = selidx_dp;
		end else if (noloone_s) begin
			selidx_dn = upfoneidx_d;
		end else begin
			selidx_dn = lofoneidx_d;
		end
	end

	// Apply mask to request
	assign loreqmasked_d = req_di & lomask_d;
	assign upreqmasked_d = req_di & ~lomask_d;

	// No one found in lower or upper bits
	assign noone_s = (noloone_s & noupone_s);

    // If no one is found at all, the resource is not allocated, else it is
	assign alloc_do = ~noone_s & avail_di;

	// Assign the assignment id to the output
	assign assid_do = selidx_dn;


	// Find first one in lower bits
	firstone_arbiter #(.G_VECTORLEN(NIN)) lower_first_one_i
	(
		.Vector_DI(loreqmasked_d),
		.FirstOneIdx_DO(lofoneidx_d),
		.NoOnes_SO(noloone_s)
	);

	// Find first one in upper bits
	firstone_arbiter #(.G_VECTORLEN(NIN)) upper_first_one_i
	(
		.Vector_DI(upreqmasked_d),
		.FirstOneIdx_DO(upfoneidx_d),
		.NoOnes_SO(noupone_s)
	);

	// Arbiter stage state
	always_ff @(posedge clk_ci or negedge rst_rbi) begin : p_regs
		if (~rst_rbi) begin
			selidx_dp <= '0;
		end else begin
			selidx_dp <= selidx_dn;
		end
	end

endmodule
