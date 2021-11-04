--!@file shift_register.vhd
--!@brief pWIDTH-bit shift register with load, enable, serial and parallel out
--!@author Mattia Barbanera, mattia.barbanera@infn.it
--!@author Hikmat Nasimi, hikmat.nasimi@pi.infn.it
--!@date 09/01/2020
--!@version 1.0 - 09/01/2020 -

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;
use ieee.numeric_std.all;

--!@brief pWIDTH-bit shift register with load, enable, serial and parallel out
--!@details pDIR decides the direction of shifts; it can be "RIGHT" or "LEFT"
entity shift_register is
    generic(
        pWIDTH  : integer := 32;
        pDIR    : string := "LEFT"
    );
    port(
        iCLK        : in  std_logic := '0';
        iEN         : in  std_logic := '0';
        iRST        : in  std_logic := '1';
        iLOAD       : in  std_logic := '0';
        iSHIFT      : in  std_logic := '0';
        iDATA       : in  std_logic_vector(pWIDTH-1 downto 0) := (others => '0');
        oSER_DATA   : out std_logic;
        oPAR_DATA   : out std_logic_vector(pWIDTH-1 downto 0)
    );
end shift_register;

architecture std of shift_register is
    signal data_reg : std_logic_vector(pWIDTH-1 downto 0) := (others => '0');
begin
    -------------------------------------
    oSER_DATA   <=  data_reg(0) when (pDIR = "RIGHT") else
                    data_reg(pWIDTH-1);
    oPAR_DATA   <= data_reg;
    -------------------------------------

    --!@brief Shift-register implementation
    shift_proc : process(iCLK)
    begin
        if (rising_edge(iCLK)) then
            if(iRST='1') then
                data_reg    <= (others => '0');
            elsif(iEN ='1')then
                if(iLOAD = '1') then
                    data_reg    <= iDATA;
                else
                    if (pDIR = "RIGHT") then
                        data_reg(pWIDTH-2 downto 0) <= data_reg(pWIDTH-1 downto 1);
                        data_reg(pWIDTH-1)          <= iSHIFT;
                    else    --LEFT
                        data_reg(pWIDTH-1 downto 1) <= data_reg(pWIDTH-2 downto 0);
                        data_reg(0)                 <= iSHIFT;
                    end if;
                end if;
            end if; --iRST+iEN
        end if; --rising_edge
    end process shift_proc;

end std;
