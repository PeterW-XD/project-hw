//altmult_complex CBX_SINGLE_OUTPUT_FILE="ON" IMPLEMENTATION_STYLE="AUTO" INTENDED_DEVICE_FAMILY=""Cyclone V"" PIPELINE=4 REPRESENTATION_A="UNSIGNED" REPRESENTATION_B="UNSIGNED" WIDTH_A=18 WIDTH_B=18 WIDTH_RESULT=36 clock dataa_imag dataa_real datab_imag datab_real result_imag result_real
//VERSION_BEGIN 21.1 cbx_mgl 2021:10:21:11:11:47:SJ cbx_stratixii 2021:10:21:11:02:24:SJ cbx_util_mgl 2021:10:21:11:02:24:SJ  VERSION_END
// synthesis VERILOG_INPUT_VERSION VERILOG_2001
// altera message_off 10463



// Copyright (C) 2021  Intel Corporation. All rights reserved.
//  Your use of Intel Corporation's design tools, logic functions 
//  and other software and tools, and any partner logic 
//  functions, and any output files from any of the foregoing 
//  (including device programming or simulation files), and any 
//  associated documentation or information are expressly subject 
//  to the terms and conditions of the Intel Program License 
//  Subscription Agreement, the Intel Quartus Prime License Agreement,
//  the Intel FPGA IP License Agreement, or other applicable license
//  agreement, including, without limitation, that your use is for
//  the sole purpose of programming logic devices manufactured by
//  Intel and sold by Intel or its authorized distributors.  Please
//  refer to the applicable agreement for further details, at
//  https://fpgasoftware.intel.com/eula.



//synthesis_resources = altmult_complex 1 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
module  mgbuq
	( 
	clock,
	dataa_imag,
	dataa_real,
	datab_imag,
	datab_real,
	result_imag,
	result_real) /* synthesis synthesis_clearbox=1 */;
	input   clock;
	input   [17:0]  dataa_imag;
	input   [17:0]  dataa_real;
	input   [17:0]  datab_imag;
	input   [17:0]  datab_real;
	output   [35:0]  result_imag;
	output   [35:0]  result_real;

	wire  [35:0]   wire_mgl_prim1_result_imag;
	wire  [35:0]   wire_mgl_prim1_result_real;

	altmult_complex   mgl_prim1
	( 
	.clock(clock),
	.dataa_imag(dataa_imag),
	.dataa_real(dataa_real),
	.datab_imag(datab_imag),
	.datab_real(datab_real),
	.result_imag(wire_mgl_prim1_result_imag),
	.result_real(wire_mgl_prim1_result_real));
	defparam
		mgl_prim1.implementation_style = "AUTO",
		mgl_prim1.intended_device_family = ""Cyclone V"",
		mgl_prim1.pipeline = 4,
		mgl_prim1.representation_a = "UNSIGNED",
		mgl_prim1.representation_b = "UNSIGNED",
		mgl_prim1.width_a = 18,
		mgl_prim1.width_b = 18,
		mgl_prim1.width_result = 36;
	assign
		result_imag = wire_mgl_prim1_result_imag,
		result_real = wire_mgl_prim1_result_real;
endmodule //mgbuq
//VALID FILE
