`include "ascii_table.vh"

module tb_spi_slave_chip_1 (
    input spi_sclk,
    input spi_mosi,
    input spi_ss_out,
    output spi_miso
);

localparam BITS_INPUT_DATA = 160176; // # of bits in input data vector
localparam OUTPUT_BYTES = 2; // # of bytes to represent puzzle output

wire r_spi_miso;
reg [BITS_INPUT_DATA-1:0] tachyon_manifold_in; // Fits number of bits from input file minus last line of period characters
reg [$clog2(BITS_INPUT_DATA)-1:0] bit_index;
reg [(OUTPUT_BYTES*8)-1:0] beam_split_count_reg;
reg read_enable;
reg [$clog2(OUTPUT_BYTES*8)-1:0] bits_read;
reg test_complete;

integer file_ptr, bytes_read;

initial begin
    file_ptr = $fopen("puzzle_7_1_input_data.txt", "rb");
    bytes_read = $fread(tachyon_manifold_in, file_ptr);
    $fclose(file_ptr);
    bit_index = BITS_INPUT_DATA - 1'b1;
    beam_split_count_reg = 0;
    read_enable = 1'b0;
    bits_read = 0;
    test_complete = 1'b0;
end

assign r_spi_miso = tachyon_manifold_in[BITS_INPUT_DATA-1];
assign spi_miso = spi_ss_out ? 1'bz : r_spi_miso;

always@(posedge spi_sclk) begin
    if(~test_complete) begin
        if(~spi_ss_out & (bit_index == 0) & read_enable) begin
            beam_split_count_reg <= beam_split_count_reg << 1;
            beam_split_count_reg[0] <= spi_mosi;
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
                tachyon_manifold_in[BITS_INPUT_DATA-1] <= 1'b0;
            end
            else begin
                tachyon_manifold_in <= tachyon_manifold_in << 1;
                bit_index <= bit_index - 1'b1;
            end
        end
    end
end

endmodule
