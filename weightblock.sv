module weightblock(
	input logic clk,
	input logic reset,
	input logic detectdone,

	input logic [9:0] maxbin,
	input logic [9:0] rdaddr2,
	input logic [9:0] rdaddr3,
	input logic [9:0] rdaddr4,
	input logic [27:0] ram1q,	// FFT RAMs
	input logic [27:0] ram2q,
	input logic [27:0] ram3q,
	input logic [27:0] ram4q,
	
	output logic done,
	output logic bnum,				// (0 to 12)
	output logic signed [7:0] doa,	// (-90 to 90)
);

enum logic [1:0] {idle, micloop};
logic ireset;
logic mmclr;				// Synchronous clear for multiply accumulator
logic [2:0] mnum;			// Microphone number
logic [3:0] bnum;			// Beam number
logic [3:0] maxbnum;		// Beam corresponding to max power
logic [5:0] dladdr;			// ROM address to get delay coefficient
logic [27:0] dcoeff;		// Delay coefficient from ROM
logic [27:0] delayprod;		// Product of FFT and delay coefficient (delay coeff. mag ~1 so no bit expansion necessary)
logic [27:0] sigpwr;		// Sum of products of delay coefficients and FFTs at maxbin
logic [27:0] maxpwr;		// Max signal power
logic signed [3:0] sspec [27:0];	// FFTs by channel at maxbin

// Note: rdaddr1 is set by freqdetect block when detectdone = 1
assign rst = ireset || reset;
assign rdaddr2 = maxbin;
assign rdaddr3 = maxbin;
assign rdaddr4 = maxbin;
assign dladdr = 13*bnum + mnum;
assign maxdir = -90 + 15*maxbnum;

// Delay matrix preloaded into ROM
delay_ROM drom (
	.clock		(clk),
	.address	(dladdr),
	.q			(dcoeff)
);

// Complex multiplier for delay * FFT
compmult mult (
	.dataa	(dcoeff),
	.datab	(sspec[mnum]),
	.result	(delayprod)
);

// Multiplier for magnitude of delayprod
multiplier magmult (
	.dataa_0	(delayprod[27:14]),
	.datab_0	(delayprod[13:0]),
	.result		(sigpwr),
	.clock0		(clk),
	.sclr0		(mmclr)
);

always_ff @(posedge) begin
	if (rst) begin
		sspec[3:0] <= {ramq1, ramq2, ramq3, ramq4};
		maxpwr <= 28'b0;
		{mnum, bnum} <= 7'b0;
		dladdr <= 6'b0;
		doa <= 8'b-1;
		done <= 0;
	end else if (dladdr < 6'd51) begin
		case (state)
			idle: if (detectdone && !done) state <= micloop;
			micloop: begin	// Loop through channels and multiply by dcoeffs
				// Multipliers work combinationally
				// Accumulator updates on clock edges
				if (mnum == 3)	begin
					state <= compare;
				end else mnum <= mnum + 1;
			end 
			compare: begin
				// Update maxpwr and maxbnum based on accumulator output
				if (sigpwr > maxpwr) begin
					maxpwr <= sigpwr;
					maxbnum <= bnum;
				end
	
				if (bnum == 12) begin
					done <= 1;
					state <= idle;
				end else begin
					bnum <= bnum + 1;
					mnum <= 0;
					state <= micloop;
				end
			end
		endcase;
	end
end

endmodule
