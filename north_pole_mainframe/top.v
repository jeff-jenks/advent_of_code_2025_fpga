module top #(
    parameter SLAVE_COUNT = 3,
    parameter SLAVE_REQUIRED_HIGH_CYCLES = 1,
    parameter SCLK_RATIO = 10,
    parameter TACHYON_MANIFOLD_WIDTH = 141,
    parameter SYNC_FLOPS = 2,
    parameter MAX_LIGHT_COUNT = 10,
    parameter MAX_BUTTON_COUNT = 13,
    parameter MACHINE_COUNT = 200,
    parameter CORE_COUNT = 2
)
(
    input clk,
    input reset_pad,
    input spi_miso_pad,
    output spi_mosi,
    output spi_sclk,
    output [SLAVE_COUNT-1:0] spi_ss_out
);

localparam MAX_SPLIT_COUNT = (((TACHYON_MANIFOLD_WIDTH)**2)-1) / 8;

wire reset;
wire spi_miso;
wire [3:0] num_out;
wire joltage_out_valid;
wire line_feed;
wire [7:0] rx_byte;
wire [7:0] tx_byte;
wire rx_byte_valid;
wire tx_byte_valid;
wire spi_ready;
wire [SLAVE_COUNT-1:0] ss_in;
wire end_of_puzzle_tx;
wire [15:0] total_joltage_out;
wire total_joltage_out_valid;
wire ascii_period;
wire ascii_S;
wire ascii_caret;
wire beam_out_valid;
wire [$clog2(MAX_SPLIT_COUNT+1)-1:0] beam_final_split_count;
wire beam_final_split_count_valid;
wire [$clog2((MAX_BUTTON_COUNT+1)*MACHINE_COUNT)-1:0] mach_total_presses_required;
wire mach_total_presses_valid;
wire mach_out_valid;
wire ascii_num;
wire ascii_close_par;
wire ascii_open_brace;
wire ascii_close_brace;

io_sync #(
    .SYNC_FLOPS(SYNC_FLOPS)
)
io_sync_inst0
(
    .clk(clk),
    .reset_pad(reset_pad),
    .spi_miso_pad(spi_miso_pad),
    .reset(reset),
    .spi_miso(spi_miso)
);

control_unit #(
    .SLAVE_COUNT(SLAVE_COUNT),
    .TACHYON_MANIFOLD_WIDTH(TACHYON_MANIFOLD_WIDTH),
    .MAX_BUTTON_COUNT(MAX_BUTTON_COUNT),
    .MACHINE_COUNT(MACHINE_COUNT)
)    
control_unit_inst0
(
    .clk(clk),
    .reset(reset),
    .spi_ready(spi_ready),
    .total_joltage_out(total_joltage_out),
    .total_joltage_out_valid(total_joltage_out_valid),
    .beam_final_split_count(beam_final_split_count),
    .beam_final_split_count_valid(beam_final_split_count_valid),
    .mach_total_presses_required(mach_total_presses_required),
    .mach_presses_valid(mach_total_presses_valid),
    .mach_end_of_puzzle_tx(end_of_puzzle_tx),
    .mach_out_valid(mach_out_valid),
    .ss_out(spi_ss_out),
    .tx_byte(tx_byte),
    .tx_byte_valid(tx_byte_valid),
    .ss_in(ss_in)
);

spi_master #(
    .SLAVE_COUNT(SLAVE_COUNT),
    .SLAVE_REQUIRED_HIGH_CYCLES(SLAVE_REQUIRED_HIGH_CYCLES),
    .SCLK_RATIO(SCLK_RATIO),
    .SYNC_FLOPS(SYNC_FLOPS)
)
spi_master_inst0
(
    .clk(clk),
    .reset(reset),
    .miso(spi_miso),
    .tx_byte(tx_byte),
    .tx_byte_valid(tx_byte_valid),
    .ss_in(ss_in),
    .spi_ready(spi_ready),
    .rx_byte(rx_byte),
    .rx_byte_valid(rx_byte_valid),
    .mosi(spi_mosi),
    .sclk(spi_sclk),
    .ss_out(spi_ss_out)
);

ascii_conv #(
    .SLAVE_COUNT(SLAVE_COUNT)
)
ascii_conv_inst0
(
    .ascii_in(rx_byte),
    .ascii_in_valid(rx_byte_valid),
    .ss_in(ss_in),
    .num_out(num_out),
    .ascii_period(ascii_period),
    .ascii_S(ascii_S),
    .ascii_caret(ascii_caret),
    .joltage_out_valid(joltage_out_valid),
    .beam_out_valid(beam_out_valid),
    .mach_out_valid(mach_out_valid),
    .ascii_num(ascii_num),
    .ascii_close_par(ascii_close_par),
    .ascii_open_brace(ascii_open_brace),
    .ascii_close_brace(ascii_close_brace),
    .line_feed(line_feed),
    .end_of_puzzle_tx(end_of_puzzle_tx)
);

joltage_calc_unit joltage_calc_unit_inst0(
    .clk(clk),
    .reset(reset),
    .joltage_in(num_out),
    .joltage_in_valid(joltage_out_valid),
    .bank_end(line_feed),
    .end_of_puzzle_tx(end_of_puzzle_tx),
    .total_joltage_out(total_joltage_out),
    .total_joltage_out_valid(total_joltage_out_valid)
);

tachyon_manifold_sim #(
    .TACHYON_MANIFOLD_WIDTH(TACHYON_MANIFOLD_WIDTH)
)
tachyon_manifold_sim_inst0
(
    .clk(clk),
    .reset(reset),
    .beam_empty(ascii_period),
    .beam_enter(ascii_S),
    .beam_splitter(ascii_caret),
    .beam_line_feed(line_feed),
    .beam_in_valid(beam_out_valid),
    .beam_final_split_count(beam_final_split_count),
    .beam_final_split_count_valid(beam_final_split_count_valid)
);

factory_machine_initializer #(
    .MAX_LIGHT_COUNT(MAX_LIGHT_COUNT),
    .MAX_BUTTON_COUNT(MAX_BUTTON_COUNT),
    .MACHINE_COUNT(MACHINE_COUNT),
    .CORE_COUNT(CORE_COUNT)
)
factory_machine_initializer_inst0
(
    .clk(clk),
    .reset(reset),
    .mach_light_off(ascii_period),
    .mach_light_on(ascii_num),
    .mach_button_index(num_out),
    .mach_next_button(ascii_close_par),
    .mach_buttons_end(ascii_open_brace),
    .mach_entry_end(ascii_close_brace),
    .mach_in_valid(mach_out_valid),
    .mach_total_presses_required(mach_total_presses_required),
    .mach_total_presses_valid(mach_total_presses_valid)
);

endmodule
