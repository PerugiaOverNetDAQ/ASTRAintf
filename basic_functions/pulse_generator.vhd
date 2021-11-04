--!@file pulse_generator.vhd
--!@brief Generate a periodic pulse
--!@author Mattia Barbanera, mattia.barbanera@infn.it
--!@date 10/06/2020
--!@version 0.2 - 10/06/2020 - Simulated; Optimized for logic occupation

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

--!@brief Generate a periodic pulse
--!@details Generate a pulse with a period of iPERIOD and pLENGTH long;
--!generate also the RISING and FALLING edges
entity pulse_generator is
  generic(
    --!Counter width
    pWIDTH    : natural := 32;
    --!Polarity of the pulse
    pPOLARITY : std_logic := '1';
    --!Length of the pulse
    pLENGTH   : natural   := 1
  );
  port(
    --!Main clock
    iCLK            : in  std_logic;
    --!Reset
    iRST            : in  std_logic;
    --!Enable
    iEN             : in  std_logic;
    --!Pulse
    oPULSE          : out std_logic;
    --!Rising edge of the pulse; synchronous to the edge
    oPULSE_RISING   : out std_logic;
    --!Falling edge of the pulse; synchronous to the edge
    oPULSE_FALLING  : out std_logic;
    --!Pulse duration (in number of iCLK cycles)
    iPERIOD         : in  std_logic_vector(pWIDTH-1 downto 0)
  );
end pulse_generator;

architecture Behavioral of pulse_generator is
  signal sSlvEnable   : std_logic_vector(pWIDTH-1 downto 0):= (others=>'0');
  signal sCounter     : std_logic_vector(pWIDTH-1 downto 0):= (others=>'0');
  signal sPulse       : std_logic:= '0';
  signal sPulseDelay  : std_logic:= '0';
  signal sRstCnt      : std_logic:= '0';
  signal sPulseRise   : std_logic:= '0';
  signal sPulseFall   : std_logic:= '0';

begin

  sSlvEnable(0)           <= iEN;
  sSlvEnable(pWIDTH-1 downto 1) <= (others => '0');
  --!@brief Counter that increments at each cycle
  --!@test Summing sSlvEnable could add combinatorial length to the path
  --!@param[in]  iCLK  Clock, used on rising edge
  freq_down_scale : process (iCLK)
  begin
  if (rising_edge(iCLK)) then
    if(iRST = '1' or sRstCnt = '1') then
      sCounter <= (others => '0');
    else
      sCounter <= sCounter + conv_integer(sSlvEnable);
      --if(iEN='1') then
      --    sCounter <= sCounter + 1;
      --end if;
    end if;
  end if;
  end process freq_down_scale;

  --!@brief Add FFDs to the combinatorial signals
  --!@param[in]  iCLK  Clock, used on rising edge
  ffds : process (iCLK)
  begin
    if (rising_edge(iCLK)) then
      oPULSE      <= sPulseDelay;
      sPulseDelay <= sPulse;
      if (pPOLARITY = '1') then
        oPULSE_RISING  <= sPulseRise;
        oPULSE_FALLING <= sPulseFall;
      else
        oPULSE_RISING  <= sPulseFall;
        oPULSE_FALLING <= sPulseRise;
      end if;
    end if;
  end process ffds;

  sPulse      <=  pPOLARITY when (iEN = '1' and (sCounter<pLENGTH)) else
                  not pPOLARITY;
  sRstCnt     <=  '1' when (sCounter = iPERIOD) else
                  '0';
  sPulseRise  <=  '1' when (iEN='1' and (sCounter=0)) else
                  '0';
  sPulseFall  <=  '1' when (iEN='1' and (sCounter=pLENGTH)) else
                  '0';

end Behavioral;
