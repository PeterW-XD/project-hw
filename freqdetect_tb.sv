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
         if (addr == 10'hCC)      data = 28'h0EE00EE;    // addr: 204 decimal when reversed; should be returned as highest
         else if (addr == 10'h260) data = 28'h0FF00FF;   // addr: 24 decimal when reversed; should be skipped even if larger than 10'hCC
         else                     data = 28'h0AA00AA;
         #500;
      end
      
      wren = 0;
      reset = 1;
      #100;
      reset = 0;
		
		#100;
		fftdone = 1;

		#1000;
	end

endmodule
