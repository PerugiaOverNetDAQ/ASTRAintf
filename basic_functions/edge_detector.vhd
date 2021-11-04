--!@file edge_detector.vhd
--!@brief Detect the rising and falling edges of an input signal
--!@details
--! Beside the edges, it generates a copy of the original signal
--!delayed of 1 clock cycle
--!@author Mattia Barbanera, mattia.barbanera@infn.it
--!@author Hikmat Nasimi, hikmat.nasimi@pi.infn.it
--!@author Matteo D'Antonio, matteo.dantonio@gmail.com
--!@date 22/09/2021

library ieee;
use ieee.std_logic_1164.all;

--!@copydoc edge_detector.vhd
entity edge_detector is
  port(
    iCLK    : in  std_logic;
    iRST    : in  std_logic;
    iD      : in  std_logic;
    oQ      : out std_logic;
    oEDGE_R : out std_logic;
    oEDGE_F : out std_logic
  );
end entity edge_detector;

--!@copydoc edge_detector.vhd
architecture std of edge_detector is
  signal s_input_delay    : std_logic := '1';
begin

  ffd_proc : process(iCLK, iRST)
  begin
    if (iRST = '1') then
      s_input_delay    <= '1';
    elsif (rising_edge(iCLK)) then
      s_input_delay    <= iD;
    end if;
  end process;

  oQ      <= s_input_delay;
  oEDGE_R <= '1' when (s_input_delay='0' and iD='1') and iRST = '0' else
             '0';
  oEDGE_F <= '1' when (s_input_delay='1' and iD='0') and iRST = '0' else
             '0';

end architecture std;
