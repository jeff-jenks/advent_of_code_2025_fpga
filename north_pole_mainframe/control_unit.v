//
// this module is to be edited per application (ie. reason for lack of parameters)
//

`include "ascii_table.vh"

module control_unit #(
    parameter SLAVE_COUNT = 1, // Must be >= 1
    parameter TACHYON_MANIFOLD_WIDTH = 3,
    parameter MAX_BUTTON_COUNT = 2,
    parameter MACHINE_COUNT = 10
)    
(
    input clk,
    input reset,
    input spi_ready,
    input [15:0] total_joltage_out,
    input total_joltage_out_valid,
    input [$clog2(MAX_SPLIT_COUNT+1)-1:0] beam_final_split_count,
    input beam_final_split_count_valid,
    input [$clog2((MAX_BUTTON_COUNT+1)*MACHINE_COUNT)-1:0] mach_total_presses_required,
    input mach_presses_valid,
    input mach_end_of_puzzle_tx,
    input mach_out_valid,
    input [SLAVE_COUNT-1:0] ss_out,
    output reg [7:0] tx_byte,
    output reg tx_byte_valid,
    output reg [SLAVE_COUNT-1:0] ss_in
);

localparam MAX_SPLIT_COUNT = (((TACHYON_MANIFOLD_WIDTH)**2)-1) / 8;
localparam stDAY_3_1 = 2'b00;
localparam stDAY_7_1 = 2'b01;
localparam stDAY_10_1 = 2'b10;
localparam stDONE = 2'b11;

reg [15:0] puzzle_day_3_1_reg;
reg [15:0] puzzle_day_7_1_reg;
reg [23:0] puzzle_day_10_1_reg;
reg [1:0] r_state;
reg [2:0] bytes_to_send;
reg next_state_delay;

always@(*) begin
    ss_in = {SLAVE_COUNT{1'b1}};

    case(r_state)
        stDAY_3_1: begin // Chip 0
            tx_byte = puzzle_day_3_1_reg[15:8];
            ss_in[0] = 1'b0;
        end

        stDAY_7_1: begin // Chip 1
            tx_byte = puzzle_day_7_1_reg[15:8];
            ss_in[1] = 1'b0;
        end

        stDAY_10_1: begin // Chip 2
            tx_byte = puzzle_day_10_1_reg[23:16];
            ss_in[2] = 1'b0;
        end

        default: begin
            tx_byte = 8'b0;
        end
    endcase

    if(~tx_byte_valid) begin
        ss_in = {SLAVE_COUNT{1'b1}};
    end
end

always@(posedge clk) begin
    if(reset) begin
        puzzle_day_3_1_reg <= 16'b0;
        puzzle_day_7_1_reg <= 16'b0;
        puzzle_day_10_1_reg <= 24'b0;
        r_state <= stDAY_3_1;
        bytes_to_send <= 3'b0;
        tx_byte_valid <= 1'b1;
        next_state_delay <= 1'b0;
    end
    else begin
        case(r_state)
            stDAY_3_1: begin
                if(next_state_delay & (&ss_out)) begin
                    r_state <= stDAY_7_1;
                    next_state_delay <= 1'b0;
                end
                else if((bytes_to_send == 1) & spi_ready) begin
                    next_state_delay <= 1'b1;
                    bytes_to_send <= bytes_to_send - 1'b1;
                end
                else if((bytes_to_send != 0) & spi_ready) begin
                    puzzle_day_3_1_reg <= puzzle_day_3_1_reg << 8;
                    bytes_to_send <= bytes_to_send - 1'b1;
                end
                else if(total_joltage_out_valid) begin
                    puzzle_day_3_1_reg <= total_joltage_out;
                    bytes_to_send <= 3'd2;
                end
            end

            stDAY_7_1: begin
                if(next_state_delay & (&ss_out)) begin
                    r_state <= stDAY_10_1;
                    next_state_delay <= 1'b0;
                end
                else if((bytes_to_send == 1) & spi_ready) begin
                    next_state_delay <= 1'b1;
                    bytes_to_send <= bytes_to_send - 1'b1;
                end
                else if((bytes_to_send != 0) & spi_ready) begin
                    puzzle_day_7_1_reg <= puzzle_day_7_1_reg << 8;
                    bytes_to_send <= bytes_to_send - 1'b1;
                end
                else if(beam_final_split_count_valid) begin
                    puzzle_day_7_1_reg <= beam_final_split_count;
                    bytes_to_send <= 3'd2;
                end
            end

            stDAY_10_1: begin
                if(mach_out_valid & mach_end_of_puzzle_tx & ~mach_presses_valid) begin
                    tx_byte_valid <= 1'b0;
                end
                else if(next_state_delay & (&ss_out)) begin
                    r_state <= stDONE;
                    next_state_delay <= 1'b0;
                end
                else if((bytes_to_send == 1) & spi_ready) begin
                    next_state_delay <= 1'b1;
                    bytes_to_send <= bytes_to_send - 1'b1;
                end
                else if((bytes_to_send != 0) & spi_ready) begin
                    puzzle_day_10_1_reg <= puzzle_day_10_1_reg << 8;
                    bytes_to_send <= bytes_to_send - 1'b1;
                end
                else if(mach_presses_valid) begin
                    tx_byte_valid <= 1'b1;
                    puzzle_day_10_1_reg[23:16] <= `ASCII_P; // Pass, was able to find correct inputs for all machines
                    puzzle_day_10_1_reg[15:0] <= mach_total_presses_required;
                    bytes_to_send <= 3'd3;
                end
            end

            default: ;
        endcase
    end
end

endmodule
