module combo_solver_core #(
    parameter MAX_LIGHT_COUNT = 2, // max # of lights to expect per machine
    parameter MAX_BUTTON_COUNT = 10 // max # of buttons in machine
)
(
    input clk,
    input reset,
    input rx_ready, // receiver of mach_presses_required is ready
    input tx_valid, // buttons_flattened and expect_lights is valid
    input [(MAX_LIGHT_COUNT*MAX_BUTTON_COUNT)-1:0] buttons_flattened, // buttons vector for single machine
    input [MAX_LIGHT_COUNT-1:0] expect_lights, // expected light value for single machine
    output reg [$clog2(MAX_BUTTON_COUNT+1)-1:0] mach_presses_required, // min # of presses required for current machine 
    output core_ready, // after current machine is done being computed, signal ready
    output reg mach_presses_valid // signals that the current mach_presses_required value is valid
);

localparam stIDLE = 1'b0; // Wait for next input then reset registers for stCOMPUTE
localparam stCOMPUTE = 1'b1; // Compute and test combination of button presses against expected light output

// lights/buttons values for a machine are stored as one hot representation:
//
// Ex. MAX_LIGHT_COUNT = 6, Current machine has 4 lights 
// 
//     Input expect lights: [.#.#]   --->   [0 0 1 0 1 0]
//
reg [MAX_LIGHT_COUNT-1:0] indicator_lights; // the lights value that is being computed for the current combination
reg [MAX_LIGHT_COUNT-1:0] expect_lights_reg; // stores the expected light value for the current machine

reg r_state;
reg [MAX_LIGHT_COUNT-1:0] machine_buttons [0:MAX_BUTTON_COUNT-1]; // holds current buttons for machine that is being tested
reg [MAX_LIGHT_COUNT-1:0] buttons_unflattened [0:MAX_BUTTON_COUNT-1]; // input buttons in array format
reg [$clog2(MAX_BUTTON_COUNT+1)-1:0] least_presses; // current least # of presses needed for current machine
reg [$clog2(MAX_BUTTON_COUNT)-1:0] current_num_buttons; // calculate # of buttons in current machine
wire [MAX_BUTTON_COUNT-1:0] current_buttons; // one-hot of button count
reg [MAX_BUTTON_COUNT-1:0] buttons_counter; // increments active bits by 1 for each combination
reg [$clog2(MAX_BUTTON_COUNT)-1:0] combo_button_counter; // counts # of buttons used in current combo

integer i;

assign core_ready = (r_state == stIDLE);

// Compute combinations of button presses for a machine by incrementing a counter that selects bits
// to use in that combination. XOR the buttons together to compute indicator lights value.
// If indicator lights is equal to the expected lights output, and the buttons count is less than
// the current least_presses count then update least_presses with this value.
// Once all combinations have been stepped through, report least_presses value.
always@(posedge clk) begin
    if(reset) begin
        r_state <= stIDLE;
        mach_presses_valid <= 1'b0;
        expect_lights_reg <= 0;
        least_presses <= 0;
        mach_presses_required <= 0;
        buttons_counter <= 0;

        for(i=0;i<MAX_BUTTON_COUNT;i=i+1) begin
            machine_buttons[i] <= 0;
        end
    end
    else begin
        case(r_state)
            stIDLE: begin
                if(rx_ready) begin
                    mach_presses_valid <= 1'b0;
                end
                if(tx_valid) begin
                    r_state <= stCOMPUTE;
                    expect_lights_reg <= expect_lights;
                    for(i=0;i<MAX_BUTTON_COUNT;i=i+1) begin
                        machine_buttons[i] <= buttons_unflattened[i];
                    end
                    least_presses <= MAX_BUTTON_COUNT;
                    buttons_counter <= 1;
                end
            end

            stCOMPUTE: begin
                if(combo_button_counter == current_num_buttons) begin
                    r_state <= stIDLE;
                    mach_presses_valid <= 1'b1;
                    if(combo_button_counter < least_presses) begin
                        mach_presses_required <= combo_button_counter;
                    end
                    else begin
                        mach_presses_required <= least_presses;
                    end
                end
                else if(indicator_lights == expect_lights_reg) begin
                    if(combo_button_counter < least_presses) begin
                        least_presses <= combo_button_counter;
                    end
                    buttons_counter <= buttons_counter + 1'b1;
                end
                else begin
                    buttons_counter <= buttons_counter + 1'b1;
                end   
            end
        endcase
    end
end

always@(*) begin
    current_num_buttons = 0;
    for(i=0;i<MAX_BUTTON_COUNT;i=i+1) begin
        if(current_buttons[i]) begin
            current_num_buttons = current_num_buttons + 1'b1;
        end
        buttons_unflattened[i] = buttons_flattened[(i*MAX_LIGHT_COUNT) +: MAX_LIGHT_COUNT];
    end
end

generate
    genvar k;
    for(k=0;k<MAX_BUTTON_COUNT;k=k+1) begin
        assign current_buttons[k] = |machine_buttons[k];
    end
endgenerate

always@(*) begin
    indicator_lights = 0;
    for(i=0;i<MAX_BUTTON_COUNT;i=i+1) begin
        if(buttons_counter[i]) begin
            indicator_lights = machine_buttons[i] ^ indicator_lights;
        end
    end
end

always@(*) begin
    combo_button_counter = 0;
    for(i=0;i<MAX_BUTTON_COUNT;i=i+1) begin
        if(buttons_counter[i]) begin
            combo_button_counter = combo_button_counter + 1'b1;
        end
    end
end

endmodule
