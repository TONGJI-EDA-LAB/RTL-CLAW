// =========================================================
// Submodule: u_block_1
// =========================================================
module u_block_1 (
input  wire  clk,
input  wire [7:0] cnt,
input  wire  rst_n,
output reg  p_green,
output reg  p_red,
output reg  p_yellow,
output reg [1:0] state
);

    // Parameters
    parameter STATE_IDLE = 2'd0,
              STATE_S1_RED = 2'd1,
              STATE_S2_YELLOW = 2'd2,
              STATE_S3_GREEN = 2'd3;

    always @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
        begin
            state <= STATE_IDLE;
            p_red <= 1'b0;
            p_green <= 1'b0;
            p_yellow <= 1'b0;
        end
        else case (state)
            STATE_IDLE:
            begin
                p_red <= 1'b0;
                p_green <= 1'b0;
                p_yellow <= 1'b0;
                state <= STATE_S1_RED;
            end
            STATE_S1_RED:
            begin
                p_red <= 1'b1;
                p_green <= 1'b0;
                p_yellow <= 1'b0;
                if (cnt == 3)
                    state <= STATE_S3_GREEN;
                else
                    state <= STATE_S1_RED;
            end
            STATE_S2_YELLOW:
            begin
                p_red <= 1'b0;
                p_green <= 1'b0;
                p_yellow <= 1'b1;
                if (cnt == 3)
                    state <= STATE_S1_RED;
                else
                    state <= STATE_S2_YELLOW;
            end
            STATE_S3_GREEN:
            begin
                p_red <= 1'b0;
                p_green <= 1'b1;
                p_yellow <= 1'b0;
                if (cnt == 3)
                    state <= STATE_S2_YELLOW;
                else
                    state <= STATE_S3_GREEN;
            end
            default:
            begin
                state <= STATE_IDLE;
            end
        endcase
    end

endmodule