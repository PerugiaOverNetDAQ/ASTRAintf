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
    oMUX_OUT		     		  : out std_logic_vector(15 downto 0)
    );
end ANALOG_READOUT_sim;


--!@copydoc ANALOG_READOUT_sim.vhd
architecture Behavior of ANALOG_READOUT_sim is

  --!Number of channel selected
  signal    sMuxOut : std_logic_vector(15 downto 0);
  --!Channel index
  signal    i       : natural;
  --!MUX time constraints (response time of the MUX)
  constant  t1      : time := 3 ns;

begin
  --!Output delay introduced by the MUX
  oMUX_OUT  <= transport sMuxOut after t1;
  
  -- Questo e quello
    assert (iMUX_READ_RESET = '0')
    report "Questo non va bene"
    severity ERROR;
  mux_shift_sim : process (iMUX_SHIFT_CLK, iHOLD, iMUX_READ_RESET)
	begin
    sMuxOut <= (others => 'Z'); 
		wait until iHOLD'event and iHOLD='0';
    
		wait until rising_edge(iMUX_READ_RESET);
		i <= 0;    
    mux_out : while (i < cFE_CHANNELS) loop
      wait until rising_edge(iMUX_SHIFT_CLK);
      sMuxOut <= std_logic_vector(to_unsigned(i, sMuxOut'length));
      i <= i + 1;
    end loop mux_out;    
	end process;


end architecture;

