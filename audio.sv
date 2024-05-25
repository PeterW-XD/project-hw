/* audio.sv
 * Top Module
 * Author: Sound Localizer
 * Notes:
 * 1. There is a startup time for mic.
 * 2. Contention across clock domains matters.
 */ 
module audio(	
	input logic clk,	// 50M, 20ns
	input logic reset,
	input logic chipselect,
	input logic read,
	input logic write,
	input logic [31:0] writedata,
	input logic [2:0] address,
	input logic SD1,	// Serial data input: microphone set 1
	input logic SD2,	// Set 2
	input logic SD3,	// Reserved
	input logic SD4,	// Reserved
	input logic SCK,	// Sampling rate * 32 bits * 2 channels: 320
	
	output logic WS,	// Sampling rate
	output logic irq,	// Reserved
	output logic [31:0] readdata,
	// X
	output logic [6:0] disp2,
	output logic [6:0] disp1,
	output logic [6:0] disp0,
	// Y
	output logic [6:0] disp5,
	output logic [6:0] disp4,
	output logic [6:0] disp3,

	// VGA
	output logic [7:0] VGA_R, VGA_G, VGA_B,
	output logic 	   VGA_CLK, VGA_HS, VGA_VS,
						VGA_BLANK_n,
	output logic 	   VGA_SYNC_n
);
	
logic rst_n = 0;
logic sck_rst = 1;
logic [3:0] count1 = 4'd0;
logic [3:0] count2 = 4'd0;
logic [5:0] clk_cnt;				// 64 counter to generate WS signal
logic [4:0] stretch_cnt1, stretch_cnt2;		// Strech signal for synchro
logic go, go_SCK;				// go command to start sampling and calculation
logic [23:0] right1, left1, right2, left2, right3, left3, right4, left4;  // Temp memory
// RAM for raw data
logic wrreq;							// write enable for raw data RAM
logic [10:0] wr_addr;				// RAM write address
logic [10:0] rd_addr;				// RAM read address
logic [15:0] ram1_in, ram2_in, ram3_in, ram4_in, ram5_in, ram6_in, ram7_in, ram8_in; // RAM inputs
logic [15:0] ram1q, ram2q, ram3q, ram4q, ram5q, ram6q, ram7q, ram8q;	// RAM outputs
logic ready1, ready2, ready3, ready4, ready5, ready6, ready7, ready8;	// Asserted when raw data RAM is full
logic rdreq1, rdreq2, rdreq3, rdreq4, rdreq5, rdreq6, rdreq7, rdreq8;
// FFT wrapper
logic [27:0] ram1_fft, ram2_fft, ram3_fft, ram4_fft, ram5_fft, ram6_fft, ram7_fft, ram8_fft;// RAM outputs for fft RAM

// Frequency detector
logic fftdone, detectdone;
logic [9:0] rd_addr_fd_x, maxbin_x;
logic [9:0] rd_addr_fd_y, maxbin_y;

// Weight block
logic [9:0] rdaddr2_wb_x, rdaddr3_wb_x, rdaddr4_wb_x;
logic [9:0] rdaddr2_wb_y, rdaddr3_wb_y, rdaddr4_wb_y;
logic wbdone, wbdone_SCK;
logic [5:0] bnum_x, bnum_y;
logic [7:0] doa_x, doa_y;

// VGA logic
logic [10:0] xcoor;
logic [9:0] ycoor;

// Testing logic
logic [9:0] rd_addr_fft1, rd_addr_fft2, rd_addr_fft3, rd_addr_fft4, rd_addr_fft5, rd_addr_fft6, rd_addr_fft7, rd_addr_fft8;

enum {IDLE, WRITE, READ} state;

/* Generate reset signal
 */
always_ff @(posedge clk) begin
	count1 <= count1 + 4'd1;
	if (count1 == 4'b1111)
		rst_n <= 1'd1;
end

always_ff @(negedge SCK) begin
	count2 <= count2 + 4'd1;
	if (count2 == 4'b1111)
		sck_rst = 1'd0;
end

/* Go signal synchronizer
 * go -> go_SCK
 * wbdone -> wbdone_SCK
 * Faster clk -> Slower SCK
 * 320/20 = 16
 * Stretch the go_clk signal so that SCK can get
 */ 
always_ff @(posedge clk) begin
	if (~rst_n) begin
		stretch_cnt1 <= 5'd0;
		stretch_cnt2 <= 5'd0;
	end else begin
		if (go) begin
			stretch_cnt1 <= 5'd16;
		end else if (stretch_cnt1 > 5'd0) begin
			stretch_cnt1 <= stretch_cnt1 - 5'd1;
		end
		if (wbdone) begin
			stretch_cnt2 <= 5'd16;
		end else if (stretch_cnt2 > 5'd0) begin
			stretch_cnt2 <= stretch_cnt2 - 5'd1;
		end		
	end
end
assign go_SCK = (stretch_cnt1 > 0) ? 1'd1 : 1'd0;
assign wbdone_SCK = (stretch_cnt2 > 0) ? 1'd1 : 1'd0;

/* WS clock generator
 * 64 division
 */
always_ff @(negedge SCK) begin // Negedge of SCK
	if (sck_rst) begin
		clk_cnt <=  6'd0;
	end else begin
		clk_cnt <= clk_cnt + 6'd1;
	end
end

assign WS = clk_cnt[5];  // Flip at 31st cycles

/* I2S decoder
 * Get left and right channels based on the clk_cnt counter
 * 0-25 left channel
 * 32-57 right channel
 */
always_ff @(negedge SCK) begin
	if (sck_rst) begin		// Initialize
		left1 <= 24'd0;
		right1 <= 24'd0;
		left2 <= 24'd0;
		right2 <= 24'd0;
		left3 <= 24'd0;
		right3 <= 24'd0;
		left4 <= 24'd0;
		right4 <= 24'd0;
		ram1_in <= 16'd0;
		ram2_in <= 16'd0;
		ram3_in <= 16'd0;
		ram4_in <= 16'd0;
		ram5_in <= 16'd0;
		ram6_in <= 16'd0;
		ram7_in <= 16'd0;
		ram8_in <= 16'd0;

		wr_addr <= 11'd2047;// 0 address is avaible
		wrreq <= 1'd0;	// Initialize with 0 to reset RAMs
		state <= IDLE;
	end else begin
		// Read from the bus
		if (clk_cnt > 0 && clk_cnt < 25) begin // Left channel, 24-bit dept, MSB first
			left1 <= {left1[22:0], SD1};
			left2 <= {left2[22:0], SD2};
			left3 <= {left3[22:0], SD3};
			left4 <= {left4[22:0], SD4};
		end else if (clk_cnt > 32 && clk_cnt < 57) begin	// Right channel
			right1 <= {right1[22:0], SD1}; 
			right2 <= {right2[22:0], SD2}; 
			right3 <= {right3[22:0], SD3}; 
			right4 <= {right4[22:0], SD4}; 
		end
		// FSM: 
		// IDLE: Transit to WRITE state when go_SCK is high
		// WRITE: Write raw data to RAMs
		// READ: Ready to be read to the FFT wrapper
		case (state)
			IDLE: begin
				if (go_SCK)
					state <= WRITE;
				else
					state <= IDLE;	
			end
			WRITE:begin
				if (clk_cnt == 57) begin	
					ram1_in <= left1[23:8];			// Discard the lesast 8 bits
					ram2_in <= right1[23:8];		
					ram3_in <= left2[23:8];
					ram4_in <= right2[23:8];
					ram5_in <= left3[23:8];
					ram6_in <= right3[23:8];
					ram7_in <= left4[23:8];
					ram8_in <= right4[23:8];

					wrreq <= 1'd1;
					wr_addr <= wr_addr + 11'd1; // Start with address 0 
				end else if (clk_cnt == 58) begin
					wrreq <= 1'd0;
				end

				if (wr_addr == 10'd1023)
					state <= READ;
				else
					state <= WRITE;
			end
			READ:	begin 
				wr_addr <= 11'd2047;
				if (go_SCK) begin
					state <= WRITE;
				end else begin
					state <= READ;
				end
			end
			default: begin 
					state <= IDLE;
			end 
		endcase
	end
end

/* Two Port RAM Instantiation
 * Raw data from i2s bus
 */ 
myfifo fifo1(
	.data	(ram1_in),
	.rdclk	(clk),
	.rdreq	(rdreq1),
	.wrclk	(SCK),
	.wrreq	(wrreq),
	.q		(ram1q),
	.rdfull	(ready1),
	.wrempty()
);

myfifo fifo2(
	.data	(ram2_in),
	.rdclk	(clk),
	.rdreq	(rdreq2),
	.wrclk	(SCK),
	.wrreq	(wrreq),
	.q		(ram2q),
	.rdfull	(ready2),
	.wrempty()
);

myfifo fifo3(
	.data	(ram3_in),
	.rdclk	(clk),
	.rdreq	(rdreq3),
	.wrclk	(SCK),
	.wrreq	(wrreq),
	.q		(ram3q),
	.rdfull	(ready3),
	.wrempty()
);

myfifo fifo4(
	.data	(ram4_in),
	.rdclk	(clk),
	.rdreq	(rdreq4),
	.wrclk	(SCK),
	.wrreq	(wrreq),
	.q		(ram4q),
	.rdfull	(ready4),
	.wrempty()
);

myfifo fifo5(
	.data	(ram5_in),
	.rdclk	(clk),
	.rdreq	(rdreq5),
	.wrclk	(SCK),
	.wrreq	(wrreq),
	.q		(ram5q),
	.rdfull	(ready5),
	.wrempty()
);
myfifo fifo6(
	.data	(ram6_in),
	.rdclk	(clk),
	.rdreq	(rdreq6),
	.wrclk	(SCK),
	.wrreq	(wrreq),
	.q		(ram6q),
	.rdfull	(ready6),
	.wrempty()
);
myfifo fifo7(
	.data	(ram7_in),
	.rdclk	(clk),
	.rdreq	(rdreq7),
	.wrclk	(SCK),
	.wrreq	(wrreq),
	.q		(ram7q),
	.rdfull	(ready7),
	.wrempty()
);
myfifo fifo8(
	.data	(ram8_in),
	.rdclk	(clk),
	.rdreq	(rdreq8),
	.wrclk	(SCK),
	.wrreq	(wrreq),
	.q		(ram8q),
	.rdfull	(ready8),
	.wrempty()
);

/* FFT wrapper module instantiation
 */ 
// X axis
fft_wrapper fft1(
	.clk(clk),
	.rst_n(rst_n),
	.go(detectdone),
	.ready(ready1),		    // Raw data ready
	.data_in(ram1q[15:2]),	// Raw data in
	.rd_addr_fft(rd_addr_fft1),// Read address of fft RAMs

	.fftdone(fftdone),
	.rdreq(rdreq1),
	.ram_q(ram1_fft)			// fft results from fft RAMs
);

fft_wrapper fft2(
	.clk(clk),
	.rst_n(rst_n),
	.go(detectdone),
	.ready(ready2),		    
	.data_in(ram2q[15:2]),
	.rd_addr_fft(rd_addr_fft2),

	.fftdone(),
	.rdreq(rdreq2), 
	.ram_q(ram2_fft)
);

fft_wrapper fft3(
	.clk(clk),
	.rst_n(rst_n),
	.go(detectdone),
	.ready(ready3),		    
	.data_in(ram3q[15:2]),
	.rd_addr_fft(rd_addr_fft3),

	.fftdone(),
	.rdreq(rdreq3),
	.ram_q(ram3_fft)
);

fft_wrapper fft4(
	.clk(clk),
	.rst_n(rst_n),
	.go(detectdone),
	.ready(ready4),
	.data_in(ram4q[15:2]),
	.rd_addr_fft(rd_addr_fft4),

	.fftdone(),
	.rdreq(rdreq4),
	.ram_q(ram4_fft)
);
// Y
fft_wrapper fft5(
	.clk(clk),
	.rst_n(rst_n),
	.go(detectdone),
	.ready(ready5),
	.data_in(ram5q[15:2]),
	.rd_addr_fft(rd_addr_fft5),

	.fftdone(),
	.rdreq(rdreq5),
	.ram_q(ram5_fft)
);
fft_wrapper fft6(
	.clk(clk),
	.rst_n(rst_n),
	.go(detectdone),
	.ready(ready6),
	.data_in(ram6q[15:2]),
	.rd_addr_fft(rd_addr_fft6),

	.fftdone(),
	.rdreq(rdreq6),
	.ram_q(ram6_fft)
);
fft_wrapper fft7(
	.clk(clk),
	.rst_n(rst_n),
	.go(detectdone),
	.ready(ready7),
	.data_in(ram7q[15:2]),
	.rd_addr_fft(rd_addr_fft7),

	.fftdone(),
	.rdreq(rdreq7),
	.ram_q(ram7_fft)
);
fft_wrapper fft8(
	.clk(clk),
	.rst_n(rst_n),
	.go(detectdone),
	.ready(ready8),
	.data_in(ram8q[15:2]),
	.rd_addr_fft(rd_addr_fft8),

	.fftdone(),
	.rdreq(rdreq8),
	.ram_q(ram8_fft)
);

// Test Interface
assign rd_addr_fft1 = rd_addr_fd_x;
assign rd_addr_fft2 = rdaddr2_wb_x;
assign rd_addr_fft3 = rdaddr3_wb_x;
assign rd_addr_fft4 = rdaddr4_wb_x;
assign rd_addr_fft5 = rd_addr_fd_y;
assign rd_addr_fft6 = rdaddr2_wb_y;
assign rd_addr_fft7 = rdaddr3_wb_y;
assign rd_addr_fft8 = rdaddr4_wb_y;

/* Frequency detector instantiation
*/
freqdetect fd_inst1(
	.clk		(clk),		// 50 MHz, 20 ns
	.reset		(~rst_n),		
	.fftdone	(fftdone),	// Set high upon FFT block finishing
	.ramq		(ram1_fft),	// Output port of channel 1 FFT RAM

	.detectdone	(detectdone),		// Set high when iteration is complete
	.ramaddr	(rd_addr_fd_x),		// Address to read from RAM
	.maxbin		(maxbin_x)// Index of max bin
);

freqdetect fd_inst2(
	.clk		(clk),		// 50 MHz, 20 ns
	.reset		(~rst_n),		
	.fftdone	(fftdone),	// Set high upon FFT block finishing
	.ramq		(ram5_fft),	// Output port of channel 1 FFT RAM

	.detectdone	(),		// Set high when iteration is complete
	.ramaddr	(rd_addr_fd_y),		// Address to read from RAM
	.maxbin		(maxbin_y)// Index of max bin
);

/* Weight block instantiation
*/
weightblock wb_inst1(
	.clk		(clk),
	.reset		(~rst_n),
	.detectdone	(detectdone),
	.maxbin		(maxbin_x),
	.ramq1		(ram1_fft),	// FFT RAMs
	.ramq2		(ram2_fft),
	.ramq3		(ram3_fft),
	.ramq4		(ram4_fft),

	.rdaddr2	(rdaddr2_wb_x),	// Will be set to maxbin for all FFT RAMs
	.rdaddr3	(rdaddr3_wb_x),
	.rdaddr4	(rdaddr4_wb_x),
	.weightdone	(wbdone),
	.bnum		(bnum_x),		// (0 to 36)
	.doa		(doa_x),		// (-90 to 90)

	.disp2		(disp2),
	.disp1		(disp1),
	.disp0		(disp0)		// 7seg displays
);

weightblock wb_inst2(
	.clk		(clk),
	.reset		(~rst_n),
	.detectdone	(detectdone),
	.maxbin		(maxbin_y),
	.ramq1		(ram5_fft),	// FFT RAMs
	.ramq2		(ram6_fft),
	.ramq3		(ram7_fft),
	.ramq4		(ram8_fft),

	.rdaddr2	(rdaddr2_wb_y),	// Will be set to maxbin for all FFT RAMs
	.rdaddr3	(rdaddr3_wb_y),
	.rdaddr4	(rdaddr4_wb_y),
	.weightdone	(),
	.bnum		(bnum_y),		// (0 to 36)
	.doa		(doa_y),		// (-90 to 90)

	.disp2		(disp5),
	.disp1		(disp4),
	.disp0		(disp3)		// 7seg displays
);

vga_ball vga_inst(
    clk, ~rst_n, xcoor, ycoor,

	VGA_R, VGA_G, VGA_B,
	VGA_CLK, VGA_HS, VGA_VS,
	VGA_BLANK_n,
	VGA_SYNC_n
);

/* Avalon bus configuration
 * readdata: FPGA -> HPS
 * writedata: HPS -> FPGA
 */  
always_ff @(posedge clk) begin
	if (reset) begin
		irq <= 1'd0;
		readdata <= 32'd0;
		go <= 1'd0;
		xcoor <= 11'd630;
		ycoor <= 10'd240;
	end else if (chipselect && read) begin
		case (address)
		3'h0: readdata <= {{24{doa_x[7]}}, doa_x};
		3'h1: readdata <= {{24{doa_y[7]}}, doa_y};
		endcase
	end else if (chipselect && write) begin
		case (address)
		3'h0 : go <= writedata[0];
		3'h1 : xcoor <= writedata[10:0];	// Lower 8 digits of xcoor
		3'h2 : ycoor <= writedata[9:0];	// Lower 8 digits of ycoor
		endcase
	end
end

endmodule
