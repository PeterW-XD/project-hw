module audio(	
				input logic clk,	// 50M, 20ns
				input logic reset,
				input logic chipselect,
				input logic read,
				input logic [2:0] address,
				input logic SD1,	// Serial data input: microphone set 1
				input logic SD2,	// set 2
				input logic SD3,	// Backup
				input logic SCK,	// Sampling rate * 32 bits * 2 channels: 325ns
				
				output logic WS,	// Smapling rate * 2 channels,
				output logic [31:0] readdata,
				output logic irq
				);
	
logic WS_d;
logic rst;
logic sck_rst;	
logic [23:0] right1, left1;  // Temp memory
logic [23:0] right2, left2;  // Temp memory
logic [5:0] clk_cnt;	// Count 64 to generate WS signal
logic [4:0] cnt;  		// Count 24 to read 24-bit wide sound signal
logic left_pop, right_pop;	// 24-bit ready signal
logic [1:0] current; 	// Current state
logic [1:0]	next;			// Next state
logic [1:0] state; 	// Synchronize SCK clock to clk clock
logic pop;					// Synchronize to clk domain
parameter IDLE = 2'b0, LEFT = 2'b1, RIGHT = 2'd2;	// Three states for reading left and right channels

/* Generate reset signal
 */
initial begin
	rst = 1;
	sck_rst = 1;
	irq = 0;
	@(posedge clk) rst = 0;
	@(posedge SCK) sck_rst = 0;
end

/* WS clk generator
 * Delay WS one cycle
 */
always_ff @(negedge SCK) begin
	if (rst) begin
		clk_cnt <=  6'd0;
		WS_d <= 1'd0;
	end else begin
		clk_cnt <= clk_cnt + 6'd1;
		WS_d <= WS; // Delay one cycle
	end
end

assign WS = clk_cnt[5];  // Flip at 31 cycle

/* I2S decoder
 * State machine with three state: IDLE, LEFT, RIGHT
 * Mealy
 * One combinational logic for state change
 * IDLE -> LEFT -> RIGHT -> LEFT -> ...
 */
always_comb begin
	case (current)
		IDLE: if (WS_d == 1 & WS == 0) next = LEFT;
					else if (WS_d == 0 & WS == 1) next = RIGHT;
					else next = current;
		LEFT: if (WS_d == 0 & WS == 1) next = RIGHT;
					else next = current;
		RIGHT: if (WS_d == 1 & WS == 0) next = LEFT;
					 else next = current;
		default: next = IDLE;
	endcase		
end

always_ff @(negedge SCK) begin
	if (sck_rst) begin
		current <= IDLE;
		cnt <= 5'd0;
		right1 <= 24'd0;
		right2 <= 24'd0;
		left1 <= 24'd0;
		left2 <= 24'd0;
		left_pop <= 1'b0;
		right_pop <= 1'b0;
	end else begin
		current <= next;	// Assign next state
		cnt <= cnt + 5'd1;// Period is 32
		case (current)
			LEFT: if (cnt < 25) begin
							left1 <= {left1[22:0], SD1};		// Left channel
							left2 <= {left2[22:0], SD2};		// Left channel
							left_pop <= 1'd0;
						end else
							left_pop <= 1'd1;
			RIGHT: if (cnt < 25) begin
							right1 <= {right1[22:0], SD1}; // Right channel
							right2 <= {right2[22:0], SD2}; // Right channel
							right_pop <= 1'd0;
						 end else 
							right_pop <= 1'd1;
			default: begin											// IDLE state included
								left_pop <= 1'd0;
								right_pop <= 1'd0;
							 end
		endcase
	end
end

always_ff @(posedge clk) begin
	if (rst) begin
		state = 2'd0;
		pop <= 1'd0;
	end else
		case (state)
			2'd0: if (right_pop) begin state <= 2'd1; pop <= 1'd1; end
			2'd1: if (right_pop) begin state <= 2'd2; pop <= 1'd0; end
			2'd2: if (~right_pop) begin state <= 2'd0; pop <= 1'd0; end
		endcase
end

// Send to HPS
always_ff @(posedge clk) begin
	if (pop) begin
		irq <= 1'd1;
	end
	if (chipselect && read)
		case (address)
		3'h0: readdata <= {{8{1'b0}}, left1};
		3'h1: readdata <= {{8{1'b0}}, right1};
		3'h2: readdata <= {{8{1'b0}}, left2};
		3'h3: readdata <= {{8{1'b0}}, right2};
		3'h4: begin
				irq <= 1'd0;
				readdata <= 32'd1;
		end
		endcase
end

endmodule

