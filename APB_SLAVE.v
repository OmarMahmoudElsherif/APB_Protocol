
module APB_SLAVE #(
	parameter DATA_WD = 32,
	parameter ADDR_WD = 16 
)	(

///////////////////// Inputs /////////////////////////////////
input	wire						PCLK,
input	wire						S_CLK,
input	wire						PRESETn,
input	wire						Addr_ER,
input	wire						Parity_ER,
input	wire						ConfigSp_ACKAPB,
input	wire	[DATA_WD-1:0]		ConfigSp_DATA,
input	wire						APB_Grant,
input	wire	[3:0]				PSTRB,
input	wire						PWRITE,
input	wire						PENABLE,
input	wire						PSEL,
input	wire	[ADDR_WD-1:0]		PADDR,
input	wire	[DATA_WD-1:0]		PWDATA,


///////////////////// Outputs ////////////////////////////////

output	reg							APB_Request,
output	wire						PREADY,
output	reg		[DATA_WD-1:0]		APB_ODATA,
output	reg		[ADDR_WD-1:0]		APB_OADDR,
output	reg		[3:0]				APB_OSTRB,
output	wire	[DATA_WD-1:0]		PRDATA,
output	wire  	[1:0]				PSLVERR
	
);

//////////////////////////////////////////////////////////////
///////////////  Internal Storage Elements  //////////////////
//////////////////////////////////////////////////////////////

reg		[DATA_WD-1:0]		SLAVE_DATA_Reg;
reg		[ADDR_WD-1:0]		SLAVE_ADDR_Reg;
reg		[3:0]				SLAVE_STRB_Reg;



//////////////////////////////////////////////////////////////
/////////////////////  Internal Signals  /////////////////////
//////////////////////////////////////////////////////////////

wire				PENABLE_SYNC;
reg					PREADY_SYNC;
wire                PRESETn_SYNC;
reg                 ConfigSp_Read_Valid;


//////////////////////////////////////////////////////////////
////////////////////////  FSM States  ////////////////////////
//////////////////////////////////////////////////////////////

reg		[2:0]		SETUP_PHASE		=	'b000,		
					WRITE_PHASE		=	'b001,
					READ_PHASE		=	'b010,
					SEND_REQUEST	=	'b011,
					WAIT_STAGE		=	'b100,
					TRAN_COMPLETE   =   'b101;
					


reg		[2:0]	Next_state,
				current_state;




//////////////////////////////////////////////////////////////
/////////////////////  State Transition  /////////////////////
//////////////////////////////////////////////////////////////

always @(posedge S_CLK or negedge PRESETn_SYNC) begin
	if (!PRESETn_SYNC) begin
		current_state	<=	SETUP_PHASE;
	end
	else  begin
		current_state	<=	Next_state;
	end
end



//////////////////////////////////////////////////////////////
////////////////////// Next State Logic  /////////////////////
//////////////////////////////////////////////////////////////

always@(*) begin

/************ initial values to avoid latches *********/
APB_Request			=	'b0;
PREADY_SYNC			=	'b0;
APB_OSTRB			=	'b0;
APB_ODATA			=	'b0;
APB_OADDR			=	'b0;


	case(current_state)
		
		WAIT_STAGE	:	begin
			if(ConfigSp_ACKAPB=='b1 && ConfigSp_Read_Valid=='b0)	 begin  // Write Transaction Done
				
				PREADY_SYNC			=	'b1;	// Ack App to tell him write transaction done
				Next_state			=	TRAN_COMPLETE;
			end
			
			else if(ConfigSp_ACKAPB=='b1 && ConfigSp_Read_Valid=='b1)	 begin // Config Space sends data to APB
	
				/*	read data from  ConfigSp_Data to internal storage element in APB */
				
				PREADY_SYNC			=	'b1;	// ack to app to tell him to read data from slave due to read transaction
				Next_state			=	TRAN_COMPLETE;
			end

			else begin
				Next_state			=	WAIT_STAGE;
			end
		end

		TRAN_COMPLETE :		begin
			//PREADY must be high for 2 clks since usually PCLK < S_CLK
			PREADY_SYNC			=	'b1;
			
		
			Next_state			=	SETUP_PHASE;
		end

		SETUP_PHASE	:	begin
			if(PENABLE_SYNC	==	'b0  ) begin  // Setup Phase of APB transaction


				/** getting PADDR  **/
				

					if(PSEL =='b1 && PWRITE =='b1) begin
						Next_state	=	WRITE_PHASE;	
					end
					else if (PSEL =='b1 && PWRITE =='b0) begin
						Next_state	=	READ_PHASE;
					end
					else begin
						Next_state	=	SETUP_PHASE;
					end
				end
			

			else begin   // no data sent from application
				Next_state			=	SETUP_PHASE;
			end
		
		end

		WRITE_PHASE	:	begin
			if(PENABLE_SYNC	==	'b1) begin  	 // Data Access Phase of APB transaction

				/** getting PWDATA using Bus synchronization **/

				
				Next_state		=	SEND_REQUEST;
			end
			else begin
				Next_state		=	WRITE_PHASE;
			end

		end


		READ_PHASE	:	begin
			if(PENABLE_SYNC	==	'b1) begin   	// Data Access Phase of APB transaction

			
				PREADY_SYNC 	=	'b1;

				Next_state		=	TRAN_COMPLETE;
			end
			else begin
				Next_state		=	READ_PHASE;
			end

		end

		SEND_REQUEST	:	begin
			APB_Request		=	'b1;	// generate request
			
			APB_OSTRB		=	SLAVE_STRB_Reg;
			APB_ODATA		=	SLAVE_DATA_Reg;
			APB_OADDR		=	SLAVE_ADDR_Reg;
			if(APB_Grant=='b1) begin  // granted access
				Next_state		=	WAIT_STAGE;
			end
			else begin
				Next_state		=	SEND_REQUEST;
			end

		end


		default		:	begin
			APB_Request			=	'b0;
			PREADY_SYNC			=	'b0;

			APB_OSTRB			=	'b0;
			APB_ODATA			=	'b0;
			APB_OADDR			=	'b0;
		
		end


	endcase

end


//////////////////////////////////////////////////////////////
/////////////////// Internal Storage Unit  ///////////////////
//////////////////////////////////////////////////////////////

always@(posedge S_CLK,negedge PRESETn_SYNC ) begin
	if(!PRESETn_SYNC) begin
			SLAVE_DATA_Reg			<=	'b0;
			SLAVE_ADDR_Reg			<=	'b0;
			SLAVE_STRB_Reg			<=	'b0;
			ConfigSp_Read_Valid		<=	'b0;
			
	end
	else begin

			if (current_state == WRITE_PHASE && PENABLE_SYNC	==	'b1) begin
				SLAVE_ADDR_Reg		<=	PADDR;
				SLAVE_DATA_Reg		<=	PWDATA;
				SLAVE_STRB_Reg		<=	PSTRB;
				ConfigSp_Read_Valid	<=	~|PSTRB;		//  if Read Transaction, Strobes = 'b0000, so ConfigSp_Read_Valid = 1,
													//	if Write Transacation , ConfigSp_Read_Valid = 0

			end

			// Config Space sends data to APB
			else if(current_state == WAIT_STAGE && ConfigSp_ACKAPB=='b1 && ConfigSp_Read_Valid=='b1) begin 
				/*	read data from  ConfigSp_Data to internal storage element in APB */
				SLAVE_DATA_Reg		<=	ConfigSp_DATA;
			end


	end


end


//////////////////////////////////////////////////////////////
/////////////////// Assign PRDATA and PSLVERR ////////////////
//////////////////////////////////////////////////////////////

//output PRDATA,PSLVERR on PREADY edge {on PCLK edge}

assign  PRDATA	= (PREADY== 'b1)	?	SLAVE_DATA_Reg		:	'b0 ;
assign  PSLVERR	= (PREADY== 'b1)	?   {Parity_ER,Addr_ER}	:	'b0 ;


//////////////////////////////////////////////////////////////
///////////////////  Bit Synchronizer For PSEL  //////////////
//////////////////////////////////////////////////////////////
BIT_SYNC SYNC_PENABLE (
	.Destination_CLK(S_CLK),
	.RST(PRESETn),
	.ASYNC_IN(PENABLE),
	.SYNC_OUT(PENABLE_SYNC)
);


//////////////////////////////////////////////////////////////
/////////////////  Bit Synchronizer For PREADY  //////////////
//////////////////////////////////////////////////////////////
BIT_SYNC SYNC_PREADY (
	.Destination_CLK(PCLK),
	.RST(PRESETn),
	.ASYNC_IN(PREADY_SYNC),
	.SYNC_OUT(PREADY)
);


//////////////////////////////////////////////////////////////
/////////////////////  Reset Synchronizer  ///////////////////
//////////////////////////////////////////////////////////////

RESET_SYNC SYNC_PRESETn (
	.Destination_CLK(S_CLK),
	.RST(PRESETn),
	.SYNC_RST(PRESETn_SYNC)
	);






endmodule