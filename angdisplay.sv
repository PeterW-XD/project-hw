module angdisplay(input logic clk,
                  input logic wbdone,        // done signal from weightblock
                  input logic [3:0] KEY,     // Reset key is 0
			      input logic signed [7:0] angle,

	    	      output logic [6:0] signdisp, disp0, disp1);

    assign reset = ~KEY[0];
    logic [7:0] absang;
	
	always_ff @(posedge clk) begin
        if (reset) begin
            absang <= 7'b0;
            signdisp <= 7'b011_1111;
            disp0 <= 7'b011_1111;
            disp1 <= 7'b011_1111;
        end else if (wbdone) begin
            absang <= angle[7] ? ~angle + 1 : angle;
            signdisp <= angle[7] ? 7'b100_0000 : 7'b111_1111;
            // Convert |angle| to two 7segs (-90 to 90)
            // Tens place
            if (0 <= absang && absang < 10)
                disp1 <= 7'b100_0000;       // 0
            else if (10 <= absang && absang < 20)
                disp1 <= 7'b111_1001;       // 1
            else if (20 <= absang && absang < 30)
                disp1 <= 7'b010_0100;       // 2
            else if (30 <= absang && absang < 40)
                disp1 <= 7'b011_0000;       // 3
            else if (40 <= absang && absang < 50)
                disp1 <= 7'b001_1001;       // 4
            else if (50 <= absang && absang < 60)
                disp1 <= 7'b001_0010;       // 5
            else if (60 <= absang && absang < 70)
                disp1 <= 7'b000_0010;       // 6
            else if (70 <= absang && absang < 80)
                disp1 <= 7'b111_1000;       // 7
            else if (80 <= absang && absang < 90)
                disp1 <= 7'b000_0000;       // 8
            else if (90 <= absang && absang < 100)
                disp1 <= 7'b001_0000;       // 9
            else
                disp1 <= 7'b011_1111;       // -

            // Ones place
            // mod 8; mod 10 too expensive and only needs to accommodate 5 degree resolution
            case (absang & 7'b000_0111) 
                1'd0:   disp0 <= 7'b100_0000;
                1'd1:   disp0 <= 7'b111_1001;
                1'd2:   disp0 <= 7'b010_0100;
                1'd3:   disp0 <= 7'b011_0000;
                1'd4:   disp0 <= 7'b001_1001;
                1'd5:   disp0 <= 7'b001_0010;
                1'd6:   disp0 <= 7'b000_0010;
                1'd7:   disp0 <= 7'b111_1000;
                default: disp0 <= 7'b011_1111;
            endcase
        end
    end
 
endmodule