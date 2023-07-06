--! @file binary2gray.vhd
--!@brief Converts plain binary to gray code (one clock-cycle operations)
--!@author Mattia Barbanera, mattia.barbanera@infn.it

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;

--!@copydoc binary2gray.vhd
entity binary2gray is
  generic (
    pSIZE  : natural := 12 --!Bit size
    );
  port (
    iCLK  : in  std_logic;  --!Clock (used at rising edge)
    iRST  : in  std_logic;  --!Reset (active high)
    iWR   : in  std_logic;  --!Sample gray input
    oWR   : out std_logic;  --!Binary out write request
    iBIN  : in  std_logic_vector(pSIZE-1 DOWNTO 0); --!Gray code
    oGRAY : out std_logic_vector(pSIZE-1 DOWNTO 0)  --!Binary code
    );
end entity;

--!@copydoc binary2gray.vhd
architecture std OF binary2gray is
  signal sBin : std_logic_vector(pSIZE-1 DOWNTO 0);
  signal sGray : std_logic_vector(pSIZE-1 DOWNTO 0);

begin
  sBin <= iBIN;

  --!@brief Sample incoming code and delay the write request
  --!@param[in]  iCLK Clock, used on rising edge
  FFD_PROC : process	(iCLK) is
  begin
    if (rising_edge(iCLK)) then
      if (iRST = '1') then
        --sBin <= (others => '0');
        oWR   <= '0';
        oGRAY  <= (others => '0');
      else
        --if (iWR = '1') then
        --  sBin <= iBIN;
        --end if;
        oWR <= iWR;
        oGRAY <= sGray;
      end if;
    end if;
  end process FFD_PROC;

  --!Actual conversion from binary to gray codes
  CONV_GENERATE : for j in 0 to pSIZE-2 generate
    --XOR of the internal bits
    sGray(j)  <= sBin(j) xor sBin(j+1);
  end generate CONV_GENERATE;
  --Last bit is the exact replica
  sGray(pSIZE-1) <= sBin(pSIZE-1);

end std;
