--!@file PRG.vhd
--!@brief Modulo per la programmazione dei canali del chip ASTRA
--!@author Matteo D'Antonio, matteo.dantonio@studenti.unipg.it

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;


--!@copydoc PRG.vhd
entity PRG is
  generic(
    pParametro : natural := 0
    );
  port(
    iCLK         : in  std_logic;       -- Clock
    iRST         : in  std_logic;       -- Reset
    -- Enable
    iEN          : in  std_logic;       -- Abilitazione del modulo PRG
    -- Setting from ASTRA Interface
    iCH_Sel      : in  std_logic_vector(5 downto 0);
    iCH_Mask     : in  std_logic;
    iCH_TP_EN    : in  std_logic;
    iCH_Disc     : in  std_logic;
    -- Output to ASTRA chip
    oPRG_CLK      : out  std_logic;                       -- Clock
    oPRG_BIT      : in  std_logic_vector(31 downto 0);    -- Output Flag
    );
end PRG;


--!@copydoc PRG.vhd
architecture Behavior of PRG is

-- Set di segnali utili per
  signal sSegnale      : std_logic;  -- 
  signal sSegnale      : std_logic;  -- 
  

begin
  -- Assegnazione segnali interni del PRG alle porte di I/O
  o        <= sSegnale;
  o        <= sSegnale;
  
  
  
  
end Behavior;


