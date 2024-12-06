`timescale 1ns/1ns
module cache_tb;
    //Input
    reg clk;
    reg rst;
    reg [1:0]cmd;
	reg [11:0]datain;
	reg [3:0]PID;
	reg datavalid;
    //Output
    wire wd;
    wire pagefault;
    wire [11:0]dataout;
	wire outvalid;
	//file read
	integer fd;
	integer fdscanf;
	reg [11:0] data;//12 bit for 4096 addresses in dram
	reg[10:0] readcnt;
	reg[10:0] dvcnt;
    //Instantiate halfadder
    cache dut(
		.clk(clk),
		.rst(rst),
		.cmd(cmd),
		.datavalid(datavalid),
		.datain(datain),
		.PID(PID),
		.pagefault(pagefault),
		.dataout(dataout),
		.outvalid(outvalid),
		.wd(wd)
    );
	initial begin 
		clk = 0;
		readcnt<=0;
		datavalid<=0;
		datain<=0;
		cmd<=2'b00;
		rst<=1;
		dvcnt<=0;
		fd = $fopen("file2.dat","r");		
		if(fd==0)begin
		    $display("find no file\n");
		    $finish;
		end	
		forever begin		
		#1 rst<=0; clk = ~clk;
		end
	end
    always @(posedge clk)
    begin		
		//write data to cache 
		if(dvcnt<43)
		begin
		datain<=data;
		cmd <=2'b10;
		datain<=data;
		if(dvcnt<22)
		PID<=4;		
		else
		PID<=3;
	    if(wd==1 && datavalid==0 && dvcnt <43) 
	    begin
	        datavalid<=1;
	        fdscanf = $fscanf(fd,"%d\n",data);
	        dvcnt<=dvcnt+1;	        
	    end
	    else
	        datavalid<=0;  
	    //if($feof(fd))
		//    $finish;  
		//else
		//   readcnt<=readcnt+1;
	    end

		
	    //read data from cache
	    if(dvcnt==43 && outvalid==0)
	    begin
	    datain<=12'b000001011111;
	    cmd<= 2'b01;
        PID<=5;
        end
		    
    end


endmodule
