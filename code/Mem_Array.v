module mem_array(
	
	input clk,
	input rst,
	input [7:0] addr,
	input [7:0] data_in,
	input [3:0] pid,
	input read_enable,
	input write_enable,
	input erase,
	output reg [7:0] data_out,
	output reg out_ready,
	output reg readwrite_valid,
	output reg erase_done,
	output reg error,
	output reg busy_flash
);

parameter PAGE_SZ = 16;			//16-byte pages
parameter PAGE_CNT = 80;		//For up to 5 processes

parameter IDLE = 3'b000;
parameter READ = 3'b001;
parameter WRITE = 3'b010;
parameter ERASE = 3'b011;
parameter VALID = 3'b100;
parameter ERROR = 3'b101;


reg [7:0] mem_array[0:((PAGE_CNT)*(PAGE_SZ)-1)];	//105x16-byte memory array, with 8 levels (bits) each index.
reg [0:((PAGE_CNT)*(PAGE_SZ)-1)] mem_full;
reg [2:0] flash_state;
reg [7:0] address = 8'b0;
reg [3:0] pid_addr = 3'b000;
reg data_stored = 8'b00000000;
reg pip;
reg read_once, write_once, erase_once;


initial begin
	
	$readmemb("C:/Users/suwei/Desktop/VLSIProject/incrementing_binary_numbers.txt", mem_array);
	mem_full = '1;
end

always @ (posedge read_enable, posedge write_enable, posedge erase) begin
	
	//address <= 8'b00000000;
	pid_addr <= 3'b000;

	address <= addr;
	pid_addr <= pid[2:0];

end

always @ (negedge read_enable, negedge write_enable, negedge erase, posedge error) begin

	if (!read_enable) begin
		read_once <= 0;
		out_ready <= 0;
		busy_flash <= 0;
	end
	if (!write_enable) begin
		write_once <= 0;
		readwrite_valid <= 0;
		busy_flash <= 0;
	end
	if (!erase) begin
		erase_once <= 0;
		erase_done <= 0;
		busy_flash <= 0;
	end
	error <= 0;

end

always @ (posedge rst) begin

	address <= 8'b00000000;
	pid_addr <= 3'b000;
	
	data_stored <= 8'b00000000;
	readwrite_valid <= 0;
	out_ready <= 0;
	erase_done <= 0;
	pip <= 0;
	busy_flash <= 0;
	read_once <= 0;
	write_once <= 0;
	erase_once <= 0;
	error <= 0;
	data_out <= 0;

	flash_state <= IDLE;

end

always @ (posedge clk) begin


	case(flash_state)
		IDLE: begin

			if (read_enable && !pip) begin
				if (!read_once) begin
					flash_state <= READ;
					pip <= 1;
					busy_flash <= 1;
				end
			end
			else if (write_enable && !pip) begin
				if (!write_once) begin
					flash_state <= WRITE;
					pip <= 1;
					busy_flash <= 1;
				end
			end
			else if (erase && !pip) begin
				if (!erase_once) begin
					flash_state <= ERASE;
					pip <= 1;
					busy_flash <= 1;
				end
			end
			if ((address < 0 || address > 255) || (pid_addr > 4)) begin
				flash_state <= ERROR;
				pip <= 1;
			end

		end
		READ: begin
			
			if (mem_full[address + pid_addr*256]) begin
				data_out <= mem_array[address + pid_addr*256];
				out_ready <= 1;
				pip <= 0;
				read_once <= 1;

			end
			else begin
				out_ready <= 0;
			end

			flash_state <= IDLE;

		end
		WRITE: begin

			mem_array[address + pid_addr*256] <= 8'b00000000;
			//mem_array[address + pid_addr*256] <= ((data_in7 << 7) | (data_in6 << 6) | (data_in5 << 5) | (data_in4 << 4) | (data_in3 << 3) | (data_in2 << 2) | (data_in1 << 1) | (data_in0));
			//mem_array[address + pid_addr*256] <= ((data_in[7] << 7) | (data_in[6] << 6) | (data_in[5] << 5) | (data_in[4] << 4) | (data_in[3] << 3) | (data_in[2] << 2) | (data_in[1] << 1) | (data_in[0]));
			mem_array[address + pid_addr*256] <= data_in;
			mem_full[address + pid_addr*256] <= 1;
			readwrite_valid <= 1;
			pip <= 0;
			write_once <= 1;
			flash_state <= IDLE;

		end
		ERASE: begin

			mem_array[address + pid_addr*256] <= 0;
			mem_full[address + pid_addr*256] <= 0;
			flash_state <= IDLE;
			pip <= 0;
			erase_once <= 1;
			erase_done <= 1;

		end
		ERROR: begin

			out_ready <= 0;
			readwrite_valid <= 0;
			erase_done <= 0;
			error <= 1;
			address <= 0;
			pid_addr <= 0;
			pip <= 0;
			busy_flash <= 0;
			flash_state <= IDLE;

		end
		default: begin

			//data_stored <= 8'b00000000;

			pip <= 0;
			busy_flash <= 0;
			read_once <= 0;
			write_once <= 0;
			erase_once <= 0;
			
			out_ready <= 0;
			readwrite_valid <= 0;
			erase_done <= 0;
			error <= 0;
			flash_state <= IDLE;

		end
	endcase
end


endmodule