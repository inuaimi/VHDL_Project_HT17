library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

entity i2c_slave is
generic (
   g_reset_active_state    : std_logic;
   g_hold_times_clk        : natural   range 10 to 1000  := 20);
port (
   clk                     : in  std_logic;
   reset                   : in  std_logic;

   i2c_sda                 : inout std_logic;
   i2c_scl                 : inout std_logic;

   i2c_address             : in  std_logic_vector(6 downto 0);
   i2c_read_req_active     : out std_logic;

   read_data               : in  std_logic_vector(7 downto 0);
   read_data_valid         : in  std_logic;
   read_data_sampled       : out std_logic;

   slave_write_valid       : out std_logic;
   slave_write_data        : out std_logic_vector(7 downto 0);
   slave_write_ready       : in  std_logic;

   master_stop             : out std_logic;
   master_ack              : out std_logic;
   master_no_ack           : out std_logic);
end entity i2c_slave;

architecture rtl of i2c_slave is

   --=========================================
   -- Types and constants
   --=========================================
   type t_main_state is (  s_idle,
                           s_get_addr,
                           s_output_ack,
                           s_release_ack,
                           s_get_data,
                           s_sample_read_data,
                           s_output_data,
                           s_master_ack,
                           s_master_ack_end,
                           s_clock_stretch,
                           s_set_data);

   --=========================================
   -- Signals
   --=========================================

   signal i2c_sda_out            : std_logic;
   signal i2c_scl_out            : std_logic;
   signal i2c_sda_r              : std_logic;
   signal i2c_sda_2r             : std_logic;
   signal i2c_sda_3r             : std_logic;
   signal i2c_scl_r              : std_logic;
   signal i2c_scl_2r             : std_logic;
   signal i2c_scl_3r             : std_logic;

   -- Signals for main process
   signal main_state             : t_main_state;
   signal i2c_address_saved      : std_logic_vector(i2c_address'range);
   signal i2c_address_shift      : std_logic_vector(i2c_address'range);
   signal i2c_r_wn_saved         : std_logic;
   signal bit_cnt                : natural range 0 to 7;
   signal master_ack_save        : std_logic;

   signal i2c_data_shift         : std_logic_vector(7 downto 0);
   signal slave_read_data_save   : std_logic_vector(7 downto 0);

   -- Counters
   signal hold_cnt_en            : std_logic;
   signal hold_cnt               : natural range 0 to g_hold_times_clk-1;
   signal hold_cnt_wrap          : std_logic;

begin

   i2c_sda  <= '0' when i2c_sda_out  = '0' else 'Z';
   i2c_scl  <= '0' when i2c_scl_out  = '0' else 'Z';

   p_double_sync : process(clk)
   begin
      if rising_edge(clk) then
         i2c_sda_r      <= i2c_sda;
         i2c_sda_2r     <= i2c_sda_r;
         i2c_sda_3r     <= i2c_sda_2r;
         i2c_scl_r      <= i2c_scl;
         i2c_scl_2r     <= i2c_scl_r;
         i2c_scl_3r     <= i2c_scl_2r;
      end if;
   end process p_double_sync;

   p_main : process(clk)
   begin
      if rising_edge(clk) then

         slave_write_valid       <= '0';
         master_no_ack           <= '0';
         master_ack              <= '0';
         read_data_sampled       <= '0';
         master_stop             <= '0';

         case main_state is
            when s_idle =>
               i2c_sda_out             <= '1';
               i2c_scl_out             <= '1';
               i2c_read_req_active     <= '0';
               hold_cnt_en             <= '0';
               -- Master stop when no frame is active on the bus
               master_stop             <= '1';
               master_ack_save         <= '0';
               slave_read_data_save    <= (others => '0');
               bit_cnt                 <= 7;
               i2c_address_saved       <= i2c_address;
               i2c_address_shift       <= (others => '0');

            when s_get_addr =>
               if i2c_scl_2r = '1' and i2c_scl_3r = '0' then
                  -- Rising edge of SCL
                  -- start hold conter
                  hold_cnt_en             <= '1';
               end if;
               if hold_cnt_wrap = '1' then
                  if bit_cnt > 0 then
                     i2c_address_shift       <= i2c_address_shift(5 downto 0) & i2c_sda_2r;
                     bit_cnt                 <= bit_cnt - 1;
                  else
                     i2c_r_wn_saved          <= i2c_sda_2r;
                     main_state              <= s_output_ack;
                  end if;
                  hold_cnt_en             <= '0';
               end if;

            when s_output_ack =>
               if i2c_scl_2r = '0' and i2c_scl_3r = '1' then
                  -- Falling edge of SCL
                  -- start hold conter
                  hold_cnt_en             <= '1';
               end if;
               if hold_cnt_wrap = '1' then
                  i2c_sda_out             <= '0';
                  hold_cnt_en             <= '0';
                  main_state              <= s_release_ack;
               else
                  main_state              <= s_output_ack;
               end if;
               master_stop             <= '0';
               if i2c_address_shift /= i2c_address_saved then
                  -- Master does not target this slave
                  -- Jump to idle state
                  master_stop             <= '1';
                  main_state              <= s_idle;
               end if;
               bit_cnt                 <= 7;

            when s_release_ack =>
               i2c_sda_out             <= '0';
               i2c_read_req_active     <= i2c_r_wn_saved;
               if i2c_scl_2r = '0' and i2c_scl_3r = '1' then
                  -- Falling edge of SCL
                  -- start hold conter
                  hold_cnt_en             <= '1';
               end if;
               if hold_cnt_wrap = '1' then
                  hold_cnt_en             <= '0';
                  if i2c_r_wn_saved = '0' then
                     -- Master is writing
                     i2c_sda_out             <= '1';
                     main_state              <= s_get_data;
                  else
                     -- Master is reading
                     if read_data_valid = '0' then
                        -- Slave read data is not valid go to clock stretch state
                        main_state              <= s_clock_stretch;
                     else
                        main_state              <= s_sample_read_data;
                     end if;
                  end if;
               end if;
               bit_cnt                 <= 7;

            when s_get_data =>
               if i2c_scl_2r = '1' and i2c_scl_3r = '0' then
                  -- Rising edge of SCL
                  -- start hold conter
                  hold_cnt_en             <= '1';
               end if;
               if hold_cnt_wrap = '1' then
                  i2c_data_shift          <= i2c_data_shift(6 downto 0) & i2c_sda_2r;
                  if bit_cnt > 0 then
                     bit_cnt                 <= bit_cnt - 1;
                  end if;
                  if bit_cnt = 0 then
                     slave_write_data        <= i2c_data_shift(6 downto 0) & i2c_sda_2r;
                     slave_write_valid       <= '1';
                     if slave_write_ready = '1' then
                        -- If slave is ready to receive data output ack
                        main_state              <= s_output_ack;
                     else
                        -- Not acknowledge go to idle state
                        main_state              <= s_idle;
                     end if;
                  end if;
                  hold_cnt_en             <= '0';
               end if;

            when s_sample_read_data =>

               read_data_sampled       <= '1';
               slave_read_data_save    <= read_data;
               main_state              <= s_output_data;

            when s_output_data =>

               i2c_sda_out             <= slave_read_data_save(7);
               if i2c_scl_2r = '0' and i2c_scl_3r = '1' then
                  -- Falling edge of SCL
                  -- start hold conter
                  hold_cnt_en             <= '1';
               end if;
               if hold_cnt_wrap = '1' then
                  hold_cnt_en             <= '0';
                  slave_read_data_save       <= slave_read_data_save(6 downto 0) & '0';
                  if bit_cnt > 0 then
                     bit_cnt                 <= bit_cnt - 1;
                  end if;
                  if bit_cnt = 0 then
                     main_state              <= s_master_ack;
                  end if;
               end if;


            when s_master_ack =>
               i2c_sda_out             <= '1';
               bit_cnt                 <= 7;
               if i2c_scl_2r = '1' and i2c_scl_3r = '0' then
                  -- Rising edge of SCL
                  -- start hold conter
                  hold_cnt_en             <= '1';
               end if;
               if hold_cnt_wrap = '1' then
                  hold_cnt_en             <= '0';
                  -- Master should ack data
                  master_no_ack           <= i2c_sda_2r;
                  master_ack              <= not i2c_sda_2r;
                  master_ack_save         <= not i2c_sda_2r;
                  main_state              <= s_master_ack_end;
               end if;


            when s_master_ack_end =>

               bit_cnt                 <= 7;
               if i2c_scl_2r = '0' and i2c_scl_3r = '1' then
                  -- Falling edge of SCL
                  -- start hold conter
                  hold_cnt_en             <= '1';
               end if;
               if hold_cnt_wrap = '1' then
                  hold_cnt_en             <= '0';
                  if master_ack_save = '1' then
                     if read_data_valid = '1' then
                        main_state                 <= s_sample_read_data;
                     else
                        main_state              <= s_clock_stretch;
                     end if;
                  else
                     main_state              <= s_idle;
                  end if;
               end if;

            when s_clock_stretch =>
               i2c_scl_out             <= '0';
               if read_data_valid = '1' then
                  -- Sample data
                  read_data_sampled       <= '1';
                  slave_read_data_save    <= read_data;
                  bit_cnt                 <= 7;
                  main_state              <= s_set_data;
                  hold_cnt_en             <= '1';
               end if;

            when s_set_data =>

               -- output data but keep clock low
               i2c_sda_out             <= slave_read_data_save(7);
               i2c_scl_out             <= '0';
               if hold_cnt_wrap = '1' then
                  if bit_cnt /= 0 then
                     bit_cnt              <= bit_cnt - 1;
                  else
                     -- release clock and go to output data state
                     i2c_scl_out          <= '1';
                     bit_cnt              <= 7;
                     hold_cnt_en          <= '0';
                     main_state           <= s_output_data;
                  end if;
               end if;



         end case;

         if i2c_sda_2r = '0' and i2c_sda_3r = '1' and i2c_scl_2r = '1' then
            -- Falling edge of SDA when SCL is high -> Start!
            -- Reset bit counter to 7
            bit_cnt                 <= 7;
            -- Jump to get address state
            main_state              <= s_get_addr;
         end if;
         if i2c_sda_2r = '1' and i2c_sda_3r = '0' and i2c_scl_2r = '1' then
            -- Rising edge of SDA when SCL is high -> Stop!
            -- Jump to idle state
            main_state              <= s_idle;
         end if;

         if reset = g_reset_active_state then
            main_state          <= s_idle;
         end if;

      end if;
   end process p_main;

   p_counters : process(clk)
   begin
      if rising_edge(clk) then

         hold_cnt_wrap     <= '0';
         if hold_cnt_en = '0' or hold_cnt >= g_hold_times_clk-1 then
            hold_cnt       <= 0;
            hold_cnt_wrap  <= hold_cnt_en;
         elsif hold_cnt_en = '1' then
             hold_cnt        <= hold_cnt + 1;
         end if;

      end if;
   end process p_counters;


end architecture rtl;