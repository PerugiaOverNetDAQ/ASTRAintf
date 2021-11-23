--!@file detectorReadout.vhd
--!@brief Interface with the FEs and ADCs of one plane of the detector
--!
--!@details Create, or forward, a clock for ASTRA and the ADCs.
--!\n\n **Reset duration shall be no less than 2 clock cycles**
--!
--!@author Mattia Barbanera, mattia.barbanera@infn.it

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

use work.basic_package.all;
use work.ASTRApackage.all;

--!@copydoc detectorReadout.vhd
entity detectorReadout is
  generic (
    pACTIVE_EDGE : string := "F"        --!"F": falling, "R": rising
    );
  port (
    iCLK          : in  std_logic;      --!Main clock
    iRST          : in  std_logic;      --!Main reset
    -- control interface
    oCNT          : out tControlIntfOut;     --!Control signals in output
    iCNT          : in  tControlIntfIn;      --!Control signals in input
    iFE_CLK_DIV   : in  std_logic_vector(15 downto 0);  --!FE SlowClock divider
    iFE_CLK_DUTY  : in  std_logic_vector(15 downto 0);  --!FE SlowClock duty cycle
    iADC_CLK_DIV  : in  std_logic_vector(15 downto 0);  --!ADC SlowClock divider
    iADC_CLK_DUTY : in  std_logic_vector(15 downto 0);  --!ADC SlowClock divider
    -- ASTRA interface
    oFE           : out tFpga2FeIntf;   --!Output signals to ASTRA
    iFE           : in  tFe2FpgaIntf;   --!Input signals from ASTRA
    -- External ADCs interface
    oADC          : out tFpga2AdcIntf;  --!Signals from FPGA to ext-ADCs
    iMULTI_ADC    : in  tMultiAdc2FpgaIntf;  --!Signals from ext-ADCs to FPGA
    -- Internal ADCs interface
    -- Collector FIFO interface
    oMULTI_FIFO   : out tMultiAdcFifoOut;    --!Collector FIFO, output interface
    iMULTI_FIFO   : in  tMultiAdcFifoIn      --!Collector FIFO, input  interface
    );
end detectorReadout;

--!@copydoc detectorReadout.vhd
architecture std of detectorReadout is
  signal sCntOut  : tControlIntfOut;
  signal sCntIn   : tControlIntfIn;
  signal sFifoOut : tMultiAdcFifoOut;
  signal sFifoIn  : tMultiAdcFifoIn;

  signal sFe          : tFpga2FeIntf;
  signal sFeRst       : std_logic;
  signal sFeOCnt      : tControlIntfOut;
  signal sFeICnt      : tControlIntfIn;
  signal sFeDataVld   : std_logic;
  signal sFeOtherEdge : std_logic;

  signal sAdc      : tFpga2AdcIntf;
  signal sAdcRst   : std_logic;
  signal sAdcOCnt  : tControlIntfOut;
  signal sAdcICnt  : tControlIntfIn;
  signal sAdcOFifo : tMultiAdcFifoIn;

  -- Clock dividers
  signal sFeCdRis, sFeCdFal   : std_logic;
  signal sFeSlwEn             : std_logic;
  signal sFeSlwRst            : std_logic;
  signal sAdcCdRis, sAdcCdFal : std_logic;
  signal sAdcSlwEn            : std_logic;
  signal sAdcSlwRst           : std_logic;

  -- FSM signals
  type tHpState is (RESET, WAIT_RESET, IDLE, START_HP_READING, FE_EDGE,
                    START_ADC_READING, WAIT_FOR_ADC_END, END_HP_READING);
  signal sHpState, sNextHpState : tHpState;
  signal sFsmSynchEn            : std_logic;

begin
  -- Combinatorial assignments -------------------------------------------------
  oCNT        <= sCntOut;
  sCntIn      <= iCNT;
  oMULTI_FIFO <= sFifoOut;
  oFE         <= sFe;
  oADC        <= sAdc;
  ------------------------------------------------------------------------------

  -- Slow signals Generator ----------------------------------------------------
  sFeICnt.slwEn <= sFeCdFal when (pACTIVE_EDGE = "F") else
                   sFeCdRis;
  sFeOtherEdge  <= sFeCdRis when (pACTIVE_EDGE = "F") else
                   sFeCdFal;
  --!@brief Generate the SlowClock and SlowEnable for the FEs interface
  FE_div : clock_divider_2
    generic map(
      pPOLARITY => '0',
      pWIDTH    => 16
      )
    port map (
      iCLK             => iCLK,
      iRST             => sFeSlwRst,
      iEN              => sFeSlwEn,
      iFREQ_DIV        => iFE_CLK_DIV,
      iDUTY_CYCLE      => iFE_CLK_DUTY,
      oCLK_OUT         => sFeICnt.slwClk,
      oCLK_OUT_RISING  => sFeCdRis,
      oCLK_OUT_FALLING => sFeCdFal
      );

  sAdcICnt.slwEn <= sAdcCdFal when (pACTIVE_EDGE = "F") else
                    sAdcCdRis;
  --!@brief Generate the SlowClock and SlowEnable for the ADC interface
  ADC_div : clock_divider_2
    generic map(
      pPOLARITY => '0',
      pWIDTH    => 16
      )
    port map (
      iCLK             => iCLK,
      iRST             => sAdcSlwRst,
      iEN              => sAdcSlwEn,
      iFREQ_DIV        => iADC_CLK_DIV,
      iDUTY_CYCLE      => iADC_CLK_DUTY,
      oCLK_OUT         => sAdcICnt.slwClk,
      oCLK_OUT_RISING  => sAdcCdRis,
      oCLK_OUT_FALLING => sAdcCdFal
      );
  ------------------------------------------------------------------------------

  sFeRst <= '1' when (sHpState = RESET) else
            '0';
  --!@brief Low-level front-end interface
  astraDriver_i : astraDriver
    port map (
      iCLK      => iCLK,
      iRST      => sFeRst,
      oCNT      => sFeOCnt,
      iCNT      => sFeICnt,
      oDATA_VLD => sFeDataVld,
      oFE       => sFe,
      iFE       => iFE
      );      

  sAdcRst <= '1' when (sHpState = RESET) else
             '0';
  --!@brief Low-level ADC interface
  MultiADC_interface_i : multiADC_interface
    port map (
      iCLK        => iCLK,
      iRST        => sAdcRst,
      oCNT        => sAdcOCnt,
      iCNT        => sAdcICnt,
      oADC        => sAdc,
      iMULTI_ADC  => iMULTI_ADC,
      oMULTI_FIFO => sAdcOFifo
      );

  --!@brief Generate multiple FIFOs to sample the ADCs
  FIFO_GENERATE : for i in 0 to cTOTAL_ADCS-1 generate
    sFifoIn(i).data <= sAdcOFifo(i).data;
    sFifoIn(i).wr   <= sAdcOFifo(i).wr;
    sFifoIn(i).rd   <= iMULTI_FIFO(i).rd;

    --!@brief FIFO buffer to collect data from the ADC
    --!@brief full and aFull flags are not used, the FIFO is supposed to be ready
    ADC_FIFO : parametric_fifo_synch
      generic map(
        pWIDTH       => cADC_DATA_WIDTH,
        pDEPTH       => cADC_FIFO_DEPTH,
        pUSEDW_WIDTH => ceil_log2(cADC_FIFO_DEPTH),
        pAEMPTY_VAL  => 3,
        pAFULL_VAL   => cADC_FIFO_DEPTH-3,
        pSHOW_AHEAD  => "OFF"
        )
      port map(
        iCLK    => iCLK,
        iRST    => iRST,
        oAEMPTY => sFifoOut(i).aEmpty,
        oEMPTY  => sFifoOut(i).empty,
        oAFULL  => sFifoOut(i).aFull,
        oFULL   => sFifoOut(i).full,
        oUSEDW  => open,
        iRD_REQ => sFifoIn(i).rd,
        iWR_REQ => sFifoIn(i).wr,
        iDATA   => sFifoIn(i).data,
        oQ      => sFifoOut(i).q
        );
  end generate FIFO_GENERATE;


  --! @brief Output signals in a synchronous fashion, without reset
  --! @param[in] iCLK Clock, used on rising edge
  HP_synch_signals_proc : process (iCLK)
  begin
    if (rising_edge(iCLK)) then
      if (sHpState = RESET or sHpState = WAIT_RESET) then
        sFeICnt.en  <= '0';
        sAdcICnt.en <= '0';
      else
        sFeICnt.en  <= '1';
        sAdcICnt.en <= '1';
      end if;

      if (sHpState = START_HP_READING) then
        sFeICnt.start <= '1';
      else
        sFeICnt.start <= '0';
      end if;

      if (sHpState = RESET or sHpState = IDLE) then
        sFeSlwRst <= '1';
      else
        sFeSlwRst <= '0';
      end if;

      if (sHpState = RESET or sHpState = FE_EDGE) then
        sAdcSlwRst <= '1';
      else
        sAdcSlwRst <= '0';
      end if;

      if (sHpState /= IDLE and sHpState /= RESET) then
        sFeSlwEn <= '1';
      else
        sFeSlwEn <= '0';
      end if;

      if (sHpState = START_ADC_READING) then
        sAdcICnt.start <= '1';
      else
        sAdcICnt.start <= '0';
      end if;

      if (sHpState = WAIT_RESET or sHpState = START_ADC_READING or
          sHpState = WAIT_FOR_ADC_END) then
        sAdcSlwEn <= '1';
      else
        sAdcSlwEn <= '0';
      end if;

      if (sHpState /= IDLE) then
        sCntOut.busy <= '1';
      else
        sCntOut.busy <= '0';
      end if;

      if (sHpState = RESET or sHpState = WAIT_RESET) then
        sCntOut.reset <= '1';
      else
        sCntOut.reset <= '0';
      end if;

      if (sHpState = END_HP_READING) then
        sCntOut.compl <= '1';
      else
        sCntOut.compl <= '0';
      end if;

      --!@todo How do I check the "when others" statement?
      sCntOut.error <= '0';

    end if;
  end process HP_synch_signals_proc;

  --! @brief Add FFDs to the combinatorial signals \n
  --! @details Delay the FE slwEn by one clock cycle to synch this FSM to the
  --! @details FSM of the FE, taking decisions when the action is performed
  --! @param[in] iCLK  Clock, used on rising edge
  ffds : process (iCLK)
  begin
    if (rising_edge(iCLK)) then
      if (iRST = '1') then
        sHpState    <= RESET;
        sFsmSynchEn <= '0';
      else
        sHpState    <= sNextHpState;
        sFsmSynchEn <= sFeICnt.slwEn;
      end if;  --iRST
    end if;  --rising_edge
  end process ffds;

  --! @brief Combinatorial FSM to operate the HP machinery
  --! @param[in] sHpState  Current state of the FSM
  --! @param[in] sCntIn    Input ports of the control interface
  --! @param[in] sFeOCnt   Output control ports of the FE_interface
  --! @param[in] sAdcOCnt  Output control ports of the ADC_interface
  --! @param[in] sFsmSynchEn Synch this FSM to the FSM of the FSM
  --! @return sNextHpState  Next state of the FSM
  --! @vhdlflow
  FSM_HP_proc : process(sHpState, sCntIn, sFeOCnt, sAdcOCnt, sFsmSynchEn,
                        sFeDataVld)
  begin
    case (sHpState) is
      --Reset the FSM
      when RESET =>
        sNextHpState <= WAIT_RESET;

      --Wait until FE and ADC completed reset
      when WAIT_RESET =>
        if (sFeOCnt.reset = '0' and sAdcOCnt.reset = '0') then
          sNextHpState <= IDLE;
        else
          sNextHpState <= WAIT_RESET;
        end if;

      --Wait for the START signal
      when IDLE =>
        if (sCntIn.en = '1' and sCntIn.start = '1') then
          sNextHpState <= START_HP_READING;
        else
          sNextHpState <= IDLE;
        end if;

      --Start reading the sensor by starting ASTRA; doesn't go to START_ADC_READING
      --because ASTRA has a first state of HOLD
      when START_HP_READING =>
        if (sFsmSynchEn = '1') then
          sNextHpState <= FE_EDGE;
        else
          sNextHpState <= START_HP_READING;
        end if;

      --Go to the last state or continue reading synchronized to the FE clock
      when FE_EDGE =>
        if (sFeOCnt.compl = '1') then
          sNextHpState <= END_HP_READING;
        else
          if (sFsmSynchEn = '1' and sFeDataVld = '1') then
            sNextHpState <= START_ADC_READING;
          else
            sNextHpState <= FE_EDGE;
          end if;
        end if;

      --Start the ADC interface
      when START_ADC_READING =>
        sNextHpState <= WAIT_FOR_ADC_END;

      --Stay in this state until the ADC interface completes the task
      when WAIT_FOR_ADC_END =>
        if (sAdcOCnt.compl = '1') then
          sNextHpState <= FE_EDGE;
        else
          sNextHpState <= WAIT_FOR_ADC_END;
        end if;

      --The HP reading is concluded
      when END_HP_READING =>
        sNextHpState <= IDLE;

      --State not foreseen
      when others =>
        sNextHpState <= RESET;

    end case;
  end process FSM_HP_proc;

end architecture std;
