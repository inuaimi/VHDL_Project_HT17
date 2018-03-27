LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL; 
entity calculation is
	port (
		clk_50 					: 	in std_logic;
		reset_n					: 	in std_logic; 
		update 					: 	in std_logic;
		TEMP_code, RH_code 	: 	in std_logic_vector(15 downto 0); 
		TEMP						:	out signed(10 downto 0);
		RH 						:	out std_logic_vector(6 downto 0);
		update_bcd 				: 	out std_logic
	);
end calculation;

architecture calculation_arc of calculation is

	-- constants that are used in the two calculation expressions 
	--(The temperature constants are upscaled because this is a fixed point development board)
	constant const_Temp_mult 	: unsigned(10 downto 0) :=to_unsigned(1757,11);  -- 175.75 (x10)
	constant const_Temp_minus 	: unsigned(8 downto 0) :=to_unsigned(468,9); -- 46.8 (x10)

	constant const_RH_mult  	: unsigned(6 downto 0) :=to_unsigned(125,7); -- 125 
	constant const_RH_minus 	: unsigned(2 downto 0) :="110";  -- -6




	TYPE FSM is(s_idle, s_calc); 
	
	signal state 				:FSM; 


	SIGNAL Temp_mult 				: unsigned(26 downto 0);
	SIGNAL TEMP_mult_div 		: unsigned(10 downto 0); 

	SIGNAL RH_mult 				: unsigned(22 downto 0); 
	SIGNAL RH_mult_div 			: unsigned(6 downto 0); 
	
	signal counter_3_cycle 		: integer range 0 to 3;
	signal tick_3_cycle 			: std_logic;
	signal delay_en 				: std_logic; 
	

	

begin

	p_calc : process(clk_50,reset_n)
	begin
		if reset_n = '0' then 
			state <= s_idle;
			
		elsif rising_edge(clk_50) then 
					
			

				case(state) is
					when s_idle => 

						if update = '1' then
							state <= s_calc;
							delay_en	<= '1';
	
						else
							state <= s_idle;
							update_bcd <= '0';
							delay_en	<= '0';

						end if;
			
					when s_calc =>

						Temp_mult 		<= 	unsigned(TEMP_code(15 downto 0)) * const_Temp_mult(10 downto 0);

						TEMP_mult_div 	<=  	Temp_mult(26 downto 16); 

						TEMP 				<= 	signed(std_logic_vector(Temp_mult_div(10 downto 0) - const_Temp_minus(8 downto 0))); 

						RH_mult 			<= 	unsigned(RH_code(15 downto 0)) * const_RH_mult(6 downto 0); 

						RH_mult_div 	<= 	RH_mult(22 downto 16); 

						RH 				<= 	std_logic_vector(unsigned(RH_mult_div(6 downto 0)) - unsigned(const_RH_minus(2 downto 0)));
						
						if tick_3_cycle = '1' then
							update_bcd 	<= '1'; 
							state 		<= s_idle;
							delay_en	<= '0';
						end if; 


				end case;
				
			end if; 



		
	end process ; -- p_calc
	
	p_update : process(clk_50)

	begin

		if rising_edge(clk_50) and delay_en = '1' then 

			if counter_3_cycle < 3 then
				counter_3_cycle <= counter_3_cycle + 1;
				tick_3_cycle <= '0'; 
			else 
				counter_3_cycle <= 0; 
				tick_3_cycle <= '1'; 
			end if;
		end if;
		
	end process ; -- p_update

end calculation_arc;