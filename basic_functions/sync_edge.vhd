--!@file sync_edge.vhd
--!@brief Synchronizes an external signal and detects its edges
--!@author Mattia Barbanera, mattia.barbanera@infn.it
--!@author Hikmat Nasimi, hikmat.nasimi@pi.infn.it
--!@date 10/08/2017
--!@version 1.0 - 10/08/2017 -

library ieee;
use ieee.std_logic_1164.all;
use work.basic_package.sync_stage;
use work.basic_package.edge_detector;

--!@brief Synchronizes an external signal and detects its edges
entity sync_edge is
    generic(
        pSTAGES  : natural :=2  --!Synchronization stages. Must be at least 2
    );
    port(
        iCLK    : in  std_logic;
        iRST    : in  std_logic;
        iD      : in  std_logic;
        oQ      : out std_logic;
        oEDGE_R : out std_logic;
        oEDGE_F : out std_logic
    );
end entity sync_edge;

architecture std of sync_edge is
    signal s_sync_d    : std_logic;
begin
    sync_i    : sync_stage
    generic map(
        pSTAGES => pSTAGES-1
    )
    port map(
        iCLK    => iCLK,
        iRST    => iRST,
        iD      => iD,
        oQ      => s_sync_d
    );

    ed_i    : edge_detector
    port map(
        iCLK    => iCLK,
        iRST    => iRST,
        iD      => s_sync_d,
        oQ      => oQ,
        oEDGE_R => oEDGE_R,
        oEDGE_F => oEDGE_F
    );

end architecture std;
