set_global_assignment -entity "multiplier" -library "lib_multiplier" -name IP_TOOL_NAME "altera_mult_add"
set_global_assignment -entity "multiplier" -library "lib_multiplier" -name IP_TOOL_VERSION "23.1"
set_global_assignment -entity "multiplier" -library "lib_multiplier" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_multiplier" -name SPD_FILE [file join $::quartus(sip_path) "multiplier.spd"]

set_global_assignment -library "lib_multiplier" -name MISC_FILE [file join $::quartus(sip_path) "multiplier_sim/multiplier.v"]
