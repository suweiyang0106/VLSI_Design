module c2cmodule(
input clk,
input rst,
input [1:0]cmd,/*NOP/ write cache/ load c2c/ translate*/
input [7:0]datain,
input datavalid,
input [3:0]PID,
output [7:0]dataout,
output busy,
output outvalid,
output pagefault,
output reg wd
);
//buffering input data
reg [7:0] buffer[0:20];
reg wtbuf_done;
reg [4:0]wtbufcnt;//need 21 elements overall
//c2cmodule cmd
parameter [1:0] NOP=2'b00, WC=2'b01/*write cache*/, LC2C=2'b10/*laod c2c*/, TL=2'b11/*translate*/;
//state
parameter [3:0] idle=4'b0000, loadbuf=4'b0001, wt_cache=4'b0010, wt_done=4'b0011, loadc2buf =4'b0100, loadc2c=4'b0101, loadc2c_done=4'b0110, translate_cam=4'b0111, translate_cache=4'b1000, translate_done=4'b1001;
reg [3:0] state, next_state;

//cache cmd
parameter [1:0] RD=2'b01, WR=2'b10, LD=2'b11;
reg [1:0] cachecmd;//NOP:2'b00, RD:2'b01, WR:2'b10, LD:2'b11
reg cdatavalid;
reg [7:0]cdatain;
reg [3:0]cPID;
wire cpagefault;
wire [7:0]cdataout;
wire coutvalid;
wire cwd;//cache write done
reg cacherdfail;//cache read fail
reg cacherd;//cache read done
//Instantiate cache
cache dut(
	.clk(clk),
	.rst(rst),
	.cmd(cachecmd),
	.datavalid(cdatavalid),
	.datain(cdatain),
	.PID(cPID),
	.pagefault(cpagefault),
	.dataout(cdataout),
	.outvalid(coutvalid),
	.wd(cwd)
);
//cam cmd
reg[1:0] camcmd;
parameter [1:0] camWR=2'b01, camRD=2'b11;
reg[7:0] camdatain;
reg[7:0] camkey;
wire[7:0] camdataout;
wire camoutvalid;
wire campagefault;
wire camoutrdy;
reg camrd;
reg camrdfail;
//Instantiate cam
cam dut2(
    .clk(clk),
    .rst(rst),
    .datain(camdatain),
    .key(camkey),
    .cmd(camcmd),
    .dataout(camdataout),
    .outvalid(camoutvalid),
    .pagefault(campagefault),
    .outrdy(camoutrdy)
);

//update state
always @(posedge clk, posedge rst)
begin
    if(rst)
    begin
        state<=idle;
        next_state<=idle;
        wtbuf_done<=0;
        wtbufcnt<=0;
        wd<=1;
        cachecmd<=NOP;
        camcmd<=NOP;
        cdatavalid<=0;
        camrd<=0;
        camrdfail<=0;
        cacherd<=0;
        cacherdfail<=0;
    end
    else
        state<=next_state;
end

//State machine
always @ (posedge clk, cmd)
begin
    case(state)
        idle:
            if(cmd==WC)
                begin
                    wd<=0;
                    next_state<=loadbuf;
                end
            else if(cmd==LC2C)
                next_state<=loadc2buf;
            else if(cmd==TL)
                next_state<=translate_cam;
            else
                begin
                wtbuf_done<=0;
                wtbufcnt<=0;
                wd<=1;
                cachecmd<=NOP;
                camcmd<=NOP;
                buffer[0]<={8'b00000000};//for regonize
                buffer[1]<={8'b00000000};//for regonize
                camrd<=0;
                camrdfail<=0;
                cacherd<=0;
                cacherdfail<=0;
                end
        loadbuf:
            begin
            if(wtbufcnt==21)
            begin
                next_state<=wt_cache;
                wtbufcnt<=0;
            end
            else
            begin
                wd<=1;
            end
            end
        wt_cache:
            if(wtbufcnt==21)
            begin    
                next_state<=wt_done;                 
                cdatavalid<=0;
                cachecmd<=NOP;
            end
            else
            begin
                cachecmd<=WR;
                cPID<=PID;
                cdatain<=buffer[wtbufcnt];
                if(cwd==1)
                begin
                    wd<=~wd;
                    cdatavalid<=~cdatavalid;
                end
                else
                    cdatavalid<=0;
            end
        wt_done:
            begin
            wtbufcnt<=0;
            next_state<=idle;
            end
        loadc2buf:
        begin
            //load data to buf    
            if(wtbufcnt==21)
            begin
                cachecmd<=NOP;
                next_state<=loadc2c;
            end
            else
            begin
                cachecmd<=LD;    
                cPID<=PID;  
            end            
            
        end
        loadc2c:
        //load buf to cam
        begin
            if(wtbufcnt==16)
            begin
                camcmd<=NOP;
                next_state<=loadc2c_done;
            end
            else
            begin
                next_state<=loadc2c;
            end
        end
        loadc2c_done:
        begin
            wtbufcnt<=0;
            next_state<= idle;
        end
        translate_cam:
        begin
            if(camrd==1)
            begin
                camcmd<=NOP;
                next_state=translate_done;
            end
            else if(campagefault==1|| camrdfail==1)//else if(camrdfail==1)
            begin
                camcmd<=NOP;
                next_state<=translate_cache;
            end
            else
            begin
                camcmd<=camRD;
                camkey<=datain;
                next_state<=translate_cam;
            end
        end
        translate_cache:
        begin
            if(cacherdfail==1||cacherd==1)
            begin
                cachecmd<=NOP;
                next_state<=translate_done;
            end
            else
            begin
                cachecmd<=RD;
                cdatain<=datain;//{datain[7:4],4'b0100};
                cPID<=PID;//4'b0100;
                next_state<=translate_cache;
            end
        end
        translate_done:
        begin
            camrd<=0;
            camrdfail<=0;
            cacherd<=0;
            cacherdfail<=0;
            next_state<=idle;
        end
    endcase
    
end
//load datain to buffer
always@(posedge datavalid)
begin
    if(state==loadbuf && cmd == WC && wtbufcnt<21)
    begin
        buffer[wtbufcnt]<=datain;
        wtbufcnt<=wtbufcnt+1;
        wd<=0;
    end
    else
        wtbufcnt<=0;    
end

//write  buffer to cache
always@(posedge cdatavalid && state == wt_cache)
begin
    if(state == wt_cache && cwd==1 && cachecmd==WR && wtbufcnt<21)
    begin
        cdatain<=buffer[wtbufcnt];
        cPID<=PID;
        wtbufcnt<=wtbufcnt+1;
        if(wtbufcnt==20)
            cachecmd<=NOP;
        else
            cachecmd<=WR;
   end
   else
   begin
        cachecmd<=NOP;
        wtbufcnt<=0;
   end
end

//write from cache to buf

always@(posedge coutvalid && state == loadc2buf)
begin
    if(state == loadc2buf && wtbufcnt<21)
    begin
        buffer[wtbufcnt-1]<=cdataout;
        cPID<=PID;
        wtbufcnt<=wtbufcnt+1;
    end
    else
        wtbufcnt<=0;
end
//write buf to cam
always@(posedge clk && state == loadc2c )
begin
    if(wtbufcnt<16)
    begin
        camcmd<=camWR;
        camdatain<=buffer[wtbufcnt];
        camkey<={wtbufcnt[3:0],PID};
        wtbufcnt<=wtbufcnt+1;
    end
    else if(wtbufcnt==16)
    begin
        camcmd<=NOP;
    end
    else
        begin
        camcmd<=NOP;
        wtbufcnt<=0;
        end
end
//read pa from cam
always@(negedge camoutvalid  && state ==translate_cam)
begin
        camcmd<=NOP;
        camrd<=1;
end
always@(negedge campagefault  && state ==translate_cam)
begin
        camcmd<=NOP;
        camrdfail<=1;
end
//read pa from cache
always@(posedge coutvalid && state == translate_cache)
begin        
        //cachecmd<=NOP;
        buffer[0]<=cdataout;
        cacherd<=1;
end
always@(negedge cpagefault && state == translate_cache)
begin
        cachecmd<=NOP;
        cacherdfail<=1;
end


assign busy = (state!=idle)&&(state!=loadc2c_done)&&(state!=translate_done);
assign outvalid = camoutvalid||cacherd;
assign dataout = (camoutvalid==1)? camdataout: ((cacherd==1)?buffer[0]:0);//dataout from cam/cache/0;
assign pagefault = cacherdfail;//campagefault;
endmodule
