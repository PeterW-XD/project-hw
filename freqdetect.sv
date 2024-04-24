module freqdetect(
		input logic clk,				// 50 MHz, 20 ns
		input logic reset,
		input logic fftdone,			// Set high upon FFT block finishing
		input logic [27:0] ramq,		// Output port of channel 1 FFT RAM

		output logic detectdone,		// Set high when iteration is complete
		output logic [9:0] ramaddr,		// Address to read from RAM
		output logic [9:0] maxbin		// Index of max bin
);

enum logic [4:0] {idle, readone, readtwo, multiply, compare} state;
logic [9:0] ramaddr_rv;  // Bit-reversal of ramaddr (restores linear index in FFT)
logic [13:0] realsq;
logic [13:0] imagsq;
logic [27:0] curmag;
logic [27:0] lastmag;
logic ireset;				// Internal reset
logic rst;

assign rst = ireset || reset;
assign curmag = realsq*realsq + imagsq*imagsq;
assign ramaddr_rv = {ramaddr[0], ramaddr[1], ramaddr[2], ramaddr[3], ramaddr[4], ramaddr[5], ramaddr[6], ramaddr[7], ramaddr[8], ramaddr[9]};

initial begin
	ireset = 1;
	@(negedge clk) ireset = 0;
end

always_ff @(posedge clk) begin
	if (rst) begin
		detectdone <= 0;

		ramaddr <= 10'b0;
		maxbin <= 10'b0;
		realsq <= 14'b0;
		imagsq <= 14'b0;
		lastmag <= 27'b0;
		
		state <= idle;
	end else begin
		case (state)
			idle: if (fftdone && !detectdone) state <= readone;
			readone:					// First read cycle; ramaddr set during compare/reset
				state <= readtwo;
			readtwo:					// Second read cycle
				state <= multiply;
			multiply: begin				// Read components into multiplier input registers
				realsq <= ramq[27:14];
				imagsq <= ramq[13:0];
				state <= compare;
			end
			compare: begin				// Update bin corresponding to squared mag max
				if ((curmag > lastmag) && (ramaddr_rv > 10'd30)) begin
					maxbin <= ramaddr;
					lastmag <= curmag;
				end
				
				if (ramaddr == 10'h3FF) begin
					detectdone <= 1;
					state <= idle;
				end else state <= readone;
				
				ramaddr <= ramaddr + 1;
			end
			
			default: state <= idle;
		endcase;
	end
end

endmodule
