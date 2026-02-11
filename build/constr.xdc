create_clock -period 4.000 -name clk -waveform {0.000 2.000} [get_ports -filter { NAME =~  "*clk*" && DIRECTION == "IN" }]


set_property PACKAGE_PIN E1 [get_ports {spi_ss_out[2]}]
set_property PACKAGE_PIN F2 [get_ports {spi_ss_out[1]}]
set_property PACKAGE_PIN G1 [get_ports {spi_ss_out[0]}]
set_property PACKAGE_PIN E5 [get_ports clk]
set_property PACKAGE_PIN F8 [get_ports reset_pad]
set_property PACKAGE_PIN F3 [get_ports spi_miso_pad]
set_property PACKAGE_PIN E4 [get_ports spi_mosi]
set_property PACKAGE_PIN D4 [get_ports spi_sclk]
create_pblock pblock_1
resize_pblock [get_pblocks pblock_1] -add {CLOCKREGION_X1Y3:CLOCKREGION_X1Y3}
add_cells_to_pblock pblock_1 -top
set_property IS_SOFT FALSE [get_pblocks pblock_1]
set_property CONTAIN_ROUTING 1 [get_pblocks pblock_1]
set_property EXCLUDE_PLACEMENT 1 [get_pblocks pblock_1]