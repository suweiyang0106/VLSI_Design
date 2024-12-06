`timescale 1ns/1ns

module flash_tb();

reg rst, clk;
//reg addr0, addr1, addr2, addr3, addr4, addr5, addr6, addr7;
reg [7:0] addr;
reg [2:0] pid;
reg read_enable, write_enable, erase;
reg [7:0] data_in;

//wire data_out0, data_out1, data_out2, data_out3, data_out4, data_out5, data_out6, data_out7;
wire [7:0] data_out;
wire out_ready, readwrite_valid, erase_done, error;


mem_array dut (

	.clk(clk),
	.rst(rst),
	.addr(addr),
	.data_in(data_in), 
	.pid(pid),
	.read_enable(read_enable),
	.write_enable(write_enable),
	.erase(erase),
	.data_out(data_out), 
	.out_ready(out_ready),
	.readwrite_valid(readwrite_valid),
	.erase_done(erase_done),
	.error(error),
	.busy_flash(busy_flash)

	);

always begin
	clk = 1'b0;
	forever #1 clk = ~clk;
	
end

initial begin
	rst = 1'b1;
	#2
	rst = 1'b0;
end




initial begin

	#4
	//addr = 8'b01010101;
	addr = 85;
	pid = 3'b011;
	read_enable = 1;
	wait(out_ready);
	read_enable = 0;
	#5

	addr = 8'b11110010;
	pid = 1;
	read_enable = 1;
	wait(out_ready);
	read_enable = 0;
	#5

	addr = 8'b00011011;
	pid = 0;
	erase = 1;
	wait(erase_done);
	erase = 0;
	#5
	
	addr = 8'b10000010;
	pid = 2;
	erase = 1;
	wait(erase_done);
	erase = 0;
	#5
	
	addr = 8'b00000100;
	pid = 4;
	data_in = 8'b00011000;
	write_enable = 1;
	wait(readwrite_valid);
	write_enable = 0;
	#5

	addr = 8'b10101000;
	pid = 3;
	data_in = 8'b11100111;
	write_enable = 1;
	wait(readwrite_valid);
	write_enable = 0;
	#5

	addr = 300;
	pid = 5;
	data_in = 20;
	write_enable = 1;
	wait(error);
	write_enable = 0;
	#5

	addr = 8'b11111111;
	pid = 2;
	data_in = 8'b10100101;
	write_enable = 1;
	wait(readwrite_valid);
	write_enable = 0;
	#5

	read_enable = 1;
	wait(out_ready);
	read_enable = 0;
	#5

$stop;
end

endmodule
