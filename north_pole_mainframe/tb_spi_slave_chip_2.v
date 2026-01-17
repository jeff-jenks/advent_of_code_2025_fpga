`include "ascii_table.vh"

module tb_spi_slave_chip_2 (
    input spi_sclk,
    input spi_mosi,
    input spi_ss_out,
    output spi_miso
);

localparam BITS_INPUT_DATA = 164240; // # of bits in input data vector
localparam OUTPUT_BYTES = 3; // # of bytes to represent puzzle output

wire r_spi_miso;
reg [BITS_INPUT_DATA-1:0] machines_list_in; // Fits number of bits from input file + extra byte for EOT character
reg [BITS_INPUT_DATA-9:0] input_file_data;
reg [(OUTPUT_BYTES*8)-1:0] total_presses_count_reg;
reg test_complete;

integer file_ptr, bytes_read;

initial begin
    file_ptr = $fopen("puzzle_10_1_input_data.txt", "rb");
    bytes_read = $fread(input_file_data, file_ptr);
    $fclose(file_ptr);
    machines_list_in = {input_file_data,`ASCII_EOT};
    total_presses_count_reg = 0;
end

assign r_spi_miso = machines_list_in[BITS_INPUT_DATA-1];
assign spi_miso = spi_ss_out ? 1'bz : r_spi_miso;

always@(*) begin
    test_complete = (total_presses_count_reg[23:16] == `ASCII_P);
end

always@(posedge spi_sclk) begin
    if(~spi_ss_out) begin
        total_presses_count_reg <= total_presses_count_reg << 1;
        total_presses_count_reg[0] <= spi_mosi;
    end
end

always@(negedge spi_sclk) begin
    if(~spi_ss_out) begin
        machines_list_in <= machines_list_in << 1;
    end
end

endmodule
