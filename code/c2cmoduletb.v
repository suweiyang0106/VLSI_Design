`timescale 1ns/1ns
module c2cmoduletb;
    //Input
    reg clk;
    reg rst;
    reg [1:0]cmd;
    reg [7:0]datain;
    reg [3:0]PID;
    reg datavalid;
    //Output    
    wire [7:0]dataout;
	wire outvalid;
	wire pagefault;
	wire busy;
	wire wd;/*write done*/
	//file read
	reg[10:0] readcnt;
	reg [7:0]data[0:41];//42 items, each has 8 bits
	//Instantiate c2cmodule
c2cmodule dut(
    .clk(clk),
    .rst(rst),
    .cmd(cmd),/*NOP/ write cache/ load c2c/ translate*/
    .datain(datain),
    .datavalid(datavalid),
    .PID(PID),
    .dataout(dataout),
    .busy(busy),
    .outvalid(outvalid),
    .pagefault(pagefault),
    .wd(wd)
    );

	initial begin 
		clk = 0;
		readcnt<=0;
		datavalid<=0;
		datain<=0;
		cmd<=2'b00;
		rst<=1;	
		$readmemh("file.txt",data);
		forever begin		
		#1 rst<=0; clk = ~clk;
		end
	end     
	
	always @(posedge clk)
	begin
	    //write data to cache
	    if(readcnt<21 && wd==1 && busy==1)
	    begin
	        cmd<=2'b01;
	        datavalid<=1;
	        datain<=data[readcnt];
	        readcnt<=readcnt+1;
	        PID<=3'b100;
	    end
	    else if(readcnt<21)
	    begin
	        cmd<=2'b01;//polling
	        datavalid<=0;
	    end
	    else if(readcnt==21)
        begin
	        cmd<=2'b00;
	        datavalid<=0;
	        readcnt<=readcnt+1;
	    end
	    //Load data to cam
	    
	    if(readcnt==22)
	    begin
	        if(wd==1 && busy==0)
	        begin
	            cmd<=2'b10;
	            readcnt<=readcnt+1;
	        end
	        else
	            cmd<=2'b00;
	    end
	    if(readcnt==23 && busy==1)
	            readcnt<=readcnt+1;//polling for busy
	    if(readcnt==24 && busy==0)
	    begin        
	        cmd<=2'b00;//polling for idle
	        readcnt<=readcnt+1;
	    end
	    //read data from cache/cam
	    if(readcnt==25 && busy==0)
	    begin
	        cmd<=2'b11;
	        PID<=4'b1000;
	        datain<={4'b0001,4'b1000};
	        readcnt<=readcnt+1;
	    end
	    if(readcnt==26 && busy==1)
	    begin//polling for busy
	        cmd<=2'b00;
	        readcnt<=readcnt+1;
	    end
	    if(readcnt==27 && busy==0)
	    begin//polling for idle
	        readcnt<=readcnt+1;
	    end
	end

endmodule
