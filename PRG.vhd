--!@file PRG.vhd
--!@brief Modulo per la configurazione dei canali del chip ASTRA
--!@details
--!
--!Configurazione locale "iCH" e globale "iG" dei canali ASTRA
--!
--! | Abbr  | Default | Description |
--! |-------|-------------|---------|
--! | iCH_Mask | x"00000000" | Disabilitazione alla ricezione della carica sul canale n-esimo, '0'= channel ON, '1'= channel OFF |
--! | iCH_TP_EN | x"00000000" | Abilitazione del circuito di test per l'iniezione artificiale della carica sul canale n-esimo, '0'= disabled, '1'= enabled |
--! | iCH_Disc | x"FFFFFFFF" | Abilitazione del circuito discriminatore per la generazione del trigger, '0'= disabled, '1'= enabled |
--! | iG_SER_TX_dis  | "00" | Bit per disabilitare la trasmissione dati da parte del serializzatore, '0'= serializzatore ON |
--! | iG_debug_en | "00" | Bit per abilitare le PAD di debug dei segnali d'uscita dagli shaper dei canali [21, 28], '0'= debug OFF |
--! | iG_PT1 | "11" | LSB della configurazione di peaking time dello shaper, '1'= 6.5 us |
--! | iG_PT2 | "00" | MSB della configurazione di peaking time dello shaper, '0'= 6.5 us |
--! | iG_FastOR_TX_dis | "00" | Bit per disabilitare il circuito di FAST-OR dedito alla generazione del segnale di trigger, '0'= fast-or ON |
--! | iG_EXT_BIAS | "00" | Bit per forzare il chip ASTRA ad utilizzare i BIAS esterni, '0'=external bias NO FORCED |
--! | iG_GAIN | "00" | Bit per impostare il guadagno del pre-amplificatore, '0'= [1.6, 160 fC] range dinamico d'ingresso |
--! | iG_POL | "00" | Bit per impostare la polarità +/- dei canali, '0'= n-strips p-substrate, '1'= p-strips n-substrate,  |
--!
--!@author Matteo D'Antonio, matteo.dantonio@studenti.unipg.it
--!@date 08/11/2021

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;


--!@copydoc PRG.vhd
entity PRG is
  generic(
    pNumChannel : natural := 64         -- Numero di canali analogici del chip ASTRA: 64(default) o 32.
    );
  port(
    iCLK         : in     std_logic;        --! Clock principale
    iRST         : in     std_logic;        --! Reset principale
    -- Enable
    iEN          : in     std_logic;        -- Abilitazione del modulo PRG
    iWE_Local    : in     std_logic;        -- Write Enable dei segnali di "Local Setting"
    iWE_Global   : in     std_logic;        -- Write Enable dei segnali di "Global Setting"
    -- Local Setting
    iCH_Mask     : in     std_logic_vector(pNumChannel-1 downto 0);
    iCH_TP_EN    : in     std_logic_vector(pNumChannel-1 downto 0);
    iCH_Disc     : in     std_logic_vector(pNumChannel-1 downto 0);
    -- Global Setting, bit 0 --> PARTIZIONE 1 --> CANALI [0, 31], bit 1 --> PARTIZIONE 2 --> CANALI [32, 63]
    iG_SER_TX_dis       : in     std_logic_vector(pDualBlock downto 0);
    iG_debug_en         : in     std_logic_vector(pDualBlock downto 0);
    iG_PT1              : in     std_logic_vector(pDualBlock downto 0);
    iG_PT2              : in     std_logic_vector(pDualBlock downto 0);
    iG_FastOR_TX_dis    : in     std_logic_vector(pDualBlock downto 0);
    iG_EXT_BIAS         : in     std_logic_vector(pDualBlock downto 0);
    iG_GAIN             : in     std_logic_vector(pDualBlock downto 0);
    iG_POL              : in     std_logic_vector(pDualBlock downto 0);
    -- Output to ASTRA (Local Configuration), bit 0 --> PARTIZIONE 1 --> CANALI [0, 31], bit 1 --> PARTIZIONE 2 --> CANALI [32, 63]
    oPRG_CLK      : out   std_logic;   		-- Slow Clock (1 - 5 MHz) in ingresso allo shift register delle configurzioni locali
    oPRG_BIT_A    : out   std_logic_vector(pDualBlock downto 0);   		-- Bit stream in ingresso allo shift register delle configurzioni locali
    oPRG_BIT_B    : out   std_logic_vector(pDualBlock downto 0);   		-- Bit stream in ingresso allo shift register delle configurzioni locali
	 oPRG_RST      : out   std_logic;   		-- Reset in ingresso allo shift register delle configurzioni locali
    -- Output to ASTRA (Global Configuration), bit 0 --> PARTIZIONE 1 --> CANALI [0, 31], bit 1 --> PARTIZIONE 2 --> CANALI [32, 63]
    oG_SER_TX_dis       : out     std_logic_vector(pDualBlock downto 0);
    oG_debug_en         : out     std_logic_vector(pDualBlock downto 0);
    oG_PT1              : out     std_logic_vector(pDualBlock downto 0);
    oG_PT2              : out     std_logic_vector(pDualBlock downto 0);
    oG_FastOR_TX_dis    : out     std_logic_vector(pDualBlock downto 0);
    oG_EXT_BIAS         : out     std_logic_vector(pDualBlock downto 0);
    oG_GAIN             : out     std_logic_vector(pDualBlock downto 0);
    oG_POL              : out     std_logic_vector(pDualBlock downto 0);
    -- Output Flag
    oBusy			: out   std_logic    -- Se oBusy='1', il PRG è impegnato nella cofigurazione locale del chip ASTRA, altrimenti è libero di ricevere comandi
    );
end PRG;


--!@copydoc PRG.vhd
architecture Behavior of PRG is
-- Dichiarazione degli stati della FSM
  type tStatus is (RESET, LISTENING, CONFIG);  -- Il PRG è una macchina a stati costituita da 3 stati.
  signal sPS : tStatus;

-- Set di segnali utili per
  signal sSegnaleQuelloChe    : std_logic;  -- 
  signal sSegnale   			   : std_logic;  -- 
  

begin
  -- Assegnazione segnali interni del PRG alle porte di I/O
  o        <= sSegnale;
  o        <= sSegnale;
  
  -- Implementazione della macchina a stati
  StateFSM_proc : process (iCLK)
  begin 
    if (rising_edge(iCLK)) then
      if (iRST = '1') then
        -- Stato di RESET. Si entra in questo stato solo se qualcuno (dall'esterno) alza il segnale di reset
        -- Local Config Reset
        oPRG1_CLK      <= '0';
        oPRG2_CLK      <= '0';
        oPRG1_RST      <= '1';
        oPRG2_RST      <= '1';
		  -- Global Config Reset
		  
		  -- Other Reset
        oBusy          <= '0';
        sPS            <= LISTENING;

      elsif (iEN = '1') then
        -- Valori di default che verranno sovrascritti, se necessario
        sSegnale     <= '1';
        sSegnale  <= '0';
        sSegnale  <= '0';
        case (sPS) is
                                -- Stato di LISTENING
          when LISTENING =>
            sSegnale     <= '0';  -- 
            sSegnale <= '1';
            if () then
              sPS <= CONFIG;
            else
              sPS <= LISTENING;
            end if;

                                        -- Stato di CONFIG
          when CONFIG =>
            if () then
              sSegnale <= cStart_of_packet;
              sSegnale   <= '1';
              sPS        <= LISTENING;
            else
              sPS <= CONFIG;
            end if;
  
  
  
  
end Behavior;


