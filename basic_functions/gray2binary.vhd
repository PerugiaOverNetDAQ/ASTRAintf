--! @file gray2binary.vhd
--!@brief Converts gray code to plain binary (one clock-cycle operations)
--!@author Mattia Barbanera, mattia.barbanera@infn.it

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;

--!@copydoc gray2binary.vhd
entity gray2binary is
  generic (
    pSIZE  : natural := 12 --!Bit size
    );
  port (
    iCLK  : in  std_logic;  --!Clock (used at rising edge)
    iRST  : in  std_logic;  --!Reset (active high)
    iWR   : in  std_logic;  --!Sample gray input
    oWR   : out std_logic;  --!Binary out write request
    iGRAY : in  std_logic_vector(pSIZE-1 DOWNTO 0); --!Gray code
    oBIN  : out std_logic_vector(pSIZE-1 DOWNTO 0)  --!Binary code
    );
end entity;

--!@copydoc gray2binary.vhd
architecture std OF gray2binary is
  signal sGray : std_logic_vector(pSIZE-1 DOWNTO 0);
  signal sBin : std_logic_vector(pSIZE-1 DOWNTO 0);

begin
  sGray <= iGRAY;

  --!@brief Sample incoming code and delay the write request
  --!@param[in]  iCLK Clock, used on rising edge
  FFD_PROC : process	(iCLK) is
  begin
    if (rising_edge(iCLK)) then
      if (iRST = '1') then
        oWR   <= '0';
        oBIN  <= (others => '0');
      else
        oWR <= iWR;
        oBIN <= sBin;
      end if;
    end if;
  end process FFD_PROC;

  --!Actual conversion from gray to binary codes
  CONV_GENERATE : for j in 0 to pSIZE-2 generate
    --XOR of the internal bits
    sBin(j) <= sGray(j) xor sBin(j+1);
  end generate CONV_GENERATE;
  --Last bit is the exact replica
  sBin(pSIZE-1) <= sGray(pSIZE-1);

end std;
