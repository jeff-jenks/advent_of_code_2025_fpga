module factory_machine_initializer #(
    parameter MAX_LIGHT_COUNT = 2, // max # of lights to expect per machine
    parameter MAX_BUTTON_COUNT = 2, // max # of buttons to expect per machine
    parameter MACHINE_COUNT = 2, // max # of machines to expect
    parameter CORE_COUNT = 2 // # of combo solver cores desired, enabling parallel computation
)
(
    input clk,
    input reset,
    input mach_light_off, // expect value of off for light from input data
    input mach_light_on, // expect value of on for light from input data
    input [3:0] mach_button_index, // index of button to be added to buttons array
    input mach_next_button, // add next mach_button_index to new button
    input mach_buttons_end, // signals end of button inputs for machine
    input mach_entry_end, // signals end of data for a machine
    input mach_in_valid, // signals that inputs are valid
    output [$clog2((MAX_BUTTON_COUNT+1)*MACHINE_COUNT)-1:0] mach_total_presses_required, // outputs total # of presses needed to configure all the machines
    output mach_total_presses_valid // signals that the current mach_total_presses_required value is valid
);

// lights/buttons values for a machine are stored as one hot representation:
//
// Ex. MAX_LIGHT_COUNT = 6, Current machine has 4 lights 
// 
//     Input expect lights: [.#.#]   --->   [0 0 1 0 1 0]
//
reg [MAX_LIGHT_COUNT-1:0] expect_lights [0:MACHINE_COUNT-1]; // stores the expected light values from input data per machine
reg [(MAX_LIGHT_COUNT*MAX_BUTTON_COUNT)-1:0] buttons [0:MACHINE_COUNT-1]; // stores button values from input data in flattened format

reg [$clog2(MACHINE_COUNT)-1:0] read_mach; // current machine that is being read in from input data
reg [$clog2(MAX_LIGHT_COUNT)-1:0] read_light; // current expect_lights index being read in from input data
reg [$clog2(MAX_BUTTON_COUNT)-1:0] read_button; // current buttons index being read in from input data
reg [MACHINE_COUNT-1:0] mach_status; // status of a machine, 0 = not read in yet or has been read in and sent to core, 1 = read in but not sent to core yet

reg [(MAX_LIGHT_COUNT*MAX_BUTTON_COUNT)-1:0] buttons_flattened; // flattens buttons array into vector for passing single machine to core
reg [(MAX_LIGHT_COUNT*MAX_BUTTON_COUNT)-1:0] pre_buttons_reg; // stores buttons values before storing to buttons array
wire compute_done; // after all machines are done being computed, signal done
reg [$clog2(MACHINE_COUNT)-1:0] compute_mach; // current machine to send to a core
reg [$clog2((MAX_BUTTON_COUNT+1)*MACHINE_COUNT)-1:0] r_total_presses_required; // current # of presses needed to configure computed machines
reg [MAX_LIGHT_COUNT-1:0] current_expect_lights; // value of expect lights for current machine
wire [CORE_COUNT-1:0] core_ready; // ready status of cores
reg [CORE_COUNT-1:0] rx_ready; // signals that data is ready to be received from a specific core
reg [CORE_COUNT-1:0] tx_valid; // signals that transmit data to the cores is valid
wire [CORE_COUNT-1:0] mach_presses_valid; // signals that the mach_presses_required value is valid for a specific core
wire [$clog2(MAX_BUTTON_COUNT+1)-1:0] mach_presses_required [0:CORE_COUNT-1]; // min # of presses required result for each core 
reg [$clog2(CORE_COUNT)-1:0] core_index; // used to index through cores for Rx and Tx
wire tx_confirmed; // signals that tx_valid and core_ready were high
reg compute_done_off; // only keeps compute_done high for one cycle
reg ignore_input; // used to ignore joltages at end of machine entry
reg mach_all_sent; // signals that all machines have been sent to the cores
reg mach_all_read; // signals that all machines have been read in from input data
reg initial_lights; // used to initialize first value of expect_lights array to 0

integer i;

assign mach_total_presses_valid = compute_done;
assign mach_total_presses_required = r_total_presses_required;
assign compute_done = mach_all_sent & (&core_ready) & ~(|mach_presses_valid) & ~compute_done_off;
assign tx_confirmed = core_ready[core_index] & tx_valid[core_index] & ~mach_all_sent;

// Read input data
always@(posedge clk) begin
    if(reset) begin
        mach_status <= 0;
        read_mach <= 0;
        read_light <= 0;
        read_button <= 0;
        ignore_input <= 1'b0;
        mach_all_read <= 1'b0;
        pre_buttons_reg <= 0;
        initial_lights <= 1'b1;
    end
    else begin
        if(mach_in_valid & ~mach_all_read) begin
            if(~ignore_input) begin
                if(mach_light_on ^ mach_light_off) begin
                    if(initial_lights) begin
                        expect_lights[read_mach] <= 0;
                        initial_lights <= 1'b0;
                    end
                    expect_lights[read_mach][read_light] <= mach_light_on;
                    read_light <= read_light + 1'b1;
                end
                else if(mach_buttons_end) begin
                    if(read_mach == (MACHINE_COUNT-1)) begin
                        mach_all_read <= 1'b1;
                    end
                    read_mach <= read_mach + 1'b1;
                    mach_status[read_mach] <= 1'b1;
                    read_light <= 0;
                    read_button <= 0;
                    ignore_input <= 1'b1;
                    pre_buttons_reg <= 0;
                    initial_lights <= 1'b1;
                    buttons[read_mach] <= pre_buttons_reg;
                end
                else if(mach_next_button) begin
                    read_button <= read_button + 1'b1;
                end
                else begin
                    pre_buttons_reg[(read_button*MAX_LIGHT_COUNT)+mach_button_index] <= 1'b1;
                end
            end
            else begin
                if(mach_entry_end) begin
                    ignore_input <= 1'b0;
                end
            end
        end

        if(tx_confirmed & ~mach_all_sent) begin
            mach_status[compute_mach] <= 1'b0;
        end
    end
end

// Tx and Rx data from cores
always@(posedge clk) begin
    if(reset) begin
        compute_mach <= 0;
        r_total_presses_required <= 0;
        core_index <= 0;
        compute_done_off <= 1'b0;
        mach_all_sent <= 1'b0;
        current_expect_lights <= 0;
        buttons_flattened <= 0;
        tx_valid <= 0;
    end
    else begin
        if(|tx_valid & core_ready[core_index]) begin
            tx_valid <= 0;
        end
        else if(mach_status[compute_mach]) begin
            if(core_index == (CORE_COUNT-1)) begin
                tx_valid[0] <= 1'b1;
            end
            else begin
                tx_valid[core_index+1] <= 1'b1;
            end
            current_expect_lights <= expect_lights[compute_mach];
            buttons_flattened <= buttons[compute_mach];              
        end

        if(compute_done) begin
            compute_done_off <= 1'b1;
        end

        if(mach_presses_valid[core_index]) begin
            r_total_presses_required <= r_total_presses_required + mach_presses_required[core_index];
        end

        if(tx_confirmed & ~mach_all_sent) begin
            if(compute_mach == (MACHINE_COUNT-1)) begin
                mach_all_sent <= 1'b1;
            end
            else begin
                compute_mach <= compute_mach + 1'b1;
            end
        end

        if(core_index == (CORE_COUNT-1)) begin
            core_index <= 0;
        end
        else begin
            core_index <= core_index + 1'b1;
        end
    end
end

always@(*) begin
    rx_ready = 0;
    rx_ready[core_index] = 1'b1;
end

generate
    genvar v;
    for(v=0;v<CORE_COUNT;v=v+1) begin
        combo_solver_core #(
            .MAX_LIGHT_COUNT(MAX_LIGHT_COUNT),
            .MAX_BUTTON_COUNT(MAX_BUTTON_COUNT)
        )
        combo_solver_core_inst
        (
            .clk(clk),
            .reset(reset),
            .rx_ready(rx_ready[v]),
            .tx_valid(tx_valid[v]),
            .buttons_flattened(buttons_flattened),
            .expect_lights(current_expect_lights),
            .mach_presses_required(mach_presses_required[v]),
            .core_ready(core_ready[v]),
            .mach_presses_valid(mach_presses_valid[v])
        );
    end
endgenerate

endmodule
