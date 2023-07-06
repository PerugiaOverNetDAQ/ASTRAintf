--! @file grayConv.vhd
--!@brief Convert and synchronize internal ADC data stream
--!@author Mattia Barbanera, mattia.barbanera@infn.it

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;
use work.basic_package.all;

--!@copydoc grayConv.vhd
entity grayConv is
  generic (
    pSIZE  : natural := 16 --!Bit size
    );
  port(
    iCLK  : in  std_logic;  --!Clock (used at rising edge)
    iRST  : in  std_logic;  --!Reset (active high)
    iWR   : in  std_logic;  --!Sample gray input
    oWR   : out std_logic;  --!Binary out write request
    iGRAY : in  std_logic_vector(pSIZE-1 DOWNTO 0); --!Gray code
    oBIN  : out std_logic_vector(pSIZE-1 DOWNTO 0)  --!Binary code
    );
end grayConv;

--!@copydoc grayConv.vhd
architecture std of grayConv is
  alias sRemainingGray  : std_logic_vector(pSIZE-12-1 downto 0)
                          is iGRAY(pSIZE-1 downto 12);
  alias sRemainingBin   : std_logic_vector(pSIZE-12-1 downto 0)
                          is oBIN(pSIZE-1 downto 12);

begin

  --!Convert gray to binary
  gray2binary_i : gray2binary
  generic map (
    pSIZE => 12
    )
  port map (
    iCLK  => iCLK,
    iRST  => iRST,
    iWR   => iWR,
    oWR   => oWR,
    iGRAY => iGRAY(11 downto 0),
    oBIN  => oBIN(11 downto 0)
    );

  --!@brief Synchronize the remaining bits
  SYNCH_PROC : process (iCLK)
  begin
    if (rising_edge(iCLK)) then
      if (iRST = '1') then
        sRemainingBin <= (others => '0');
      else
        if (iWR = '1') then
          sRemainingBin <= sRemainingGray;
        end if; --iWR
      end if; --iRST
    end if; --iCLK
  end process SYNCH_PROC;


end architecture std;
