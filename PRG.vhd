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
		pNumBlock             : natural := 2;         --!Numero di partizioni ASTRA utilizzate (min=1, max=2)
    pChannelPerBlock      : natural := 32        --!Numero di canali analogici d'ingresso per singola partizione
		);
  port(
    iCLK         				  : in  std_logic;        --!Clock principale
    iRST         				  : in  std_logic;        --!Reset principale
    -- Enable
    iEN          				  : in  std_logic;        --!Abilitazione del modulo PRG
    iWE		     				    : in  std_logic;        --!Configura il chip ASTRA con i valori "Local" e Global" in ingresso
    -- ASTRA Local Setting
    iCH_Mask     				  : in  std_logic_vector((pNumBlock*pChannelPerBlock)-1 downto 0);
    iCH_TP_EN    				  : in  std_logic_vector((pNumBlock*pChannelPerBlock)-1 downto 0);
    iCH_Disc     				  : in  std_logic_vector((pNumBlock*pChannelPerBlock)-1 downto 0);
    oLOCAL_SETTING   		  : out tAstraLocalSetting;
    -- ASTRA Global Setting
    iGLOBAL_SETTING  		  : in  tAstraGlobalSetting;
    oGLOBAL_SETTING			  : out tAstraGlobalSetting;
    -- PRG Clock Divider
    iPERIOD_CONFIG_CLOCK	: in  std_logic_vector(31 downto 0);		--!Periodo dello SlowClock in numero di cicli del main clock
    iDC_CONFIG_CLOCK			: in  std_logic_vector(31 downto 0);		--!Duty Cycle dello SlowClock in numero di cicli del main clock
    -- Output Flag
    oFLAG				          : out tControlIntfOut    --! Se busy='1', il PRG è impegnato nella cofigurazione locale del chip ASTRA, altrimenti è libero di ricevere comandi
    );
end PRG;


--!@copydoc PRG.vhd
architecture Behavior of PRG is
--!Il PRG è una FSM costituita da soli 3 stati
  type tStatus is (RESET, LISTENING, CONFIG);
  signal sPS : tStatus;
  
--!Dichiarazione del tipo per selezionare i canali locali
  type tChannelSel is (DISCRIMINATOR, TEST_PULSE, MASK);
  signal sCS : tChannelSel;

--!Reset in ingresso al clock_divider 
  signal sClockDividerReset   : std_logic;
--!Fronti di salita del clock_divider
  signal sClkOutRising   	    : std_logic;
--!Fronti di discesa del clock_divider
  signal sClkOutFalling   	  : std_logic;
--!Numero del canale locale selezionato
  signal sChCounter					  : natural range 0 to 127;


begin
  --!Slow clock con frequenza [1-5 MHz]
	SlowClockGen : clock_divider
	generic map(
		pPolarity 			=> '0'
		)
	port map(
		iCLK 					    => iCLK,
		iRST 					    => sClockDividerReset,
		iEN 					    => iEN,
		iPERIOD			 	    => iPERIOD_CONFIG_CLOCK,
		iDUTY_CYCLE			  => iDC_CONFIG_CLOCK,
		oCLK_OUT 			    => oLOCAL_SETTING.clk,
		oCLK_OUT_RISING 	=> sClkOutRising,
		oCLK_OUT_FALLING 	=> sClkOutFalling
		);
  
  --!Implementazione della macchina a stati
  StateFSM_proc : process (iCLK)
  begin 
    if (rising_edge(iCLK)) then
      if (iRST = '1') then
        --!Stato di RESET
        -- Local Config Reset
        oLOCAL_SETTING.rst	<= '1';								                        -- Local Config Reset = '1'
        -- Global Config Reset
        oGLOBAL_SETTING		  <= ('0', '0', '1', '0', '0', '0', '0', '0');	-- PT1='1' (GAIN --> "01")
        -- Other
        oFLAG					      <= ('0', '0', '1', '0');								      -- reset FLAG = '1'
        sClockDividerReset  <= '1';
        sPS           	 	  <= LISTENING;
        
      elsif (iEN = '1') then
        --!Valori di default che verranno sovrascritti, se necessario
        oLOCAL_SETTING.rst	<= '0';
        oFLAG.reset	        <= '0';
        oFLAG.busy	        <= '0';
        case (sPS) is
        
          --!Ascolta le richieste di configurazione Locale o Globale
          when LISTENING =>
            if (iWE = '1') then
              sPS                 <= CONFIG;
            else
              sClockDividerReset  <= '0';
              sChCounter          <= pChannelPerBlock - 1;
              sCS           	 	  <= DISCRIMINATOR;
              oGLOBAL_SETTING		  <= iGLOBAL_SETTING;
              sPS                 <= LISTENING;
            end if;
            
          --!Configura il chip ASTRA
          when CONFIG =>
            oFLAG.busy	<= '1';
            if (sChCounter + 1 > 0) then
              if (sClkOutRising = '1') then
                case (sCS) is
                  when DISCRIMINATOR =>
                    oLOCAL_SETTING.Bit_A  <= iCH_Disc(sChCounter);
                    oLOCAL_SETTING.Bit_B  <= iCH_Disc(sChCounter + (pChannelPerBlock*(pNumBlock - 1)));
                    sCS           	 	    <= TEST_PULSE;
                  when TEST_PULSE =>
                    oLOCAL_SETTING.Bit_A  <= iCH_TP_EN(sChCounter);
                    oLOCAL_SETTING.Bit_B  <= iCH_TP_EN(sChCounter + (pChannelPerBlock*(pNumBlock - 1)));
                    sCS           	 	    <= MASK;
                  when MASK =>
                    oLOCAL_SETTING.Bit_A  <= iCH_Mask(sChCounter);
                    oLOCAL_SETTING.Bit_B  <= iCH_Mask(sChCounter + (pChannelPerBlock*(pNumBlock - 1)));
                    sChCounter            <= sChCounter - 1;                                        
                    sCS           	 	    <= DISCRIMINATOR;
                  when others =>
                    oFLAG.error	          <= '1';
                    sClockDividerReset    <= '1';
                    sChCounter            <= 0;
                    sCS           	 	    <= MASK;
                end case;
              end if;
            else
              sPS   <= LISTENING;
            end if;
            
          when others =>
            oFLAG.error	        <= '1';
            sClockDividerReset  <= '1';
            sChCounter          <= 0;
            sPS                 <= LISTENING;
				end case;  
      end if;
    end if;
  end process;


end Behavior;


