library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
library work;

entity testbench_proj is

end entity testbench_proj;

architecture bhv of testbench_proj is

   -- Clock and reset generation
   signal clock_50         : std_logic := '0';
   signal reset_n          : std_logic := '0';
   signal kill_clock       : std_logic := '0';
 
   -- Signals for I2C slave
   signal i2c_sda                : std_logic;
   signal i2c_scl                : std_logic;
   signal i2c_read_req_active    : std_logic;
   signal read_data              : std_logic_vector(7 downto 0);
   signal read_data_valid        : std_logic;
   signal read_data_sampled      : std_logic;
   signal slave_write_valid      : std_logic;
   signal slave_write_data       : std_logic_vector(7 downto 0);
   signal slave_write_ready      : std_logic;
   signal master_stop            : std_logic;
   signal master_ack             : std_logic;
   signal master_no_ack          : std_logic;

   --signals for top level
   signal lcd_data               : std_logic_vector(7 downto 0);
   signal lcd_E                  : std_logic;
   signal lcd_RW                 : std_logic;
   signal lcd_RS                 : std_logic;
   signal led_sensor             : std_logic;      
   signal led_upd                : std_logic;


   procedure pr_pull_up(signal pull_up_signal : inout std_logic) is
   begin
      if pull_up_signal = 'U' or pull_up_signal = 'X' then
         pull_up_signal     <= 'Z';
      elsif pull_up_signal = 'Z' then
         pull_up_signal     <= '1';
      end if;
   end procedure pr_pull_up;


begin -- architecture


--===============CLOCK===============--
   p_generate_clock : process
   begin
      clock_50 <= '0';
      wait for 10 ns;
      while ( kill_clock = '0' ) loop
         clock_50 <= not clock_50;
         wait for 10 ns;
      end loop;
      -- wait forever;
      wait;
   end process p_generate_clock;


--===============RESET===============--
   p_generate_reset : process
   begin
      -- Set reset active
      reset_n     <= '0';
      wait for 123 ns;
      -- Set reset inactive
      reset_n     <= '1';
      -- Wait forever
      wait;
   end process p_generate_reset;


   pr_pull_up(i2c_scl);
   pr_pull_up(i2c_sda);

--===============TOP LEVEL===============--
   i_top_project : entity work.topproject
      port map(   
               clk_50               => clock_50,      
               b_reset              => reset_n,      
               lcd_data             => lcd_data,         
               lcd_E                => lcd_E,      
               lcd_RS               => lcd_RS,       
               lcd_RW               => lcd_RW,       
               led_sensor           => led_sensor,
                     
               i2c_sda              => i2c_sda,       
               i2c_scl              => i2c_scl);



--===============I2C SLAVE===============--
   i_i2c_slave : entity work.i2c_slave
   generic map(
      g_reset_active_state    => '0',
      g_hold_times_clk        => 20)
   port map(
      clk                     => clock_50,
      reset                   => reset_n,

      i2c_sda                 => i2c_sda,
      i2c_scl                 => i2c_scl,

      i2c_address             => "1000000",
      i2c_read_req_active     => i2c_read_req_active,

      read_data               => read_data,
      read_data_valid         => read_data_valid,
      read_data_sampled       => read_data_sampled,

      slave_write_valid       => slave_write_valid,
      slave_write_data        => slave_write_data,
      slave_write_ready       => slave_write_ready,

      master_stop             => master_stop,
      master_ack              => master_ack,
      master_no_ack           => master_no_ack);


   p_si7006_model : process
   begin
      read_data_valid   <= '0';
      read_data         <= X"00";
      wait until reset_n = '1';
      while kill_clock = '0' loop

         wait until slave_write_valid = '1' or kill_clock = '1';
         if slave_write_valid = '1' and slave_write_data = X"E5" then
            read_data         <= X"2A";   -- RH MSB  
            wait until i2c_read_req_active = '1';
            wait for 50 us;
            read_data_valid   <= '1';
            wait until read_data_sampled = '1';
            read_data         <= X"7A";   -- RH LSB -- 14,7% humidity received
            wait until master_stop = '1';
         elsif slave_write_valid = '1' and slave_write_data = X"E0" then
            read_data         <= X"20";   -- TEMP MSB
            read_data_valid   <= '1';
            wait until read_data_sampled = '1';
            read_data         <= X"94";   -- TEMP LSB -- (-24,5) degree celcius received
            wait until master_stop = '1';
         end if;
         read_data_valid   <= '0';
      end loop;

      wait;
   end process p_si7006_model;

   slave_write_ready <= '1';

end architecture bhv;