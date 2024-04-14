`timescale 1ns/100ps 
module testbench; 

reg clk;
wire[13:0] fsin_o, fcos_o;

initial 
begin 
	clk = 0;
end

always 
begin 
	#10 clk = !clk;
end

wire reset_n;

nco_signal nco_inst(
	.clk (clk),
	.reset_n(reset_n),
	.clken(1'b1), 
	.phi_inc_i(32'd3355443), // from nco ip core 
	.fsin_o (fsin_o),
	.fcos_o(fcos_o), 
	.out_valid(out_valid)
);



fft_wrapper fft_wrapper_inst
(
	.clk(clk),
	.in_signal(in_signal_sig),
	.real_power(real_power_sig),
	.imag_power(imag_power_sig), 
	.fft_source_sop(fft_source_sop_sig),
	.sink_sop(sink_sop_sig),
	.sink_eop(sink_eop_sig),
	.sink_valid(sink_valid_sig)
	//.reset_n(reset_n)
);
endmodule
