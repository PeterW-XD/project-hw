set_global_assignment -entity "pll_new" -library "lib_pll_new" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "pll_new" -library "lib_pll_new" -name IP_TOOL_VERSION "21.1"
set_global_assignment -entity "pll_new" -library "lib_pll_new" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_pll_new" -name SPD_FILE [file join $::quartus(sip_path) "pll_new.spd"]

set_global_assignment -library "lib_pll_new" -name MISC_FILE [file join $::quartus(sip_path) "pll_new_sim/pll_new.vo"]
