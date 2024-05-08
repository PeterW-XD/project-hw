module freqdetect(
		input logic clk,				// 50 MHz, 20 ns
		input logic [3:0] KEY,			// Reset key is 0
		input logic fftdone,			// Set high upon FFT block finishing
		input logic [27:0] ramq,		// Output port of channel 1 FFT RAM

		output logic detectdone,		// Set high when iteration is complete
		output logic [9:0] ramaddr,		// Address to read from RAM
		output logic [9:0] maxbin		// Index of max bin
);

enum logic [5:0] {idle, readone, readtwo, multiply, compare, complete} state;
logic [9:0] ramaddr_rv;  // Bit-reversal of ramaddr (restores linear index in FFT)
logic signed [13:0] real_c;
logic signed [13:0] imag_c;
logic [28:0] cursqmag;
logic [28:0] maxsqmag;

assign reset = ~KEY[0];
assign cursqmag = real_c*real_c + imag_c*imag_c;
assign ramaddr_rv = {ramaddr[0], ramaddr[1], ramaddr[2], ramaddr[3], ramaddr[4], ramaddr[5], ramaddr[6], ramaddr[7], ramaddr[8], ramaddr[9]};

always_ff @(posedge clk) begin
	if (reset) begin
		detectdone <= 0;

		ramaddr <= 10'b0;
		maxbin <= 10'b0;
		real_c <= 14'b0;
		imag_c <= 14'b0;
		maxsqmag <= 27'b0;

		state <= idle;
	end else begin
		case (state)
			idle:
				if (fftdone && !detectdone)	state <= readone;
			readone:					// First read cycle; ramaddr set during compare/reset
				state <= readtwo;
			readtwo:					// Second read cycle
				state <= multiply;
			multiply: begin				// Read components into multiplier input registers
				real_c <= ramq[27:14];
				imag_c <= ramq[13:0];
				state <= compare;
			end
			compare: begin				// Update bin corresponding to squared mag max
				if ((cursqmag > maxsqmag) && (ramaddr_rv > 10'd30)) begin
					maxbin <= ramaddr;
					maxsqmag <= cursqmag;
				end
				
				if (ramaddr == 10'h3FF) begin
					detectdone <= 1;
					state <= complete;
				end else begin
					state <= readone;
					ramaddr <= ramaddr + 1;
				end
			end
			complete: begin	// Hold ramaddr at maxbin until fftdone signal
				ramaddr <= maxbin;
				detectdone <= 0;

				if (fftdone) begin
					ramaddr <= 10'b0;
					maxbin <= 10'b0;
					real_c <= 14'b0;
					imag_c <= 14'b0;
					maxsqmag <= 27'b0;
					state <= readone;
				end
			end

			default: state <= idle;
		endcase;
	end
end

endmodule
