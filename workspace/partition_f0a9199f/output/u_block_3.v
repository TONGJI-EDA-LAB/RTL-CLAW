// =========================================================
// Submodule: u_block_3
// =========================================================
module u_block_3 (
input  wire  clk,
input  wire  p_green,
input  wire  p_red,
input  wire  p_yellow,
input  wire  rst_n,
output reg  green,
output reg  red,
output reg  yellow
);

    // Parameters
    parameter 	idle = 2'd0,
				s1_red = 2'd1,
				s2_yellow = 2'd2,
				s3_green = 2'd3;

    always @(posedge clk or negedge rst_n)
            if(!rst_n)
    			begin
    				yellow <= 1'd0;
    				red <= 1'd0;
    				green <= 1'd0;
    			end
    		else
    			begin
    				yellow <= p_yellow;
    				red <= p_red;
    				green <= p_green;
    			end

endmodule