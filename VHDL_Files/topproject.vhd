LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

entity topproject is
port (


			clk_50   	: in  		std_logic;
			b_reset 		: in  		std_logic;
			lcd_data 	: inout 		std_logic_vector(7 downto 0); 
			lcd_E 		: out	 		std_logic; 
			lcd_RS 		: out 		std_logic; 
			lcd_RW 		: out 		std_logic; 
			led_sensor	: out 		std_logic;
			i2c_sda 		: inout 		std_logic; 
			i2c_scl 		: inout 		std_logic

);
end entity topproject ; -- top_project

architecture top_arc of topproject is




	component lcd_controller is
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
	end component;


	component print_values is
		port (
			clk_50 				: in 		std_logic;
			reset_n 				: in		std_logic; 
			i_update 			: in 		std_logic; 
			o_update				: out 	std_logic;
			lcd_r					: in 		std_logic; 
			temp_negativ		: in 		std_logic; 
			temp_bcd 			: in 		std_logic_vector(15 downto 0); 
			rh_bcd 				: in 		std_logic_vector(15 downto 0); 
			print_ascii 		: out 	std_logic_vector(7 downto 0); 
			nextLine 			: out 	std_logic; 
			clearLcd 			: out 	std_logic;
			display_cleared	: in 		std_logic
		);
	end component;

	Component Binary_to_BCD is
		port(
			clk    			: in 	std_logic;
			reset 			: in 	std_logic;
			temp_result 	: in 	signed(10 downto 0);
			bcd_update 		: in 	std_logic;
			rh_result 		: in 	std_logic_vector(6 downto 0);
			temp_bcd 		: out std_logic_vector(15 downto 0);
			rh_bcd 			: out std_logic_vector(15 downto 0);
			negative 		: out std_logic;
			update_print	: out std_logic);

	end Component;

	Component calculation is
		port (
		clk_50 				: in 	std_logic;
		reset_n				: in 	std_logic; 
		update 				: in 	std_logic;
		TEMP_code			: in 	std_logic_vector(15 downto 0); 
		RH_code 				: in 	std_logic_vector(15 downto 0); 
		TEMP					: out signed(10 downto 0);
		RH 					: out std_logic_vector(6 downto 0);
		update_bcd 			: out std_logic

		);
	end Component;


	Component update_200ms is
		port (
		clk_50 	: in	std_logic;
		reset 	: in 	std_logic;
		upd 		: out std_logic
		);
	end Component;

	Component sensor_ctrl is
		port(
		start_read 			: in 		std_logic; 	
		reset_n 				: in 		std_logic; 
		led_ack_error 		: out 	std_logic; 
		clk 					: in 		std_logic;
		sda 					: inout 	std_logic; 
		scl 					: inout 	std_logic; 
		temp_code			: out 	std_logic_vector(15 downto 0);	
		rh_code 				: out 	std_logic_vector(15 downto 0);	
		start_calc 			: out 	std_logic
		);
	end Component; -- temp_sensor

		-- signals used to connect lcd_controller with printvalues
		signal lcd_ready 			: std_logic;
		signal lcd_update 		: std_logic;
		signal ascii 				: std_logic_vector(7 downto 0); 
		signal changeline 		: std_logic;
		signal clearlcd 			: std_logic; 
		signal lcd_cleared 		: std_logic; 


		-- signals used to connect binary_to_bcd with printvalues 
		signal bcd_temp 			: std_logic_vector(15 downto 0);
		signal bcd_rh 				: std_logic_vector(15 downto 0);
		signal bcd_upd_print 	: std_logic;
		signal bcd_negativ 		: std_logic; 
		

		-- signals used to connect binary_to_bcd with calculation
		signal update_bcd 		: std_logic;
		signal Temp_binary 		: signed(10 downto 0);
		signal RH_binary 			: std_logic_vector(6 downto 0);
		
		-- signal used to coonect update to temp_sensor
		signal update_sensor 	: std_logic; 
		
		
		-- signals used to connect Temp_sensor with calculation
		signal T_code 				: std_logic_vector(15 downto 0);
		signal R_code 				: std_logic_vector(15 downto 0);
		signal update_calc 		: std_logic; 






begin
			U1: lcd_controller
				port map(
				CLK_50  			=> clk_50,
				reset_n  		=> b_reset,
				disp_data  		=> lcd_data,
				disp_E  			=> lcd_E,
				disp_RS  		=> lcd_RS,
				disp_RW  		=> lcd_RW,
				update 	 		=> lcd_update,
				ready  			=> lcd_ready,
				ascii_char 		=> ascii,
				changeLine 		=> changeline, 
				clean_screen 	=> clearlcd,
				lcd_cleared 	=> lcd_cleared); 

			U2: print_values
				port map(
				clk_50  				=> clk_50,
				reset_n  			=> b_reset,
				i_update 			=> bcd_upd_print, 
				o_update				=> lcd_update,
				lcd_r					=> lcd_ready,
				temp_negativ		=> bcd_negativ,
				temp_bcd 			=> bcd_temp,
				rh_bcd 				=> bcd_rh, 
				print_ascii 		=> ascii,
				nextLine 			=> changeline,
				clearLcd		 		=> clearlcd,
				display_cleared 	=> lcd_cleared ); 	
				
			U3: Binary_to_BCD
				port map(
				clk  					=> clk_50,
				reset 				=> b_reset,
				temp_result  		=> Temp_binary,
				bcd_update  		=> update_bcd	,
				rh_result  			=> RH_binary,
				temp_bcd 			=> bcd_temp,
				rh_bcd  				=> bcd_rh,
				negative 		 	=> bcd_negativ ,
				update_print  		=> bcd_upd_print);
			
			U4: calculation
				port map(
				clk_50 				=> clk_50,
				reset_n 				=> b_reset, 
				update 				=> update_calc,
				TEMP_code 			=> T_code, 
				RH_code 				=> R_code, 
				TEMP 					=> Temp_binary, 		
				RH 					=> RH_binary,					
				update_bcd 			=> update_bcd); 

			U5: update_200ms 
				port map(
				clk_50 				=> clk_50,
				reset 				=> b_reset,
				upd 					=> update_sensor);


			U6: sensor_ctrl 
				port map(
				start_read 			=> update_sensor,
				reset_n 				=> b_reset,
				led_ack_error 		=> led_sensor, 
				clk 					=> clk_50,
				sda 					=> i2c_sda, 
				scl 					=> i2c_scl, 
				temp_code 			=> T_code, 
				rh_code 				=> R_code,
				start_calc 			=> update_calc);



end top_arc;