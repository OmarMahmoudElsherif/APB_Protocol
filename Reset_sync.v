
module RESET_SYNC (
input		wire		Destination_CLK,
input		wire		RST,
output		reg			SYNC_RST
	);

//Destination FlipFlop
reg			FF1;


//Sequential always
always @(posedge Destination_CLK, negedge RST) begin
	if(!RST) begin
		FF1 				<= 'b0;
		SYNC_RST			<= 'b0;
	end
	else begin
		FF1 				<= 'b1;
		SYNC_RST			<= FF1;
	end

end




endmodule
