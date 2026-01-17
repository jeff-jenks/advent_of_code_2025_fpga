`include "ascii_table.vh"

module ascii_conv #(
    parameter SLAVE_COUNT = 1 // Must be >= 1
)    
(
    input [7:0] ascii_in,
    input ascii_in_valid,
    input [SLAVE_COUNT-1:0] ss_in,
    output reg [3:0] num_out,
    output ascii_period,
    output ascii_S,
    output ascii_caret,
    output joltage_out_valid,
    output beam_out_valid,
    output mach_out_valid,
    output line_feed,
    output end_of_puzzle_tx,
    output ascii_num,
    output ascii_close_par,
    output ascii_open_brace,
    output ascii_close_brace
);

reg num_out_valid;

assign joltage_out_valid = ascii_in_valid & ~ss_in[0];
assign beam_out_valid = ascii_in_valid & ~ss_in[1];
assign mach_out_valid = ascii_in_valid & ~ss_in[2] & (ascii_period | ascii_num | num_out_valid | ascii_close_par | ascii_open_brace | ascii_close_brace);

assign ascii_period = (ascii_in == `ASCII_PERIOD);
assign ascii_S = (ascii_in == `ASCII_S);
assign ascii_caret = (ascii_in == `ASCII_CARET);
assign line_feed = (ascii_in == `ASCII_LF);
assign end_of_puzzle_tx = (ascii_in == `ASCII_EOT);
assign ascii_num = (ascii_in == `ASCII_NUM);
assign ascii_close_par = (ascii_in == `ASCII_CLOSE_PAR);
assign ascii_open_brace = (ascii_in == `ASCII_OPEN_BRACE);
assign ascii_close_brace = (ascii_in == `ASCII_CLOSE_BRACE);

always@(*) begin
    num_out_valid = 1'b1;
    case(ascii_in)
        `ASCII_0: num_out = 4'd0;

        `ASCII_1: num_out = 4'd1;

        `ASCII_2: num_out = 4'd2;

        `ASCII_3: num_out = 4'd3;

        `ASCII_4: num_out = 4'd4;

        `ASCII_5: num_out = 4'd5;

        `ASCII_6: num_out = 4'd6;

        `ASCII_7: num_out = 4'd7;

        `ASCII_8: num_out = 4'd8;

        `ASCII_9: num_out = 4'd9;

        default: begin
            num_out = 4'd0;
            num_out_valid = 1'b0;
        end
    endcase
end

endmodule
