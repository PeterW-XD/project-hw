`timescale 1ns / 1ps

module freqdetect_tb();
   parameter CLK_PERIOD = 20; // Clock period in ns

   logic clk;
   logic reset;
   logic fftdone;
   logic detectdone;
   logic wren;
   logic [9:0] wraddr;
   logic [9:0] ramaddr;
   logic [9:0] maxbin;
   logic [27:0] data;
   logic [27:0] ramq;

	FFT_RAM ram (
		.clock		(clk),
		.rdaddress	(ramaddr),
		.data			(data),
		.wraddress	(wraddr),
		.wren			(wren),
      .q          (dut.ramq)
	);
	
	freqdetect dut (
      .clk(clk),
      .reset(reset),
      .fftdone(fftdone),
      .detectdone(detectdone),
		.ramq(ram.q),
      .ramaddr(ramaddr),
      .maxbin(maxbin)
   );

	always #((CLK_PERIOD / 2)) clk = ~clk;

   initial begin

		clk = 0;
      reset = 0;
      fftdone = 0;
      wren = 1;

      // Fill RAM
      for (int addr = 0; addr < 1024; addr++) begin
         wraddr = addr;
         ramaddr  = addr;
         if (addr == 10'hCC) data = 28'hDDDD;
         else                data = 28'hAAAA;
         #1000;
      end
      
      wren = 0;
      reset = 1;
      #100;
      reset = 0;
		
		#100;
		fftdone = 1;

		#100000;
	end

endmodule
