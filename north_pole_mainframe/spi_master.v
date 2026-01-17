// CPOL = 0 (SCLK idle level is low)
// CPHA = 0 (First bit outputs when ss_in goes low. Bits are output on SCLK transition to idle level, and sampled on SCLK transition from idle level)

module spi_master #(
    parameter SLAVE_COUNT = 1, // Must be >= 1
    parameter SLAVE_REQUIRED_HIGH_CYCLES = 1, // Must be >= 1
    parameter SCLK_RATIO = 2, // Must be >= 2 and evenly divisible by 2
    parameter SYNC_FLOPS = 2 // # of sync flops used to sync miso
)
(
    input clk,
    input reset,
    input miso,
    input [7:0] tx_byte,
    input tx_byte_valid,
    input [SLAVE_COUNT-1:0] ss_in,
    output reg spi_ready,
    output reg [7:0] rx_byte,
    output reg rx_byte_valid,
    output reg mosi,
    output reg sclk,
    output reg [SLAVE_COUNT-1:0] ss_out
);

localparam stIDLE = 2'b00;
localparam stTX_RX_BYTE = 2'b01;
localparam stDONE = 2'b10;
localparam stSS_HIGH_TIME = 2'b11;
localparam HALF_SCLK_RATIO = SCLK_RATIO >> 1;

wire sclk_rising_edge;
wire sclk_falling_edge;
reg [1:0] r_state;
reg [2:0] read_bit_count;
reg [2:0] write_bit_count;
reg [$clog2(SCLK_RATIO+1)-1:0] sclk_count;
reg [$clog2(SLAVE_REQUIRED_HIGH_CYCLES+1)-1:0] ss_high_cycles_count;
reg [7:0] r_tx_byte;
reg [7:0] rx_byte_buffer;
reg [$clog2(SYNC_FLOPS)-1:0] read_delay;
reg read_delay_active;

// Find edges for sclk
assign sclk_rising_edge = (sclk_count == HALF_SCLK_RATIO);
assign sclk_falling_edge = (sclk_count == SCLK_RATIO);

always@(posedge clk) begin
    if(reset) begin
        r_state <= stIDLE;
        ss_out <= {SLAVE_COUNT{1'b1}};
        read_bit_count <= 3'd7;
        write_bit_count <= 3'd6;
        sclk_count <= 0;
        sclk <= 1'b0;
        spi_ready <= 1'b1;
        r_tx_byte <= 8'b0;
        rx_byte <= 8'b0;
        rx_byte_valid <= 1'b0;
        rx_byte_buffer <= 8'b0;
        ss_high_cycles_count <= 0;
        mosi <= 1'b0;
        read_delay <= 0;
        read_delay_active <= 1'b0;
    end
    else begin
        if(r_state != stIDLE) begin
            // Drive sclk counter
            if(sclk_count == SCLK_RATIO) begin
                sclk_count <= 1;
            end
            else begin
                sclk_count <= sclk_count + 1'b1;
            end
        end

        // If SYNC_FLOPS > 0, apply delay to read
        if(SYNC_FLOPS > 0) begin
            if(read_delay_active) begin
                if(read_delay == 0) begin
                    read_delay_active <= 1'b0;
                    if(read_bit_count == 0) begin
                        rx_byte <= {rx_byte_buffer[7:1],miso};
                        rx_byte_valid <= 1'b1;
                    end
                    else begin
                        rx_byte_buffer[read_bit_count] <= miso;
                        read_bit_count <= read_bit_count - 1'b1;
                    end
                end
                else begin
                    read_delay <= read_delay - 1'b1;
                end
            end
        end

        case(r_state)
            stIDLE: begin
                // Wait for input byte to be valid and ensure only one ss bit is low. Output first tx bit through mosi
                if(tx_byte_valid & ^(~ss_in)) begin
                    r_state <= stTX_RX_BYTE;
                    r_tx_byte <= tx_byte;
                    ss_out <= ss_in;
                    spi_ready <= 1'b0;
                    sclk_count <= 1;
                    read_bit_count <= 3'd7;
                    write_bit_count <= 3'd6;
                    ss_high_cycles_count <= 0;
                    mosi <= tx_byte[7];
                end
            end

            stTX_RX_BYTE: begin
                // TX and RX bits. Output RX byte as soon as last bit is received
                if(read_bit_count == 0) begin
                    if(sclk_rising_edge) begin
                        r_state <= stDONE;
                        sclk <= ~sclk;
                        if(SYNC_FLOPS == 0) begin
                            rx_byte <= {rx_byte_buffer[7:1],miso};
                            rx_byte_valid <= 1'b1;
                        end
                        else begin
                            read_delay <= (SYNC_FLOPS - 1'b1);
                            read_delay_active <= 1'b1;
                        end
                    end
                    else if(sclk_falling_edge) begin
                        sclk <= ~sclk;
                        mosi <= r_tx_byte[write_bit_count];
                        write_bit_count <= write_bit_count - 1'b1;
                    end
                end
                else begin
                    if(sclk_rising_edge) begin
                        sclk <= ~sclk;
                        if(SYNC_FLOPS == 0) begin
                            rx_byte_buffer[read_bit_count] <= miso;
                            read_bit_count <= read_bit_count - 1'b1;
                        end
                        else begin
                            read_delay <= (SYNC_FLOPS - 1'b1);
                            read_delay_active <= 1'b1;
                        end
                    end
                    else if(sclk_falling_edge) begin
                        sclk <= ~sclk;
                        mosi <= r_tx_byte[write_bit_count];
                        write_bit_count <= write_bit_count - 1'b1;
                    end
                end
            end

            stDONE: begin
                // Byte received
                if(rx_byte_valid) rx_byte_valid <= 1'b0;
                if(sclk_falling_edge) sclk <= ~sclk;
                if(sclk_rising_edge) begin
                    r_state <= stSS_HIGH_TIME;
                    ss_out <= {SLAVE_COUNT{1'b1}};
                end
            end

            stSS_HIGH_TIME: begin
                // Hold ss pins high for their required high time between spi transactions
                if(sclk_rising_edge) begin
                    if(ss_high_cycles_count == (SLAVE_REQUIRED_HIGH_CYCLES - 1)) begin
                        r_state <= stIDLE;
                        spi_ready <= 1'b1;
                    end
                    else begin
                        ss_high_cycles_count <= ss_high_cycles_count + 1'b1;
                    end
                end
            end
        endcase
    end
end

endmodule
