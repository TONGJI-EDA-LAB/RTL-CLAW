// =========================================================
// Submodule: u_block_2
// =========================================================
module u_block_2 (
input  wire  clk,
input  wire  green,
input  wire  p_green,
input  wire  p_red,
input  wire  p_yellow,
input  wire  pass_request,
input  wire  red,
input  wire  rst_n,
input  wire  yellow,
output reg [7:0] cnt
);

    // Parameters
    parameter 	idle = 2'd0,
				s1_red = 2'd1,
				s2_yellow = 2'd2,
				s3_green = 2'd3;

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
    		else cnt <= cnt -1;

endmodule
