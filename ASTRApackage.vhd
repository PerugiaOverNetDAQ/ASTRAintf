--!@file ASTRApackage.vhd
--!@brief Constants, components declarations and functions
--!@author Mattia Barbanera, mattia.barbanera@infn.it

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.basic_package.all;

--!@copydoc ASTRApackage.vhd
package ASTRApackage is
  constant cADC_DATA_WIDTH       : natural := 16;   --!ADC data-width
  constant cADC_FIFO_DEPTH       : natural := 256;  --!ADC FIFO number of words
  constant cADC_MULTIFIFO_DEPTH  : natural := 8;    --!ADC MULTI FIFO number of words
  constant cFE_DAISY_CHAIN_DEPTH : natural := 1;   --!FEs in a daisy chain
  constant cFE_CHANNELS          : natural := 32;  --!Channels per FE
  constant cFE_CLOCK_CYCLES      : natural := cFE_DAISY_CHAIN_DEPTH*cFE_CHANNELS;  --!Number of clock cycles to feed a chain
  constant cFE_SHIFT_2_CLK       : natural := 1; --!Wait between FE shift and clock assertion
  constant cTOTAL_ADCS           : natural := 2; --!Total ADCs

  constant cCLK_FREQ             : natural := 20; --!Clock frequency in ns (used only to compute delay)
  constant cMULT                  : natural := 320; --!Multiplier of the BUSY stretch in ns

  constant cFE_CLK_DIV   : std_logic_vector(15 downto 0) := int2slv(40, 16); --!FE SlowClock divider
  constant cADC_CLK_DIV  : std_logic_vector(15 downto 0) := int2slv(2, 16);  --!ADC SlowClock divider
  constant cFE_CLK_DUTY  : std_logic_vector(15 downto 0) := int2slv(4, 16);  --!FE SlowClock duty cycle
  constant cADC_CLK_DUTY : std_logic_vector(15 downto 0) := int2slv(4, 16);  --!ADC SlowClock duty cycle
  constant cTRG2HOLD     : std_logic_vector(15 downto 0) := int2slv(325, 16);  --!Clock-cycles between an external trigger and the FE-HOLD signal
  constant cADC_DELAY    : std_logic_vector(15 downto 0) := int2slv(29, 16);  --!Delay from the FE falling edge and the start of the AD conversion
  constant cBUSY_LEN     : std_logic_vector(15 downto 0) := int2slv((cFE_CLOCK_CYCLES*cTOTAL_ADCS*cCLK_FREQ)/(2*cMULT), 16);  --!320-ns duration of busy extension time

  constant cPRG_CLK_DIV  : std_logic_vector(15 downto 0) := int2slv(50, 16);  --!PRG clock period
  constant cPRG_CLK_DUTY : std_logic_vector(15 downto 0) := int2slv(25, 16);  --!PRG clock duty cycle

  -- Types for the FE interface ------------------------------------------------
  --!ASTRA front-End input signals (from the FPGA)
  type tFpga2FeIntf is record
    hold_b   : std_logic;
    readRst  : std_logic;
    shiftClk : std_logic;
    test     : std_logic;
  end record tFpga2FeIntf;

  --!ASTRA front-End output signals (to the FPGA)
  type tFe2FpgaIntf is record
    readRstRet  : std_logic;  
    shiftClkRet : std_logic;
  end record tFe2FpgaIntf;

  --!Control interface for a generic block: input signals
  type tControlIntfIn is record
    en     : std_logic; --!Enable
    start  : std_logic; --!Start
    slwClk : std_logic; --!Slow clock to forward to the device
    slwEn  : std_logic; --!Event for slow clock synchronisation
  end record tControlIntfIn;

  --!Control interface for a generic block: output signals
  type tControlIntfOut is record
    busy  : std_logic;  --!Busy flag
    error : std_logic;  --!Error flag
    reset : std_logic;  --!Resetting flag
    compl : std_logic;  --!completion of task
  end record tControlIntfOut;

  --!AD7276A ADC input signals (from the FPGA)
  type tFpga2AdcIntf is record
    SClk : std_logic;
    Cs   : std_logic; -- Active Low
  end record tFpga2AdcIntf;
  
  --!ASTRA ADC input signals (from the FPGA)
  type tFpga2AstraAdc is record
    RstDig    : std_logic;     --!Reset of the ADC, counter and serializer
    AdcConv   : std_logic;     --!Digital pulse to start the conversion of the ADC
    SerShClk  : std_logic;     --!Shift clock (1-10 MHz) to read the channels ADC data
    SerLoad   : std_logic;     --!Digital pulse to enable the serializer to load data
    SerSend   : std_logic;     --!Digital pulse to enable the serializer to output data
  end record tFpga2AstraAdc;

  --!AD7276A ADC output signals (to the FPGA)
  type tAdc2FpgaIntf is record
    SData  : std_logic;
    clkRet : std_logic;
    csRet  : std_logic;
  end record tAdc2FpgaIntf;
  
  --!ASTRA ADC output signals (to the FPGA)
  type tAstraAdc2Fpga is record
    SerData     : std_logic;      --!Input from serializer bit stream
    ClkRet      : std_logic;      --!Return clock from ASTRA
    SerSendRet  : std_logic;      --!Return SER_SEND from ASTRA
  end record tAstraAdc2Fpga;

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
  
  --!Shift register signals
  type tShiftRegInterface is record
    en     : std_logic;
    load   : std_logic;
    serIn  : std_logic;
    parIn  : std_logic_vector(cADC_DATA_WIDTH-1 downto 0);
    serOut : std_logic;
    parOut : std_logic_vector(cADC_DATA_WIDTH-1 downto 0);
  end record tShiftRegInterface;

  --!Multiple AD7276A ADCs output signals and FIFOs
  type tMultiAdc2FpgaIntf is array (0 to cTOTAL_ADCS-1) of tAdc2FpgaIntf;
  type tMultiAdcFifoIn is array (0 to cTOTAL_ADCS-1) of tFifoIn_ADC;
  type tMultiAdcFifoOut is array (0 to cTOTAL_ADCS-1) of tFifoOut_ADC;
  
  --!MultiShift register signals
  type tMultiShiftRegIntf is array (0 to cTOTAL_ADCS-1) of tShiftRegInterface;
  
  --!Multiple ASTRA ADCs output signals
  type tMultiAstraAdc2Fpga is array (0 to cTOTAL_ADCS-1) of tAstraAdc2Fpga;

  --!Initialization constants for the upper types
  constant c_TO_FIFO_INIT : tFifoIn_ADC := (wr   => '0',
                                            data => (others => '0'),
                                            rd   => '0');
  constant c_FROM_FIFO_INIT : tFifoOut_ADC := (full   => '0',
                                               empty  => '1',
                                               aFull  => '0',
                                               aEmpty => '0',
                                               q      => (others => '0'));
  constant c_TO_FIFO_INIT_ARRAY : tMultiAdcFifoIn := (others => c_TO_FIFO_INIT);
  constant c_FROM_FIFO_INIT_ARRAY : tMultiAdcFifoOut := (others => c_FROM_FIFO_INIT);

  --!Configuration ports to the MSD subpart
  type astraConfig is record
    feClkDiv    : std_logic_vector(15 downto 0);  --!FE slowClock divider  
    feClkDuty   : std_logic_vector(15 downto 0);  --!FE slowClock duty cycle
    adcClkDiv   : std_logic_vector(15 downto 0);  --!ADC slowClock divider
    adcClkDuty  : std_logic_vector(15 downto 0);  --!ADC slowClock duty cycle
    adcIntClkDiv    : std_logic_vector(15 downto 0);  --!Fast clock duration (in number of iCLK cycles) to drive ADC counter and serializer
    adcIntClkDuty   : std_logic_vector(15 downto 0);  --!Duty cycle fast clock duration (in number of iCLK cycles)
    adcIntConvTime  : std_logic_vector(15 downto 0);  --!Conversion time (in number of iCLK cycles)
    trg2Hold    : std_logic_vector(15 downto 0);  --!Clock-cycles between an external trigger and the FE-HOLD signal
    extendBusy  : std_logic_vector(15 downto 0);  --!320-ns duration of busy extension time
    adcDelay    : std_logic_vector(15 downto 0);  --!Delay from FEclk to ADC start
    adcFastMode : std_logic;
    prgStart    : std_logic;
    prgClkDiv   : std_logic_vector(15 downto 0);  --!PRG interface clock divider
    prgClkDuty  : std_logic_vector(15 downto 0);  --!PRG interface clock duty cycle
    chMask      : std_logic_vector(63 downto 0);  --!Channels mask
    chTpEn      : std_logic_vector(63 downto 0);  --!Test-pulse enable
    chDisc      : std_logic_vector(63 downto 0);  --!Discriminator enable
  end record astraConfig;
  
  --!ASTRA Global setting interface
  type tAstraGlobalSetting is record
    serialTxDisable : std_logic;  --!Disable the serializer
    debugEn         : std_logic;  --!Enable the 8 debug output ports
    peakTime1       : std_logic;  --!Peaking-time register LSB
    peakTime2       : std_logic;  --!Peaking-time register MSB
    fastOrTxDisable : std_logic;  --!Disable the fast-or TX
    externalBias    : std_logic;  --!Use external bias
    gain            : std_logic;  --!Preamplifier gain
    polarity        : std_logic;  --!Preamplifier polarity
  end record tAstraGlobalSetting;
  
  --!ASTRA Local setting serial interface
  type tPrgIntf is record
    clk   : std_logic;  --!Slow clock (1-5 MHz)
    bitA  : std_logic;  --!Channel configuration serial data (BLOCK A,  0-31)
    bitB  : std_logic;  --!Channel configuration serial data (BLOCK B, 32-63)
    rst   : std_logic;  --!Reset
  end record tPrgIntf;

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

  --!@brief Low-level ASTRA interface to analog multiplexer
  component astraDriver is
    port (
      --# {{clocks|Clock}}
      iCLK            : in  std_logic;
      --# {{control|Control}}
      iRST            : in  std_logic;
      oCNT            : out tControlIntfOut;
      iCNT            : in  tControlIntfIn;
      oDATA_VLD       : out std_logic;
      iADC_INT_EXT_b  : in  std_logic;
      --# {{acqCompl|acqCompl}}
      iACQSTN_COMPL   : in std_logic;
      --# {{ASTRA interface}}
      oFE             : out tFpga2FeIntf;
      iFE             : in  tFe2FpgaIntf
      );
  end component astraDriver;

  --!@brief Readout instantiating astraDriver, multiADC_interface, and internal ADC intf
  component detectorReadout is
    generic (
      pACTIVE_EDGE : string
    );
    port (
      --# {{clocks|Clock}}
      iCLK                : in  std_logic;
      iRST                : in  std_logic;
      --# {{control|Control}}
      oCNT                : out tControlIntfOut;
      iCNT                : in  tControlIntfIn;
      iADC_INT_EXT_b      : in  std_logic;
      --# {{parameters}}
      iFE_CLK_DIV         : in  std_logic_vector(15 downto 0);
      iFE_CLK_DUTY        : in  std_logic_vector(15 downto 0);
      iADC_CLK_DIV        : in  std_logic_vector(15 downto 0);
      iADC_CLK_DUTY       : in  std_logic_vector(15 downto 0);
      iADC_DELAY          : in  std_logic_vector(15 downto 0);
      iADC_INT_CLK_DIV    : in  std_logic_vector(15 downto 0);
      iADC_INT_CLK_DUTY   : in  std_logic_vector(15 downto 0);
      iADC_INT_CONV_TIME  : in  std_logic_vector(15 downto 0);
      --# {{ASTRA interface}}
      oFE                 : out tFpga2FeIntf;
      iFE                 : in  tFe2FpgaIntf;
      --# {{External ADCs interface}}
      oADC                : out tFpga2AdcIntf;
      iMULTI_ADC          : in  tMultiAdc2FpgaIntf;
      --# {{Internal ADCs interface}}
      oADC_INT_FAST_CLK   : out std_logic;
      oMULTI_ADC_INT      : out tFpga2AstraAdc;
      iMULTI_ADC_INT      : in  tMultiAstraAdc2Fpga;
      --# {{Collector FIFO interface}}
      oMULTI_FIFO         : out tMultiAdcFifoOut;
      iMULTI_FIFO         : in  tMultiAdcFifoIn
    );
  end component;

  --!@brief ASTRA PRG interface for local configurations
  component PRG_driver is
    generic (
      pNumBlock   : natural := 2;
      pChPerBlock : natural := 32
    );
    port (
      --# {{clocks|Clock}}
      iCLK            : in  std_logic;
      --# {{control|Control}}
      iRST            : in  std_logic;
      iPRG_ASTRA_RST  : in std_logic;
      iEN             : in  std_logic;
      iWE             : in  std_logic;
      iPERIOD_CLK     : in  std_logic_vector(31 downto 0);
      iDUTY_CYCLE_CLK : in  std_logic_vector(31 downto 0);
      oFLAG           : out tControlIntfOut;
      --# {{Configurations}}
      iCH_Mask        : in  std_logic_vector((pNumBlock*pChPerBlock)-1 downto 0);
      iCH_TP_EN       : in  std_logic_vector((pNumBlock*pChPerBlock)-1 downto 0);
      iCH_Disc        : in  std_logic_vector((pNumBlock*pChPerBlock)-1 downto 0);
      --# {{PRG Interface}}
      oLOCAL_SETTING  : out tPrgIntf
    );
  end component;
  
  ----!@brief PLL to generate internal clock (Fast clock, FSM clock, Receiver clock) inside ADC_INT_driver
  component pll is
    port(
      refclk   : in  std_logic := '0';  -- refclk.clk
      rst      : in  std_logic := '0';  -- reset.reset
      outclk_0 : out std_logic;         -- outclk0.clk (25 MHz)
      outclk_1 : out std_logic;         -- outclk1.clk (50 MHz)
      outclk_2 : out std_logic;         -- outclk2.clk (100 MHz)
      outclk_3 : out std_logic;         -- outclk3.clk (200 MHz)
      locked   : out std_logic          -- locked.export
    );
  end component;
  
  --!@brief Internal ASTRA ADCs interface
component ADC_INT_driver is
  port(
    --!FSM Main Command
    iCLK            : in  std_logic;        --!Clock
    iRST            : in  std_logic;        --!Reset
    iCTRL           : in  tControlIntfIn;   --!Control (enable, start, slow clock, slow enable)
    oFLAG				    : out tControlIntfOut;  --!Flag (busy, error, resetting, completetion)
    --!registerArray Interface
    iFAST_FREQ_DIV  : in std_logic_vector(15 downto 0);  --!Fast clock duration (in number of iCLK cycles) to drive ADC counter and serializer
    iFAST_DC        : in std_logic_vector(15 downto 0);  --!Duty cycle fast clock duration (in number of iCLK cycles)
    iCONV_TIME      : in std_logic_vector(15 downto 0);  --!Conversion time (in number of iCLK cycles)
    --!Fast Clock
    oFAST_CLK       : out std_logic;     --!Input of ADC fast clock (25-100 MHz)
    --!Serializer Command/Data
    iMULTI_ADC      : in  tMultiAstraAdc2Fpga;  --!Signals from the ADCs to the FPGA
    oMULTI_ADC      : out tFpga2AstraAdc;       --!Signals from the FPGA to the ADCs
    --!Word in output
    iMULTI_FIFO_RE  : in  std_logic_vector (cTOTAL_ADCS-1 downto 0);   --!Read request
    oMULTI_FIFO     : out tMultiAdcFifoOut      --!Output data, empty and full FIFO
    );
end component;
 
 

end ASTRApackage;
