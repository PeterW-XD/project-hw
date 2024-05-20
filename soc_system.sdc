
    foreach {clock port} {
	clock_50_1 CLOCK_50
	clock_50_2 CLOCK2_50
	clock_50_3 CLOCK3_50
	clock_50_4 CLOCK4_50
    } {
	create_clock -name $clock -period 20ns [get_ports $port]
    }
    
    create_clock -name clock_27_1 -period 37 [get_ports TD_CLK27]

    derive_pll_clocks -create_base_clocks
    derive_clock_uncertainty

