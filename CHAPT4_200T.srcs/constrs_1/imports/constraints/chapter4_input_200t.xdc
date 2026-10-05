###############################################################################
# GX-BIDT Chapter 4: matrix keypad, EC11, five-way key and Touch-key
# Vivado 2025.2
# Device: XC7A200T-FBG484-2
###############################################################################

# 50 MHz system clock
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports sys_clk]
create_clock -name sys_clk -period 20.000 [get_ports sys_clk]

# A-group input lines
set_property -dict {PACKAGE_PIN N13 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {I_SWC[0]}]
set_property -dict {PACKAGE_PIN V22 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {I_SWC[1]}]
set_property -dict {PACKAGE_PIN W21 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {I_SWC[2]}]
set_property -dict {PACKAGE_PIN W22 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {I_SWC[3]}]

# A-group common lines: keypad row outputs / Touch-key input in touch mode
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {O_SWR[0]}]
set_property -dict {PACKAGE_PIN Y19 IOSTANDARD LVCMOS33} [get_ports {O_SWR[1]}]
set_property -dict {PACKAGE_PIN V18 IOSTANDARD LVCMOS33} [get_ports {O_SWR[2]}]
set_property -dict {PACKAGE_PIN V19 IOSTANDARD LVCMOS33} [get_ports {O_SWR[3]}]

# FPGA_S1 five-way key
set_property -dict {PACKAGE_PIN V17  IOSTANDARD LVCMOS33 PULLUP true} [get_ports S1_KEYA]
set_property -dict {PACKAGE_PIN W17  IOSTANDARD LVCMOS33 PULLUP true} [get_ports S1_KEYB]
set_property -dict {PACKAGE_PIN U17  IOSTANDARD LVCMOS33}             [get_ports S1_KEYC_TOUCH]
set_property -dict {PACKAGE_PIN U18  IOSTANDARD LVCMOS33 PULLUP true} [get_ports S1_KEYD]
set_property -dict {PACKAGE_PIN AA18 IOSTANDARD LVCMOS33 PULLUP true} [get_ports S1_KEYP]

# FPGA_EC1 rotary encoder
set_property -dict {PACKAGE_PIN AB18 IOSTANDARD LVCMOS33 PULLUP true} [get_ports EC_A]
set_property -dict {PACKAGE_PIN AA19 IOSTANDARD LVCMOS33 PULLUP true} [get_ports EC_B]
set_property -dict {PACKAGE_PIN AB20 IOSTANDARD LVCMOS33 PULLUP true} [get_ports EC_KEY]

# Five active-high yellow user LEDs
set_property -dict {PACKAGE_PIN J16 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN E22 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN F18 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN E19 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN D21 IOSTANDARD LVCMOS33} [get_ports {led[4]}]
