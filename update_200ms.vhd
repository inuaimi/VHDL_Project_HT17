LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;

entity update_200ms is
	port (
		clk_50 	: in 	std_logic;
		reset 	: in 	std_logic;
		upd 		: out std_logic
	);
end update_200ms;

architecture rtl of update_200ms is
	constant c_cnt_max 	: integer 	:= 10000000-1; --50mhz clock => 200ms = 10000000 cycles
	signal tick 			: std_logic;
	signal counter 		: integer range 0 to c_cnt_max;

begin

	p_update : process(clk_50, reset)
	   begin
	      if reset = '0' then
	         upd <= '0';
	         counter <= 0;
	      elsif rising_edge(clk_50) then
	         if counter < c_cnt_max then
	            counter <= counter + 1;
	            upd <= '0'; 
	         else
	            counter <= 0; 
	            upd <= '1';
	         end if ;
	      end if;
	end process p_update; 

end rtl;