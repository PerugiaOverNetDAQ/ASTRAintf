--!@file ANALOG_READOUT_sim.vhd
--!@Emulatates the behavior of ASTRA analog readout
--!@details
--!
--! | Signal  | Description | Default value |
--! |---------|-------------|-------|
--! | iMUX_SHIFT_CLK | Slow clock to read the analogue MUX | 1-10 MHz |
--! | iHOLD | Input of holf signal for the S&H circuit | Low Active |
--! | iMUX_READ_RESET | Reset to start the analog mux readout | Low Active |
--! | oMUX_OUT | Mux readout | - |
--!
--!@author Matteo D'Antonio, matteo.dantonio@pg.infn.it
--!@date 22/11/2021


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;

use work.ASTRApackage.all;


--!@copydoc ANALOG_READOUT_sim.vhd
entity ANALOG_READOUT_sim is
  port(
    iMUX_SHIFT_CLK        : in  std_logic;
    iHOLD         				: in  std_logic;
    iMUX_READ_RESET       : in  std_logic;
    oMUX_OUT		     		  : out std_logic_vector(7 downto 0)
    );
end ANALOG_READOUT_sim;


--!@copydoc ANALOG_READOUT_sim.vhd
architecture Behavior of ANALOG_READOUT_sim is

  --!Number of channel selected
  signal    sMuxOut : std_logic_vector(7 downto 0);
  --!Channel index
  signal    i       : natural;
  --!MUX time constraints (response time of the MUX)
  constant  t1      : time := 3 ns;

begin
  --!Introduced a delay on the output
  oMUX_OUT  <= transport sMuxOut after t1;
  
  --!Set iHOLD before iMUX_READ_RESET
    assert (iHOLD = '1' and iMUX_READ_RESET = '1')
    report "An Attempt was made to set iMUX_READ_RESET before iHOLD"
    severity ERROR;
  mux_shift_sim : process
	begin
    sMuxOut <= (others => 'Z');
		wait until iHOLD'event and iHOLD='0';
		wait until iMUX_READ_RESET'event and iMUX_READ_RESET='1';
		i <= 0;
    mux_out : while (i < cFE_CHANNELS) loop
      wait until iMUX_SHIFT_CLK'event and iMUX_SHIFT_CLK='1';
      sMuxOut <= std_logic_vector(to_unsigned(i, sMuxOut'length));
      i <= i + 1;
      
      --!Incomplete Transaction
      assert (iHOLD = '1' and iMUX_READ_RESET = '0')
      report "An Attempt was made to modify iHOLD or iMUX_READ_RESET before that the transaction was completed"
      severity ERROR;
    end loop mux_out;    
	end process;


end architecture;

