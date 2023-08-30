
module BIT_SYNC (

input		wire		Destination_CLK,
input		wire		RST,
input		wire		ASYNC_IN,
output		reg			SYNC_OUT
	
	);

//Destination FlipFlop
reg			FF1;
//Synchronization FlipFlop
reg			FF2;


//flag
reg		Pulse_Conv_flg;

//Sequential always
always @(posedge Destination_CLK, negedge RST) begin
	if(!RST) begin
		FF1 		<= 'b0;
		FF2			<= 'b0;
	end
	else begin
		FF1 		<= ASYNC_IN;
		FF2			<= FF1;
	end

end


//Pulse Converter Logic
always@(posedge Destination_CLK, negedge RST) begin
	if(!RST) begin
		Pulse_Conv_flg		=	'b1;
	end
	
	else begin
	
		if(FF2	==	'b1) begin
	
			if(Pulse_Conv_flg	==	'b1) begin
				SYNC_OUT			=	'b1;
				Pulse_Conv_flg		=	'b0;
			end	
	
			else begin
				SYNC_OUT			=	'b0;
				Pulse_Conv_flg		=	'b0;			
			end		
	
		end
	
		else begin
			Pulse_Conv_flg			=	'b1;
			SYNC_OUT				=	'b0;
		end
	end
end


endmodule
