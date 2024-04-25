module weightblock(
	input logic clk,
	input logic reset,
	input logic detectdone,

	input logic [9:0] maxbin,
	input logic [9:0] rdaddr2,
	input logic [9:0] rdaddr3,
	input logic [9:0] rdaddr4,
	input logic [23:0] ram1q,
	input logic [23:0] ram2q,
	input logic [23:0] ram3q,
	input logic [23:0] ram4q,
	
	output logic done,
	output logic [7:0] doa,		// signed (-90 to 90)
);

input logic [3:0] fftvals [27:0];

// Note: rdaddr1 is set by freqdetect block when detectdone = 1
assign rdaddr2 = maxbin;
assign rdaddr3 = maxbin;
assign rdaddr4 = maxbin;

endmodule
