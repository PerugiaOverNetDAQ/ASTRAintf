--!@file astraDriver.vhd
--!@brief Low-level interface of the analog multiplexer of ASTRA
--!@todo #5 Add test pulse management @mbarbane
--!@author Mattia Barbanera, mattia.barbanera@infn.it

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

use work.basic_package.all;
use work.ASTRApackage.all;

--!@copydoc astraDriver.vhd
entity astraDriver is
  port (
    iCLK            : in  std_logic;          --!Main clock
    iRST            : in  std_logic;          --!Main reset
    -- control interface
    oCNT            : out tControlIntfOut;    --!Control signals in output
    iCNT            : in  tControlIntfIn;     --!Control signals in input
    oDATA_VLD       : out std_logic;          --!Flags data available at ADC input
    iADC_INT_EXT_b  : in  std_logic;          --!External/Internal ADC select --> 0=EXT, 1=INT
    -- ADC_INT_driver interface
    iACQSTN_COMPL   : in std_logic;           --!Internal ADC acquisition complete
    -- ASTRA interface
    oFE             : out tFpga2FeIntf;       --!Signals from the FPGA to ASTRA
    iFE             : in  tFe2FpgaIntf        --!Signals from ASTRA to the FPGA
    );
end astraDriver;

--!@copydoc astraDriver.vhd
architecture std of astraDriver is
  constant cCH_COUNT_WIDTH  : natural
                                := ceil_log2(cFE_CHANNELS+cFE_SHIFT_2_CLK+1)+1;
  constant cDC_COUNT_WIDTH  : natural := ceil_log2(cFE_DAISY_CHAIN_DEPTH)+1;
  constant cS2C_COUNT_WIDTH : natural := 4;

  signal sCntIn   : tControlIntfIn;
  signal sCntOut  : tControlIntfOut;
  signal sFpga2Fe : tFpga2FeIntf;
  signal sFe2Fpga : tFe2FpgaIntf;

  type tFsmFe is (RESET, IDLE, SYNCH_START, HOLD, READ_RESET,
                  CLOCK_FORWARD, SYNCH_END, COMPLETE);
  signal sFeState, sNextFeState : tFsmFe;

  --!@brief Wait for the enable assertion to change state
  --!@param[in] en  If '1', go to destination state
  --!@param[in] src Source state; remain here until enable is asserted
  --!@param[in] dst Destination state; go here when enable is asserted
  --!@return FSM next state depending on the enable assertion
  function wait4en (en : std_logic; src : tFsmFe; dst : tFsmFe) return tFsmFe is
    variable goto : tFsmFe;
  begin
    if (en = '1') then
      goto := dst;
    else
      goto := src;
    end if;
    return goto;
  end function wait4en;

  type tChCountInterface is record
    preset : std_logic_vector(cCH_COUNT_WIDTH-1 downto 0);
    count  : std_logic_vector(cCH_COUNT_WIDTH-1 downto 0);
    en     : std_logic;
    load   : std_logic;
    carry  : std_logic;
  end record tChCountInterface;
  signal sChCountRst  : std_logic;
  signal sChCount     : tChCountInterface;

  type tDcCountInterface is record
    preset : std_logic_vector(cDC_COUNT_WIDTH-1 downto 0);
    count  : std_logic_vector(cDC_COUNT_WIDTH-1 downto 0);
    en     : std_logic;
    load   : std_logic;
    carry  : std_logic;
  end record tDcCountInterface;
  signal sDcCountRst  : std_logic;
  signal sDcCount     : tDcCountInterface;

  type tS2cCountInterface is record
    preset : std_logic_vector(cS2C_COUNT_WIDTH-1 downto 0);
    count  : std_logic_vector(cS2C_COUNT_WIDTH-1 downto 0);
    en     : std_logic;
    load   : std_logic;
    carry  : std_logic;
  end record tS2cCountInterface;
  signal sS2cCountRst : std_logic;
  signal sS2cCount    : tS2cCountInterface;
begin
  -- Combinatorial assignments -------------------------------------------------
  oCNT   <= sCntOut;
  sCntIn <= iCNT;
  oFE <= sFpga2Fe;
  sFe2Fpga <= iFE;
  ------------------------------------------------------------------------------

  --! @brief Output signals in a synchronous fashion, without reset
  --! @param[in] iCLK Clock, used on rising edge
  FE_synch_signals_proc : process (iCLK)
  begin
    if (rising_edge(iCLK)) then
      if (iADC_INT_EXT_b = '1') then
        --!default values, to be overwritten when necessary
        oDATA_VLD         <= '0';
        sFpga2Fe.readRst  <= '0';        
        sFpga2Fe.shiftClk <= '0';
        sFpga2Fe.test     <= '0';
        
        if (sNextFeState = RESET) then
          sCntOut.reset <= '1';
        else
          sCntOut.reset <= '0';
        end if;
        
        if (sNextFeState /= IDLE) then
          sCntOut.busy <= '1';
        else
          sCntOut.busy <= '0';
        end if;
        
        if (sFeState = HOLD) then
          sFpga2Fe.hold_b <= '0';
        else
          sFpga2Fe.hold_b <= '1';
        end if;      

        if (sNextFeState = COMPLETE) then
          sCntOut.compl <= '1';
        else
          sCntOut.compl <= '0';
        end if;
        
        --!@todo How do I check the "when others" statement?
        sCntOut.error <= '0';        
        
      else   
      
        if (sFeState = HOLD or sFeState = READ_RESET
            or sFeState = CLOCK_FORWARD or sFeState = SYNCH_END) then
          sFpga2Fe.hold_b <= '0';
        else
          sFpga2Fe.hold_b <= '1';
        end if;

        if (sFeState = READ_RESET or sFeState = CLOCK_FORWARD
            or sFeState = SYNCH_END) then
          sFpga2Fe.readRst <= '1';
        else
          sFpga2Fe.readRst <= '0';
        end if;

        if (sFeState = CLOCK_FORWARD or sFeState = SYNCH_END 
            or sFeState = HOLD or sFeState = READ_RESET) then
          sFpga2Fe.shiftClk <= sCntIn.slwClk;
        else
          sFpga2Fe.shiftClk <= '0';
        end if;

        if (sNextFeState /= IDLE) then
          sCntOut.busy <= '1';
        else
          sCntOut.busy <= '0';
        end if;

        if (sNextFeState = RESET) then
          sCntOut.reset <= '1';
        else
          sCntOut.reset <= '0';
        end if;

        --!@todo How do I check the "when others" statement?
        sCntOut.error <= '0';

        if (sNextFeState = COMPLETE) then
          sCntOut.compl <= '1';
        else
          sCntOut.compl <= '0';
        end if;

        if (sNextFeState = CLOCK_FORWARD or sNextFeState = READ_RESET) then
          oDATA_VLD <= '1';
        else
          oDATA_VLD <= '0';
        end if;
      end if;
    end if;
  end process FE_synch_signals_proc;

  --!Counters default
  sChCount.load   <= '0';
  sDcCount.load   <= '0';
  sS2cCount.load  <= '0';
  sChCount.preset <= (others => '0');
  sDcCount.preset <= (others => '0');
  sS2cCount.preset<= (others => '0');

  sChCountRst <= '1' when (sFeState = RESET or sFeState = IDLE) else
                 '0';
  sChCount.en <= sCntIn.slwEn when (sFeState = CLOCK_FORWARD or sFeState = READ_RESET) else
                 '0';
  --! @brief Multi-purpose counter to implement delays in the FSM
  CH_COUNTER : counter
    generic map(
      pOVERLAP  => "Y",
      pBUSWIDTH => cCH_COUNT_WIDTH
      )
    port map(
      iCLK   => iCLK,
      iRST   => sChCountRst,
      iEN    => sChCount.en,
      iLOAD  => sChCount.load,
      iDATA  => sChCount.preset,
      oCOUNT => sChCount.count,
      oCARRY => sChCount.carry
      );

  sDcCountRst <= '1' when (sFeState = RESET or sFeState = IDLE) else
                 '0';
  sDcCount.en <= sCntIn.slwEn when (sFeState = SYNCH_END) else
                 '0';
  --!@brief Count the number of FEs in the daisy chain
  DC_COUNTER : counter
    generic map(
      pOVERLAP  => "Y",
      pBUSWIDTH => cDC_COUNT_WIDTH
      )
    port map(
      iCLK   => iCLK,
      iRST   => sDcCountRst,
      iEN    => sDcCount.en,
      iLOAD  => sDcCount.load,
      iDATA  => sDcCount.preset,
      oCOUNT => sDcCount.count,
      oCARRY => sDcCount.carry
      );

  sS2cCountRst <= '1' when (sFeState /= READ_RESET) else
                  '0';
  sS2cCount.en <= sCntIn.slwEn when (sFeState = READ_RESET) else
                  '0';
  --!@brief Count the slwClk cycles between the READ_RESET and clk assertion
  S2C_COUNTER : counter
    generic map(
      pOVERLAP  => "Y",
      pBUSWIDTH => cS2C_COUNT_WIDTH
      )
    port map(
      iCLK   => iCLK,
      iRST   => sS2cCountRst,
      iEN    => sS2cCount.en,
      iLOAD  => sS2cCount.load,
      iDATA  => sS2cCount.preset,
      oCOUNT => sS2cCount.count,
      oCARRY => sS2cCount.carry
      );

  --! @brief Add FFDs to the combinatorial signals \n
  --! @param[in] iCLK  Clock, used on rising edge
  ffds : process (iCLK)
  begin
    if (rising_edge(iCLK)) then
      if (iRST = '1') then
        sFeState <= RESET;
      else
        sFeState <= sNextFeState;
      end if;  --iRST
    end if;  --rising_edge
  end process ffds;

  --! @brief Combinatorial FSM to operate the FEs
  --! @param[in] sFeState  Current state of the FSM
  --! @param[in] sCntIn Input signals of the control interface
  --! @param[in] sChCount.count Output of the delay counter
  --! @return sNextFeState  Next state of the FSM
  FSM_FE_proc : process (sFeState, sCntIn, sChCount.count,
                         sDcCount.count, sS2cCount.count,
                         iADC_INT_EXT_b, iACQSTN_COMPL)
  begin
    case (sFeState) is
      --Reset the FSM
      when RESET =>
        sNextFeState <= IDLE;

      --Wait for the START signal to be asserted
      when IDLE =>
        if (iADC_INT_EXT_b = '1') then
          if (sCntIn.en = '1' and sCntIn.start = '1') then
            sNextFeState <= HOLD;
          else
            sNextFeState <= IDLE;
          end if;
        else        
          if (sCntIn.en = '1' and sCntIn.start = '1') then
            sNextFeState <= SYNCH_START;
          else
            sNextFeState <= IDLE;
          end if;
        end if;

      --Wait for the slow-clock enable before starting
      when SYNCH_START =>
        sNextFeState <= wait4en(sCntIn.slwEn, SYNCH_START, HOLD);

      --Assert the HOLD signal
      when HOLD =>
        if (iADC_INT_EXT_b = '1') then
          if (iACQSTN_COMPL = '1') then
            sNextFeState <= COMPLETE;
          else
            sNextFeState <= HOLD;
          end if;
        else
          sNextFeState <= wait4en(sCntIn.slwEn, HOLD, READ_RESET);
        end if;

      --Assert the readRst signal without forwarding clock
      when READ_RESET =>
        if (sS2cCount.count <
                  int2slv(cFE_SHIFT_2_CLK-1, sS2cCount.count'length)) then
          --Wait until the  delay is over
          sNextFeState <= READ_RESET;
        else
          --Delay concluded
          sNextFeState <= wait4en(sCntIn.slwEn, READ_RESET, CLOCK_FORWARD);
        end if;

      --Send the remaining clocks to ASTRA(s)
      when CLOCK_FORWARD =>
        if (sChCount.count <
            int2slv(cFE_CHANNELS, sChCount.count'length)) then
          sNextFeState <= CLOCK_FORWARD;
        else
          sNextFeState <= SYNCH_END;
        end if;

      --Wait for the slow clock enable before ending the readout
      when SYNCH_END =>
        if (sDcCount.count <
                  int2slv(cFE_DAISY_CHAIN_DEPTH-1, sDcCount.count'length)) then
          --Still other ASTRAs in the chain
          sNextFeState <= wait4en(sCntIn.slwEn, SYNCH_END, READ_RESET);
        else
          --No more ASTRAs to readout
          sNextFeState <= wait4en(sCntIn.slwEn, SYNCH_END, COMPLETE);
        end if;

      when COMPLETE =>
        sNextFeState <= IDLE;

      --State not foreseen
      when others =>
        sNextFeState <= RESET;

    end case;
  end process FSM_FE_proc;


end architecture std;
