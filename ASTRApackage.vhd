--!@file ASTRApackage.vhd
--!@brief Constants, components declarations and functions
--!@author Mattia Barbanera, mattia.barbanera@infn.it

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.basic_package.all;

--!@copydo ASTRApackage
package FOOTpackage is
  constant cADC_DATA_WIDTH       : natural := 16;  --!ADC data-width
  constant cADC_FIFO_DEPTH       : natural := 256;  --!ADC FIFO number of words
  constant cTOTAL_ADC_WORDS_NUM  : natural := 2048;  --! numero totale massimo di parole da 16 bit nella fifo finale 1280??
  constant cFE_DAISY_CHAIN_DEPTH : natural := 2;   --!FEs in a daisy chain
  constant cFE_CHANNELS          : natural := 64;  --!Channels per FE
  constant cFE_CLOCK_CYCLES      : natural := cFE_DAISY_CHAIN_DEPTH*cFE_CHANNELS;  --!Number of clock cycles to feed a chain
  constant cFE_SHIFT_2_CLK       : natural := 2; --!Wait between FE shift and clock assertion
  constant cTOTAL_ADCS           : natural := 10; --!Total ADCs


  constant cFE_CLK_DIV   : std_logic_vector(15 downto 0) := int2slv(40, 16); --!FE SlowClock divider: was 160 at the GSI test beam
  constant cADC_CLK_DIV  : std_logic_vector(15 downto 0) := int2slv(2, 16);  --!ADC SlowClock divider
  constant cFE_CLK_DUTY  : std_logic_vector(15 downto 0) := int2slv(4, 16);  --!FE SlowClock duty cycle
  constant cADC_CLK_DUTY : std_logic_vector(15 downto 0) := int2slv(4, 16);  --!ADC SlowClock duty cycle
  --!iCFG_PLANE bits: 2:0: FE-Gs;  3: FE-test; 4: Ext-TRG; 15:5: x
  constant cCFG_PLANE    : std_logic_vector(15 downto 0) := x"0007";  --!uStrip configurations
  constant cTRG_PERIOD   : std_logic_vector(31 downto 0) := x"0000FFFF";  --!Clock cycles between two internal triggers
  constant cTRG2HOLD     : std_logic_vector(15 downto 0) := int2slv(325, 16);  --!Clock-cycles between an external trigger and the FE-HOLD signal

  -- Types for the FE interface ------------------------------------------------
  --!IDE1140_DS front-End input signals (from the FPGA)
  type tFpga2FeIntf is record
    G0      : std_logic;
    G1      : std_logic;
    G2      : std_logic;
    Hold    : std_logic;                -- Active High
    DRst    : std_logic;
    ShiftIn : std_logic;                -- Active Low
    Clk     : std_logic;
    TestOn  : std_logic;
  --Cal       : std_logic; --!@todo Table 2 (page 7) of datasaheet
  end record tFpga2FeIntf;

  --!IDE1140_DS front-End output signals (to the FPGA)
  type tFe2FpgaIntf is record
    ShiftOut : std_logic;               -- Active Low
  end record tFe2FpgaIntf;

  --!Control interface for a generic block: input signals
  type tControlIntfIn is record
    en     : std_logic;                 --!Enable
    start  : std_logic;                 --!Start
    slwClk : std_logic;                 --!Slow clock to forward to the device
    slwEn  : std_logic;                 --!Event for slow clock synchronisation
  end record tControlIntfIn;

  --!Control interface for a generic block: output signals
  type tControlIntfOut is record
    busy  : std_logic;                  --!Busy flag
    error : std_logic;                  --!Error flag
    reset : std_logic;                  --!Resetting flag
    compl : std_logic;                  --!completion of task
  end record tControlIntfOut;

  --!AD7276A ADC input signals (from the FPGA)
  type tFpga2AdcIntf is record
    SClk : std_logic;
    Cs   : std_logic;                   -- Active Low
  end record tFpga2AdcIntf;

  --!AD7276A ADC output signals (to the FPGA)
  type tAdc2FpgaIntf is record
    SData : std_logic;
  end record tAdc2FpgaIntf;

  --!Input signals of a typical FIFO memory
  type tFifoIn_ADC is record
    data : std_logic_vector(cADC_DATA_WIDTH-1 downto 0);  --!Input data port
    rd   : std_logic;                                     --!Read request
    wr   : std_logic;                                     --!Write request
  end record tFifoIn_ADC;

  --!Output signals of a typical FIFO memory
  type tFifoOut_ADC is record
    q      : std_logic_vector(cADC_DATA_WIDTH-1 downto 0);  --!Output data port
    aEmpty : std_logic;                                     --!Almost empty
    empty  : std_logic;                                     --!Empty
    aFull  : std_logic;                                     --!Almost full
    full   : std_logic;                                     --!Full
  end record tFifoOut_ADC;

  --!Output signals of the collector FIFOs
  type tAllFifoOut_ADC is record
    q      : std_logic_vector((2*cADC_DATA_WIDTH)-1 downto 0);  --!Output data port
    aEmpty : std_logic;                 --!Almost empty
    empty  : std_logic;                 --!Empty
    aFull  : std_logic;                 --!Almost full
    full   : std_logic;                 --!Full
  end record tAllFifoOut_ADC;

  --!Configuration ports to the MSD subpart
  type msd_config is record
    feClkDuty    : std_logic_vector(15 downto 0);  --!FE slowClock duty cycle
    feClkDiv     : std_logic_vector(15 downto 0);  --!FE slowClock divider
    adcClkDuty   : std_logic_vector(15 downto 0);  --!ADC slowClock duty cycle
    adcClkDiv    : std_logic_vector(15 downto 0);  --!ADC slowClock divider
    --!iCFG_PLANE bits: 2:0: FE-Gs;  3: FE-test; 4: Ext-TRG; 15:5: x
    cfgPlane     : std_logic_vector(15 downto 0);  --!uStrip configuration
    intTrgPeriod : std_logic_vector(31 downto 0);  --!Clock-cycles between two internal triggers
    trg2Hold     : std_logic_vector(15 downto 0);  --!Clock-cycles between an external trigger and the FE-HOLD signal
  end record msd_config;

  --!Multiple AD7276A ADCs output signals and FIFOs
  type tMultiAdc2FpgaIntf is array (0 to cTOTAL_ADCS-1) of tAdc2FpgaIntf;
  type tMultiAdcFifoIn is array (0 to cTOTAL_ADCS-1) of tFifoIn_ADC;
  type tMultiAdcFifoOut is array (0 to cTOTAL_ADCS-1) of tFifoOut_ADC;

  --!Initialization constants for the upper types
  constant c_FROM_FIFO_INIT : tFifoOut_ADC := (full   => '0',
                                               empty  => '1',
                                               aFull  => '0',
                                               aEmpty => '0',
                                               q      => (others => '0'));
  constant c_TO_FIFO_INIT : tFifoIn_ADC := (wr   => '0',
                                            data => (others => '0'),
                                            rd   => '0');
  constant c_TO_FIFO_INIT_ARRAY : tMultiAdcFifoIn := (others => c_TO_FIFO_INIT);
  constant c_FROM_FIFO_INIT_ARRAY : tMultiAdcFifoOut := (others => c_FROM_FIFO_INIT);

  -- Components ----------------------------------------------------------------
  --!@brief Low-level multiple AD7276 ADCs interface
  component multiADC_interface is
    port (
      --# {{clocks|Clock}}
      iCLK        : in  std_logic;
      --# {{control|Control}}
      iRST        : in  std_logic;
      oCNT        : out tControlIntfOut;
      iCNT        : in  tControlIntfIn;
      --# {{ADC Interface}}
      oADC        : out tFpga2AdcIntf;
      iMULTI_ADC  : in  tMultiAdc2FpgaIntf;
      --# {{data|ADC Data Output}}
      oMULTI_FIFO : out tMultiAdcFifoIn
      );
  end component multiADC_interface;
  
  --!@brief Divisore di frequenza con rilevamento dei fronti di salita e di discesa
  component clock_divider_md is
    generic(
	   pPeriod				: natural;		-- Periodo di conteggio del contatore (che di fatto andrà a definire la frequenza del segnale PWM) espresso in "numero di cicli di clock"
		pDutyCycle			: natural;		-- Numero di cicli di clock per i quali l'uscita dovrà tenersi "alta"
		pPolarity			: std_logic;	-- Logica di funzionamento del dispositivo. Se pPolarity=0-->logica positiva, se pPolarity=1-->logica negata
		pRiseFall2Count	: std_logic		-- Definiamo con "RiseFall2Count" il parametro che seleziona quali fronti d'onda conteggiare. Se RiseFall2Count=0--> rising edge, se RiseFall2Count=1--> falling edge
		);
	 port(
		--!Input
		iCLK 				: in std_logic;	-- Clock principale
		iRST 				: in std_logic;	-- Reset principale
		iEN 				: in std_logic;	-- Abilita il contatore per la generazione del segnale di clock d'uscita
		iEdgeCount_RST : in std_logic;	-- Ingresso per il reset del contatore dei fronti d'onda
		--!Output
		oCLK_OUT 			: out std_logic;							-- Uscita del dispositivo	
		oCLK_OUT_RISING 	: out std_logic;							-- Uscita di segnalazione dei fronti di salita
		oCLK_OUT_FALLING 	: out std_logic;							-- Uscita di segnalazione dei fronti di discesa
		oEDGE_COUNTER 		: out std_logic_vector(11 downto 0)	-- Uscita contenente il numero di fronti di salita/discesa rilevati dal detector
		);
  end component;

end FOOTpackage;
