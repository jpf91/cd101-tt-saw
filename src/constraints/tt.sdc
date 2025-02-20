# Taken from original Openlane base.sdc and slightly modified. Modified content is marked.
# -------------------------------------------------------------------------------------------------
set clock_port __VIRTUAL_CLK__
if { [info exists ::env(CLOCK_PORT)] } {
    set port_count [llength $::env(CLOCK_PORT)]

    if { $port_count == "0" } {
        puts "\[WARNING] No CLOCK_PORT found. A dummy clock will be used."
    } elseif { $port_count != "1" } {
        puts "\[WARNING] Multi-clock files are not currently supported by the base SDC file. Only the first clock will be constrained."
    }

    if { $port_count > "0" } {
        set ::clock_port [lindex $::env(CLOCK_PORT) 0]
    }
}
set port_args [get_ports $clock_port]
puts "\[INFO] Using clock $clock_port…"
create_clock {*}$port_args -name $clock_port -period $::env(CLOCK_PERIOD)

set input_delay_value [expr $::env(CLOCK_PERIOD) * $::env(IO_DELAY_CONSTRAINT) / 100]
set output_delay_value [expr $::env(CLOCK_PERIOD) * $::env(IO_DELAY_CONSTRAINT) / 100]
puts "\[INFO] Setting output delay to: $output_delay_value"
puts "\[INFO] Setting input delay to: $input_delay_value"

set_max_fanout $::env(MAX_FANOUT_CONSTRAINT) [current_design]
if { [info exists ::env(MAX_TRANSITION_CONSTRAINT)] } {
    set_max_transition $::env(MAX_TRANSITION_CONSTRAINT) [current_design]
}
if { [info exists ::env(MAX_CAPACITANCE_CONSTRAINT)] } {
    set_max_capacitance $::env(MAX_CAPACITANCE_CONSTRAINT) [current_design]
} 

set clk_input [get_port $clock_port]
set clk_indx [lsearch [all_inputs] $clk_input]

set all_inputs_wo_clk [lreplace [all_inputs] $clk_indx $clk_indx ""]

# Custom constraints: Also remove SPI SCLK port here
# -------------------------------------------------------------------------------------------------
proc kch_remove_port {portlist portname} {
    set port_input [get_port $portname]
    set port_indx [lsearch $portlist $port_input]
    return [lreplace $portlist $port_indx $port_indx ""]
}
# SPI CLK, MOSI and NSS
set spi_clk_pin {uio_in[3]}
set spi_mosi_pin {uio_in[1]}
set spi_nss_pin {uio_in[0]}
set all_inputs_wo_clk [kch_remove_port $all_inputs_wo_clk $spi_clk_pin]
set all_inputs_wo_clk [kch_remove_port $all_inputs_wo_clk $spi_mosi_pin]
set all_inputs_wo_clk [kch_remove_port $all_inputs_wo_clk $spi_nss_pin]
# -------------------------------------------------------------------------------------------------

#set rst_input [get_port resetn]
#set rst_indx [lsearch [all_inputs] $rst_input]
#set all_inputs_wo_clk_rst [lreplace $all_inputs_wo_clk $rst_indx $rst_indx ""]
set all_inputs_wo_clk_rst $all_inputs_wo_clk

# correct resetn
set clocks [get_clocks $clock_port]

# Note: Just assume fastest clock for all other inputs... 
# Trigger is actually sampled by ADSR clock and reset is sampled by both ADSR and normal CLK.
# But it should be fine.
set_input_delay $input_delay_value -clock $clocks $all_inputs_wo_clk_rst
set_output_delay $output_delay_value -clock $clocks [all_outputs]

if { ![info exists ::env(SYNTH_CLK_DRIVING_CELL)] } {
    set ::env(SYNTH_CLK_DRIVING_CELL) $::env(SYNTH_DRIVING_CELL)
}

set_driving_cell \
    -lib_cell [lindex [split $::env(SYNTH_DRIVING_CELL) "/"] 0] \
    -pin [lindex [split $::env(SYNTH_DRIVING_CELL) "/"] 1] \
    $all_inputs_wo_clk_rst

set_driving_cell \
    -lib_cell [lindex [split $::env(SYNTH_CLK_DRIVING_CELL) "/"] 0] \
    -pin [lindex [split $::env(SYNTH_CLK_DRIVING_CELL) "/"] 1] \
    $clk_input

set cap_load [expr $::env(OUTPUT_CAP_LOAD) / 1000.0]
puts "\[INFO] Setting load to: $cap_load"
set_load $cap_load [all_outputs]

puts "\[INFO] Setting clock uncertainty to: $::env(CLOCK_UNCERTAINTY_CONSTRAINT)"
set_clock_uncertainty $::env(CLOCK_UNCERTAINTY_CONSTRAINT) $clocks

puts "\[INFO] Setting clock transition to: $::env(CLOCK_TRANSITION_CONSTRAINT)"
set_clock_transition $::env(CLOCK_TRANSITION_CONSTRAINT) $clocks

puts "\[INFO] Setting timing derate to: $::env(TIME_DERATING_CONSTRAINT)%"
set_timing_derate -early [expr 1-[expr $::env(TIME_DERATING_CONSTRAINT) / 100]]
set_timing_derate -late [expr 1+[expr $::env(TIME_DERATING_CONSTRAINT) / 100]]

# Custom constraints.
# -------------------------------------------------------------------------------------------------
# The SPI Clock 10 MHz. Mostly stuff from above, but simplified
set spi_clk_ns 100

set spi_clk_port [get_ports $spi_clk_pin]
puts "\[INFO] Using SPI clock $spi_clk_port"
set spi_in_ports [list [get_port $spi_mosi_pin] [get_port $spi_nss_pin]]

create_clock $spi_clk_port -name {spi_clk} -period $spi_clk_ns
set spi_clk [get_clocks {spi_clk}]
set spi_input_delay_value [expr $spi_clk_ns * $::env(IO_DELAY_CONSTRAINT) / 100]
set_input_delay $spi_input_delay_value -clock $spi_clk $spi_in_ports

set_driving_cell \
    -lib_cell [lindex [split $::env(SYNTH_DRIVING_CELL) "/"] 0] \
    -pin [lindex [split $::env(SYNTH_DRIVING_CELL) "/"] 1] \
    $spi_in_ports

set_driving_cell \
    -lib_cell [lindex [split $::env(SYNTH_CLK_DRIVING_CELL) "/"] 0] \
    -pin [lindex [split $::env(SYNTH_CLK_DRIVING_CELL) "/"] 1] \
    $spi_clk_port

set_clock_uncertainty $::env(CLOCK_UNCERTAINTY_CONSTRAINT) $spi_clk
set_clock_transition $::env(CLOCK_TRANSITION_CONSTRAINT) $spi_clk


# The generated clocks
set clk_div2_pin [get_pins -of_object [get_nets -hierarchical {stop.syn.clki.gen[0].inst.q}] -filter "direction == output"]
set clk_div4_pin [get_pins -of_object [get_nets -hierarchical {stop.syn.clki.gen[1].inst.q}] -filter "direction == output"]
set clk_div8_pin [get_pins -of_object [get_nets -hierarchical {stop.syn.clki.gen[2].inst.q}] -filter "direction == output"]
set clk_div16_pin [get_pins -of_object [get_nets -hierarchical {stop.syn.clki.gen[3].inst.q}] -filter "direction == output"]
set clk_div32_pin [get_pins -of_object [get_nets -hierarchical {stop.syn.clk_mult}] -filter "direction == output"]
set clk_div64_pin [get_pins -of_object [get_nets -hierarchical {stop.syn.clki.gen[5].inst.q}] -filter "direction == output"]
set clk_div128_pin [get_pins -of_object [get_nets -hierarchical {stop.syn.clki.gen[6].inst.q}] -filter "direction == output"]
set clk_div256_pin [get_pins -of_object [get_nets -hierarchical {stop.syn.clk_sample_x2}] -filter "direction == output"]
set clk_div512_pin [get_pins -of_object [get_nets -hierarchical {stop.dbg_clk_sample}] -filter "direction == output"]
set clk_div1024_pin [get_pins -of_object [get_nets -hierarchical {stop.syn.clki.gen[10].inst.clk}] -filter "direction == output"]
set clk_div2048_pin [get_pins -of_object [get_nets -hierarchical {stop.syn.clki.gen[10].inst.q}] -filter "direction == output"]
set clk_div4096_pin [get_pins -of_object [get_nets -hierarchical {stop.syn.clki.gen[11].inst.q}] -filter "direction == output"]
set clk_div8192_pin [get_pins -of_object [get_nets -hierarchical {stop.syn.clki.gen[12].inst.q}] -filter "direction == output"]
set clk_div16384_pin [get_pins -of_object [get_nets -hierarchical {stop.syn.clki.gen[13].inst.q}] -filter "direction == output"]
set clk_div32768_pin [get_pins -of_object [get_nets -hierarchical {stop.syn.clki.gen[14].inst.q}] -filter "direction == output"]
set clk_div65536_pin [get_pins -of_object [get_nets -hierarchical {stop.dbg_clk_adsr}] -filter "direction == output"]
create_generated_clock -name {clk_div2} -source {clk} -divide_by 2 $clk_div2_pin
create_generated_clock -name {clk_div4} -source $clk_div2_pin -divide_by 2 $clk_div4_pin
create_generated_clock -name {clk_div8} -source $clk_div4_pin -divide_by 2 $clk_div8_pin
create_generated_clock -name {clk_div16} -source $clk_div8_pin -divide_by 2 $clk_div16_pin
create_generated_clock -name {clk_div32} -source $clk_div16_pin -divide_by 2 $clk_div32_pin
create_generated_clock -name {clk_div64} -source $clk_div32_pin -divide_by 2 $clk_div64_pin
create_generated_clock -name {clk_div128} -source $clk_div64_pin -divide_by 2 $clk_div128_pin
create_generated_clock -name {clk_div256} -source $clk_div128_pin -divide_by 2 $clk_div256_pin
create_generated_clock -name {clk_div512} -source $clk_div256_pin -divide_by 2 $clk_div512_pin
create_generated_clock -name {clk_div1024} -source $clk_div512_pin -divide_by 2 $clk_div1024_pin
create_generated_clock -name {clk_div2048} -source $clk_div1024_pin -divide_by 2 $clk_div2048_pin
create_generated_clock -name {clk_div4096} -source $clk_div2048_pin -divide_by 2 $clk_div4096_pin
create_generated_clock -name {clk_div8192} -source $clk_div4096_pin -divide_by 2 $clk_div8192_pin
create_generated_clock -name {clk_div16384} -source $clk_div8192_pin -divide_by 2 $clk_div16384_pin
create_generated_clock -name {clk_div32768} -source $clk_div16384_pin -divide_by 2 $clk_div32768_pin
create_generated_clock -name {clk_div65536} -source $clk_div32768_pin -divide_by 2 $clk_div65536_pin

# Let's pretend clk and spi_clk are mesochronous, and they never interact
set_clock_groups -asynchronous -group {clk} -group {spi_clk} -group {clk_div2} -group {clk_div4} -group {clk_div8} -group {clk_div16} -group {clk_div32} -group {clk_div64} -group {clk_div128} -group {clk_div256} -group {clk_div512} -group {clk_div1024} -group {clk_div2048} -group {clk_div4096} -group {clk_div8192} -group {clk_div16384} -group {clk_div32768} -group {clk_div65536}

# -------------------------------------------------------------------------------------------------
# End of Custom constraints.

if { [info exists ::env(OPENLANE_SDC_IDEAL_CLOCKS)] && $::env(OPENLANE_SDC_IDEAL_CLOCKS) } {
    unset_propagated_clock [all_clocks]
} else {
    set_propagated_clock [all_clocks]
}

