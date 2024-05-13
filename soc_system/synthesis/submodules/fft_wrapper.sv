/* FFT Wrapper for One Channel
 * Author: Sound Localizer Team
 * Includes:
 * 1. FFT ip core, RAM ip core
 * 2. FFT control logic
 * FFT Mode: Variable Streaming
 * Version Notes: 
 * I made the variable names consistent with fft_block's for clarity.
 */
module fft_wrapper(
	input logic clk,
	input logic rst_n,					// Active low
	input logic go,							// Reset FSM
	input logic ready,					// Raw data RAMs ready to be read
	input logic [13:0]data_in,	// Raw data input
	input logic [9:0]rd_addr_fft,	// Read address of fft RAMs

	output logic out_ready,			// Reserved
	output logic [10:0]addr_raw,// Read address of the raw data RAMs
	output logic [27:0]ram_q		// fft results from fft RAM
);

logic ready_ff1, ready_raw;	// ready signal synchronize: SCK->clk
logic go_ff1, go_ff2;		// go signal: SCK->clk
logic [9:0]count;		// 1024 counter
logic sor; 				// start of read (raw data)
// fft ip singals
logic sink_valid, sink_ready, source_valid;
logic sink_sop, sink_eop, source_sop, source_eop;
logic [13:0] source_real, source_imag;
// RAM signals
logic [9:0] wr_addr;
logic wren;

enum {IDLE, READ, WRITE, READY} state;
enum {VACANT, START} state_wr_addr;
parameter FFT_PTS = 11'd1024;

/* Generate sink_eop & sink_sop stream signals for fft_block
 * sor (start of raw) ensures addr_raw to output correctly,
 * which can align with the sink_sop & sink_eop stream
 */
always @(posedge clk) begin
	if (~rst_n) begin
		count = 10'd1;
	end else begin
		count <= count + 1'b1;
		if (count == 10'd0) begin 
			sink_eop <= 0;
			sink_sop <= 1;
			sink_valid <= 1;
		end else if(count == 10'd1) begin 
			sink_sop <= 0;
		end else if (count == 10'd1020) begin
			sor <= 1;
		end else if (count == 10'd1021) begin
			sor <= 0;
		end else if (count == 10'd1023) begin
			sink_eop <= 1;
		end
	end
end

/* Control Calculation
 * FSM
 * IDLE: Wait for the ready signals from raw data RAM and FFT engine
 * READ: Read the raw data out of the RAM
 * WRITE: Write the fft results to RAM when source_eop 
 * (I intentionally used eop instead of sop since eop is one cycle earlier than sop)
 * (So that it won't miss the first output in terms of wren)
 * READY: fft RAM is ready to be read to the next stage
 */ 
always_ff @(posedge clk) begin
	if (~rst_n) begin
		state <= IDLE;
		ready_ff1 <= 1'd0;
		ready_raw <= 1'd0;
		go_ff1 <= 1'd0;
		go_ff2 <= 1'd0;
		addr_raw <= 11'd2047;
		wren <= 1'd0;
		out_ready <= 1'd0;
	end else begin
		// Synchronize from SCK -> clk (Slow -> Fast) with 2 flip-flops
		ready_ff1 <= ready;
		ready_raw <= ready_ff1;
		go_ff1 <= go;
		go_ff2 <= go_ff1;	

		case (state)
			IDLE: begin
				out_ready <= 1'd0;
				if (ready_raw && sink_ready && sor) 
					state <= READ;
				else
					state <= IDLE; 
			end
			READ: begin
				addr_raw <= addr_raw + 11'd1;
				if (addr_raw == 11'd2046) begin // because the calculation delay of fft is about 1024
					state <= WRITE;
				end else begin
					state <= READ;
				end
			end
			WRITE: begin
				if (source_eop) begin
					wren <= 1'd1;
				end
				if (wr_addr == 10'd1023) begin
					wren <= 1'd0;
					state <= READY;
				end else
					state <= WRITE;
			end
			READY: begin
				out_ready <= 1'd1;
				if (go_ff2)
					state <= IDLE;
				else
					state <= READY;
				
			end
			default: begin
						state <= IDLE;
			end
		endcase
	end
end

/* Generate Control Singals for fft RAM
 * FSM
 * VACANT: wait until source_eop to start wr_addr streaming
 * START: generate wr_addr singal stream for FFT RAM
 */
always @(posedge clk) begin
	if (~rst_n) begin
		wr_addr <= 10'd0;
		state_wr_addr <= VACANT;
	end else begin
		case (state_wr_addr)
			VACANT: begin 
				wr_addr <= 10'd0;
				if (source_eop)
					state_wr_addr <= START;
				else 
					state_wr_addr <= VACANT;
			end
			START: begin
				wr_addr <= wr_addr + 10'd1;
			end
			default: state_wr_addr <= VACANT;
		endcase
	end
end

fft_block fft_init(
	.clk(clk), 
	.reset_n(rst_n), 
	.sink_valid(sink_valid), // Asserted when data is valid 
	.sink_ready(sink_ready), // Output. Asserted when fft engine can accept data. 
	.sink_error(2'b00), 	// Error 
	.sink_sop(sink_sop), 		// Start of input
	.sink_eop(sink_eop), 		// End of input
	.sink_real(data_in),// Real input data (signed)
	.sink_imag(14'd0), 
	.fftpts_in(FFT_PTS),			// The number of points
	.inverse(1'b0), 
	.source_valid(source_valid),		// Output valid
	.source_ready(1'b1),// Asserted when downstream module is able to accept data
	.source_error(),					// Output error 
	.source_sop(source_sop), // Start of output. Only valid when source valid
	.source_eop(source_eop), 
	.source_real(source_real), 
	.source_imag(source_imag),
	.fftpts_out()
);

ram_fft_output fft_ram1(
	.clock		(clk),
	.data		({source_real, source_imag}),	// 28 bits width
	.rdaddress	(rd_addr_fft),					// 10 bits width address
	.wraddress	(wr_addr),
	.wren		(wren),
	.q			(ram_q)
);

endmodule      
