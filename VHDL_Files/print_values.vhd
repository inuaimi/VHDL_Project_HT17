LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

entity print_values is
	port (
		clk_50 				: in 	std_logic;
		reset_n 				: in 	std_logic; 
		i_update 			: in 	std_logic; 
		o_update				: out std_logic;
		lcd_r					: in 	std_logic; 
		temp_negativ		: in 	std_logic; 
		temp_bcd 			: in 	std_logic_vector(15 downto 0); 
		rh_bcd 				: in 	std_logic_vector(15 downto 0); 
		print_ascii 		: out std_logic_vector(7 downto 0); 
		nextLine 			: out std_logic; 
		clearLcd 			: out std_logic;
		display_cleared 	: in 	std_logic

	
	);
end print_values;

architecture print_value_arc of print_values is
		
		constant c_cnt_700us_max : integer := 35000-1; --50mhz clock => 700us = 35000 cycles

		TYPE string_array_line1 is array ( 0 to 14 ) of std_logic_vector(7 downto 0);

		TYPE string_array_line2 is array (0 to 8) of std_logic_vector(7 downto 0);

		TYPE FSM is( s_idle, s_clearLcd, s_waitLcdclear, s_firstLine,s_nextline, s_secondLine); 


		signal lcd_string_01       : string_array_line1; 
		signal lcd_string_02       : string_array_line2; 
		
		signal state : FSM; 

		signal print_counter 		: natural range 0 to 20 :=0; 
	  
		signal delay_ena 				: std_logic; 
	



		signal cnt_700us 				: std_logic; 
		signal counter_700us 		: integer range 0 to c_cnt_700us_max :=0; 
 



begin

	 lcd_string_01 <= (x"54", x"45", x"4d", x"50", x"3a", --TEMP:
							x"2d",
							x"3" & temp_bcd(15 downto 12), -- hundreds
							x"3" & temp_bcd(11 downto 8), -- tens 
							x"3" & temp_bcd(7 downto 4), --ones
							x"2e", 
							x"3" & temp_bcd(3 downto 0), -- deci
							x"DF", 
							x"43",
							x"20",
							x"20"); 		


	 	lcd_string_02 <= (x"52", x"48", x"3a", -- RH: 
							x"3" & rh_bcd(11 downto 8), 
							x"3" & rh_bcd(7 downto 4), 
							x"3" & rh_bcd(3 downto 0), 
							x"25",
							x"20",
							x"20"); 	
         
  
  p_print : process(clk_50)
  begin
	if reset_n = '0' then 
		state <= s_idle;
		delay_ena <= '0';
		nextLine	<= '0';
		clearLcd <= '0'; 	
		o_update <= '0';

  	elsif rising_edge(clk_50) then 

  		case(state) is
		
		
  			when s_idle =>
					
					delay_ena <= '0';
					nextLine	<= '0';
					clearLcd <= '0'; 


					if i_update = '1' and lcd_r = '1' then 
						state <= s_clearLcd; 
					end if;
				
			when s_clearLcd => 
			
					clearLcd <= '1'; 
					state <= s_waitLcdclear; 
					
			when s_waitLcdclear => -- waiting for the lcd to clear
			
					clearLcd <= '0'; 
					
					if display_cleared = '1' then 
							state <= s_firstLine;
							delay_ena <= '1';
					end if; 
  			
			
			when s_firstLine => 

					print_ascii <= lcd_string_01(print_counter); 

					if cnt_700us = '1' then -- a loop that sends a new char every 700us

								if (print_counter = 4 and temp_negativ = '0') then 
										
										if (temp_bcd(11 downto 8) = "0000" and temp_bcd(15 downto 12) = "0000") then -- if both hundreds & tens is 0 and a positive number => jump to ones (and dont print -)
											print_counter <= print_counter + 4;
											
										elsif (temp_bcd(15 downto 12) = "0000") then -- if only hundreds is 0 and a positive number => jump to tens 
											print_counter <= print_counter + 3;
											
										end if;
										
								elsif (print_counter = 5 and temp_negativ = '1') then
										
										if (temp_bcd(11 downto 8) = "0000" and temp_bcd(15 downto 12) = "0000") then -- if both if both hundreds & tens is 0 and a negative number => jump to ones 
											print_counter <= print_counter + 3;
											
										elsif (temp_bcd(15 downto 12) = "0000") then -- if only hundreds is 0 and a negative number => jump to tens 
											print_counter <= print_counter + 2;
											
										end if;
								else 
										print_counter <= print_counter + 1;
									
								end if; 
					end if; 
					
					
					if print_counter = 14 then 
							delay_ena <= '0';
							 o_update <= '0';
							 state <= s_nextline;
							print_counter <= 0;  
					else 
						o_update <= '1';
						delay_ena <= '1';



					end if; 

  			when s_nextline => 
					nextLine	<= '1';
					if lcd_r = '1'  then 
						state <= s_secondLine;
						delay_ena <= '1';
					end if; 

  					

  			when s_secondLine =>  
					nextLine	<= '0';
					print_ascii <= lcd_string_02(print_counter); 

					if cnt_700us = '1' then 

							if (rh_bcd(11 downto 8) = "0000" and rh_bcd(7 downto 4) = "0000" and print_counter = 2) then --if both hundreds & tens is 0 => jump to ones
											print_counter <= print_counter + 3;
							elsif (rh_bcd(11 downto 8) = "0000" and print_counter = 2) then --if only hundreds is 0 => jump to tens
											print_counter <= print_counter + 2;
							else 
										print_counter <= print_counter + 1;
									
							end if; 

					end if; 
				
				if print_counter = 8 then -- 7 vid sim 
						delay_ena <= '0';
						 o_update <= '0';
						 state <= s_idle;
						 print_counter <= 0;  

				else 
					o_update <= '1';
					delay_ena <= '1';



				end if; 
						

  		end case;

  	end if; 
  	
  end process ; -- p_print

  p_count_line1 : process( clk_50)
  begin


  	if rising_edge(clk_50) and delay_ena = '1' then
  		
		if counter_700us < c_cnt_700us_max then
			counter_700us <= counter_700us + 1;
			cnt_700us <= '0'; 
		else

			counter_700us <= 0; 
			cnt_700us <= '1'; 
		end if;

	end if;

  	
  end process ; --  p_count_line1


end print_value_arc;