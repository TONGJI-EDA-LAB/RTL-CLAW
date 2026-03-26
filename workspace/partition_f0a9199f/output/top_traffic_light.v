// =========================================================
// Top-level wrapper for partitioned traffic light
// =========================================================
module top_traffic_light (
    input rst_n,
    input clk,
    input pass_request,
    output wire [7:0] clock,
    output reg red,
    output reg yellow,
    output reg green
);

    // Internal signals
    wire [7:0] cnt;
    wire [1:0] state;
    wire p_red, p_yellow, p_green;
    
    // Instantiate submodules
    u_block_1 u_block_1_inst (
        .clk(clk),
        .cnt(cnt),
        .rst_n(rst_n),
        .p_green(p_green),
        .p_red(p_red),
        .p_yellow(p_yellow),
        .state(state)
    );
    
    u_block_2 u_block_2_inst (
        .clk(clk),
        .green(green),
        .p_green(p_green),
        .p_red(p_red),
        .p_yellow(p_yellow),
        .pass_request(pass_request),
        .red(red),
        .rst_n(rst_n),
        .yellow(yellow),
        .cnt(cnt)
    );
    
    u_block_3 u_block_3_inst (
        .clk(clk),
        .p_green(p_green),
        .p_red(p_red),
        .p_yellow(p_yellow),
        .rst_n(rst_n),
        .green(green),
        .red(red),
        .yellow(yellow)
    );
    
    // Continuous assignment
    assign clock = cnt;

endmodule