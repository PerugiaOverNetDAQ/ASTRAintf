--!@file ADC_EXT_sim.vhd
--!@Emulatates the behavior of AD7276A on hybrid board
--!@details
--!
--! | Signal  | Description | Default value |
--! |---------|-------------|-------|
--! | iSCLK | Input of external ADC clock | 500k-48 MHz |
--! | iCS | Start of Conversion | Low Active |
--! | oSDATA | External ADC readout | 0-0-DB12-DB11-DB10-DB9-DB8-DB7-DB6-DB5-DB4-DB3-DB2-DB1-0-0 |
--!
--!@author Matteo D'Antonio, matteo.dantonio@pg.infn.it
--!@date 30/11/2021


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;

--use work.ASTRApackage.all;


--!@copydoc ADC_EXT_sim.vhd
entity ADC_EXT_sim is
  port(
    iSCLK         : in std_logic;
    iCS           : in std_logic;
    oSDATA        : out std_logic_vector(3 downto 0)
    );
end ADC_EXT_sim;


--!@copydoc ADC_EXT_sim.vhd
architecture Behavior of ADC_EXT_sim is

  --!Flag to indicate the state of work for ADC
  signal    sWorkFlag   : std_logic;
  --!Flag to indicate the state of quiet for ADC
  signal    sQuietFlag  : std_logic;
  --!Digital bit index
  signal    i           : natural;
  -- ADC time constraints
  constant tq           : time := 4  ns;   --!Minimum quiet time between conversions
  constant t2           : time := 6  ns;   --!CS to SCLK setup time
  constant t3           : time := 4  ns;   --!Delay from CS until SDATA three-state disabled
  constant t4           : time := 15 ns;   --!Data access time after SCLK falling edge
  constant t7           : time := 5  ns;   --!SCLK to data valid hold time
  constant t8           : time := 14 ns;   --!SCLK falling edge to SDATA high-impedance

begin
  --!Invalid use of the Synchronization Clock
  assert not(iCS = '1' and falling_edge(iSCLK))
  report "An Attempt was made to receive the digital bit when Chip Select high"
  severity ERROR;
  --!Incomplete Transaction
  assert not(sWorkFlag = '1' and rising_edge(iCS))
  report "An Attempt was made to modify Chip Select before that the conversion was completed"
  severity ERROR;
  --!Minimum quiet time not respected
  assert not(sQuietFlag = '1' and falling_edge(iCS))
  report "Chip Select pull down too early"
  severity ERROR;

  external_ADC_sim : process
	begin
    --!Default values, to be overwritten when necessary
    oSDATA      <= (others => 'Z');
    i           <= 0;
    sWorkFlag   <= '0';
    sQuietFlag  <= '0';
    --!External ADC implementation
    --!Two header zeros
		wait until falling_edge(iCS);
    sWorkFlag   <= '1';
    wait for t3;
    oSDATA <= (others => '0');
    wait for t2 - t3;
		wait until falling_edge(iSCLK);
    wait for t7;
    oSDATA <= (others => 'X');
    wait for t4 - t7;
    oSDATA <= (others => '0');

    --!Twelve digital bit
    ADC_out : while (i < 11) loop
      wait until falling_edge(iSCLK);
      wait for t7;
      oSDATA <= (others => 'X');
      wait for t4 - t7;
      oSDATA <= std_logic_vector(to_unsigned(12-i, oSDATA'length));
      i      <= i + 1;
    end loop ADC_out;

    --!Two trailer zeros
    wait until falling_edge(iSCLK);
    wait for t7;
    oSDATA <= (others => 'X');
    wait for t4 - t7;
    oSDATA <= (others => '0');
    wait until falling_edge(iSCLK);
    wait for t7;
    oSDATA <= (others => 'X');
    wait for t4 - t7;
    oSDATA <= (others => '0');
    wait until falling_edge(iSCLK);
    wait for t8;
    oSDATA      <= (others => 'Z');
    sWorkFlag   <= '0';
    sQuietFlag  <= '1';
    wait for tq;
	end process;


end architecture;
