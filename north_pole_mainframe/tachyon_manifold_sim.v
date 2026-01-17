//
// The taychon manifold schematic length is tracked in a reduced form as shown in the example below, removing unnecessary lines from the coordinate system.
// In the example reduced schematic, the top-left coordinate is (0,0) and the bottom-right coordinate is (6,3).
//
// ...S...          ...S... 
// ...|...          ..|^|..
// ..|^|..   --->   .|^|^|.
// ..|.|..          |^|^|^| 
// .|^|^|.
// .|.|.|.
// |^|^|^|
// |.|.|.|

module tachyon_manifold_sim #(
    parameter TACHYON_MANIFOLD_WIDTH = 3 // width of taychon manifold being simulated (ie. periods across in input file), must be odd and >= 3
)
(
    input clk,
    input reset,
    input beam_empty, // signals that the "." character has been read in, symbolizing empty space
    input beam_enter, // signals that the "S" character has been read in, symbolizing the starting coordinates of the beam
    input beam_splitter, // signals that the "^" character has been read in, symbolizing a beam splitter
    input beam_line_feed, // signals that the line feed character has been read in, symbolizing the end of the x-coordinates at a unit length of the taychon manifold
    input beam_in_valid, // signals that the current input is valid
    output [$clog2(MAX_SPLIT_COUNT+1)-1:0] beam_final_split_count, // the final split count reported
    output beam_final_split_count_valid // goes high when final_line and beam_line_feed are high
);

localparam MAX_BEAM_COUNT = TACHYON_MANIFOLD_WIDTH; // max # of beams that the simulator will have to keep track of based on width
localparam MAX_SPLIT_COUNT = (((TACHYON_MANIFOLD_WIDTH)**2)-1) / 8; // max number of splits that could occur based on width
localparam MAX_Y_COORD = (TACHYON_MANIFOLD_WIDTH - 1) / 2; // max y-coordinate based on width

reg [$clog2(MAX_SPLIT_COUNT+1)-1:0] split_count; // counts # of splits
reg [MAX_BEAM_COUNT-1:0] beam_coord; // stores x-coordinates of beams from last line, one-bit per x-pos
wire final_line; // goes high when the max y-coordinate is reached
reg [$clog2(TACHYON_MANIFOLD_WIDTH)-1:0] current_x; // current x-coordinate in schematic
reg [$clog2(MAX_Y_COORD+1)-1:0] current_y; // current y-coordinate in schematic
wire beam_above; // signals that there is a beam above the current (x,y) coordinate (minus 1 y-coordinate meaning above)
reg previous_split; // signals that previous character was a splitter that had an input beam
reg previous_beam; // signals that the previous (x,y) coordinate has a beam
reg active_every_other; // module only runs every other line, ignoring the empty space lines

assign beam_above = beam_coord[current_x];
assign final_line = (current_y == MAX_Y_COORD);
assign beam_final_split_count_valid = beam_in_valid & final_line & beam_line_feed & active_every_other;
assign beam_final_split_count = split_count;

always@(posedge clk) begin
    if(reset) begin
        beam_coord <= 0;
        split_count <= 0;
        current_x <= 0;
        current_y <= 0;
        previous_split <= 1'b0;
        previous_beam <= 1'b0;
        active_every_other <= 1'b1;
    end
    else begin
        if(beam_in_valid) begin
            // Adjust current coordinates after each character
            if(beam_line_feed) begin
                current_x <= 0;
                active_every_other <= ~active_every_other;
                if(active_every_other) begin
                    current_y <= current_y + 1'b1;
                end
            end
            else begin
                current_x <= current_x + 1'b1;
            end

            if(active_every_other) begin
                previous_split <= 1'b0;
                previous_beam <= 1'b0;
                if(beam_enter) begin
                    beam_coord[current_x] <= 1'b1;
                end
                else if(beam_above) begin
                    if(beam_splitter) begin
                        previous_split <= 1'b1;
                        split_count <= split_count + 1'b1;
                        if(previous_beam) begin
                            beam_coord[current_x + 1'b1] <= 1'b1;
                            beam_coord[current_x] <= 1'b0;
                        end
                        else begin
                            beam_coord[current_x - 1'b1] <= 1'b1;
                            beam_coord[current_x + 1'b1] <= 1'b1;
                            beam_coord[current_x] <= 1'b0;
                        end
                    end
                    else if(beam_empty) begin
                        previous_beam <= 1'b1;
                    end
                end
                else if(previous_split) begin
                    previous_beam <= 1'b1;
                end
            end
        end
    end
end

endmodule
