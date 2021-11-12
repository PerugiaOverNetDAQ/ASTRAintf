--!@file PRG.vhd
--!@brief Modulo per la configurazione dei canali del chip ASTRA
--!@author Matteo D'Antonio, matteo.dantonio@studenti.unipg.it
--!@date 08/11/2021

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;


--!@copydoc PRG.vhd
entity PRG is
  generic(
    pDualChannel : std_logic := '1'         -- Numero di partizioni del chip ASTRA. Se DualChannel='1', andranno configurati 64 canali analogici (32 per ogni partizione); nel qual caso le due partizioni vengono configurate all'unisono. Altrimenti, se DualChannel='0', vengono configurati solo 32 canali.   Di default DualChannel='1' --> 64 canali analogici d'ingresso
    );
  port(
    iCLK         : in     std_logic;        -- Clock principale del modulo PRG
    iRST         : in     std_logic;        -- Reset principale del modulo PRG
    -- Enable
    iEN          : in     std_logic;        -- Abilitazione del modulo PRG
    iWE_Local    : in     std_logic;        -- Write Enable dei segnali di "Local Setting"
    iWE_Global   : in     std_logic;        -- Write Enable dei segnali di "Global Setting"
    -- Local Setting
    iCH1_Mask     : in     std_logic_vector(31 downto 0);     -- Se iCH1_Mask(n)  ='0', il canale n-esimo della partizione 1 è abilitato alla ricezione della carica. Se CH1_Mask(n)='1'il canale n-esimo è disabilitato.                                           Di default iCH1_Mask(n)   ='0' --> channel ON
    iCH1_TP_EN    : in     std_logic_vector(31 downto 0);     -- Se iCH1_TP_EN(n) ='0', il circuito di test per l'iniezione artificiale della carica sul canale n-esimo della partizione 1 è disconnesso. Se iCH1_TP_EN(n)='1' il circuito di test è connesso.      Di default iCH1_TP_EN(n)  ='0' --> test OFF
    iCH1_Disc     : in     std_logic_vector(31 downto 0);     -- Se iCH1_Disc(n)  ='1', l'uscita del discriminatore n-esimo per la generazione del trigger relativo alla partizione 1 è abilitata. Se iCH1_Disc(n)='0' l'uscita del discriminatore è disabilitata.  Di default iCH1_Disc      ='1' --> trigger ON
    iCH2_Mask     : in     std_logic_vector(31 downto 0);     --    "   PARTIZIONE 2  "
    iCH2_TP_EN    : in     std_logic_vector(31 downto 0);     --    "   PARTIZIONE 2  "
    iCH2_Disc     : in     std_logic_vector(31 downto 0);     --    "   PARTIZIONE 2  "
    -- Global Setting
    iG1_SER_TX_dis       : in     std_logic;      -- Bit per disabilitare la trasmissione dati da parte del serializzatore della partizione 1.                         Di default iSER_TX_dis        ='0' --> serializzatore ON
    iG1_debug_en         : in     std_logic;      -- Bit per abilitare le PAD di debug dei segnali d'uscita dagli shaper dei canali [21, 28] della partizione 1.       Di default iG1_debug_en       ='0' --> debug OFF
    iG1_PT1              : in     std_logic;      -- LSB della configurazione di peaking time dello shaper della partizione 1.                                         Di default iG1_PT1            ='1' --> 6.5 us
    iG1_PT2              : in     std_logic;      -- MSB della configurazione di peaking time dello shaper della partizione 1.                                         Di default iG1_PT1            ='0' --> 6.5 us
    iG1_FastOR_TX_dis    : in     std_logic;      -- Bit per disabilitare il circuito di FAST-OR dedito alla generazione del segnale di trigger della partizione 1.    Di default iG1_FastOR_TX_dis  ='0' --> fast-or ON
    iG1_EXT_BIAS         : in     std_logic;      -- Bit per forzare il chip ASTRA ad utilizzare i BIAS esterni sulla partizione 1.                                    Di default iG1_EXT_BIAS       ='0' --> external bias NO FORCED
    iG1_GAIN             : in     std_logic;      -- Bit per impostare il guadagno del pre-amplificatore.                                                              Di default iG1_GAIN           ='0' --> [1.6, 160 fC] range dinamico d'ingresso
    iG1_POL              : in     std_logic;      -- Bit per impostare la polarità +/- dei canali.                                                                     Di default iG1_POL            ='0' --> n-strips, p-substrate detector
    iG2_SER_TX_dis       : in     std_logic;      --    "   PARTIZIONE 2  "
    iG2_debug_en         : in     std_logic;      --    "   PARTIZIONE 2  "
    iG2_PT1              : in     std_logic;      --    "   PARTIZIONE 2  "
    iG2_PT2              : in     std_logic;      --    "   PARTIZIONE 2  "
    iG2_FastOR_TX_dis    : in     std_logic;      --    "   PARTIZIONE 2  "
    iG2_EXT_BIAS         : in     std_logic;      --    "   PARTIZIONE 2  "
    iG2_GAIN             : in     std_logic;      --    "   PARTIZIONE 2  "
    iG2_POL              : in     std_logic;      --    "   PARTIZIONE 2  "
    -- Output to ASTRA (Local Configuration)
    oPRG1_CLK      : out   std_logic;                       -- Slow Clock (1 - 5 MHz) in ingresso allo shift register delle configurzioni locali (PARTIZIONE 1 --> CANALI [1, 32])
    oPRG1_BIT      : out   std_logic_vector(31 downto 0);   -- Bit stream in ingresso allo shift register delle configurzioni locali (PARTIZIONE 1 --> CANALI [1, 32])
    oPRG1_RST      : out   std_logic;                       -- Reset in ingresso allo shift register delle configurzioni locali (PARTIZIONE 1 --> CANALI [1, 32])
    oPRG2_CLK      : out   std_logic;                       --    "   PARTIZIONE 2  "
    oPRG2_BIT      : out   std_logic_vector(31 downto 0);   --    "   PARTIZIONE 2  "
    oPRG2_RST      : out   std_logic;                       --    "   PARTIZIONE 2  "
    -- Output to ASTRA (Global Configuration)
    oG1_SER_TX_dis       : out     std_logic;      -- Bit per disabilitare la trasmissione dati da parte del serializzatore della partizione 1
    oG1_debug_en         : out     std_logic;      -- Bit per abilitare le PAD di debug dei segnali d'uscita dagli shaper dei canali [21, 28] della partizione 1
    oG1_PT1              : out     std_logic;      -- LSB della configurazione di peaking time dello shaper della partizione 1
    oG1_PT2              : out     std_logic;      -- MSB della configurazione di peaking time dello shaper della partizione 1
    oG1_FastOR_TX_dis    : out     std_logic;      -- Bit per disabilitare il circuito di FAST-OR dedito alla generazione del segnale di trigger della partizione 1
    oG1_EXT_BIAS         : out     std_logic;      -- Bit per forzare il chip ASTRA ad utilizzare i BIAS esterni sulla partizione 1
    oG1_GAIN             : out     std_logic;      -- Bit per impostare il guadagno del pre-amplificatore
    oG1_POL              : out     std_logic;      -- Bit per impostare la polarità +/- dei canali
    oG2_SER_TX_dis       : out     std_logic;      --    "   PARTIZIONE 2  "
    oG2_debug_en         : out     std_logic;      --    "   PARTIZIONE 2  "
    oG2_PT1              : out     std_logic;      --    "   PARTIZIONE 2  "
    oG2_PT2              : out     std_logic;      --    "   PARTIZIONE 2  "
    oG2_FastOR_TX_dis    : out     std_logic;      --    "   PARTIZIONE 2  "
    oG2_EXT_BIAS         : out     std_logic;      --    "   PARTIZIONE 2  "
    oG2_GAIN             : out     std_logic;      --    "   PARTIZIONE 2  "
    oG2_POL              : out     std_logic;      --    "   PARTIZIONE 2  "
    -- Output Flag
    oBusy         : out   std_logic    -- Se oBusy='1', il PRG è impegnato nella cofigurazione locale del chip ASTRA, altrimenti è libero di ricevere comandi
    );
end PRG;


--!@copydoc PRG.vhd
architecture Behavior of PRG is
-- Dichiarazione degli stati della FSM
  type tStatus is (RESET, LISTENING, CONFIG);  -- Il PRG è una macchina a stati costituita da 3 stati.
  signal sPS : tStatus;

-- Set di segnali utili per
  signal sSegnale      : std_logic;  -- 
  signal sSegnale      : std_logic;  -- 
  

begin
  -- Assegnazione segnali interni del PRG alle porte di I/O
  o        <= sSegnale;
  o        <= sSegnale;
  
  -- Implementazione della macchina a stati
  StateFSM_proc : process (iCLK)
  begin 
    if (rising_edge(iCLK)) then
      if (iRST = '1') then
        -- Stato di RESET. Si entra in questo stato solo se qualcuno dall'esterno alza il segnale di reset
        
        oPRG1_CLK      <= '0';
        oPRG2_CLK      <= '0';
        oPRG1_RST      <= '1';
        oPRG2_RST      <= '1';
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


