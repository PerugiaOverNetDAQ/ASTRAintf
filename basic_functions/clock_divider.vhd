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
		pPOLARITY	: std_logic := '0'		--! Logica di funzionamento del dispositivo. Se pPOLARITY=0-->logica positiva, se pPOLARITY=1-->logica negata
		);
	port(
		-- Input
		iCLK 				: in std_logic;								--! Clock principale
		iRST 				: in std_logic;								--! Reset principale
		iEN 				: in std_logic;								--! Abilita il contatore per la generazione del segnale di clock d'uscita
		iPERIOD			: in std_logic_vector(31 downto 0);		--! Periodo di conteggio del contatore (che di fatto andrà a definire la frequenza del segnale PWM) espresso in "numero di cicli di clock"
																				--! NOTA BENE: per avere valori d'uscita significativi occorre iPERIOD > 1
		iDUTY_CYCLE		: in std_logic_vector(31 downto 0);		--! Numero di cicli di clock per i quali l'uscita dovrà tenersi "alta"
		-- Output
		oCLK_OUT 			: out std_logic;							--! Uscita del dispositivo
		oCLK_OUT_RISING 	: out std_logic;							--! Uscita di segnalazione dei fronti di salita
		oCLK_OUT_FALLING 	: out std_logic							--! Uscita di segnalazione dei fronti di discesa
		);
end clock_divider;


--!@copydoc clock_divider.vhd
architecture Behavior of clock_divider is
-- Set di segnali interni per
	signal sReset 				: std_logic;								--! Segnale di reset principale
	signal sCounter 			: std_logic_vector(31 downto 0);		--! Contatore per la generazione dell'onda rettangolare d'uscita
	signal sOutProc 			: std_logic;								--! ClockOut pre polarity-MUX
	signal sClockOut 			: std_logic;								--! ClockOut post polarity-MUX
	signal sClockOutDelay_1	: std_logic;								--! ClockOut post polarity-MUX ritardato di 1 ciclo di clock
	signal sClockOutDelay_2	: std_logic;								--! ClockOut post polarity-MUX ritardato di 2 cicli di clock
	
begin
	-- Assegnazione della porta di reset ad un segnale interno
	sReset <= iRST;
	
	counter_PWM_process : process (iCLK)
	begin
		if rising_edge(iCLK) then
			if (iRST = '1') then									-- Se iRST=1 --> azzera il contatore
				sCounter <= (others => '0');
			elsif (iEN = '1') then								-- Se iEN=1 --> abilita l'incremento del contatore PWM, altrimenti tieni il conteggio "congelato"
					if (sCounter < (iPERIOD - 1)) then		-- Se sCounter<iPERIOD --> incrementa il contatore. Il termine "-1" tiene conto del fatto che un ciclo di clock va "sprecato" per azzerare il contatore. Quindi in quel ciclo lì non andremo ad incrementarlo
						sCounter <= sCounter + 1;				-- Se iEN=1 --> l'incremento è effettivo, altrimenti se iEN=1 tieni il conteggio "congelato"
					else
						sCounter <= (others => '0');			-- Se sCounter>=iPERIOD --> azzera il contatore
					end if;
			end if;
		end if;
	end process;
	
	output_process : process (iCLK)
	begin
		if rising_edge(iCLK) then
			if (iRST = '1') then							-- Se iRST=1 --> Manda in uscita un valore "basso"
				sOutProc <= '0';
			elsif (sCounter < iDUTY_CYCLE) then		-- Se sCounter<iDUTY_CYCLE --> Manda in uscita un valore "alto". NOTA: si utilizza il "<" e non il "<=" in quanto la condizione del costrutto "if" viene verificata un istante prima del fronte di salita del clock (cioè in "sCounter-1"), mentre il corpo "dell'if" viene eseguito nell'istante attuale (cioè in "sCounter")
				sOutProc <= '1';
			else
				sOutProc <= '0';							-- Se sCounter>=iDUTY_CYCLE --> Manda in uscita un valore "basso"
			end if;
		end if;
	end process;
	
	-- Ritarda di 1 ciclo di clock il segnale "sClockOut". Infatti, noto sClockOut[k] e sClockOut[k-1], possiamo rilevare i fronti d'onda
	FFD1_process : process (iCLK)
	begin
		if rising_edge(iCLK) then
			if (iRST = '1') then
				sClockOutDelay_1 <= '0';
			else
				sClockOutDelay_1 <= sClockOut;
			end if;
		end if;
	end process;
	
	-- Ritarda di 2 cicli di clock il segnale "sClockOut". Serve per shiftare il segnale d'uscita di un ciclo di clock rispetto all'uscita dei detector dei fronti d'onda
	FFD2_process : process (iCLK)
	begin
		if rising_edge(iCLK) then
			if (iRST = '1') then
				sClockOutDelay_2 <= '0';
			else
				sClockOutDelay_2 <= sClockOutDelay_1;
			end if;
		end if;
	end process;
	
	-- Rileva i fronti di salita e discesa del segnale PWM generato
	edge_detector_process : process (iCLK)
	begin
		if rising_edge(iCLK) then
			if (iRST = '1') then
				oCLK_OUT_RISING 	<= '0';
				oCLK_OUT_FALLING 	<= '0';
			else
				oCLK_OUT_RISING 	<= ((sClockOutDelay_1 xor sClockOut) and sClockOut);			-- Se ClockOut[k-1]=0, ClockOut[k]=1 --> oCLK_OUT_RISING=1. In tutti gli altri casi oCLK_OUT_RISING=0
				oCLK_OUT_FALLING 	<= (sClockOutDelay_1 xor sClockOut) and (not sClockOut);		-- Se ClockOut[k-1]=1, ClockOut[k]=0 --> oCLK_OUT_FALLING=1. In tutti gli altri casi oCLK_OUT_FALLING=0
			end if;
		end if;
	end process;
	
	
	-- Data Flow per il controllo dell'uscita
	with pPOLARITY select
		sClockOut <= sOutProc when '0',										-- Se pPOLARITY=0 --> utilizziamo una logica normale, cioè il segnale sOutProc viene riportato in uscita così com'è
						(not sOutProc) and (not sReset) when others;		-- Se pPOLARITY=1 --> utilizziamo una logica negata, cioè il segnale sOutProc viene riportato in uscita negato	 
	oCLK_OUT <= sClockOutDelay_2;	
	
	
end Behavior;

