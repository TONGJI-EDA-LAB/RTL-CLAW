`timescale 1ns/1ns

module verified_traffic_light
    (
      input  rst_n,
      input  clk,
      input  pass_request,
      output wire[7:0] clock,
      output reg  red,
      output reg  yellow,
      output reg  green
    );

    // =========================================================
    // Parameter Definitions
    // =========================================================
    parameter idle = 2'd0,
              s1_red = 2'd1,
              s2_yellow = 2'd2,
              s3_green = 2'd3;

    // =========================================================
    // Internal Variable Declarations
    // =========================================================
    reg [7:0] cnt;
    reg [1:0] u_block_1_state;
    reg       p_red;
    reg       p_yellow;
    reg       p_green;

    // =========================================================
    // Always Block 1 (State Machine)
    // =========================================================
    always @(posedge clk or negedge rst_n)
        begin
            if(!rst_n)
            begin
                u_block_1_state <= idle;
                p_red   <= 1'b0;
                p_green <= 1'b0;
                p_yellow <= 1'b0;
            end
            else case(u_block_1_state)
            idle:
                begin
                    p_red   <= 1'b0;
                    p_green <= 1'b0;
                    p_yellow <= 1'b0;
                    u_block_1_state <= s1_red;
                end
            s1_red:
                begin
                    p_red   <= 1'b1;
                    p_green <= 1'b0;
                    p_yellow <= 1'b0;
                    if (cnt == 3)
                        u_block_1_state <= s3_green;
                    else
                        u_block_1_state <= s1_red;
                end
            s2_yellow:
                begin
                    p_red   <= 1'b0;
                    p_green <= 1'b0;
                    p_yellow <= 1'b1;
                    if (cnt == 3)
                        u_block_1_state <= s1_red;
                    else
                        u_block_1_state <= s2_yellow;
                end
            s3_green:
                begin
                    p_red   <= 1'b0;
                    p_green <= 1'b1;
                    p_yellow <= 1'b0;
                    if (cnt == 3)
                        u_block_1_state <= s2_yellow;
                    else
                        u_block_1_state <= s3_green;
                end
            default:
                begin
                    p_red   <= 1'b0;
                    p_green <= 1'b0;
                    p_yellow <= 1'b0;
                    u_block_1_state <= idle;
                end
            endcase
        end

    // =========================================================
    // Always Block 2 (Counter)
    // =========================================================
    always @(posedge clk or negedge rst_n)
        if(!rst_n)
            cnt <= 7'd10;
        else if (pass_request&&green&&(cnt>10))
            cnt <= 7'd10;
        else if (!green&&p_green)
            cnt <= 7'd60;
        else if (!yellow&&p_yellow)
            cnt <= 7'd5;
        else if (!red&&p_red)
            cnt <= 7'd10;
        else
            cnt <= cnt - 1;

    // =========================================================
    // Assign Statement
    // =========================================================
    assign clock = cnt;

    // =========================================================
    // Always Block 3 (Output)
    // =========================================================
    always @(posedge clk or negedge rst_n)
        if(!rst_n)
        begin
            yellow <= 1'd0;
            red    <= 1'd0;
            green  <= 1'd0;
        end
        else
        begin
            yellow <= p_yellow;
            red    <= p_red;
            green  <= p_green;
        end

endmodule
