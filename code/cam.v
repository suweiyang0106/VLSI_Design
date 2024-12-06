module cam(
input clk,
input rst,
input [7:0] datain,/*physical addr*/
input [7:0] key,/*virtual addr*/
input [1:0] cmd,
output [7:0] dataout,
output outvalid,/*for output valid data*/
output pagefault,
output outrdy/*for input valid data, when ==1, u can send data in now*/
);
reg [7:0] storage_data[31:0];
reg [7:0] storage_key[31:0];
reg [31:0] storage_full;//location empty status
reg [31:0] midx, eidx;
reg mmatch, ematch;
//cmd
parameter[1:0] NOP=2'b00, INS=2'b01, DEL=2'b10, RD=2'b11;
//state
parameter[2:0] idle=3'b000, write=3'b001, read=3'b010, delete=3'b011, done=3'b100;
reg[1:0] state, next_state;
//WR signal
reg wd, rd;//write done and read done signals
//FSM
integer rstidx;
always@(posedge clk, posedge rst)
begin
    if(rst)
    begin
        for(rstidx=0;rstidx<32;rstidx= rstidx+ 1) begin 
        storage_data[rstidx]<=11'h00; storage_key[rstidx]<=8'h00; 
        end
        storage_full<=0;
        wd<=0;
        rd<=0;   
        state<=idle;
        next_state<=idle;   
    end
    else
        state = next_state;
end

always@(posedge clk, cmd, key)
begin
    case(state)
        idle:
        begin
            if(cmd==INS)
            begin
                next_state<=write;
            end
            else if(cmd==RD)
            begin
                next_state<=read;
            end
            else if(cmd==DEL)
                next_state<=delete;
            else
            begin
                wd<=0;
                rd<=0;
                next_state<=idle;
            end
        end
        write:
            if(wd==1)
                next_state<=done;
            else
                next_state<=write;
        read:
            if(rd==1)
                next_state<=done;
            else
                begin
                rd<=1;
                next_state<=read;
                end
        delete:
            if(wd==1)
                next_state<=done;
            else
                next_state<=delete;
        done:
            begin
            next_state<=idle;
            wd<=0;
            rd<=0;
            end
        default:
            next_state<=idle;
    endcase
end

//Find matching key
integer i;//for finding match idx
always @(*) begin
	mmatch <= 0;//not match
	midx <= 0;//match idx
	for(i=0; i<32; i=i+1)	begin
		if(storage_full[i] && storage_key[i]==key) begin 
			mmatch<=1; 
			midx<=i ;
		end	else begin
		//	mmatch <= 0;//not match
		//	midx <= 0;//match idx
		end
	end
end

//Find empty location
integer e;//for finding empyt idx
always @(*)
begin
	ematch=0;//default 0
	eidx=0;//defualt 0
	for(e=0;e<32;e=e+1)
		if(!storage_full[e])begin
		ematch=1;eidx=e;
		end else begin
		//ematch=0;eidx=0;
		end
end

//Insert or delete items
always @(posedge clk)
begin
	case(cmd)
		INS:
			if(ematch && !mmatch) begin
				storage_full[eidx]<=1;
				storage_data[eidx]<=datain;
				storage_key[eidx]<=key;
				wd<=1;
			end else if(mmatch) begin
				storage_data[midx]<= datain;
			end
		DEL:
			if(mmatch ==1) storage_full[midx]<=0;
			else storage_full[midx] <= storage_full[midx];
		default:;
	endcase
end

assign dataout = (state==read && cmd==RD && mmatch)?storage_data[midx]:0;
assign outvalid =
		(state==read && cmd == RD  && mmatch ) ;
		//||(cmd == INS && ( mmatch || ematch ));
assign pagefault = (cmd == RD && !mmatch );
assign outrdy = (state==idle);

endmodule
