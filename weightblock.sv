module weightblock(
	input logic clk,
	input logic reset,
	input logic detectdone,

	input logic [9:0] maxbin,
	input logic [27:0] ramq1,	// FFT RAMs
	input logic [27:0] ramq2,
	input logic [27:0] ramq3,
	input logic [27:0] ramq4,
	
	output logic [9:0] rdaddr2,	// Will be set to maxbin for all FFT RAMs
	output logic [9:0] rdaddr3,
	output logic [9:0] rdaddr4,
	output logic done,
	output logic [3:0] bnum,		// (0 to 12)
	output logic signed [7:0] doa	// (-90 to 90)
);

enum logic [4:0] {idle, memread, micloop, compare, complete} state;
logic rcount;				// Read cycle counter
logic [2:0] mnum;			// Microphone number
logic [3:0] maxbnum;		// Beam corresponding to max power
logic [5:0] dladdr;			// ROM address to get delay coefficient
logic [27:0] dcoeff;		// Delay coefficient from ROM
logic [55:0] delayprod;		// Product of FFT and delay coefficient
logic signed [31:0] ssreal;	// real(sigsum); sigsum = sum of all delayprods for a given bnum
logic signed [31:0] ssimag; // imag(sigsum)
logic [63:0] ssrealsq;		// real(sigsum)^2
logic [63:0] ssimagsq;		// imag(sigsum)^2
logic [64:0] sigpwr;		// |sigsum|^2, i.e. array output power
logic [64:0] maxpwr;		// Max array output power
logic signed [27:0] sspec [3:0];	// FFTs by channel at maxbin

// Note: rdaddr1 is set to maxbin by freqdetect block while it is in its complete state
assign rdaddr2 = maxbin;
assign rdaddr3 = maxbin;
assign rdaddr4 = maxbin;
assign dladdr = 4*bnum + mnum;
assign doa = -90 + 15*maxbnum;
assign sigpwr = ssrealsq + ssimagsq;

// Delay matrix preloaded into ROM
delay_ROM drom (
	.clock		(clk),
	.address	(dladdr),
	.q			(dcoeff)
);

// Complex multiplier for delay * FFT
compmult cmult (
	.dataa_real		(dcoeff[27:14]),
	.dataa_imag		(dcoeff[13:0]),
	.datab_real		(sspec[mnum][27:14]),
	.datab_imag		(sspec[mnum][13:0]),
	.result_real	(delayprod[55:28]),
	.result_imag	(delayprod[27:0])
);

// Multiplier IP computes square for real(sigsum)^2
realmult m1 (
	.dataa	(ssreal),
	.result	(ssrealsq)
);

// Multiplier IP computes square for imag(sigsum)^2
realmult m2 (
	.dataa	(ssimag),
	.result	(ssimagsq)
);

always_ff @(posedge clk) begin
	if (reset) begin
		sspec[3:0] <= {ramq4, ramq3, ramq2, ramq1};
		maxpwr <= 28'b0;
		maxbnum <= 4'b0;
		ssreal <= 32'b0;
		ssimag <= 32'b0;
		{mnum, bnum} <= 7'b0;
		rcount <= 0;
		done <= 0;

		state <= idle;
	end else if (dladdr < 6'd52) begin
		case (state)
			idle: begin
				if (detectdone && !done) state <= memread;
			end
			memread: begin
				if (rcount != 1) begin
					rcount <= rcount + 1;
				end else begin
					rcount <= 0;
					state <= micloop;
				end
			end
			micloop: begin	// Loop through channels and multiply by dcoeffs
				// Multipliers work combinationally
				ssreal <= ssreal + {{4{delayprod[55]}}, delayprod[55:28]};
				ssimag <= ssimag + {{4{delayprod[27]}}, delayprod[27:0]};
				if (mnum == 3)	begin
					state <= compare;
				end else begin
					mnum <= mnum + 1;
					state <= memread;
				end
			end 
			compare: begin
				// Update maxpwr and maxbnum
				if (sigpwr > maxpwr) begin
					maxpwr <= sigpwr;
					maxbnum <= bnum;
				end
				if (bnum == 4'd12) begin
					done <= 1;
					state <= complete;
				end else begin
					bnum <= bnum + 1;
					mnum <= 0;
					ssreal <= 32'b0;
					ssimag <= 32'b0;
					state <= memread;
				end
			end
			complete: begin
				done <= 0;
				if (detectdone) begin
					sspec[3:0] <= {ramq4, ramq3, ramq2, ramq1};
					maxpwr <= 65'b0;
					maxbnum <= 4'b0;
					ssreal <= 32'b0;
					ssimag <= 32'b0;
					{mnum, bnum} <= 7'b0;
					rcount <= 0;
					state <= memread;
				end
			end
		endcase;
	end
end

endmodule
