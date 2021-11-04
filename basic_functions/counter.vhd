--!@file counter.vhd
--!@brief pBUSWIDTH-bit counter with load and enable.
--!@author Mattia Barbanera, mattia.barbanera@infn.it
--!@author Hikmat Nasimi, hikmat.nasimi@pi.infn.it
--!@date 09/01/2020
--!@version 1.0 - 09/01/2020 -

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;
use ieee.numeric_std.all;

--!@brief pBUSWIDTH-bit counter with load and enable.
--!@details If pOVERLAP is "N", the counter stops at its maximum value.
entity counter is
    generic(
        pOVERLAP     : string  := "N"; --!if "N", the counter stops at its max
        pBUSWIDTH    : natural := 32   --!Bit-width of the counter
    );
    port(
        iCLK    : in  std_logic; --!Main clock
        iEN     : in  std_logic; --!Enable
        iRST    : in  std_logic; --!Reset
        iLOAD   : in  std_logic; --!Load the preset value
        iDATA   : in  std_logic_vector (pBUSWIDTH-1 downto 0); --!Preset value
        oCOUNT  : out std_logic_vector (pBUSWIDTH-1 downto 0); --!Result
        oCARRY  : out std_logic --!Carry in case of overflow
    );
end counter;

architecture std of counter is
    signal count    : std_logic_vector (pBUSWIDTH-1 downto 0);
    signal carry    : std_logic;
    signal eoc_word : std_logic_vector (pBUSWIDTH-1 downto 0);

    begin
        ------------------------------------------
        eoc_word    <= (others=>'1');
        carry       <= '1' when count = eoc_word else '0';
        ------------------------------------------

        --!@brief Counter with reset, load and enable
        counter_proc : process(iCLK)
        begin
            if (rising_edge(iCLK)) then
                if(iRST='1') then
                    count   <= (others=>'0');
                else
                    if(iLOAD = '1') then
                        count <= iDATA;
                    else
                        if (pOVERLAP = "N") then
                            if(carry = '1') then
                                count   <= count;
                            else
                                count   <= count + iEN;
                            end if;
                        else
                            count   <= count + iEN;
                        end if;
                    end if;
                end if;
            end if;
        end process counter_proc;

        --!@brief Add FFDs to the combinatorial signals
        ffds : process(iCLK)
        begin
            if (rising_edge(iCLK)) then
                oCOUNT  <= count;
                oCARRY  <= carry;
            end if;
        end process ffds;
end std;
