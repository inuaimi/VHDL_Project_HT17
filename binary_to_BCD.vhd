library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
 
entity Binary_to_BCD is

    port(
        clk, reset 		: in 	std_logic;
        temp_result 		: in 	signed(10 downto 0);
        bcd_update 		: in 	std_logic;
        rh_result 		: in 	std_logic_vector(6 downto 0);
        temp_bcd 			: out std_logic_vector(15 downto 0);
        rh_bcd 			: out std_logic_vector(15 downto 0);
        negative 			: out std_logic;
        update_print 	: out std_logic);

end entity;
 
architecture rtl of Binary_to_BCD is


    constant c_cnt_2ms_max : integer := 100000-1; 

    type states is (idle, start, shift, done);
    signal state, state_next : states;

    signal counter_2ms : integer range 0 to c_cnt_2ms_max;



 
    signal binary_temp, binary_temp_next : std_logic_vector(10 downto 0)					:= (others => '0');
    signal binary_rh, binary_rh_next : std_logic_vector(10 downto 0)							:= (others => '0');
    signal bcds_temp, bcds_temp_reg, bcds_temp_next : std_logic_vector(15 downto 0)	 	:= (others => '0');
    signal bcds_rh, bcds_rh_reg, bcds_rh_next : std_logic_vector(15 downto 0) 			:= (others => '0');
    
    -- output register keep output constant during conversion
    signal bcds_temp_out_reg, bcds_temp_out_reg_next : std_logic_vector(15 downto 0)	:= (others => '0');
    signal bcds_rh_out_reg, bcds_rh_out_reg_next : std_logic_vector(15 downto 0) 		:= (others => '0');
	 
    -- need to keep track of shifts
    signal shift_counter, shift_counter_next : natural range 0 to 11;
    signal temp_to_bcd : unsigned(10 downto 0) := (others => '0');
	 
	 
begin
 
	p_negative : process(temp_result)
		  begin
		  
				if temp_result(temp_result'high) = '1' then
					negative <= '1';
					temp_to_bcd <= unsigned(std_logic_vector(signed(-temp_result)));
			  else
					negative <= '0';
					temp_to_bcd <= unsigned(temp_result);
			  end if; 
	end process;    

    p_main : process(clk, reset)
    begin
     
        if reset = '0' then
            binary_temp <= (others => '0');
            binary_rh <= (others => '0');
            bcds_temp <= (others => '0');
            bcds_rh <= (others => '0');
            state <= idle;
            bcds_temp_out_reg <= (others => '0');
            bcds_rh_out_reg <= (others => '0');
            shift_counter <= 0;
        
        elsif rising_edge(clk) then
            binary_temp <= binary_temp_next;
            binary_rh <= binary_rh_next;
            bcds_temp <= bcds_temp_next;
            bcds_rh <= bcds_rh_next;
            state <= state_next;
            bcds_temp_out_reg <= bcds_temp_out_reg_next;
            bcds_rh_out_reg <= bcds_rh_out_reg_next;
            shift_counter <= shift_counter_next;

        end if;
    end process;
 
   
	p_convert : process(clk)
		 begin
		 
		 if rising_edge(clk) then 
			  
			  state_next <= state;
			  bcds_temp_next <= bcds_temp;
			  bcds_rh_next <= bcds_rh;
			  binary_temp_next <= binary_temp;
			  binary_rh_next <= binary_rh;
			  shift_counter_next <= shift_counter;
			  update_print <= '0';

	 
			  case state is

					when idle =>
						 
						 if bcd_update = '1' then
							state_next <= start;
							update_print <='0';
						 end if; 

					when start =>
					
							state_next <= shift;
							binary_temp_next <= std_logic_vector(temp_to_bcd);
							binary_rh_next <= ("0000" & rh_result);
							bcds_temp_next <= (others => '0');
							bcds_rh_next <= (others => '0');
							shift_counter_next <= 0;

					when shift =>
					
						 if shift_counter = 11 then
							  state_next <= done;
						 else
							  binary_temp_next <= binary_temp(9 downto 0) & '0';
							  binary_rh_next <= binary_rh(9 downto 0) & '0';

							  bcds_temp_next <= bcds_temp_reg(14 downto 0) & binary_temp(binary_temp'high);
							  bcds_rh_next <= bcds_rh_reg(14 downto 0) & binary_rh(binary_rh'left);
							  shift_counter_next <= shift_counter + 1;
						 end if;
					
					when done =>
							state_next <= idle;
							update_print <= '1';


			  end case;
			  
			end if; 

	end process;


  
 

    
    bcds_temp_reg(15 downto 12) <= bcds_temp(15 downto 12) + 3 when bcds_temp(15 downto 12) > 4 
		 else
			  bcds_temp(15 downto 12);
    
    bcds_temp_reg(11 downto 8) <= bcds_temp(11 downto 8) + 3 when bcds_temp(11 downto 8) > 4 
		 else
			  bcds_temp(11 downto 8);
    
    bcds_temp_reg(7 downto 4) <= bcds_temp(7 downto 4) + 3 when bcds_temp(7 downto 4) > 4 
		 else
			  bcds_temp(7 downto 4);
   
    bcds_temp_reg(3 downto 0) <= bcds_temp(3 downto 0) + 3 when bcds_temp(3 downto 0) > 4 
		 else
			  bcds_temp(3 downto 0);
 
    bcds_rh_reg(15 downto 12) <= bcds_rh(15 downto 12) + 3 when bcds_rh(15 downto 12) > 4 
		 else
			  bcds_rh(15 downto 12);
    
    bcds_rh_reg(11 downto 8) <= bcds_rh(11 downto 8) + 3 when bcds_rh(11 downto 8) > 4 
		 else
			  bcds_rh(11 downto 8);
    
    bcds_rh_reg(7 downto 4) <= bcds_rh(7 downto 4) + 3 when bcds_rh(7 downto 4) > 4 
		 else
			  bcds_rh(7 downto 4);
   
    bcds_rh_reg(3 downto 0) <= bcds_rh(3 downto 0) + 3 when bcds_rh(3 downto 0) > 4 
		 else
			  bcds_rh(3 downto 0);    


    bcds_temp_out_reg_next <= bcds_temp when state = done 
		 else
			  bcds_temp_out_reg;

    bcds_rh_out_reg_next <= bcds_rh when state = done 
		 else
			  bcds_rh_out_reg;    
    

	temp_bcd 	<= std_logic_vector(bcds_temp_out_reg);
	rh_bcd 		<= bcds_rh_out_reg; 
  
 
end architecture;