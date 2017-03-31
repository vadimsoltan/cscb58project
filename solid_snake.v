module solid_snake(initialize, master_clk, keyboard_clk, data, dac_clk, vga_r, vga_g, vga_b, vga_h_sync, vga_v_sync, empty, HEX0, HEX1);
	
	input master_clk, keyboard_clk, data;
	output reg [7:0]vga_r, vga_g, vga_b;
	output vga_h_sync, vga_v_sync, dac_clk, empty;
	output [6:0] HEX0, HEX1;
	
	// wires for us to store the random location created by the random generator
	wire [9:0]randomXlocation;
	wire [8:0]randomYlocation;
	
	// wire for us to sync all of the processes on the same clock
	wire vga_clk;
	
	// wries to traverse the screen
	wire [9:0] xPixel;
	wire [9:0] yPixel;

	// wires to assign RGB
	wire R;
	wire G;
	wire B;

	// get the direction from keyboard into a wire
	wire [4:0] snake_direction;

	reg wall, death, feed, end_game;

	// registers for us to store snack coordinates
	reg [9:0] snackX;
	reg [8:0] snackY;

	reg snackLocationX, snackLocationY, snack;

	integer snackCount, bodyCounter, bodyCounter1, snakeResetCounter;
	
	// register for us to keep track of the snake's size
	reg [6:0] snake_size;

	// registers for us to keep track of the snakes bodys location
	// (should use arrays)
	reg [9:0] snakeXarr[0:127];
	reg [8:0] snakeYarr[0:127];

	reg head;
	reg body;
	wire update_kb, initialize;
	
	wire bad, good;
	wire onWall;

	reg found;

	wire display_area;

	hex_decoder hex1(snake_size[3:0], HEX0);
	hex_decoder hex2(snake_size[6:4], HEX1);
	
	clock_adapter adapter1(master_clk, vga_clk);

	vga_adapter adapter2(vga_clk, xPixel, yPixel, display_area, vga_h_sync, vga_v_sync, empty);

	random_generator rand1(vga_clk, randomXlocation, randomYlocation);

	keyboard_input input1(keyboard_clk, data, snake_direction, initialize);

	input_updater up1(master_clk, update_kb);

	assign dac_clk = vga_clk;

	assign onWall = (randomXlocation<10) || (randomXlocation>630) || (randomYlocation<10) || (randomYlocation>470);


	// 1. GENERATE THE WALLS FIRST
	always @(posedge vga_clk)
	begin
		wall <= (((xPixel >= 0) && (xPixel < 11) || (xPixel >= 630) && (xPixel < 641)) || ((yPixel >= 0) && (yPixel < 11) || (yPixel >= 470) && (yPixel < 481)));
	end
	
	// 2. GENERATE THE SNACK COORDINATES
	always @(posedge vga_clk)
	begin
	snackCount = snackCount + 1;
		if(snackCount == 1)
		begin
			snackX <= 50;
			snackY <= 50;
		end
		else
		begin	
			if(feed)
			begin
				if(onWall)
				begin
					snackX <= 69;
					snackY <= 59;
				end
				else
				begin
					snackX <= randomXlocation;
					snackY <= randomYlocation;
				end
			end
			else if(~initialize)
			begin
				if((onWall)
				begin
					snackX <=200;
					snackY <=350;
				end
				else
				begin
					snackX <= randomXlocation;
					snackY <= randomYlocation;
				end
			end
		end
	end
	
	// 2.1 GENERATE THE SNACK AT THE COORDINATES
	always @(posedge vga_clk)
	begin
		snackLocationX <= (xPixel > snackX && xPixel < (snackX + 10));
		snackLocationY <= (yPixel > snackY && yPixel < (snackY + 10));
		snack = snackLocationX && snackLocationY;
	end
	
	// 3. GENERATE THE PLAYER MOVEMENTS
	always@(posedge update_kb)
	begin
	if(initialize)
	begin
		for(bodyCounter = 127; bodyCounter > 0; bodyCounter = bodyCounter - 1)
			begin
				if(bodyCounter <= snake_size - 1)
				begin
					snakeXarr[bodyCounter] = snakeXarr[bodyCounter - 1];
					snakeYarr[bodyCounter] = snakeYarr[bodyCounter - 1];
				end
			end
		case(snake_direction)
			5'b00010: snakeYarr[0] <= (snakeYarr[0] - 10);
			5'b00100: snakeXarr[0] <= (snakeXarr[0] - 10);
			5'b01000: snakeYarr[0] <= (snakeYarr[0] + 10);
			5'b10000: snakeXarr[0] <= (snakeXarr[0] + 10);
			endcase	
		end
	else if(~initialize)
	begin
		for(snakeResetCounter = 1; snakeResetCounter < 128; snakeResetCounter = snakeResetCounter + 1)
		begin
		snakeXarr[snakeResetCounter] = 1000;
		snakeYarr[snakeResetCounter] = 1000;
		end
	end
	
	end
	
	// 4. GENERATE THE BODY	
	always@(posedge vga_clk)
	begin
		found = 0;
		
		for(bodyCounter1 = 1; bodyCounter1 < snake_size; bodyCounter1 = bodyCounter1 + 1)
		begin
			if(~found)
			begin				
				body = ((xPixel > snakeXarr[bodyCounter1] && xPixel < snakeXarr[bodyCounter1]+10) && (yPixel > snakeYarr[bodyCounter1] && yPixel < snakeYarr[bodyCounter1]+10));
				found = body;
			end
		end
	end


	// 5. GENERATE THE HEAD
	always@(posedge vga_clk)
	begin	
		head = (xPixel > snakeXarr[0] && xPixel < (snakeXarr[0]+10)) && (yPixel > snakeYarr[0] && yPixel < (snakeYarr[0]+10));
	end
		
	assign bad = wall || body;
	assign good = snack;
	
	// 6. GENERATE THE FSM
	always @(posedge vga_clk)
		// check if the snake ate the snack 
		if(good && head) 
		begin 
			feed<=1;
			snake_size = snake_size+1;
		end
		else if(~initialize) 
			snake_size = 1;										
		else 
			feed=0;
	
	always @(posedge vga_clk) 
		// check if the snake hit the wall or tried to eat itself
		if(bad && head) 
		
			death<=1;
	
		else 
		
			death=0;
	
	always @(posedge vga_clk) 
		if(death) 
		
			end_game<=1;
	
		else if(~initialize) 
		
			end_game=0; 		
	

	// 7. DISPLAY THE GAME			
	assign R = (display_area && (snack || end_game));
	
	assign G = (display_area && (wall && ~end_game) );

	assign B = (display_area && ((head||body) && ~end_game));

	always@(posedge vga_clk)
	begin
		vga_r = {8{R}};
		vga_g = {8{G}};
		vga_b = {8{B}};
	end 

endmodule

// Switch 50MHz to 25MHz
module clock_adapter(master_clk, vga_clk);

	input master_clk;
	output reg vga_clk;
	reg trans_clk;

	always@(posedge master_clk)
	begin
		trans_clock <= ~trans_clock;
		vga_clk <= trans_clock;
	end
endmodule

module vga_adapter(vga_clk, xPixel, yPixel, display_area, vga_h_sync, vga_v_sync, empty);

	input vga_clk;
	output reg [9:0]xPixel, yPixel; 
	output reg display_area;  
	output vga_h_sync, vga_v_sync, empty;

	reg porch_h_sync, porch_v_sync; 
	
	integer porch_hf = 640;
	integer horizontal_sync = 655;
	integer porch_hb = 747;
	integer maximum_horizontal = 793;

	integer porch_vf = 480;
	integer vertical_sync = 490;
	integer porch_vb = 492; 
	integer maximum_vertical = 525; 

	always@(posedge vga_clk)
	begin
		if(xPixel == maximum_horizontal)
			xPixel <= 0;
		else
			xPixel <= xPixel + 1;
	end

	always@(posedge vga_clk)
	begin
		if(xPixel == maximum_h)
		begin
			if(yPixel == maximum_vertical)
				yPixel <= 0;
			else
			yPixel <= yPixel + 1;
		end
	end
	
	always@(posedge vga_clk)
	begin
		display_area <= ((xPixel < porch_hf) && (yPixel < porch_vf)); 
	end

	always@(posedge vga_clk)
	begin
		porch_h_sync <= ((xPixel >= horizontal_sync) && (xPixel < porch_hb)); 
		porch_v_sync <= ((yPixel >= vertical_sync) && (yPixel < porch_vb)); 
	end
 
	assign vga_v_sync = ~porch_v_syng; 
	assign vga_h_sync = ~porch_h_sync;
	assign empty = display_area;
endmodule		

module random_generator(vga_clk, randomXlocation, randomYlocation);
	input vga_clk;
 	output reg [6:0] randomx;
 	output reg [6:0] randomy;

	always @(posedge vga_clk)
	begin  
	randomx <= ((randomx + 3) % 69) + 1;
	randomy <= ((randomy + 5) % 42) + 1;
	end
endmodule

module keyboard_input(keyboard_clk, input_data, snake_direction, reset);

	input keyboard_clk, input_data;
	output reg [4:0] snake_direction;
	output reg reset = 0; 
	reg [7:0] info;
	reg [10:0]key_info, previous_info;
	integer counter = 0;

always@(negedge keyboard_clk)
	begin
		key_info[counter] = input_data;
		counter = counter + 1;			
		if(counter == 11)
		begin
			if(previous_info == 8'hF0)
			begin
				info <= key_info[8:1];
			end
			previous_info = key_info[8:1];
			counter = 0;
		end
	end
	
	always@(info)
	begin
		if(info == 8'hE075) // up
			snake_direction = 5'b00010;
		else if(info == 8'hE06b) // left
			snake_direction = 5'b00100;
		else if(info == 8'hE072) // down
			snake_direction = 5'b01000;
		else if(info == 8'hE074) // right
			snake_direction = 5'b10000;
		else if(info == 8'h76) // escape
			reset <= ~reset;
		else snake_direction <= snake_direction;
	end	
endmodule

module input_updater(main_clock, refresh);
	input main_clock;
	output reg refresh;
	reg [21:0]counter;	

	always@(posedge main_clock)
	begin
		counter <= counter + 1;
		if(counter == 1777777)
		begin
			refresh <= ~refresh;
			counter <= 0;
		end	
	end
endmodule

module hex_decoder(decimal_digit, segments);
    input [3:0] decimal_digit;
    output reg [6:0] segments;
   
    always @(*)	
        case (decimal_digit)
            4'd0: segments = 7'b100_0000;
            4'd1: segments = 7'b111_1001;
            4'd2: segments = 7'b010_0100;
            4'd3: segments = 7'b011_0000;
            4'd4: segments = 7'b001_1001;
            4'd5: segments = 7'b001_0010;
            4'd6: segments = 7'b000_0010;
            4'd7: segments = 7'b111_1000;
            4'd8: segments = 7'b000_0000;
            4'd9: segments = 7'b001_1000;
            default: segments = 4'd0;
        endcase
endmodule
