`timescale 1ns/1ns
module cam_tbnewdata;
    //Input
    reg clk;
    reg rst;
    reg [1:0]cmd;
	reg [7:0]datain;//physical address
	reg [7:0]key;//pte+pt+pid=8bits
	reg datavalid;
    //Output
    wire [7:0]dataout;
	wire outvalid;
	wire outrdy;
	wire pagefault;
	//file read
	reg [7:0]data[0:41];//42 items, each has 8 bits
	reg[10:0] readcnt;
	reg[10:0] dvcnt;
	reg [4:0]keycnt;
	reg [3:0]PID;
    //Instantiate cam
    cam dut(
        .clk(clk),
        .rst(rst),
        .datain(datain),
        .key(key),
        .cmd(cmd),
        .dataout(dataout),
        .outvalid(outvalid),
        .pagefault(pagefault),
        .outrdy(outrdy)
    );
    
	initial begin 
		clk = 0;
		readcnt<=0;
		datavalid<=0;
		datain<=0;
		key<=0;
		cmd<=2'b00;
		rst<=1;
		dvcnt<=0;
		keycnt<=0;
		PID<=4'b0100;
		$readmemh("camdata.txt",data);
		forever begin		
		#1 rst<=0; clk = ~clk;
		end
	end
    always @(posedge clk)
    begin		
		//write data to cam 		
		if(readcnt<32)
		begin
		    if(outrdy==1)
		    begin
	            readcnt<=readcnt+1;
	            datain<=data[readcnt];
	            key<= {keycnt[3:0],PID};
	            cmd <=2'b01;
	            keycnt<=keycnt+1;
	            if(keycnt<15)
                PID<=4'b0100;
                else
                PID<=4'b0011;	
            end
        end
		
	    //read data from cam
        if(readcnt==32)
        begin
		    if(outrdy==1)
		    begin
		    cmd <=2'b11;
		    key<={4'b1010,4'b0100};
		    readcnt<=readcnt+1;
            end        
        end
        if(readcnt==33)
        begin
        //polling
            if(outvalid==1||pagefault==1)
            begin
                readcnt<=readcnt+1;
            end
        end
        
        //read page fault test
        if(readcnt==34)
        begin
		    if(outrdy==1 )
		    begin
		    cmd <=2'b11;
		    key<={4'b1010,4'b0000};
		    readcnt<=readcnt+1;
            end
        end
        if(readcnt==35)
        begin//polling
            if(outvalid==1||pagefault==1)
            begin
                readcnt<=readcnt+1;
                cmd<=2'b00;
            end   
        end         
        
        //delet data from cam
        if(readcnt==36)
        begin
		    if(outrdy==1 && outvalid==0 && pagefault==0)
		    begin
		    cmd <=2'b10;
		    key<={4'b1010,4'b0100};
		    readcnt<=readcnt+1;
            end 
        end

	    //read deleted data from cam, expected page fault
        if(readcnt==37)
        begin
		    if(outrdy==1)
		    begin
		    cmd <=2'b11;
		    key<={4'b1010,4'b0100};
		    readcnt<=readcnt+1;
            end        
        end
        if(readcnt==33)
        begin
        //polling
            if(outvalid==1||pagefault==1)
            begin
                readcnt<=readcnt+1;
            end
        end

    end

endmodule
