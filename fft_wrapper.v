module fft_wrapper(clk, in_signal, real_out, imag_out, fft_source_sop, sink_sop, sink_eop, sink_valid, reset_n);

input clk;
input wire[13:0] in_signal;

output wire[13:0] real_out;
output wire[13:0] imag_out;

wire[13:0] real_power;
wire[13:0] imag_power;
output wire sink_valid;
output wire sink_sop;
output wire sink_eop;
output wire fft_source_sop;

wire sink_ready;

wire[10:0] fft_pts;
wire fft_source_eop;

wire[13:0] real_to_fft_p;
wire[13:0] imag_to_fft_p;
reg[4:0] count;
output reg reset_n;
//reg eop2, sop2, eop5;

assign real_out = real_power/10000;
assign imag_out = imag_power/10000;

initial begin
	reset_n = 0;
	count = 5'd0;
end

always @(posedge clk) begin 
	count = count + 5'd1;
	if (count == 5'd10) begin
		reset_n = 1;
	end
end


control_fft control_fft_inst (
	.clk(clk), 
	.in_signal(in_signal), 
	.sink_valid(sink_valid), 
	.sink_ready(sink_ready), 
	.sink_error(), 
	.sink_sop(sink_sop), 
	.sink_eop(sink_eop), 
	.inverse(inverse), 
	.out_real(real_to_fft_p), 
	.out_imag(imag_to_fft_p), 
	.fft_pts(fft_pts)
);

fft_block fft_inst(
	.clk(clk), 
	.reset_n(reset_n), 
	.sink_valid(sink_valid), 
	.sink_ready(sink_ready), 
	.sink_error(2'b00), 
	.sink_sop(sink_sop), 
	.sink_eop(sink_eop), 
	.sink_real(real_to_fft_p),
	.sink_imag(imag_to_fft_p),
	.fftpts_in (fft_pts),
	.inverse(1'b0), 
	.source_valid(), 
	.source_ready(1'b1), 
	.source_error(),
	.source_sop(fft_source_sop),
	.source_eop(fft_source_eop), 
	.source_real(real_power), 
	.source_imag(imag_power),
	.fftpts_out()
);

endmodule
