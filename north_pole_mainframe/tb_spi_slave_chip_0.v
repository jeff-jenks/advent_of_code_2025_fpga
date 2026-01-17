`include "ascii_table.vh"

module tb_spi_slave_chip_0 (
    input spi_sclk,
    input spi_mosi,
    input spi_ss_out,
    output spi_miso
);

localparam BITS_INPUT_DATA = 161608; // # of bits in input data vector
localparam OUTPUT_BYTES = 2; // # of bytes to represent puzzle output

wire r_spi_miso;
reg [BITS_INPUT_DATA-1:0] joltage_in_test_values; // Fits number of bits from input file + extra byte for EOT character
reg [BITS_INPUT_DATA-9:0] input_file_data;
reg [$clog2(BITS_INPUT_DATA)-1:0] bit_index;
reg [(OUTPUT_BYTES*8)-1:0] total_joltage_reg;
reg read_enable;
reg [$clog2(OUTPUT_BYTES*8)-1:0] bits_read;
reg test_complete;

integer file_ptr, bytes_read;

initial begin
    file_ptr = $fopen("puzzle_3_1_input_data.txt", "rb");
    bytes_read = $fread(input_file_data, file_ptr);
    $fclose(file_ptr);
    joltage_in_test_values = {input_file_data,`ASCII_EOT};
    bit_index = BITS_INPUT_DATA - 1'b1;
    total_joltage_reg = 0;
    read_enable = 1'b0;
    bits_read = 0;
    test_complete = 1'b0;
end

assign r_spi_miso = joltage_in_test_values[BITS_INPUT_DATA-1];
assign spi_miso = spi_ss_out ? 1'bz : r_spi_miso;

always@(posedge spi_sclk) begin
    if(~test_complete) begin
        if(~spi_ss_out & (bit_index == 0) & read_enable) begin
            total_joltage_reg <= total_joltage_reg << 1;
            total_joltage_reg[0] <= spi_mosi;
            if(bits_read == ((OUTPUT_BYTES*8)-1)) begin
                read_enable <= 1'b0;
                test_complete <= 1'b1;
            end
            else begin
                bits_read <= bits_read + 1'b1;
            end
        end
    end
    else begin
        test_complete <= 1'b0;
    end
end 

always@(negedge spi_sclk) begin
    if(~test_complete) begin
        if(~spi_ss_out) begin
            if(bit_index == 0) begin
                read_enable <= 1'b1;
                joltage_in_test_values[BITS_INPUT_DATA-1] <= 1'b0;
            end
            else begin
                joltage_in_test_values <= joltage_in_test_values << 1;
                bit_index <= bit_index - 1'b1;
            end
        end
    end
end

endmodule
