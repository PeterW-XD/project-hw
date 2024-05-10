/* FFT Wrapper for one channel
 * Author: Sound Localizer
 * Includes:
 * 1. FFT ip core, RAM ip core
 * 2. FFT control logic
 */
module fft_wrapper(
	input logic clk,
	input logic rst_n,					// Active low
	input logic go,						// Reset FSM
	input logic ready,					// Raw data RAMs ready to be read input from audio.sv
	input logic [13:0] data_in,				// Raw data input
	input logic [9:0] rd_addr_fft,				// Read address of fft RAMs -> pass through signal

	output logic [10:0] addr_raw,				// Read address of the raw data RAMs
	output logic [27:0] ram_q				// fft results from fft RAM
);

	logic ready_ff1, ready_raw;				// ready signal synchronize: SCK->clk
	logic go_ff1, go_ff2;					// go signal: SCK->clk
	logic valid_ff1, valid_ff2;
	logic finish;

	// fft ip singals
	logic in_valid, ready_fft, out_valid;
	logic in_sop, in_eop, out_sop, out_eop;
	logic [13:0] out_real, out_imag;

	// RAM signals
	logic [9:0] wr_addr;
	logic wren;

	enum {IDLE, READ, WRITE} state, next_state;
	enum {VACANT, START, BLOCK1, STOP, BLOCK2} flag, next_flag;
	parameter RAM_FULL = 11'd1023, FFT_PTS = 11'd1024;

/* Control Calculation
 * FSM
 * IDLE: Wait for the ready signals from raw data RAM and FFT engine
 * READ: Read the raw data out of the RAM
 * WRITE: Write the fft results to RAM when out_valid(source_valid) is high
 */ 
/* Control in_sop and in_eop (i.e. sink_sop & sink_eop)
 * FSM
 * VACANT: sink_sop and sink_eop are low. 
 * Transit to START when valid_ff1 is high;
 * START: set sink_sop to high for one cycle. (Naturally delays two cycles because of FSM)
 * BLOCK1: BLOCK the FSM until finish is high.
 * STOP: set sink_eop to high for one cycle.
 * BLOCK2: BLOCK the FSM until reset (go)
 */ 
	always_comb begin
		if (~rst_n) begin
			state = IDLE;
			flag = VACANT:
			finish = 1'd0;
			addr_raw = 11'd0;
			wr_addr = 10'd0;
			valid_ff1 = 1'd0;
			ready = 1'd0;
			go = 1'd0;
			in_sop = 1'd0;
			in_eop = 1'd0;
		end else begin
			case (state) 
				IDLE: begin 
					valid_ff1 = 1'd0;
					next_state =  (ready_raw && ready_fft) ? READ : IDLE;
				end
				READ: begin
					valid_ff1 = 1'd1;
					addr_raw = addr_raw + 11'd1;
					next_state = (addr_raw == RAM_FULL) ? WRITE : READ;
					finish = (addr_raw == RAM_FULL) ? 1'b1 : 1'b0; 
				end
				WRITE: begin
					addr_raw = 11'd0;
					next_state = (go_ff2) ? IDLE : WRITE; // 
					wr_addr = (out_valid) ? wr_addr + 10'd1 : 10'd0;
				end
				default: next_state = IDLE;
			endcase
			case (flag) 
				VACANT: begin
					in_sop = 1'd0;
					in_eop = 1'd0;
					next_flag = (valid_ff1) ? START : VACANT;
				end
				START: begin
					in_sop = 1'd1;
					next_flag = BLOCK1;
				end
				BLOCK1: begin
					in_sop = 1'd0;
					next_flag = (finish) ? STOP : BLOCK1;
				end
				STOP: begin
					in_eop = 1'd1;
					next_flag = BLOCK2;
				end
				BLOCK2: begin
					in_eop = 1'd0;
					next_flag = (go_ff2) ? VACANT : BLOCK2;
				end
				default: next_flag = VACANT;
			endcase 
		end
	end

	/*synchronizer |-> ready, go, valid signals*/
	always_ff @(posedge clk) begin
		if (~rst_n) begin
			//ready <= 1'b0;
			ready_ff1 <= 1'd0;
			ready_raw <= 1'd0;
			//go <= 1'b0;			
			go_ff1 <= 1'd0;
			go_ff2 <= 1'd0;
			//valid_ff1 <= 1'd0;
			valid_ff2 <= 1'd0;
			in_valid <= 1'd0;
		end else begin
			ready_ff1 <= ready;
			ready_raw <= ready_ff1; // use ready_raw 
			go_ff1 <= go;
			go_ff2 <= go_ff1; // use go_ff2 
			// valid_ff1 delays two clk cycles to align with the outputs of RAM (raw data RAM)
			valid_ff2 <= valid_ff1; 
			in_valid <= valid_ff2; // use in_valid
		end
	end

	/*FSM FF*/
	always_ff @(posedge clk) begin
		if (~rst_n) begin
			state <= IDLE;
			flag <= VACANT;
		end else begin
			state <= next_state;
			flag <= next_flag;
		end
	end

	assign wren = rst_n ? out_valid : 1'd0;



	fft_block fft_init(
		// INPUT 
		.clk(clk), 
		.reset_n(rst_n), 
		.sink_valid(in_valid),			// Asserted when data is valid 
		.sink_error(2'b00), 			// Error 
		.sink_sop(in_sop), 			// Start of input
		.sink_eop(in_eop), 			// End of input
		.sink_real(data_in),			// Real input data (signed)
		.sink_imag(data_in), 
		.fftpts_in(FFT_PTS),			// The number of points
		.inverse(1'b0), 
		.source_ready(1'b1),			// Asserted when downstream module is able to accept data

		// OUTPUT 
		.sink_ready(ready_fft), 		// Output. Asserted when fft engine can accept data.
		.source_valid(out_valid),		// Output valid
		.source_error(),			// Output error 
		.source_sop(out_sop), 			// Start of output. Only valid when source valid
		.source_eop(out_eop), 
		.source_real(out_real), 		// output_real
		.source_imag(out_imag),			// output_imag 
		.fftpts_out()
	);

	ram_fft_output fft_ram1(
		// INPUT
		.clock			(clk),
		.data			({out_real, out_imag}),			// 28 bits width
		.rdaddress		(rd_addr_fft),				// 10 bits width address
		.wraddress		(wr_addr),
		.wren			(wren),

		// OUTPUT
		.q			(ram_q)
	);

endmodule      
