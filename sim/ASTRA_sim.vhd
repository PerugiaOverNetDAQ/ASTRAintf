library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

use work.basic_package.all;
use work.ASTRApackage.all;


entity ASTRA_sim is

end entity ASTRA_sim;

architecture behav of ASTRA_sim is
  -- Generics
  constant pACTIVE_EDGE : string := "F";

  -- clock period
  constant clk_period : time := 20 ns;
  constant cable_delay : time := 5 ns;

  -- Signal ports
  signal iCLK               : std_logic;
  signal iRST               : std_logic;
  signal oCNT               : tControlIntfOut;
  signal iCNT               : tControlIntfIn;
  signal iADC_INT_EXT_b     : std_logic;
  signal iFE_CLK_DIV        : std_logic_vector(15 downto 0);
  signal iFE_CLK_DUTY       : std_logic_vector(15 downto 0);
  signal iADC_CLK_DIV       : std_logic_vector(15 downto 0);
  signal iADC_CLK_DUTY      : std_logic_vector(15 downto 0);
  signal iADC_DELAY         : std_logic_vector(15 downto 0);
  signal iADC_INT_CLK_DIV   : std_logic_vector(15 downto 0);
  signal iADC_INT_CLK_DUTY  : std_logic_vector(15 downto 0);
  signal iADC_INT_CONV_TIME : std_logic_vector(15 downto 0);
  signal iCNT_Test          : std_logic;
  signal iCNT_TEST_CH       : std_logic_vector(7 downto 0);
  signal oFE                : tFpga2FeIntf;
  signal iFE                : tFe2FpgaIntf;
  signal oADC               : tFpga2AdcIntf;
  signal iMULTI_ADC         : tMultiAdc2FpgaIntf;
  signal oADC_INT_FAST_CLK  : std_logic;
  signal oMULTI_ADC_INT     : tFpga2AstraAdc;
  signal iMULTI_ADC_INT     : tMultiAstraAdc2Fpga;
  signal oMULTI_FIFO        : tMultiAdcFifoOut;
  signal iMULTI_FIFO        : tMultiAdcFifoIn;

  --ASTRA signals
  signal sFeFROMFpga        : tFpga2FeIntf;

  --External ADCs
  signal sExtAdcFROMFpga    : tFpga2AdcIntf;
  signal sExtAdcTOFpga      : tMultiAdc2FpgaIntf;

  --Internal ADCs
  signal sIntAdcFROMFpga    : tFpga2AstraAdc;
  signal sIntAdcTOFpga      : tMultiAstraAdc2Fpga;

begin

  detectorReadout_i : entity work.detectorReadout
  generic map (
    pACTIVE_EDGE => pACTIVE_EDGE
  )
  port map (
    iCLK               => iCLK,
    iRST               => iRST,
    oCNT               => oCNT,
    iCNT               => iCNT,
    iADC_INT_EXT_b     => iADC_INT_EXT_b,
    iFE_CLK_DIV        => iFE_CLK_DIV,
    iFE_CLK_DUTY       => iFE_CLK_DUTY,
    iADC_CLK_DIV       => iADC_CLK_DIV,
    iADC_CLK_DUTY      => iADC_CLK_DUTY,
    iADC_DELAY         => iADC_DELAY,
    iADC_INT_CLK_DIV   => iADC_INT_CLK_DIV,
    iADC_INT_CLK_DUTY  => iADC_INT_CLK_DUTY,
    iADC_INT_CONV_TIME => iADC_INT_CONV_TIME,
    iCNT_Test          => iCNT_Test,
    iCNT_TEST_CH       => iCNT_TEST_CH,
    oFE                => oFE,
    iFE                => iFE,
    oADC               => oADC,
    iMULTI_ADC         => iMULTI_ADC,
    oADC_INT_FAST_CLK  => oADC_INT_FAST_CLK,
    oMULTI_ADC_INT     => oMULTI_ADC_INT,
    iMULTI_ADC_INT     => iMULTI_ADC_INT,
    oMULTI_FIFO        => oMULTI_FIFO,
    iMULTI_FIFO        => iMULTI_FIFO
  );

  --FIXME: cannot understand the logic of the module
  --ANALOG_READOUT_sim_i : entity work.ANALOG_READOUT_sim
  --port map (
  --  iMUX_SHIFT_CLK  => sFeFROMFpga.shiftClk,
  --  iHOLD           => sFeFROMFpga.hold_b,
  --  iMUX_READ_RESET => sFeFROMFpga.readRst,
  --  oMUX_OUT        =>
  --);

  --FIXME: cannot understand the logic of the module
  --ADC_EXT_sim_i : entity work.ADC_EXT_sim
  --port map (
  --  iSCLK  => sExtAdcFROMFpga.SClk,
  --  iCS    => sExtAdcFROMFpga.Cs,
  --  oSDATA =>
  --  );


  CLK_PROC : process
  begin
    iCLK <= '1';
    wait for clk_period/2;
    iCLK <= '0';
    wait for clk_period/2;
  end process;

  STIM_PROC : process
  begin
    iCNT.en       <= '0';
    iCNT.start    <= '0';
    iRST <= '1';
    wait for 100 ns;

    iRST <= '0';
    wait for 40 ns;

    iCNT.en       <= '1';
    iCNT.start    <= '1';
    wait for 100 ns;

    iCNT.start    <= '0';
    wait for 40 us;

    iCNT.start    <= '1';
    wait for 100 ns;

    iCNT.start    <= '0';
    wait;
  end process;

  --Configurations
  iADC_INT_EXT_b      <= '0';
  iFE_CLK_DIV         <= x"0028";
  iFE_CLK_DUTY        <= x"0008";
  iADC_CLK_DIV        <= x"0002";
  iADC_CLK_DUTY       <= x"0001";
  iADC_DELAY          <= x"001D";
  iADC_INT_CLK_DIV    <= x"0002";
  iADC_INT_CLK_DUTY   <= x"0001";
  iADC_INT_CONV_TIME  <= x"203A";
  iCNT_Test           <= '0';
  iCNT_TEST_CH        <= x"16";

  --Cable transport: from FPGA to ASTRA
  sFeFROMFpga     <= transport oFE after cable_delay;
  sExtAdcFROMFpga <= transport oADC after cable_delay;
  sIntAdcFROMFpga <= transport oMULTI_ADC_INT after cable_delay;
  --Cable transport: from ASTRA to FPGA
  iFE.readRstRet  <= transport sFeFROMFpga.readRst after cable_delay;
  iFE.shiftClkRet <= transport sFeFROMFpga.shiftClk after cable_delay;
  RET_GEN : for ii in 0 to cTOTAL_ADCS-1 generate
    iMULTI_ADC(ii).clkRet         <= transport sExtAdcFROMFpga.SClk after cable_delay;
    iMULTI_ADC(ii).csRet          <= transport sExtAdcFROMFpga.Cs after cable_delay;
    iMULTI_ADC_INT(ii).ClkRet     <= transport sIntAdcFROMFpga.SerShClk after cable_delay;
    iMULTI_ADC_INT(ii).SerSendRet <= transport sIntAdcFROMFpga.SerSend after cable_delay;
  end generate RET_GEN;

  --Internal/External ADC Generator
  --FIXME: update with dedicated modules
  ADC_GEN : for ii in 0 to cTOTAL_ADCS-1 generate
    iMULTI_ADC(ii).SData        <= '1';
    iMULTI_ADC_INT(ii).SerData  <= '1';
    --Endlessly-deep FIFO
    iMULTI_FIFO(ii).rd          <= '1';
    iMULTI_FIFO(ii).data <= (others => '0');  --not used
    iMULTI_FIFO(ii).wr <= '0';  --not used
  end generate ADC_GEN;

  --Signals not used
  iCNT.slwClk   <= '0';
  iCNT.slwEn    <= '0';


end architecture behav;
