--!@file sync_stage.vhd
--!@brief Synchronize the external signals with the iCLK domain
--!@author Mattia Barbanera, mattia.barbanera@infn.it
--!@author Hikmat Nasimi, hikmat.nasimi@pi.infn.it
--!@date 09/01/2020
--!@version 1.0 - 09/01/2020 - Add syn_allow_retiming attributes

library ieee;
use ieee.std_logic_1164.all;

--!@brief Synchronize the external signals with the iCLK domain
entity sync_stage is
    generic(
        pSTAGES  : natural := 2 --!Synchronization stages. Must be at least 2
    );
    port(
        iCLK    : in  std_logic;
        iRST    : in  std_logic;  --!Reset; NOT CONNECTED
        iD      : in  std_logic;
        oQ      : out std_logic
    );
end entity;

architecture std of sync_stage is
    signal pipeline: std_logic_vector (pSTAGES-1 downto 0);

    -- syn_allow_retiming determines if registers can be
    -- moved across combinational logic to improve performance.
    -- They must not be moved for the synchronization stages.
    --!@todo Will the attributes syn_allow_retiming work with altera FPGAs?
    attribute syn_allow_retiming : boolean;
    attribute syn_allow_retiming of pipeline: signal is false;

begin
    oQ  <= pipeline(0);

    sync_proc : process (iCLK)
    begin
        if(rising_edge(iCLK)) then
            pipeline(pSTAGES-1) <= iD;
            if (pSTAGES >= 2) then
                pipeline(pSTAGES-2 downto 0) <= pipeline(pSTAGES-1 downto 1);
            end if;
        end if;
    end process sync_proc;

end std;
