`timescale 1ns / 1ps

module tb();

parameter SLAVE_COUNT = 3;
parameter SLAVE_REQUIRED_HIGH_CYCLES = 1;
parameter SCLK_RATIO = 4;
parameter TACHYON_MANIFOLD_WIDTH = 141;
parameter SYNC_FLOPS = 2;
parameter MAX_LIGHT_COUNT = 10;
parameter MAX_BUTTON_COUNT = 13;
parameter MACHINE_COUNT = 200;
parameter CORE_COUNT = 2;

localparam DAY_3_1_ANSWER = 16'd16993;
localparam DAY_7_1_ANSWER = 16'd1711;
localparam DAY_10_1_ANSWER = 10'd530;

reg clk, reset;
wire spi_miso;
wire spi_mosi;
wire spi_sclk;
wire [SLAVE_COUNT-1:0] spi_ss_out;

always #5 clk = ~clk;

always@(posedge clk) begin
    if(tb.top_inst0.factory_machine_initializer_inst0.tx_confirmed) begin
        $display("Machine %d sent to Core %d", tb.top_inst0.factory_machine_initializer_inst0.compute_mach, tb.top_inst0.factory_machine_initializer_inst0.core_index);
    end
end

always@(negedge spi_sclk) begin
    if(tb.inst_tb_spi_slave_chip_0.test_complete) begin
        $display("********** Day 3, Part 1 **********");
        $display("Total Joltage Output = %d", tb.inst_tb_spi_slave_chip_0.total_joltage_reg);
        $display("Expected Total Joltage Output = %d", DAY_3_1_ANSWER);
        if(tb.inst_tb_spi_slave_chip_0.total_joltage_reg == DAY_3_1_ANSWER) begin
            $display("Status: PASS");
        end
        else begin
            $display("Status: FAIL");
        end
    end
    if(tb.inst_tb_spi_slave_chip_1.test_complete) begin
        $display("********** Day 7, Part 1 **********");
        $display("Beam Split Count = %d", tb.inst_tb_spi_slave_chip_1.beam_split_count_reg);
        $display("Expected Beam Split Count = %d", DAY_7_1_ANSWER);
        if(tb.inst_tb_spi_slave_chip_1.beam_split_count_reg == DAY_7_1_ANSWER) begin
            $display("Status: PASS");
        end
        else begin
            $display("Status: FAIL");
        end
        $display("********** Day 10, Part 1 **********");
    end
    if(tb.inst_tb_spi_slave_chip_2.test_complete) begin
        $display("********** Day 10, Part 1 **********");
        $display("Button Presses Required = %d", tb.inst_tb_spi_slave_chip_2.total_presses_count_reg[15:0]);
        $display("Expected Button Presses Required = %d", DAY_10_1_ANSWER);
        if(tb.inst_tb_spi_slave_chip_2.total_presses_count_reg[15:0] == DAY_10_1_ANSWER) begin
            $display("Status: PASS");
        end
        else begin
            $display("Status: FAIL");
        end
        $finish();
    end
end

initial begin
    //$dumpfile("sim_waves.vcd");
    //$dumpvars(0, tb); // Dump all signals
    clk = 0;
    reset = 1;

    @(posedge clk);
    @(negedge clk);
    
    reset = 0;
end

tb_spi_slave_chip_0 inst_tb_spi_slave_chip_0(
    .spi_sclk(spi_sclk),
    .spi_mosi(spi_mosi),
    .spi_ss_out(spi_ss_out[0]),
    .spi_miso(spi_miso)
);

tb_spi_slave_chip_1 inst_tb_spi_slave_chip_1(
    .spi_sclk(spi_sclk),
    .spi_mosi(spi_mosi),
    .spi_ss_out(spi_ss_out[1]),
    .spi_miso(spi_miso)
);

tb_spi_slave_chip_2 inst_tb_spi_slave_chip_2(
    .spi_sclk(spi_sclk),
    .spi_mosi(spi_mosi),
    .spi_ss_out(spi_ss_out[2]),
    .spi_miso(spi_miso)
);

top #(
    .SLAVE_COUNT(SLAVE_COUNT),
    .SLAVE_REQUIRED_HIGH_CYCLES(SLAVE_REQUIRED_HIGH_CYCLES),
    .SCLK_RATIO(SCLK_RATIO),
    .TACHYON_MANIFOLD_WIDTH(TACHYON_MANIFOLD_WIDTH),
    .SYNC_FLOPS(SYNC_FLOPS),
    .MAX_LIGHT_COUNT(MAX_LIGHT_COUNT),
    .MAX_BUTTON_COUNT(MAX_BUTTON_COUNT),
    .MACHINE_COUNT(MACHINE_COUNT),
    .CORE_COUNT(CORE_COUNT)
) 
top_inst0
(
    .clk(clk),
    .reset_pad(reset),
    .spi_miso_pad(spi_miso),
    .spi_mosi(spi_mosi),
    .spi_sclk(spi_sclk),
    .spi_ss_out(spi_ss_out)
);

endmodule
