module audio(	
				input logic clk,	// 50M, 20ns
				input logic reset,
				input logic chipselect,
				input logic read,
				input logic [1:0] address,
				input logic SD,
				input logic SCK,// Sampling rate * 32 bits * 2 channels: 325ns
				
				output logic WS,// Smapling rate * 2 channels
				output logic [31:0] readdata
				);
	
logic WS_d;
logic sck_rst;	
logic [23:0] right, left;  // Temp mem
//logic [2:0] clk_cnt1; // Count to 8. Total: 16 * 20ns = 320ns
logic [5:0] clk_cnt2;	// Count 64
logic [4:0] cnt;  // Count 24
logic left_pop, right_pop;
logic [1:0] current; // Current state
logic [1:0]	next;			// Next state
logic rst;
parameter IDLE = 2'b0, LEFT = 2'b1, RIGHT = 2'd2;

// SCK clk generator
//always_ff @(posedge clk) begin
//	if (rst) begin
//		SCK <= 1'd0;
//		clk_cnt1 <= 3'd0;
//	end else if (clk_cnt1 == 7) begin
//		SCK <= ~SCK;
//		clk_cnt1 <= 3'd0;
//	end else
//		clk_cnt1 <= clk_cnt1 + 3'd1;
//end

// WS clk generator
always_ff @(negedge SCK) begin
	if (rst) begin
		//WS <= 1'd0;
		clk_cnt2 <=  9'd0;
		WS_d <= 1'd0;
	//end else if (clk_cnt2 == 31) begin
	//	WS <= ~WS;
	//	clk_cnt2 <= 9'd0;
	end else begin
		clk_cnt2 <= clk_cnt2 + 6'd1;
		WS_d <= WS; // Delay one cycle
	end
end

assign WS = clk_cnt2[5];

initial begin
	rst = 1;
	sck_rst = 1;
	@(posedge clk) rst = 0;
	@(posedge SCK) sck_rst = 0;
end

/* I2S decoder
 * State machine with three state: IDLE, LEFT, RIGHT
 * Mealy
 * One combinational logic for state change
 * One Sequential logic
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
		right <= 24'd0;
		left <= 24'd0;
		left_pop <= 1'b0;
		right_pop <= 1'b0;
	end else begin
		current <= next;	// Assign next state
		cnt <= cnt + 5'd1;// Period is 32
		case (current)
			LEFT: if (cnt < 25) begin
							left <= {left[22:0], SD};		// Left channel
							left_pop <= 1'd0;
						end else
							left_pop <= 1'd1;
			RIGHT: if (cnt < 25) begin
							right <= {right[22:0], SD}; // Right channel
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

// Send to HPS
always_ff @(posedge clk) begin
	if (sck_rst) begin
		readdata <= 32'd0;
	end else if (chipselect && read) begin
		case (address)
		2'h0: readdata <= {{8{1'b0}}, left};
		2'h1: readdata <= {{8{1'b0}}, right};
		2'h2: readdata <= {{30{1'b0}}, right_pop, left_pop};
		endcase
	end
end

endmodule
