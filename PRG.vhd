--!@file PRG.vhd
--!@brief Modulo per la configurazione dei canali del chip ASTRA
--!@details
--!
--!Configurazione locale "iCH" e globale "iG" dei canali ASTRA
--!
--! | Abbr  | Default | Description | eg |
--! |-------|-------------|---------|----|
--! | iCH_Mask | x"00000000" | Disabilitazione alla ricezione della carica sul canale n-esimo | '0'= channel ON, '1'= channel OFF |
--! | iCH_TP_EN | x"00000000" | Abilitazione del circuito di test per l'iniezione artificiale della carica sul canale n-esimo | '0'= disabled, '1'= enabled |
--! | iCH_Disc | x"FFFFFFFF" | Abilitazione del circuito discriminatore per la generazione del trigger | '0'= disabled, '1'= enabled |
--! | iG_SER_TX_dis  | '0' | Bit per disabilitare la trasmissione dati da parte del serializzatore | '0'= serializzatore ON |
--! | iG_debug_en | '0' | Bit per abilitare le PAD di debug dei segnali d'uscita dagli shaper dei canali [21, 28] | '0'= debug OFF |
--! | iG_PT1 | '1' | LSB della configurazione di peaking time dello shaper | '1'= 6.5 us |
--! | iG_PT2 | '0' | MSB della configurazione di peaking time dello shaper | '0'= 6.5 us |
--! | iG_FastOR_TX_dis | '0' | Bit per disabilitare il circuito di FAST-OR dedito alla generazione del segnale di trigger | '0'= fast-or ON |
--! | iG_EXT_BIAS | '0' | Bit per forzare il chip ASTRA ad utilizzare i BIAS esterni | '0'=external bias NO FORCED |
--! | iG_GAIN | '0' | Bit per impostare il guadagno del pre-amplificatore | '0'= [1.6, 160 fC] range dinamico d'ingresso |
--! | iG_POL | '0' | Bit per impostare la polarità +/- dei canali | '0'= n-strips p-substrate, '1'= p-strips n-substrate,  |
--!
--!@author Matteo D'Antonio, matteo.dantonio@studenti.unipg.it
--!@date 08/11/2021

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;

use work.basic_package.all;
use work.ASTRApackage.all;

--!@copydoc PRG.vhd
entity PRG is
  generic(
		pNumBlock             : natural := 2;         --!Blocchi ASTRA (min=1, max=2)
    pChannelPerBlock      : natural := 32         --!Canali per singolo blocco
		);
  port(
    iCLK         				  : in  std_logic;        --!Clock principale
    iRST         				  : in  std_logic;        --!Reset principale
    -- Enable
    iEN          				  : in  std_logic;        --!Abilitazione del modulo PRG
    iWE		     				    : in  std_logic;        --!Configura il chip ASTRA con i valori "Local" e Global" in ingresso
    -- PRG Clock Divider
    iPERIOD_CLK	          : in  std_logic_vector(31 downto 0);		--!Periodo dello SlowClock in numero di cicli del main clock
    iDUTY_CYCLE_CLK			  : in  std_logic_vector(31 downto 0);		--!Duty Cycle dello SlowClock in numero di cicli del main clock
    -- Output Flag
    oFLAG				          : out tControlIntfOut;    --! Se busy='1', il PRG è impegnato nella cofigurazione locale del chip ASTRA, altrimenti è libero di ricevere comandi
    -- ASTRA Local Setting
    iCH_Mask     				  : in  std_logic_vector((pNumBlock*pChannelPerBlock)-1 downto 0);
    iCH_TP_EN    				  : in  std_logic_vector((pNumBlock*pChannelPerBlock)-1 downto 0);
    iCH_Disc     				  : in  std_logic_vector((pNumBlock*pChannelPerBlock)-1 downto 0);
    oLOCAL_SETTING   		  : out tAstraLocalSetting;
    -- ASTRA Global Setting
    iGLOBAL_SETTING  		  : in  tAstraGlobalSetting;
    oGLOBAL_SETTING			  : out tAstraGlobalSetting
    );
end PRG;


--!@copydoc PRG.vhd
architecture Behavior of PRG is
--!Il PRG è una FSM costituita da soli 3 stati
  type tPrgStatus is (RESET, IDLE, SYNCH, CONFIG_DISC, CONFIG_TP, CONFIG_MASK, CONFIG_END);
  signal sPS : tPrgStatus;

--!Contatore del tempo necessario allo stato di reset
  signal sResetCounter        : std_logic_vector(7 downto 0);
--!Slow Clock prodotto dal clock_divider
  signal sClkOut   	          : std_logic;
--!Switch per silenziare l'uscita del clock divider
  signal sClkOutEn   	        : std_logic; 
--!Fronti di salita del clock_divider
  signal sClkOutRising   	    : std_logic;
--!Fronti di discesa del clock_divider
  signal sClkOutFalling   	  : std_logic;
--!Selettore degli ingressi di configurazione locale
  signal sChCounter					  : integer range -2 to 127;


begin
  --!I pin di Global Setting di ASTRA sono connessi direttamente all'ingresso del PRG_Driver
  oGLOBAL_SETTING	<= iGLOBAL_SETTING;
  
  --!Slow clock con frequenza [1-5 MHz]
	SlowClockGen : clock_divider
	generic map(
		pPolarity 			=> '0'
		)
	port map(
		iCLK 					    => iCLK,
		iRST 					    => iRST,
		iEN 					    => '1',
		iPERIOD			 	    => iPERIOD_CLK,
		iDUTY_CYCLE			  => iDUTY_CYCLE_CLK,
		oCLK_OUT 			    => sClkOut,
		oCLK_OUT_RISING 	=> sClkOutRising,
		oCLK_OUT_FALLING 	=> sClkOutFalling
		);
  --!sCLK_OUT on/off
  oLOCAL_SETTING.clk <= sClkOut and sClkOutEn;
  
  --!Implementazione della macchina a stati
  StateFSM_proc : process (iCLK)
  begin 
    if (rising_edge(iCLK)) then
      if (iRST = '1') then
        --!Local Config Reset
        oLOCAL_SETTING.rst	  <= '1';								                     -- Local Config Reset = '1'
        oLOCAL_SETTING.bitA   <= '0';                                    -- Bit stream "A" = '0'
        oLOCAL_SETTING.bitB   <= '0';                                    -- Bit stream "B" = '0'
        --!Other
        oFLAG					        <= ('0', '0', '1', '0');								   -- reset FLAG = '1'
        sClkOutEn             <= '0';
        sResetCounter         <= (others => '0');
        sPS <= RESET;
      elsif (iEN = '1') then
        --!Valori di default che verranno sovrascritti, se necessario
        sClkOutEn           <= '0';
        oLOCAL_SETTING.rst	<= '0';
        oFLAG.reset	        <= '0';
        oFLAG.busy	        <= '0';
        case (sPS) is
        
          --!Attendi per almeno 1 ciclo di Slow Clock con il PRG_RESET alto
          when RESET =>
            if (sResetCounter < iPERIOD_CLK - 1) then 
              --!Local Config Reset
              oLOCAL_SETTING.rst	 <= '1';								                      -- Local Config Reset = '1'
              oLOCAL_SETTING.bitA  <= '0';                                     -- Bit stream "A" = '0'
              oLOCAL_SETTING.bitB  <= '0';                                     -- Bit stream "B" = '0'
              --!Other
              oFLAG					      <= ('0', '0', '1', '0');								      -- reset FLAG = '1'
              sResetCounter       <= sResetCounter + 1;
              sPS           	 	  <= RESET;
            else
              sResetCounter       <= (others => '0');
              sPS                 <= IDLE;
            end if;
          
          --!Ascolta le richieste di configurazione Locale o Globale
          when IDLE =>
            if (iWE = '1') then
              sChCounter          <= pChannelPerBlock - 1;
              sPS                 <= SYNCH;
            else
              sPS                 <= IDLE;
            end if;
          
          --!Sincronizza la bit stream dati rispetto al fronte di discesa dello Slow Clock
          when SYNCH =>
            if (sClkOutFalling = '1') then
              sClkOutEn             <= '1';
              oLOCAL_SETTING.bitA   <= iCH_Disc(sChCounter);
              oLOCAL_SETTING.bitB   <= iCH_Disc(sChCounter + (pChannelPerBlock*(pNumBlock - 1)));
              sPS                   <= CONFIG_TP;
            else
              sPS                   <= SYNCH;
            end if;
          
          --!Configura il Discriminatore
          when CONFIG_DISC =>
            sClkOutEn   <= '1';
            oFLAG.busy	<= '1';            
            if (sClkOutFalling = '1') then
              oLOCAL_SETTING.bitA  <= iCH_Disc(sChCounter);
              oLOCAL_SETTING.bitB  <= iCH_Disc(sChCounter + (pChannelPerBlock*(pNumBlock - 1)));
              sPS           	 	   <= CONFIG_TP;
            end if;
            
          --!Configura il Test Pulse
          when CONFIG_TP =>
            sClkOutEn   <= '1';
            oFLAG.busy	<= '1';            
            if (sClkOutFalling = '1') then
              oLOCAL_SETTING.bitA  <= iCH_TP_EN(sChCounter);
              oLOCAL_SETTING.bitB  <= iCH_TP_EN(sChCounter + (pChannelPerBlock*(pNumBlock - 1)));
              sPS           	 	   <= CONFIG_MASK;
          end if; 
            
          --!Configura la maschera
          when CONFIG_MASK =>
            sClkOutEn   <= '1';
            oFLAG.busy	<= '1';            
            if (sClkOutFalling = '1') then
              oLOCAL_SETTING.bitA  <= iCH_Mask(sChCounter);
              oLOCAL_SETTING.bitB  <= iCH_Mask(sChCounter + (pChannelPerBlock*(pNumBlock - 1)));
              sPS           	 	   <= CONFIG_MASK;
              sChCounter           <= sChCounter - 1;
              if (sChCounter > 0) then
                sPS   <= CONFIG_DISC;
              else
                sPS   <= CONFIG_END;
              end if;
            end if;
          
          --! Acquisizione dell'ultimo bit dello stream dati
          when CONFIG_END =>
            if (sClkOutFalling = '1') then
              sPS         <= IDLE;
            else
              sClkOutEn   <= '1';
              oFLAG.busy	<= '1';
            end if;
          
          --!Nessuno degli stati precedenti: errore  
          when others =>
            oFLAG.error	        <= '1';
            sClkOutEn           <= '0';
            sChCounter          <= 0;
            sPS                 <= IDLE;
				end case;  
      end if;
    end if;
  end process;


end Behavior;


