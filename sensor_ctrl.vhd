library ieee; 
use ieee.std_logic_1164.all; 

entity sensor_ctrl is
	
  port (
	
  		start_read 				: in 		std_logic; -- measurement starts when start_read is '1'
		reset_n 					: in 		std_logic; 
  		led_ack_error 			: out 	std_logic; 
  		clk 						: in 		std_logic;
  		sda 						: inout 	std_logic; 
  		scl 						: inout 	std_logic; 
  		temp_code,rh_code 	: out 	std_logic_vector(15 downto 0); -- datasheet 
  		start_calc 				: out 	std_logic

  ) ;
end entity ; -- temp_sensor

architecture temp_funcu of sensor_ctrl is

	component i2c_master 

		GENERIC(
		    input_clk : INTEGER := 50_000_000; --input clock speed from user logic in Hz
		    bus_clk   : INTEGER := 400_000);   --speed the i2c bus (scl) will run at in Hz
		PORT(
		    clk       : IN     STD_LOGIC;                    --system clock
		    reset_n   : IN     STD_LOGIC;                    --active low reset
		    ena       : IN     STD_LOGIC;                    --latch in command
		    addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --address of target slave
		    rw        : IN     STD_LOGIC;                    --'0' is write, '1' is read
		    data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data to write to slave
		    busy      : OUT    STD_LOGIC;                    --indicates transaction in progress
		    data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
		    ack_error : BUFFER STD_LOGIC;                    --flag if improper acknowledge from slave
		    sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
		    scl       : INOUT  STD_LOGIC);      

	end component; 
			
			TYPE machine is(s_idle,s_start,first_state, sec_state, third_state, 
					fourth_state, fifth_state, sixth_state,seventh_state,eighth_state, 
					ninth_state, tenth_state, eleventh_state, last_state,s_checkresult, s_done);
					
			signal ena       	: 	std_logic;                    --latch in command
			signal rw        	:	std_logic;                    --'0' is write, '1' is read
			signal data_wr   	: 	std_logic_vector(7 DOWNTO 0); --data to write to slave
			signal busy      	: 	std_logic;                    --indicates transaction in progress
			signal data_rd   	: 	std_logic_vector(7 DOWNTO 0); --data read from slave
			signal temp_lsbs 	:	std_logic_vector(1 downto 0);
			signal rh_lsbs 	: 	std_logic_vector(1 downto 0); 
			signal state 		: 	machine; 

begin



	U1: i2c_master
		GENERIC map (

						input_clk 	=> 50000000,
						bus_clk 		=> 100000)

		port map (

						clk 			=> clk,    
						reset_n 		=> reset_n,  
						ena 			=> ena,      
						addr 			=> "1000000",
						rw 			=> rw,       
						data_wr		=> data_wr,
						busy 			=> busy,   
						data_rd 		=> data_rd,
						ack_error 	=> led_ack_error,
						sda 			=> sda,
						scl 			=> scl);

p_i2c_master : process(clk, reset_n)
begin


			if rising_edge(clk) then 

				case(state) is

					when s_idle =>
							rw <= '0';
							ena <= '0';
							data_wr <= X"00";
							start_calc <= '0';
							
							if start_read = '1' then 
								state <= s_start;
							end if; 

					when s_start =>

							rw <= '0';
							ena <= '0'; 
							if busy = '0' then 
								ena <= '1'; 
								state <= first_state;
							end if; 
							data_wr <= X"E5"; -- Measure RH


					when first_state =>
					
							if busy = '1' then
								rw <= '1'; 
								state <= sec_state; 
							end if; 

					when sec_state =>
					
							if busy = '0' then 
								state <= third_state; 
							end if;

					when third_state =>
					
							if busy = '1' then 
								state <= fourth_state; 
							end if;

					when fourth_state =>
					
							if busy = '0' then 
								rh_code(15 downto 8) <= data_rd; 
								state <= fifth_state; 
							end if;

					when fifth_state =>
					
							if busy = '1' then
								data_wr <= X"E0"; -- Read Temperature Value from Previous RH Measurement
								state <= sixth_state;  
							end if; 

					when sixth_state =>
							rw <= '0';
							ena <= '0'; 
							if busy = '0' then
							
								ena <= '1'; 
								rh_code(7 downto 0) <= data_rd;
								rh_lsbs <= data_rd(1 downto 0); 
								state <= seventh_state; 
							end if; 

					when seventh_state => 
					
							if busy = '1' then
								rw <= '1';
								state <= eighth_state; 
							end if; 

					when eighth_state => 
					
							if busy = '0' then 
								state <= ninth_state;
							end if;

					when ninth_state =>
					
							if busy = '1' then
								state <= tenth_state; 
							end if;
							
					when tenth_state => 
					
							if busy = '0' then
								temp_code(15 downto 8) <= data_rd; 
								state <= eleventh_state; 
							end if;
							
					when eleventh_state =>
					
							if busy = '1' then
								ena <= '0';
								state <= last_state; 
							end if;
					when last_state =>
					
							if busy = '0' then -- 7
								temp_code(7 downto 0) <= data_rd;
								temp_lsbs <= data_rd(1 downto 0); 
								state <= s_checkresult;
							end if;
					when s_checkresult => 
					
							if temp_lsbs /= "00" and rh_lsbs /= "10" then -- => error
							state <= s_idle;

							else 
							state <= s_done; 
							
							end if ;

					when s_done =>
					
							start_calc <= '1'; 
							state <= s_idle;
				end case ;



			end if; 

			if reset_n = '0' then 
					state <= s_idle;
			end if; 


end process ; -- p_i2c_master


end architecture ; -- temp_funcu