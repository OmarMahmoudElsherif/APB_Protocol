`timescale 1ns/1ps

module APB_SLAVE_TB();


/////////////////////////////////////////////////////////
///////////////////// Parameters ////////////////////////
/////////////////////////////////////////////////////////

parameter DATA_WD_TB   = 32 ;    
parameter ADDR_WD_TB   = 16 ;    
parameter PCLK_PERIOD  = 20 ; 
parameter S_CLK_PERIOD = 10 ;	// Assume S_CLK > PCLK

/////////////////////////////////////////////////////////
//////////////////// DUT Signals ////////////////////////
/////////////////////////////////////////////////////////

reg             			        PCLK_TB; 
reg             			        S_CLK_TB; 
reg									PRESETn_TB;
reg									Addr_ER_TB;
reg									Parity_ER_TB;
reg									ConfigSp_ACKAPB_TB;
reg									ConfigSp_APBValid_TB;
reg			[DATA_WD_TB-1:0]		ConfigSp_DATA_TB;
reg									APB_Grant_TB;
reg			[3:0]					PSTRB_TB;
reg									PWRITE_TB;
reg									PENABLE_TB;
reg									PSEL_TB;
reg			[ADDR_WD_TB-1:0]		PADDR_TB;
reg			[DATA_WD_TB-1:0]		PWDATA_TB;


wire								APB_Request_TB;
wire								PREADY_TB;
wire		[DATA_WD_TB-1:0]		APB_ODATA_TB;
wire		[ADDR_WD_TB-1:0]		APB_OADDR_TB;
wire		[3:0]					APB_OSTRB_TB;
wire		[DATA_WD_TB-1:0]		PRDATA_TB;
wire		[1:0]					PSLVERR_TB;



//Application Internal Storage 
reg			[DATA_WD_TB-1:0]		App_Data_reg;



////////////////////////////////////////////////////////
////////////////// initial block /////////////////////// 
////////////////////////////////////////////////////////


initial begin
	//initialize
	initialize();
	//reset
	reset();

	//Send Data using APB
	send_write_transaction('d152,'d12,'b1111);


	//Send Data using APB
	send_read_transaction('d85,'d34,'b0000);



	#(10*PCLK_PERIOD);

	$finish();

end




////////////////////////////////////////////////////////
/////////////////////// TASKS //////////////////////////
////////////////////////////////////////////////////////

/////////////// Signals Initialization //////////////////

task initialize ;
  begin
	PCLK_TB					= 	1'b0;
	S_CLK_TB				= 	1'b0;
	PRESETn_TB				= 	1'b1;    // rst is deactivated
	Addr_ER_TB				= 	1'b0;	
	Parity_ER_TB			= 	1'b0;
	ConfigSp_ACKAPB_TB		=	1'b0;
	ConfigSp_APBValid_TB	=	1'b0;
	ConfigSp_DATA_TB		=	'b0;
	PWRITE_TB				=	'b0;
	PENABLE_TB				=	'b0;
	PSEL_TB					=	'b0;
	PADDR_TB                =   'b0;
	APB_Grant_TB			=	'b0;
	PWDATA_TB				=	'b0;


	App_Data_reg			=   'b0;

	
  end
endtask

///////////////////////// RESET /////////////////////////

task reset ;
 begin
  #(PCLK_PERIOD)
  PRESETn_TB  				= 'b0;           // rst is activated
  #(PCLK_PERIOD)
  PRESETn_TB  = 'b1;
  #(PCLK_PERIOD) ;
  
 end
endtask


/////////////////////// Send Data ///////////////////////

task send_write_transaction ;
	input	[DATA_WD_TB-1:0]	Data_in;
	input	[ADDR_WD_TB-1:0]	Addr_in;
	input	[3:0]				STRB_in;
	begin
		PWRITE_TB	=	'b1;
		PSEL_TB		=	'b1;
		PENABLE_TB	=	'b0;
		PWDATA_TB	=	Data_in;
		PADDR_TB    =   Addr_in;
		PSTRB_TB    =   STRB_in;
		#PCLK_PERIOD;
		
		PENABLE_TB	=	'b1;
		
		// Grant Access to APB
		#(3*PCLK_PERIOD);
		APB_Grant_TB			=	'b1;
		PSEL_TB					=	'b0;
		
		// Ack from Configuration Space (Transaction Done)
		#(2*PCLK_PERIOD);
		ConfigSp_ACKAPB_TB		=	1'b1;
		
		#(PCLK_PERIOD);
		ConfigSp_ACKAPB_TB		=	1'b0;
		APB_Grant_TB			=	'b0;

		@(posedge PREADY_TB);
		PSEL_TB		=	'b0;
		PENABLE_TB	=	'b0;
		$display ("Write Transfer Transaction Completed\n");
		$display ("	Data : %d, Addr : %d, Strobes :%d \n",Data_in,Addr_in,STRB_in);
		#(2*PCLK_PERIOD)
		initialize();
	end
endtask




/////////////////////// Send Data ///////////////////////

task send_read_transaction ;
	input	[DATA_WD_TB-1:0]	Data_in;
	input	[ADDR_WD_TB-1:0]	Addr_in;
	input	[3:0]				STRB_in;
	begin
		PWRITE_TB	=	'b1;
		PSEL_TB		=	'b1;
		PENABLE_TB	=	'b0;
		PWDATA_TB	=	Data_in;
		PADDR_TB    =   Addr_in;
		PSTRB_TB    =   STRB_in;
		#PCLK_PERIOD;
		
		PENABLE_TB	=	'b1;
		
		// Grant Access to APB
		#(3*PCLK_PERIOD);
		APB_Grant_TB			=	'b1;
		PSEL_TB					=	'b0;

		
		
		// Ack from Configuration Space (Transaction Done)
		#(2*PCLK_PERIOD);
		ConfigSp_ACKAPB_TB		=	1'b1;
		ConfigSp_APBValid_TB	=	1'b1;

		// Configuration Space Sends Data to APB
		ConfigSp_DATA_TB		=	'd150;

		#(PCLK_PERIOD);

		ConfigSp_ACKAPB_TB		=	1'b0;
		ConfigSp_APBValid_TB	=	1'b0;
		APB_Grant_TB			=	'b0;

		@(posedge PREADY_TB);
		PSEL_TB		=	'b0;
		PENABLE_TB	=	'b0;
		$display ("Read Transfer Transaction Completed\n");
		

		//App Reads Data from APB Slave
		PWRITE_TB	=	'b0;
		PSEL_TB		=	'b1;
		PENABLE_TB	=	'b0;

		#PCLK_PERIOD;

		PENABLE_TB	=	'b1;
		#(2*PCLK_PERIOD);
		App_Data_reg	=	PRDATA_TB;
		$display ("Data Read From APB is : %d \n",App_Data_reg);
		#(2*PCLK_PERIOD)
		initialize();
	end
endtask






///////////////////// Clock Generators //////////////////

always #(PCLK_PERIOD/2)  PCLK_TB  = ~PCLK_TB ;
always #(S_CLK_PERIOD/2) S_CLK_TB = ~S_CLK_TB ;




////////////////////////////////////////////////////////
//////////////// DUT Instantiation ///////////////////// 
////////////////////////////////////////////////////////

APB_SLAVE #(
	.DATA_WD(DATA_WD_TB) ,
	.ADDR_WD(ADDR_WD_TB)  

)  DUT	(
///////////////////// Inputs /////////////////////////////////
		.PCLK(PCLK_TB),
		.S_CLK(S_CLK_TB),
		.PRESETn(PRESETn_TB),
		.Addr_ER(Addr_ER_TB),
		.Parity_ER(Parity_ER_TB),
		.ConfigSp_ACKAPB(ConfigSp_ACKAPB_TB),
		.ConfigSp_APBValid(ConfigSp_APBValid_TB),
		.ConfigSp_DATA(ConfigSp_DATA_TB),
		.APB_Grant(APB_Grant_TB),
		.PSTRB(PSTRB_TB),
		.PWRITE(PWRITE_TB),
		.PENABLE(PENABLE_TB),
		.PSEL(PSEL_TB),
		.PADDR(PADDR_TB),
		.PWDATA(PWDATA_TB),
///////////////////// Outputs ////////////////////////////////
		.APB_Request(APB_Request_TB),
		.PREADY(PREADY_TB),
		.APB_ODATA(APB_ODATA_TB),
		.APB_OADDR(APB_OADDR_TB),
		.APB_OSTRB(APB_OSTRB_TB),
		.PRDATA(PRDATA_TB),
		.PSLVERR(PSLVERR_TB)
);




endmodule