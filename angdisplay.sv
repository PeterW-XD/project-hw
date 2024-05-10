module angdisplay(input logic clk,
                  input logic wbdone,        // done signal from weightblock
                  input logic [3:0] KEY,     // Reset key is 0
			      input logic signed [7:0] angle,

	    	      output logic [6:0] signdisp, disp0, disp1);

    logic [7:0] absang;
    logic [7:0] tens;

    assign reset = ~KEY[0];
    assign absang = angle[7] ? ~angle + 1 : angle;

    always_comb begin
        if (0 <= absang && absang < 10)
            tens = 8'd0;
        else if (10 <= absang && absang < 20)
            tens = 8'd10;
        else if (20 <= absang && absang < 30)
            tens = 8'd20;
        else if (30 <= absang && absang < 40)
            tens = 8'd30;
        else if (40 <= absang && absang < 50)
            tens = 8'd40;
        else if (50 <= absang && absang < 60)
            tens = 8'd50;
        else if (60 <= absang && absang < 70)
            tens = 8'd60;
        else if (70 <= absang && absang < 80)
            tens = 8'd70;
        else if (80 <= absang && absang < 90)
            tens = 8'd80;
        else if (90 <= absang && absang < 100)
            tens = 8'd90;
        else
            tens = 0;
    end
	
	always_ff @(posedge clk) begin
        if (reset) begin
            signdisp <= 7'b011_1111;
            disp0 <= 7'b011_1111;
            disp1 <= 7'b011_1111;
        end else if (wbdone) begin
            signdisp <= angle[7] ? 7'b100_0000 : 7'b111_1111;
            // Convert |angle| to two 7segs (-90 to 90)
            // Tens place
            case (tens)
                8'd0:    disp1 <= 7'b111_1111;       // blank
                8'd10:   disp1 <= 7'b111_1001;       // 1
                8'd20:   disp1 <= 7'b010_0100;       // 2
                8'd30:   disp1 <= 7'b011_0000;       // 3
                8'd40:   disp1 <= 7'b001_1001;       // 4
                8'd50:   disp1 <= 7'b001_0010;       // 5
                8'd60:   disp1 <= 7'b000_0010;       // 6
                8'd70:   disp1 <= 7'b111_1000;       // 7
                8'd80:   disp1 <= 7'b000_0000;       // 8
                8'd90:   disp1 <= 7'b001_0000;       // 9
                default: disp1 <= 7'b011_1111;       // -
            endcase

            // Ones place
            // mod 8; mod 10 too expensive and only needs to accommodate 5 degree resolution
            case ((absang - tens) & 8'b000_0111) 
                8'd0:   disp0 <= 7'b100_0000;
                8'd1:   disp0 <= 7'b111_1001;
                8'd2:   disp0 <= 7'b010_0100;
                8'd3:   disp0 <= 7'b011_0000;
                8'd4:   disp0 <= 7'b001_1001;
                8'd5:   disp0 <= 7'b001_0010;
                8'd6:   disp0 <= 7'b000_0010;
                8'd7:   disp0 <= 7'b111_1000;
                default: disp0 <= 7'b011_1111;
            endcase
        end
    end

endmodule