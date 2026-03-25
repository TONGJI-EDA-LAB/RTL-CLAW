// =========================================================
// Submodule: u_block_1
// =========================================================
module u_block_1 (
input  wire  clk,
input  wire [7:0] cnt,
input  wire  idle,
input  wire  rst_n,
input  wire  s1_red,
input  wire  s2_yellow,
input  wire  s3_green,
output wire  p_green,
output wire  p_red,
output wire  p_yellow
);

    // Parameters
    parameter 	idle = 2'd0,
				s1_red = 2'd1,
				s2_yellow = 2'd2,
				s3_green = 2'd3;

    // Internal variables with module prefix
reg [1:0] u_block_1_state;

    always @(posedge clk or negedge rst_n)
        begin
            if(!rst_n)
            begin
    			u_block_1_state <= idle;
    			p_red <= 1'b0;
    			p_green <= 1'b0;
    			p_yellow <= 1'b0;
            end
            else case(u_block_1_state)
    		idle:
    			begin
    				p_red <= 1'b0;
    				p_green <= 1'b0;
    				p_yellow <= 1'b0;
    				u_block_1_state <= s1_red;
    			end
    		s1_red:
    			begin
    				p_red <= 1'b1;
    				p_green <= 1'b0;
    				p_yellow <= 1'b0;
    				if (cnt == 3)
    					u_block_1_state <= s3_green;
    				else
    					u_block_1_state <= s1_red;
    			end
    		s2_yellow:
    			begin
    				p_red <= 1'b0;
    				p_green <= 1'b0;
    				p_yellow <= 1'b1;
    				if (cnt == 3)
    					u_block_1_state <= s1_red;
    				else
    					u_block_1_state <= s2_yellow;
    			end
    		s3_green:
    			begin
    				p_red <= 1'b0;
    				p_green <= 1'b1;
    				p_yellow <= 1'b0;
    				if (cnt == 3)
    					u_block_1_state <= s2_yellow;
    				else
    					u_block_1_state <= s3_green;
    			end
    		endcase
    	end

endmodule
