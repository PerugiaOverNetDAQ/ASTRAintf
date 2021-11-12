--!@file clock_divider.vhd
--!@brief Divisore di frequenza con la possibilità di regolare il duty cycle dell'onda rettangolare prodotta. In aggiunta ci sono uscite per la rilevazione dei fronti di salita e di discesa del segnale di output
--!@author Matteo D'Antonio, matteo.dantonio@studenti.unipg.it
--!@date 10/11/2021

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;


--!@copydoc clock_divider.vhd
entity clock_divider is
	generic(
		pPeriod				: natural 	:= 50;		-- Periodo di conteggio del contatore (che di fatto andrà a definire la frequenza del segnale PWM) espresso in "numero di cicli di clock"
		pDutyCycle			: natural 	:= 25;		-- Numero di cicli di clock per i quali l'uscita dovrà tenersi "alta"
		pPolarity			: std_logic := '0';		-- Logica di funzionamento del dispositivo. Se pPolarity=0-->logica positiva, se pPolarity=1-->logica negata
		pRiseFall2Count	: std_logic := '0'		-- Definiamo con "pRiseFall2Count" il parametro che seleziona quali fronti d'onda conteggiare. Se pRiseFall2Count=0--> rising edge, se pRiseFall2Count=1--> falling edge
		);
	port(
		--!Input
		iCLK 				: in std_logic;		-- Clock principale
		iRST 				: in std_logic;		-- Reset principale
		iEN 				: in std_logic;		-- Abilita il contatore per la generazione del segnale di clock d'uscita
		iEdgeCount_RST : in std_logic;		-- Ingresso per il reset del contatore dei fronti d'onda
		--!Output
		oCLK_OUT 			: out std_logic;							-- Uscita del dispositivo
		oCLK_OUT_RISING 	: out std_logic;							-- Uscita di segnalazione dei fronti di salita
		oCLK_OUT_FALLING 	: out std_logic;							-- Uscita di segnalazione dei fronti di discesa
		oEDGE_COUNTER 		: out std_logic_vector(11 downto 0)	-- Uscita contenente il numero di fronti di salita/discesa rilevati dal detector
		);
end clock_divider;


--!@copydoc clock_divider.vhd
architecture Behavior of clock_divider is
-- Set di segnali interni per
	signal sReset 				: std_logic;								-- Segnale di reset principale
	signal sCounter 			: std_logic_vector(25 downto 0);		-- Contatore per la generazione dell'onda rettangolare d'uscita
	signal sRiseCounter 		: std_logic_vector(11 downto 0);		-- Contatore per il conteggio del numero di fronti di salita
	signal sFallCounter 		: std_logic_vector(11 downto 0);		-- Contatore per il conteggio del numero di fronti di discesa
	signal sOutProc 			: std_logic;								-- ClockOut pre polarity-MUX
	signal sClockOut 			: std_logic;								-- ClockOut post polarity-MUX
	signal sClockOutDelay_1	: std_logic;								-- ClockOut post polarity-MUX ritardato di 1 ciclo di clock
	signal sDetectRising 	: std_logic;								-- Uscita del detector dei fronti di salita
	signal sDetectFalling 	: std_logic;								-- Uscita del detector dei fronti di discesa
	
begin
	-- Assegnazione della porta di reset ad un segnale interno
	sReset <= iRST;
	
	counter_PWM_process : process (iCLK)
	begin
		if rising_edge(iCLK) then
			if (iRST = '1') then									-- Se iRST=0 --> azzera il contatore
				sCounter <= (others => '0');
			elsif (iEN = '1') then								-- Se iEN=1 --> abilita l'incremento del contatore PWM, altrimenti tieni il conteggio "congelato"
					if (sCounter < (pPeriod - 1)) then		-- Se sCounter<pPeriod --> incrementa il contatore. Il termine "-1" tiene conto del fatto che un ciclo di clock va "sprecato" per azzerare il contatore. Quindi in quel ciclo lì non andremo ad incrementarlo
						sCounter <= sCounter + 1;				-- Se iEN=1 --> l'incremento è effettivo, altrimenti se iEN=1 tieni il conteggio "congelato"
					else
						sCounter <= (others => '0');			-- Se sCounter>=pPeriod --> azzera il contatore
					end if;
			end if;
		end if;
	end process;
	
	output_process : process (iCLK)
	begin
		if rising_edge(iCLK) then
			if (iRST = '1') then							-- Se iRST=0 --> Manda in uscita un valore "basso"
				sOutProc <= '0';
			elsif (sCounter < pDutyCycle) then		-- Se sCounter<pDutyCycle --> Manda in uscita un valore "alto". NOTA: si utilizza il "<" e non il "<=" in quanto la condizione del costrutto "if" viene verificata un istante prima del fronte di salita del clock (cioè in "sCounter-1"), mentre il corpo "dell'if" viene eseguito nell'istante attuale (cioè in "sCounter")
				sOutProc <= '1';
			else
				sOutProc <= '0';							-- Se sCounter>=pDutyCycle --> Manda in uscita un valore "basso"
			end if;
		end if;
	end process;
	
	FFD1_process : process (iCLK)				-- Questo Flip Flop D serve per memorizzare lo stato precedente (rispetto a quello attuale) del segnale PWM che stiamo generando
	begin
		if rising_edge(iCLK) then				-- Ad ogni fronte di salita del clock, "sClockOutDelay_1" contiene il valore dell'uscita nel ciclo di clock precedente
			if (iRST = '1') then
				sClockOutDelay_1 <= '0';
			else
				sClockOutDelay_1 <= sClockOut;
			end if;
		end if;
	end process;
	
	rising_edge_counter_process : process (iCLK)
	begin
		if rising_edge(iCLK) then											
			if (iEdgeCount_RST = '1' or iRST = '1') then		-- Condizione di reset del contatore dei fronti d'onda
				sRiseCounter <= (others => '0');
			elsif	(sDetectRising = '1') then						-- Ogni volta che cambia lo stato d'uscita del oCLK_OUT_RISING, se questo vale '1' incrementa il contatore dei fronti d'onda altrimenti lascia il valore inalterato
				sRiseCounter <= sRiseCounter + 1;
			end if;
		end if;
	end process;
	
	falling_edge_counter_process : process (iCLK)
	begin
		if rising_edge(iCLK) then															
			if (iEdgeCount_RST = '1' or iRST = '1') then		-- Condizione di reset del contatore dei fronti d'onda
				sFallCounter <= (others => '0');
			elsif	(sDetectFalling = '1') then					-- Ogni volta che cambia lo stato d'uscita del oCLK_OUT_RISING, se questo vale '1' incrementa il contatore dei fronti d'onda altrimenti lascia il valore inalterato
				sFallCounter <= sFallCounter + 1;
			end if;
		end if;
	end process;
		

	-- Data Flow per il controllo dell'uscita
	with pPolarity select
		sClockOut <= sOutProc when '0',										-- Se pPolarity=0 --> utilizziamo una logica normale, cioè il segnale sOutProc viene riportato in uscita così com'è
						(not sOutProc) and (not sReset) when others;		-- Se pPolarity=1 --> utilizziamo una logica negata, cioè il segnale sOutProc viene riportato in uscita negato	 
	oCLK_OUT <= sClockOutDelay_1;	
	
	-- Data Flow per il controllo dei fronti di salita
	sDetectRising <= ((sClockOutDelay_1 xor sClockOut) and sClockOut) and (not sReset);			-- Se ClockOut[k-1]=0, ClockOut[k]=1 --> oCLK_OUT_RISING=1. In tutti gli altri casi oCLK_OUT_RISING=0
	oCLK_OUT_RISING <= sDetectRising;
	
	-- Data Flow per il controllo dei fronti di discesa
	sDetectFalling <= (sClockOutDelay_1 xor sClockOut) and (not sClockOut) and (not sReset);	-- Se ClockOut[k-1]=1, ClockOut[k]=0 --> oCLK_OUT_FALLING=1. In tutti gli altri casi oCLK_OUT_FALLING=0
	oCLK_OUT_FALLING <= sDetectFalling;
	
	-- Data Flow per il conteggio dei fronti d'onda
	with pRiseFall2Count select
		oEDGE_COUNTER <= sRiseCounter when '0',			-- Se pRiseFall2Count=0 conteggia i fronti di salita, altrimenti quelli di discesa
							  sFallCounter when others;
	
	
end Behavior;

