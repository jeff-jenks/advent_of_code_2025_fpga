`timescale 1ns / 1ps

module tb();

parameter SLAVE_COUNT = 3;
parameter SLAVE_REQUIRED_HIGH_CYCLES = 1;
parameter SCLK_RATIO = 10;
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

time puzzle_time_start,puzzle_time_total;
time process_time_start,process_time_total;
reg test_start;
reg [2:0] test_select;
reg final_out_hit;
reg [1:0] wait_for_ready;
reg [CORE_COUNT-1:0] start_count;
integer cycle_count [0:CORE_COUNT-1];
integer min_cycles_per_op;
real mean_cycles_per_op;
integer max_cycles_per_op;

integer i;

always #2 clk = ~clk;

always@(posedge clk) begin
    if(test_start) begin
        case(test_select)
            3'b001: begin
                if(tb.inst_tb_spi_slave_chip_0.test_complete) begin
                    test_start <= 1'b0;
                    test_select <= 3'b010;
                    process_time_total = $time - process_time_start;
                end
                else if(tb.top_inst0.joltage_calc_unit_inst0.total_joltage_out_valid) begin
                    final_out_hit <= 1'b1;
                end
                else if(tb.top_inst0.joltage_calc_unit_inst0.joltage_in_valid & ~final_out_hit) begin
                    puzzle_time_start = $time;
                end
                else if(tb.top_inst0.joltage_calc_unit_inst0.op_done & ~final_out_hit) begin
                    puzzle_time_total = puzzle_time_total + ($time - puzzle_time_start);
                end
            end
            3'b010: begin
                if(tb.inst_tb_spi_slave_chip_1.test_complete) begin
                    test_start <= 1'b0;
                    test_select <= 3'b100;
                    process_time_total = $time - process_time_start;
                end
                else if(tb.top_inst0.tachyon_manifold_sim_inst0.beam_final_split_count_valid) begin
                    final_out_hit <= 1'b1;
                end
                else if(tb.top_inst0.tachyon_manifold_sim_inst0.beam_in_valid & ~final_out_hit) begin
                    puzzle_time_start = $time;
                end
                else if(tb.top_inst0.tachyon_manifold_sim_inst0.op_done & ~final_out_hit) begin
                    puzzle_time_total = puzzle_time_total + ($time - puzzle_time_start);
                end
            end
            3'b100: begin
                if(tb.inst_tb_spi_slave_chip_2.test_complete) begin
                    test_start <= 1'b0;
                    test_select <= 3'b000;
                    process_time_total = $time - process_time_start;
                    mean_cycles_per_op = mean_cycles_per_op / MACHINE_COUNT;
                end
                else if(tb.top_inst0.factory_machine_initializer_inst0.mach_total_presses_valid) begin
                    final_out_hit <= 1'b1;
                end
                else if(tb.top_inst0.factory_machine_initializer_inst0.mach_in_valid & tb.top_inst0.factory_machine_initializer_inst0.mach_buttons_end & ~final_out_hit & (wait_for_ready == 0)) begin
                    puzzle_time_start = $time;
                    wait_for_ready <= 2'b01;
                end
                else if((wait_for_ready < 2'd3) & (wait_for_ready != 0)) begin
                    wait_for_ready <= wait_for_ready + 1'b1;
                end
                else if(&tb.top_inst0.factory_machine_initializer_inst0.core_ready & ~final_out_hit & (wait_for_ready == 2'd3)) begin
                    puzzle_time_total = puzzle_time_total + ($time - puzzle_time_start);
                    wait_for_ready <= 2'b0;
                end

                for(i=0;i<CORE_COUNT;i=i+1) begin
                    if(start_count[i]) begin
                        if(tb.top_inst0.factory_machine_initializer_inst0.core_ready[i]) begin
                            start_count[i] <= 1'b0;
                            mean_cycles_per_op = mean_cycles_per_op + (cycle_count[i] + 1);
                            if(min_cycles_per_op > (cycle_count[i] + 1)) begin
                                min_cycles_per_op = cycle_count[i] + 1;
                            end
                            if(max_cycles_per_op < (cycle_count[i] + 1)) begin
                                max_cycles_per_op = cycle_count[i] + 1;
                            end
                            cycle_count[i] = 0;
                        end
                        else begin
                            cycle_count[i] = cycle_count[i] + 1;
                        end
                    end
                    else if(~tb.top_inst0.factory_machine_initializer_inst0.core_ready[i]) begin
                        start_count[i] <= 1'b1;
                    end
                end
            end
        endcase
    end
    else if(test_select & ~spi_ss_out) begin
        test_start <= 1'b1;
        final_out_hit <= 1'b0;
        puzzle_time_start = 0;
        puzzle_time_total = 0;
        process_time_start = $time;
        process_time_total = 0;
        start_count <= 0;
        for(i=0;i<CORE_COUNT;i=i+1) begin
            cycle_count[i] = 0;
        end
        min_cycles_per_op = 2147483647;
        mean_cycles_per_op = 0;
        max_cycles_per_op = 0;
        wait_for_ready <= 2'b0;
    end
end

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
        $display("Cycles/Op: 1"); // Will never be greater than 1 cycle
        $display("Puzzle Core Processing Time: %0t", puzzle_time_total);
        $display("Total Processing Time: %0t", process_time_total);
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
        $display("Cycles/Op: 1"); // Will never be greater than 1 cycle
        $display("Puzzle Core Processing Time: %0t", puzzle_time_total);
        $display("Total Processing Time: %0t", process_time_total);
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
        $display("Min Cycles/Op: %0d", min_cycles_per_op);
        $display("Mean Cycles/Op: %0.3f", mean_cycles_per_op);
        $display("Max Cycles/Op: %0d", max_cycles_per_op);
        $display("Puzzle Core Processing Time: %0t", puzzle_time_total);
        $display("Total Processing Time: %0t", process_time_total);
        $finish();
    end
end

initial begin
    //$dumpfile("sim_waves.vcd");
    //$dumpvars(0, tb); // Dump all signals

    $timeformat(-9, 0, " ns");

    puzzle_time_start = 0;
    puzzle_time_total = 0;
    process_time_start = 0;
    process_time_total = 0;
    test_start = 0;
    test_select = 3'b001;
    final_out_hit = 0;
    start_count = 0;
    for(i=0;i<CORE_COUNT;i=i+1) begin
        cycle_count[i] = 0;
    end
    min_cycles_per_op = 2147483647;
    mean_cycles_per_op = 0;
    max_cycles_per_op = 0;
    wait_for_ready = 2'b0;

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
