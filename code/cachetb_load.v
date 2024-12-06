`timescale 1ns/1ns
module cache_tb_laod;
    //Input
    reg clk;
    reg rst;
    reg [1:0]cmd;
	reg [7:0]datain;
	reg [3:0]PID;
	reg datavalid;
    //Output
    wire wd;
    wire pagefault;
    wire [7:0]dataout;
	wire outvalid;
	//file read
	reg[10:0] readcnt;
	reg[10:0] dvcnt;
	reg [7:0]data[0:41];//42 items, each has 8 bits
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
		$readmemh("file.txt",data);
		forever begin		
		#1 rst<=0; clk = ~clk;
		end
	end
    always @(posedge clk)
    begin		
        
		//write data to cache 
		if(dvcnt<43)
		begin		    
		    cmd <=2'b10;
		    if(dvcnt<21)
		        PID<=4;		
		    else
		        PID<=3;
	        if(wd==1 && datavalid==0 && dvcnt <43) 
	            begin
	                datavalid<=1;
	                readcnt<=readcnt+1;
	                dvcnt<=dvcnt+1;	   
	                datain<=data[readcnt];     
	            end
	        else
	            datavalid<=0;  
	            
	        if(dvcnt==42)
	         begin   cmd<=2'b00; dvcnt<=dvcnt+1;end
	    end        
		
	    //read data from cache
	    if(dvcnt==43 && outvalid==0)
	    begin
	    datain<=8'h00;
	    cmd<= 2'b01;
        PID<=3;
        end
        if(outvalid==1 && dvcnt==43)//for cache back to idle
        begin    
            cmd<=2'b00;
            dvcnt<=dvcnt+1;
        end
        
        //load data from cache
        if(dvcnt==44 && outvalid==0)
        begin
            cmd<=2'b11;
            PID<=3;
            dvcnt<=dvcnt+1;
        end
        //else if(dvcnt==44 && outvalid==1)
            
        //begin end
        
        if( outvalid==1 && dvcnt >=45)
            dvcnt<=dvcnt+1;
        if(dvcnt==66)
            cmd<=2'b00;
        //if(dvcnt>=45)
         //   cmd<=2'b00;
        
    end


endmodule
