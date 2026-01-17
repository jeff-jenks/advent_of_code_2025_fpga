module io_sync #(
    parameter SYNC_FLOPS = 2
)    
(
    input clk,
    input reset_pad,
    input spi_miso_pad,
    output reset,
    output spi_miso
);

reg [SYNC_FLOPS-1:0] reset_sync;
reg [SYNC_FLOPS-1:0] spi_miso_sync;

generate
    if(SYNC_FLOPS == 0) begin
        assign reset = reset_pad;
        assign spi_miso = spi_miso_pad;
    end
    else begin
        assign reset = reset_sync[0];
        assign spi_miso = spi_miso_sync[0];

        always@(posedge clk) begin
            reset_sync <= {reset_pad,reset_sync[SYNC_FLOPS-1:1]};
            spi_miso_sync <= {spi_miso_pad,spi_miso_sync[SYNC_FLOPS-1:1]};
        end
    end
endgenerate

endmodule
