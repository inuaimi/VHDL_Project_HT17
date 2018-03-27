LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;

entity lcd_controller is
	port (

		CLK_50 			: in 		std_logic;
		reset_n 			: in 		std_logic; 
		disp_data 		: inout 	std_logic_vector(7 downto 0); 
		disp_E 			: out 	std_logic; 
		disp_RS 			: out 	std_logic; 
		disp_RW 			: out 	std_logic;
		update 			: in 		std_logic; 
		ready 			: out 	std_logic; 
		ascii_char 		: in 		std_logic_vector(7 downto 0); 
		changeLine 		: in 		std_logic; 
		clean_screen 	: in 		std_logic; 
		lcd_cleared 	: out 	std_logic

	);
end lcd_controller;


architecture lcd_controller_arc of lcd_controller is

	TYPE FSM IS(powerOn,
		functionSet,
		displayOff,
		displayClear,
		entryModeSet,
		homeCommand,
		displayOn, 
		idle, -- ready to do a task
		send,
		nextline);
	
	constant c_cnt_1ms_max 		: integer := 50000-1; 	--50mhz clock => 1ms = 50000 cycles
	constant c_cnt_2ms_max 		: integer := 100000-1; 	--50mhz clock => 2ms = 100000 cycles
	constant c_cnt_700us_max 	: integer := 35000-1; 	--50mhz clock => 700us = 35000 cycles
	constant c_20_cycles 		: integer :=20-1; 
	constant c_4_cycles 			: integer := 4-1; 
	
	signal current_state 		: FSM;
	
	
	signal cnt_1ms 				: std_logic; 
	signal cnt_2ms 				: std_logic; 
	signal cnt_700us 				: std_logic;

	

	

	signal counter_1ms 			: integer range 0 to c_cnt_1ms_max;
	signal counter_2ms 			: integer range 0 to c_cnt_2ms_max; 
	signal counter_700us 		: integer range 0 to c_cnt_700us_max;



	
	
	
	signal reset_cnt 				: std_logic; -- used to reset delay counters 
	signal init 					: std_logic; -- init is used to be able to reuse states like displayclear 









begin


	p_lcd_backend : process(reset_n, CLK_50 )
	begin
		if reset_n = '0' then
			current_state <= powerOn;
			disp_RS <= '0'; 
			disp_RW <= '0';
			disp_data <= x"00"; 
			disp_E <= '0'; 
			reset_cnt <= '1'; 
			
		elsif rising_edge(CLK_50) then
			
			case (current_state) is
				when powerOn =>
				
					ready <= '0'; 
					init <= '1'; 
					reset_cnt <= '0'; 

					if cnt_2ms = '1' then  -- wait for power stabilization >2ms 
						current_state <= functionSet;
						reset_cnt <= '1'; 
					end if;


				when functionSet =>
				
						disp_RS <= '0'; 
						disp_RW <= '0';
						disp_data <= x"38"; 
						reset_cnt <= '0'; 
						
						if cnt_700us = '1' then
							current_state <= displayOff; 
							reset_cnt <= '1'; 
						end if;

						if c_4_cycles < counter_700us and counter_700us < c_20_cycles then 
							disp_E <= '1'; 

						else
							disp_E <= '0'; 

						end if; 

						
				when displayOff =>
				
						disp_RS <= '0'; 
						disp_RW <= '0';
						disp_data <= x"08"; 
						reset_cnt <= '0'; 
						
						if cnt_700us = '1' then 
							current_state <= displayClear; 
							reset_cnt <= '1'; 

						end if; 



						if c_4_cycles < counter_700us and counter_700us < c_20_cycles then 
							disp_E <= '1'; 

						else
							disp_E <= '0'; 
						end if; 


				when displayClear => 
				
						disp_RS <= '0'; 
						disp_RW <= '0';
						disp_data <= x"01"; 
						reset_cnt <= '0'; 

						if cnt_2ms = '1' then 
						
								if init = '1' then
									current_state <= entryModeSet; 
								else 
									current_state <= homecommand; 
								end if; 
						
							reset_cnt <= '1'; 
						end if;

						if c_4_cycles < counter_2ms and counter_2ms < c_20_cycles then 
							disp_E <= '1'; 

						else
							disp_E <= '0'; 

						end if; 

	

				when entryModeSet =>
				
						disp_RS <= '0'; 
						disp_RW <= '0';
						disp_data <= x"06"; 
						reset_cnt <= '0'; 

						if cnt_700us = '1' then
							current_state <= homeCommand; 
							reset_cnt <= '1'; 
						end if;


						if c_4_cycles < counter_700us and counter_700us < c_20_cycles then 
							disp_E <= '1'; 

						else
							disp_E <= '0'; 

						end if; 

	
				when homeCommand =>
				
						disp_RS <= '0'; 
						disp_RW <= '0';
						disp_data <= x"02";
						reset_cnt <= '0'; 

						if cnt_700us = '1' then 
								
								if init = '1' then
									current_state <= displayOn; 
								else 
									current_state <= idle;
									lcd_cleared <= '1'; 
								end if; 
								
								reset_cnt <= '1'; 

						end if; 


						if c_4_cycles < counter_700us and counter_700us < c_20_cycles then 
							disp_E <= '1'; 

						else
							disp_E <= '0'; 

						end if; 




				when displayOn =>
				
						disp_RS <= '0'; 
						disp_RW <= '0';
						disp_data <= x"0C";
						reset_cnt <= '0'; 

						if cnt_700us = '1' then
							current_state <= idle;
							reset_cnt <= '1';

						end if;
						
						
						if c_4_cycles < counter_700us and counter_700us < c_20_cycles then 
							disp_E <= '1'; 

						else
							disp_E <= '0'; 

						end if; 

					 
				when idle =>
				
						disp_E <= '0';
						ready <= '1';
						disp_RW <= '0'; 
						disp_RS <= '1';
						init <= '0';
						lcd_cleared <= '0'; 
						disp_data <= x"00"; 


						if update = '1' then
							current_state <= send; 
							reset_cnt <= '1';
							ready <= '0';
						elsif clean_screen = '1' then 
							current_state <= homeCommand; 
							reset_cnt <= '1';
							ready <= '0';
						end if;
				
				when send =>
				
						disp_RW <= '0'; 
						disp_RS <= '1';
						disp_data <= ascii_char;
						reset_cnt <= '0';


						if cnt_700us = '1' then
							if changeLine = '1' then 
								current_state <= nextline;
								disp_RS <= '1';
								reset_cnt <= '1';
								ready <= '0';
							else 
									current_state <= idle;
									disp_RS <= '1'; 
									reset_cnt <= '1'; 
							end if;
		
						end if;
						
						
						if c_4_cycles < counter_700us and counter_700us < c_20_cycles then 
								disp_E <= '1'; 
						else
								disp_E <= '0'; 

						end if;
						
				when nextline =>

					disp_RW <= '0';
					disp_data <= x"C0";
					reset_cnt <= '0'; 

					if cnt_700us = '1' then
						current_state <= idle;
						reset_cnt <= '1';
						disp_E <= '0'; 


					end if;
					
					if  5 < counter_700us and counter_700us < 25 then 
						
						disp_RS <= '0'; 
						disp_E <= '1';
					else 
						disp_RS <= '1'; 
						disp_E <= '0';
					end if; 
			end case;

		end if; -- end if rising_edge(clk)
		
	end process p_lcd_backend; 


	

	p_cnt : process(CLK_50, reset_n )

		begin

			if reset_n = '0' then 
				counter_700us <= 0; 
				counter_1ms <= 0;
				counter_2ms <= 0; 

			
			elsif rising_edge(CLK_50) then
			
				
				if reset_cnt = '1' then 
					counter_700us <= 0; 
					counter_1ms <= 0;
					counter_2ms <= 0;
					
				else

					-- 700us delay

					if counter_700us < c_cnt_700us_max then
						counter_700us <= counter_700us + 1;
						cnt_700us <= '0'; 
					else
						counter_700us <= 0; 
						cnt_700us <= '1'; 
					end if;

					-- 1ms delay

					if counter_1ms < c_cnt_1ms_max then
						counter_1ms <= counter_1ms + 1; 
						cnt_1ms <= '0'; 
					else
						counter_1ms <= 0; 
						cnt_1ms <= '1'; 
					end if;

					-- 2ms delay 

					if counter_2ms < c_cnt_2ms_max then 
						counter_2ms <= counter_2ms + 1;
						cnt_2ms <= '0'; 

					else
						counter_2ms <= 0; 
						cnt_2ms <= '1'; 
					end if;
									
				end if; 

				
			end if;

		
	end process ; -- p_cnt

end lcd_controller_arc;