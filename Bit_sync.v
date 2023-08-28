
module BIT_SYNC (
input	wire	Destination_CLK,
input	wire	RST,
input	wire	ASYNC_IN,
output	reg		SYNC_OUT,
	);

//Destination FlipFlop
reg			FF1;

//Sequential always
always @(posedge Destination_CLK, negedge RST) begin
	if(!RST) begin
		FF1 		<= 'b0;
		SYNC_OUT	<= 'b0;
	end
	else begin
		FF1 		<= ASYNC_IN;
		SYNC_OUT	<= FF1;
	end

end



endmodule
