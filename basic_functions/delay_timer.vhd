--!@file delay_timer.vhd
--!@brief Delay an input pulse of the specified clock cycles
--!@author Mattia Barbanera, mattia.barbanera@infn.it
--!@date 10/06/2020
--!@version 0.1 - 10/06/2020 - Stand-alone simulation

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;
use ieee.numeric_std.all;

use work.basic_package.all;

--!@brief Delay an input pulse of the specified clock cycles
entity delay_timer is
  port(
    iCLK    : in  std_logic; --!Main clock
    iRST    : in  std_logic; --!Reset
    iSTART  : in  std_logic; --!Start
    iDELAY  : in  std_logic_vector(15 downto 0); --!Delay in iCLK cycles
    oBUSY   : out std_logic; --!Busy
    oOUT    : out std_logic  --!Asserted after iDELAY clock cycles
  );
end delay_timer;

architecture std of delay_timer is
  signal sCount : std_logic_vector(iDELAY'length-1 downto 0);
  signal sStartEvent : std_logic;
  signal sEn : std_logic;

  signal sDelayed : std_logic;

begin
  --!@brief Detects the edges of the iSTART signals, synchronous to iCLK
  --!@test By controlling only the iSTART port should be enough,
  --!@test without the edge detector; it can be less secure.
  en_generator : edge_detector
    port map(
      iCLK    => iCLK,
      iRST    => iRST,
      iD      => iSTART,
      oQ      => open,
      oEDGE_R => sStartEvent,
      oEDGE_F => open
    );

  oBUSY <= sEn;
  --!@brief Enable the counter at the rising edge of iSTART and
  --!@brief Disable the counter when delay is enough
  en_proc : process(iCLK)
  begin
    if (rising_edge(iCLK)) then
      if (iRST = '1') then
        sEn <= '0';
      else
        if (sDelayed = '1') then
          sEn <= '0';
        elsif (sStartEvent = '1') then
          sEn <= '1';
        end if;
      end if; --iRST
    end if; --rising_edge
  end process;

  --!@brief Simple counter with enable port
  count_proc : process(iCLK)
  begin
    if (rising_edge(iCLK)) then
      if (iRST = '1' or sDelayed = '1') then
        sCount <= (others=>'0');
      else
        sCount <= sCount + sEn;
      end if; --iRST
    end if; --rising_edge
  end process;

  oOUT <= sDelayed;
  --!@brief Signal when the delay-time is passed
  delay_proc : process(iCLK)
  begin
    if (rising_edge(iCLK)) then
      if (iRST = '1') then
        sDelayed <= '0';
      else
        if (sCount = iDELAY) then
          sDelayed <= '1';
        else
          sDelayed <= '0';
        end if; --sCount
      end if; --iRST
    end if; --rising_edge
  end process;

end std;
