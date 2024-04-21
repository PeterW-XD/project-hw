`timescale 1ns / 1ps

module freqdetect_tb();

    // Parameters
    parameter CLK_PERIOD = 20; // Clock period in ns

    // Signals
    logic clk;
    logic reset;
    logic fftdone;
    logic [27:0] ramq;
    logic detectdone;
    logic [10:0] ramaddr;
    logic [10:0] maxbin;

    // Instantiate the module
    freqdetect dut (
        .clk(clk),
        .reset(reset),
        .fftdone(fftdone),
        .ramq(ramq),
        .detectdone(detectdone),
        .ramaddr(ramaddr),
        .maxbin(maxbin)
    );

    // Clock generation
    always #((CLK_PERIOD / 2)) clk = ~clk;

    // Test stimulus
    initial begin
        clk = 0;
        reset = 1;
        fftdone = 0;
        ramq = 0;
        
        #10;
        reset = 0;

        // Test case: Provide FFT done signal and RAM data with max value at index 300
        fftdone = 1;
        ramaddr = 0;
        repeat (1024) begin
            ramq = 28'h00000000;
            if (ramaddr == 204) begin
                ramq = 28'h000FF000;
            end
            #20;
            ramaddr = ramaddr + 1;
        end

        $finish;
    end

endmodule
