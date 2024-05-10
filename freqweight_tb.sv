`timescale 1ns / 1ps

module freqweight_tb();
    parameter CLK_PERIOD = 20; // Clock period in ns

    // shared signals
    logic clk;
    logic reset;

    // freqdetect logic
    logic fftdone;
    logic [9:0] maxbin;

    // weightblock signals
    logic done;
    logic [5:0] bnum;
    logic [7:0] doa;

    FFT1_TESTRAM ram1 (
	    .clock		(clk),
		.rdaddress	(dut1.ramaddr),
        .wren       (0),
        .wraddress  (),
		.data		(),
        .q          (dut1.ramq)
	);

    FFT2_TESTRAM ram2 (
	    .clock		(clk),
		.rdaddress	(dut2.rdaddr2),
        .wren       (0),
        .wraddress  (),
		.data		(),
        .q          (dut2.ramq2)
	);

    FFT3_TESTRAM ram3 (
	    .clock		(clk),
		.rdaddress	(dut2.rdaddr3),
        .wren       (0),
        .wraddress  (),
		.data		(),
        .q          (dut2.ramq3)
	);

    FFT4_TESTRAM ram4 (
	    .clock		(clk),
		.rdaddress	(dut2.rdaddr4),
        .wren       (0),
        .wraddress  (),
		.data		(),
        .q          (dut2.ramq4)
	);

    freqdetect dut1 (
        .clk        (clk),
        .KEY        ({3'b0, reset}),
        .fftdone    (fftdone),
        .detectdone (dut2.detectdone),
        .ramq       (ram1.q),
        .ramaddr    (ram1.rdaddress),
        .maxbin     (maxbin)
    );

    weightblock dut2 (
        .clk        (clk),
        .KEY        ({3'b0, reset}),
        .detectdone (dut1.detectdone),
        .maxbin     (dut1.maxbin),
        .ramq1      (ram1.q),
        .ramq2      (ram2.q),
        .ramq3      (ram3.q),
        .ramq4      (ram4.q),

        .rdaddr2    (ram2.rdaddress),
        .rdaddr3    (ram3.rdaddress),
        .rdaddr4    (ram4.rdaddress),
        .done       (done),
        .bnum       (bnum),
        .doa        (doa)
    );

    always #((CLK_PERIOD / 2)) clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        fftdone = 0;

        #100;
        reset = 0;
        #100;
        reset = 1;
        
        #100;
        fftdone = 1;
        #20;
        fftdone = 0;

        #150000;
        fftdone = 1;
        #20;
        fftdone = 0;

        #150000;

        $stop;
    end


endmodule
