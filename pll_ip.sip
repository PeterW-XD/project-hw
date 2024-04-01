set_global_assignment -entity "pll_ip" -library "lib_pll_ip" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "pll_ip" -library "lib_pll_ip" -name IP_TOOL_VERSION "21.1"
set_global_assignment -entity "pll_ip" -library "lib_pll_ip" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_pll_ip" -name SPD_FILE [file join $::quartus(sip_path) "pll_ip.spd"]

set_global_assignment -library "lib_pll_ip" -name MISC_FILE [file join $::quartus(sip_path) "pll_ip_sim/pll_ip.vo"]
