--!@file pulse_extender.vhd
--!@brief Extend an input pulse
--!@author Mattia Barbanera, mattia.barbanera@infn.it
--!@date 23/01/2023
--!@version 0.0

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.basic_package.all;

--!@brief Generate a periodic pulse
--!@details Generate a pulse with a period of iPERIOD and pLENGTH long;
--!generate also the RISING and FALLING edges
entity pulse_extender is
  generic(
    --!Counter width
    pWIDTH    : natural := 32;
    --!Length of the pulse
    pLENGTH   : natural   := 1;
    --!Polarity of the input pulse
    pPOL_IN   : std_logic := '1';
    --!Polarity of the output pulse
    pPOL_OUT  : std_logic := '1'
  );
  port(
    --!Main clock
    iCLK            : in  std_logic;
    --!Reset
    iRST            : in  std_logic;
    --!Enable
    iEN             : in  std_logic;
    --!Input pulse
    iPULSE          : in  std_logic;
    --!Pulse
    oPULSE          : out std_logic
  );
end pulse_extender;

architecture Behavioral of pulse_extender is
  signal sStartCnt    : std_logic:= '0';
  signal sEndCnt      : std_logic:= '0';
  signal sCounter     : std_logic_vector(pWIDTH-1 downto 0):= (others=>'0');

  signal sPulseIn     : std_logic:= '0';
  signal sPulseOut    : std_logic:= '0';

begin

  --sPulseIn <= iPULSE when pPOL_IN = '1' else
  --            not iPULSE;
  --oPULSE <= sPulseOut when pPOL_OUT = '1' else
  --          not sPulseOut;
  oPULSE <= sPulseOut;

  pulse_extender_proc : process (iCLK)
  begin
  if (rising_edge(iCLK)) then
    if(iRST = '1') then
      sStartCnt <= '0';
      sEndCnt   <= '0';
      sCounter  <= (others => '0');
      sPulseOut    <= '0';
    else
      --Start if enabled and with a pulse in input
      if(iEN='1' and iPULSE = '1') then
        sStartCnt <= '1';
      else
        if (sEndCnt = '1') then
          sStartCnt <= '0';
        end if;
      end if; --StartCnt

      --Stop when long enough
      if (sCounter < int2slv(pLENGTH-1, pWIDTH)) then
        sEndCnt <= '0';
      else
        sEndCnt <= '1';
      end if;
      
      --pulse and counter logic
      if (sEndCnt = '1') then
        sCounter <= (others => '0');
        sPulseOut <= '0';
      else
        if (sStartCnt = '1') then
          sCounter <= sCounter + '1';
          sPulseOut <= '1';
        else
          sCounter <= (others => '0');
          sPulseOut <= '0';
        end if;
      end if;
    end if;--RST
  end if;--clk
  end process pulse_extender_proc;


end Behavioral;
