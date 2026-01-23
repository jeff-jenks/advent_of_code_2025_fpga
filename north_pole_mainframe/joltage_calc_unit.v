module joltage_calc_unit (
    input clk,
    input reset,
    input [3:0] joltage_in, // joltage value of battery
    input joltage_in_valid, // signals that the joltage_in value is valid
    input bank_end, // signals that the current valid joltage_in value is the last in the current bank
    input end_of_puzzle_tx, // signals that the end of the puzzle input has been reached
    output [15:0] total_joltage_out, // the sum of the max bank joltages
    output total_joltage_out_valid // signals that the total_joltage_out value is valid
);

`ifdef SIM
    reg op_done;
`endif

wire [6:0] bank_joltage; // joltage value of bank
wire bank_joltage_valid; // signals that the bank_joltage value is valid. Not currently used
reg [3:0] joltage_in_reg [0:1]; // joltage_in_reg[1] stores the tens-place value, joltage_in_reg[0] stores the ones-place value
reg [15:0] last_total_joltage_out;

integer i;

assign bank_joltage = (joltage_in_reg[1] * 4'd10) + joltage_in_reg[0];
//assign bank_joltage = ((joltage_in_reg[1] << 3) + (joltage_in_reg[1] << 1)) + joltage_in_reg[0]; // alternative to multiply operator

assign total_joltage_out = last_total_joltage_out + bank_joltage;

assign bank_joltage_valid = joltage_in_valid & bank_end;
assign total_joltage_out_valid = joltage_in_valid & end_of_puzzle_tx;

always@(posedge clk) begin
    if(reset) begin
        `ifdef SIM
            op_done <= 1'b0;
        `endif
        for(i=0;i<2;i=i+1) begin
            joltage_in_reg[i] <= 0; // joltage values can only be 1 to 9, so 0 represents invalid joltage, ie. haven't received at least two joltage values yet
        end
        last_total_joltage_out <= 16'b0;
    end
    else begin
        `ifdef SIM
            if(op_done) begin
                op_done <= 1'b0;
            end
        `endif
        // Calculate max bank joltage + keep running sum of max bank joltages
        if(joltage_in_valid & ~end_of_puzzle_tx) begin
            `ifdef SIM
                op_done <= 1'b1;
            `endif
            if(bank_end) begin // last iteration (reset registers for next bank)
                joltage_in_reg[1] <= 0;
                joltage_in_reg[0] <= 0;
                last_total_joltage_out <= total_joltage_out;
            end
            else begin
                if(joltage_in_reg[1] == 0) begin // first iteration
                    joltage_in_reg[1] <= joltage_in;
                end
                else if(joltage_in_reg[0] == 0) begin // second iteration
                    joltage_in_reg[0] <= joltage_in;
                end
                else begin // third+ iteration
                    if(joltage_in_reg[1] < joltage_in_reg[0]) begin
                        joltage_in_reg[1] <= joltage_in_reg[0];
                        joltage_in_reg[0] <= joltage_in;
                    end
                    else if(joltage_in_reg[0] < joltage_in) begin
                        joltage_in_reg[0] <= joltage_in;
                    end
                end
            end
        end
    end    
end

endmodule
