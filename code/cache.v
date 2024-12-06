module cache(
input clk,
input rst,
input [1:0] cmd,
input datavalid,/*read posedge for datain update*/
input [7:0] datain,
input [3:0]PID,
output pagefault,
output [7:0]dataout,
output outvalid,
output reg wd/*write done*/
);
//commands
parameter [1:0] NOP=2'b00, RD=2'b01, WR=2'b10, LD=2'b11;
//states
parameter [3:0] idle=4'b0000, WPT=4'b0001, WPTE=4'b0010, WPID=4'b0011, Wdone=4'b0100, RPID=4'b0101, RPTE=4'b0110, RPT=4'b0111, Rdone=4'b1000, LoadC2C=4'b1001,LoadC2Cbusy=4'b1010, LoadC2cdone=4'b1011;
reg [3:0] state, next_state;
//cache space
reg [7:0] sram [0:20];//21 for proc_a
reg [7:0] sram2 [0:20];//21 for proc_b
reg[4:0] sramidx;
//condition

reg pid, pte, pt;//bit up when it is done
reg rpid, rpte, rpt, rdone;
reg pfsig;
reg loadsig;//load signal
//read buf
reg [7:0] rbuf;

always @(posedge clk, posedge rst)
begin
    if(rst)
    begin
		next_state<=idle;
		state<=idle;
		pid<=0;
		pte<=0;
		pt<=0;
		sramidx<=5'b00000;
		rpid<=0;
		rpte<=0;
		rpt<=0;
		pfsig<=0;
		rbuf<=0;
		wd<=0;
		rdone<=0;
		loadsig<=0;
    end
    else
	    state = next_state;
end

always @(state,pid,pte,pt,pfsig,loadsig, posedge clk, datavalid)
begin
	case(state)
		idle:
		begin
			if(cmd==WR)
				next_state<=WPT;
			else if(cmd==RD)
				next_state<=RPID;
		    else if(cmd==LD)
		        next_state<=LoadC2C;
			else 
			begin
				next_state<=idle;
				state<=idle;
				pid<=0;
				pte<=0;
				pt<=0;
				sramidx<=5'b00000;
				rpid<=0;
				rpte<=0;
				rpt<=0;
				pfsig<=0;
				rbuf<=0;
				wd<=0;
				rdone<=0;
				loadsig<=0;
			end
		end
		WPT:
			if(pt==1)
				next_state=WPTE;
			else
			    begin
			    wd<=1;
				next_state=WPT;
				end
		WPTE:
			if(pte==1)
				next_state<=WPID;
			else
			    begin
			    wd<=1;
				next_state=WPTE;
				end
		WPID:
		begin
			if(pid==1)
				next_state<=Wdone;
			else
			    begin
			    wd<=1;
				next_state<=WPID;
				end
		end
		Wdone:
		begin
			pid<=0;
			pte<=0;
			pt<=0;
			sramidx<=5'b00000;
			next_state<=idle;
		end
		RPID:
		begin
			rpid<=1;
			next_state=RPTE;
		end
		RPTE:
		begin
			if(pfsig==1)
				next_state<=Rdone;
			else
			begin
				rpte<=1;
				next_state=RPT;
			end
		end
		RPT:
		begin
			if(rdone==1)
				next_state<=Rdone;
			else
				begin
				rpt<=1;
				next_state=RPT;
				end
		end
		Rdone:
		begin
		    sramidx<=0;
			next_state<=idle;
	    end
	    LoadC2C:
	    begin
	        if(sramidx==21)
	        begin
	            loadsig<=0;
	            next_state=LoadC2cdone;
	        end
	        else
	        begin
	            loadsig<=1;
	            next_state=LoadC2Cbusy;    
	        end
	    end
	    LoadC2Cbusy:
	    begin
	        loadsig<=0;
	        next_state=LoadC2C;
	    end
	    LoadC2cdone:
	    begin
	        sramidx<=0;
	        next_state=idle;
	    end
		default:;
	endcase
end
//write PT
always@(posedge datavalid)
begin
	if(PID[0]==0 && state==WPT && cmd==WR && sramidx<5'b10000)
	begin
		sram[sramidx] <= datain;
		sramidx <= sramidx+1;
		wd<=0;
	end
	else if(PID[0]==1 && state==WPT && cmd==WR && sramidx<5'b10000)
	begin
		sram2[sramidx] <= datain;
		sramidx <= sramidx+1;
		wd<=0;
	end
	else
		pt<=0;
	if(sramidx == 5'b01111 && cmd==WR)
		pt<=1;
	else
		pt<=0;	
end
//write PTE
always@(posedge datavalid)
begin
	if(PID[0]==0 && state==WPTE && cmd==WR && sramidx<5'b10100)
	begin	
		sram[sramidx] <= (sramidx-16)<<2;//datain;
		sramidx <= sramidx+1;
		wd<=0;
	end
	else if(PID[0]==1 && state==WPTE && cmd==WR && sramidx<5'b10100)
	begin
		sram2[sramidx] <= (sramidx-16)<<2;//datain;
		sramidx <= sramidx+1;
		wd<=0;
	end
	else
		pte<=0;
	if(sramidx == 5'b10011 && cmd==WR)
		pte<=1;
	else
		pte<=0;
end
//write PID
always@(posedge datavalid)
begin
	if(PID[0]==0 && state==WPID && cmd==WR && (sramidx < 5'b10101))
	begin
		sram[sramidx] <= datain;//{8'h00, PID};
		sramidx <= sramidx+1;
		pid<=1;
		wd<=0;
	end
	else if(PID[0]==1 && state==WPID && cmd==WR && sramidx < 5'b10101)
	begin
		sram2[sramidx] <= datain;//{8'h00, PID};
		sramidx <= sramidx+1;
		pid<=1;
		wd<=0;
	end
	else
		pid<=0;
end

//read PID
always@(posedge rpid)
begin
	if(state == RPID && rpid)
	begin
		if(PID[0]==0 && {8'h00,PID} == sram[20])
		begin
			sramidx <= sramidx +1;
		end
		else if(PID[0]==1  && {8'h00,PID} == sram2[20])
		begin
			sramidx <= sramidx +1;
		end
		else
			pfsig<=1;
	end
	else
	    rpid<=0;
end
//read PTE
always@(posedge rpte)
begin
	if(state == RPTE && rpte)
	begin
		if(PID[0]==0)
			rbuf<=sram[16 + datain[7:6]];
		else
			rbuf<=sram2[16 + datain[7:6]];
	end
	else
		rpte<=0;
end
//read PT
always@(posedge rpt)
begin
	if(state==RPT && rpt)
	begin
		if(PID[0]==0)
			rbuf<=sram[rbuf+datain[5:4]];			
		else
			rbuf<=sram2[rbuf+datain[5:4]];
			rdone<=1;
	end
	else
		rpt<=0;
end

//load cache content
always@(posedge loadsig)
begin
    if(state==LoadC2C && loadsig)
    begin
        if(PID[0]==0)
            rbuf <= sram[sramidx];
        else
            rbuf <= sram2[sramidx];
        sramidx <= sramidx+1;
    end
end

//output
assign pagefault = ((cmd==RD) && (state==Rdone && pfsig==1));
assign outvalid = ((cmd==RD) && state==Rdone && rdone)||(cmd==LD && loadsig==1);
assign dataout = (((cmd==RD)&&(rdone==1))||(cmd==LD && loadsig==1))?rbuf:0;


endmodule
