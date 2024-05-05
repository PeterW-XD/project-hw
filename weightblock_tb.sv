`timescale 1ns / 1ps

module weightblock_tb();
    parameter CLK_PERIOD = 20; // Clock period in ns

    logic clk;
    logic reset;
    logic wren;
    logic done;
    logic detectdone;
    
    logic [5:0] bnum;
    logic [7:0] doa;
    logic [27:0] fft1;
    logic [27:0] fft2;
    logic [27:0] fft3;
    logic [27:0] fft4;

    logic [9:0] rdaddress;
    logic [9:0] wraddress;

	FFT_RAM ram1 (
	    .clock		(clk),
		.rdaddress	(10'd44),
        .wren       (wren),
        .wraddress  (wraddress),
		.data		(fft1),
        .q          (dut.ramq1)
	);

    FFT_RAM ram2 (
	    .clock		(clk),
		.rdaddress	(dut.rdaddr2),
        .wren       (wren),
        .wraddress  (wraddress),
		.data		(fft2),
        .q          (dut.ramq2)
	);

    FFT_RAM ram3 (
	    .clock		(clk),
		.rdaddress	(dut.rdaddr3),
        .wren       (wren),
        .wraddress  (wraddress),
		.data		(fft3),
        .q          (dut.ramq3)
	);

    FFT_RAM ram4 (
	    .clock		(clk),
		.rdaddress	(dut.rdaddr4),
        .wren       (wren),
        .wraddress  (wraddress),
		.data		(fft4),
        .q          (dut.ramq4)
	);
	
	weightblock dut (
        .clk        (clk),
        .reset      (reset),
        .detectdone (detectdone),
        .maxbin     (10'd44),
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
        clk = 1;
        reset = 0;
        wren = 0;
        done = 0;
        detectdone = 0;
        bnum = 4'b0;
        doa = 8'b0;
        rdaddress = 10'd44;
        wraddress = 10'd44;

        // 60 AOA
        // fft1[27:14] = -14'd226;
        // fft1[13:0] = -14'd310;
        // fft2[27:14] = 14'd338;
        // fft2[13:0] = -14'd175;
        // fft3[27:14] = -14'd175;
        // fft3[13:0] = -14'd557;
        // fft4[27:14] = 14'd156;
        // fft4[13:0] = 14'd501;

        // 85 AOA (SNR = 5)
        // fft1[27:14] = -14'd297;
        // fft1[13:0] = -14'd306;
        // fft2[27:14] = 14'd59;
        // fft2[13:0] = 14'd427;
        // fft3[27:14] = 14'd197;
        // fft3[13:0] = -14'd383;
        // fft4[27:14] = -14'd385;
        // fft4[13:0] = 14'd165;

        // -45 AOA but algorithm finds 75 (-15 SNR)
        fft1[27:14] = -14'd365;
        fft1[13:0] = -14'd244;
        fft2[27:14] = 14'd106;
        fft2[13:0] = 14'd509;
        fft3[27:14] = 14'd357;
        fft3[13:0] = -14'd468;
        fft4[27:14] = -14'd228;
        fft4[13:0] = 14'd306;

        // Fill RAM
        wren = 1;
        #40;
        wren = 0;

        // Reset
        reset = 1;
        #40;
        reset = 0;

        // Trigger weightblock to start
        detectdone = 1;
        #20;
        detectdone = 0;

        #10000;

        // Test reset behavior
        detectdone = 1;
        #20;
        detectdone = 0;

        #15000;
        $stop;
    end

endmodule
