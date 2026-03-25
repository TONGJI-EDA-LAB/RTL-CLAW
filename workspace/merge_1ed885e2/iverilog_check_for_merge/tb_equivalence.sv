`timescale 1ns/1ns

module tb_equivalence;
    reg rst_n;
    reg clk;
    reg pass_request;
    wire [7:0] clock_orig;
    wire [7:0] clock_merged;
    wire red_orig, yellow_orig, green_orig;
    wire red_merged, yellow_merged, green_merged;

    // Instantiate original
    verified_traffic_light dut_original (
        .rst_n(rst_n),
        .clk(clk),
        .pass_request(pass_request),
        .clock(clock_orig),
        .red(red_orig),
        .yellow(yellow_orig),
        .green(green_orig)
    );

    // Instantiate merged (renamed to avoid conflict)
    verified_traffic_light_merged dut_merged (
        .rst_n(rst_n),
        .clk(clk),
        .pass_request(pass_request),
        .clock(clock_merged),
        .red(red_merged),
        .yellow(yellow_merged),
        .green(green_merged)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test stimulus
    initial begin
        $display("=== Equivalence Check Start ===");
        rst_n = 0;
        pass_request = 0;
        
        #15;
        rst_n = 1;
        
        #10;
        
        // Run for 200 cycles and check equivalence
        for (integer i = 0; i < 200; i = i + 1) begin
            @(posedge clk);
            #1;
            if (clock_orig !== clock_merged) begin
                $display("FAIL at cycle %0d: clock mismatch! original=%h, merged=%h", 
                         i, clock_orig, clock_merged);
                $finish;
            end
            if (red_orig !== red_merged) begin
                $display("FAIL at cycle %0d: red mismatch! original=%b, merged=%b", 
                         i, red_orig, red_merged);
                $finish;
            end
            if (yellow_orig !== yellow_merged) begin
                $display("FAIL at cycle %0d: yellow mismatch! original=%b, merged=%b", 
                         i, yellow_orig, yellow_merged);
                $finish;
            end
            if (green_orig !== green_merged) begin
                $display("FAIL at cycle %0d: green mismatch! original=%b, merged=%b", 
                         i, green_orig, green_merged);
                $finish;
            end
        end
        
        $display("=== PASS: All outputs match for 200 cycles ===");
        $finish;
    end

    initial begin
        #50000;
        $display("FAIL: Timeout - simulation did not complete");
        $finish;
    end
endmodule