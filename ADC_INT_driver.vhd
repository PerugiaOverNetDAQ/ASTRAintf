--!@file ADC_INT_driver.vhd
--!@brief Interface to ASTRA ADCs
--!@details
--!
--!1) Drives the analog to digital conversion (FastCLK, RESET_dig, ADC_convert)
--!2) Controls the serializer (SER_shift_CLK, SER_load, SER_send)
--!3) Receives data from ASTRA (SER_OUT)
--!
--!@author Matteo D'Antonio, matteo.dantonio@pg.infn.it
--!@date 01/03/2022


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;
use work.basic_package.all;
use work.ASTRApackage.all;


--!@copydoc ADC_INT_driver.vhd
entity ADC_INT_driver is
  port(
    --FSM Main Command
    iCLK            : in  std_logic;        --!Clock
    iRST            : in  std_logic;        --!Reset
    iCTRL           : in  tControlIntfIn;   --!Control (enable, start, slow clock, slow enable)
    oFLAG				    : out tControlIntfOut;  --!Flag (busy, error, resetting, completetion)
    --registerArray Interface
    iFAST_FREQ_DIV  : in std_logic_vector(15 downto 0);  --!Fast clock duration (in number of iCLK cycles) to drive ADC counter and serializer
    iFAST_DC        : in std_logic_vector(15 downto 0);  --!Duty cycle fast clock duration (in number of iCLK cycles)
    iCONV_TIME      : in std_logic_vector(15 downto 0);  --!Conversion time (in number of iCLK cycles)
    --ADC Main Commands
    oFAST_CLK       : out std_logic;     --!Input of ADC fast clock (25-100 MHz)
    oRST_DIG        : out std_logic;     --!Reset of the ADC, counter and serializer
    oADC_CONV       : out std_logic;     --!Digital pulse to start the conversion of the ADC
    --Serializer Command/Data
    iMULTI_ADC      : in  tMultiAstraAdc2Fpga;  --!Signals from the ADCs to the FPGA
    oMULTI_ADC      : out tFpga2AstraAdc        --!Signals from the FPGA to the ADCs    
    );
end ADC_INT_driver;


--!@copydoc ADC_INT_driver.vhd
architecture Behavior of ADC_INT_driver is
  --!FSM states
  type tAdcStatus is (IDLE, ADC_RST, ADC_CONV, SER_SHIFT, SER_LOAD, SER_SEND);
  signal sAdcState : tAdcStatus;

  --FSM counter
  signal sHoldCounter       : std_logic_vector(15 downto 0);  --!Signals duration
  signal sDelayCounter      : std_logic_vector(15 downto 0);  --!Delay between signals
  signal sAdcCounter        : std_logic_vector(4 downto 0);   --!ADC select

  --!Clock_divider Interface
  signal sFreqDivRst        : std_logic;    --!Reset
  signal sFastClockR        : std_logic;    --!Output rising edge
  signal sFastClockF        : std_logic;    --!Output falling edge
  signal sClkRx				      : std_logic;	  --!Receiver clock
  --signal sFastClock         : std_logic;    --!Output
  
  
begin
  --- FSM clock, Fast clock, Receiver clock ----------------------------------------
  generate_fast_clock_0 : clock_divider_2
	generic map(
		pPOLARITY => '1',
    pWIDTH    => 16
		)
	port map(
		iCLK 				      => iCLK,
		iRST 				      => sFreqDivRst,
		iEN 				      => '1',
		oCLK_OUT 			    => oFAST_CLK,
		oCLK_OUT_RISING 	=> sFastClockR,
		oCLK_OUT_FALLING	=> sFastClockF,
		iFREQ_DIV         => iFAST_FREQ_DIV,
		iDUTY_CYCLE       => iFAST_DC
		);
    
  -- PLL with "auto-reset" ON (automatically self-resets the PLL on loss of lock)
	-- generate_fast_clock_1 : pll
	-- port map(
    -- refclk   =>	iCLK,
    -- rst      =>	sFreqDivRst,
		-- outclk_0 =>	,
    -- outclk_1 =>	,
    -- outclk_2 =>	,
    -- outclk_3 =>	,
		-- locked   =>	
		-- );
    
  --- Transmitter Commands to ASTRA ------------------------------------------------
  ADC_FSM_proc : process (iCLK)
  begin 
    if (rising_edge(iCLK)) then
      if (iRST = '1') then
        sFreqDivRst     <= '1';
        sHoldCounter    <= (others => '0');
        sDelayCounter   <= (others => '0');
        sAdcCounter     <= (others => '0');
        sAdcState       <= IDLE;
        oFLAG			<= ('0', '0', '1', '0');	  --!reset FLAG = '1'
        oRST_DIG        <= '0';
        oADC_CONV       <= '0';
        oMULTI_ADC.SerShClk   <= '0';
        oMULTI_ADC.SerLoad    <= '0';
        oMULTI_ADC.SerSend    <= '0';        
      elsif (iCTRL.en = '1') then
        --!default values, to be overwritten when necessary
        sFreqDivRst     <= '0';
        oFLAG			<= ('1', '0', '0', '0');	  --!busy FLAG = '1'
        case (sAdcState) is
          
          --!Wait for new acquisition
          when IDLE =>
            if (iCTRL.start = '1') then
              sHoldCounter  <= x"0001";
              sAdcState     <= ADC_RST;
              oRST_DIG      <= '1';
            else
              sFreqDivRst   <= '1';
              sAdcState     <= IDLE;
              oFLAG.busy		<= '0';
              oRST_DIG      <= '0';
            end if;
          --!Reset to set all the digital logic in the correct condition
          when ADC_RST =>
            if (sFastClockR = '1') then
              sAdcState     <= ADC_RST;
              if (sHoldCounter < 2) then
                sHoldCounter  <= sHoldCounter + 1;
                oRST_DIG      <= '1';
              else
                oRST_DIG      <= '0'; 
                if (sDelayCounter < 1) then
                  sDelayCounter   <= sDelayCounter + 1;
                else
                  sHoldCounter    <= x"0001";                   
                  sDelayCounter   <= (others => '0');
                  sAdcState       <= ADC_CONV;
                  oADC_CONV       <= '1';
                end if;
              end if;
            end if;            
          --!Start of the ADC conversion
          when ADC_CONV =>
            if (sHoldCounter < iCONV_TIME) then              
              sHoldCounter  <= sHoldCounter + 1;
              sAdcState     <= ADC_CONV;
              oADC_CONV     <= '1';
            else            
              oADC_CONV     <= '0';
              if (sFastClockR = '1') then
                if (sDelayCounter < 1) then
                    sDelayCounter   <= sDelayCounter + 1;
                  else
                    sHoldCounter    <= x"0001";               
                    sDelayCounter   <= (others => '0');
                    sAdcState       <= SER_SHIFT;
                    oMULTI_ADC.SerShClk     <= '1';
                  end if;
              end if;
            end if;          
          --!Propagates the channel pointer to enable the readout of the digitized information
          when SER_SHIFT =>
            if (sFastClockR = '1') then
              sAdcState     <= SER_SHIFT;
              if (sHoldCounter < 2) then
                sHoldCounter    <= sHoldCounter + 1;
                oMULTI_ADC.SerShClk     <= '1'; 
              else
                oMULTI_ADC.SerShClk     <= '0'; 
                if (sDelayCounter < 1) then
                  sDelayCounter   <= sDelayCounter + 1;
                else
                  sHoldCounter    <= x"0001";                   
                  sDelayCounter   <= (others => '0');
                  sAdcState       <= SER_LOAD;
                  oMULTI_ADC.SerLoad       <= '1';
                end if;
              end if;
            end if;
          --!Enable the serializer to load the data from the bus and serialize it
          when SER_LOAD =>
            if (sFastClockR = '1') then
              sAdcState     <= SER_LOAD;
              if (sHoldCounter < 2) then
                sHoldCounter  <= sHoldCounter + 1;
                oMULTI_ADC.SerLoad     <= '1'; 
              else
                oMULTI_ADC.SerLoad     <= '0'; 
                if (sDelayCounter < 1) then
                  sDelayCounter   <= sDelayCounter + 1;
                else
                  sHoldCounter    <= x"0001";                  
                  sDelayCounter   <= (others => '0');
                  sAdcState       <= SER_SEND;
                  oMULTI_ADC.SerSend       <= '1';
                end if;
              end if;
            end if;
          --!Enable the serializer output
          when SER_SEND =>            
            if (sFastClockR = '1') then
              sAdcState     <= SER_SEND;
              if (sHoldCounter < 8) then
                sHoldCounter  <= sHoldCounter + 1;
                oMULTI_ADC.SerSend     <= '1'; 
              else
                oMULTI_ADC.SerSend     <= '0'; 
                if (sDelayCounter < 1) then
                  sDelayCounter   <= sDelayCounter + 1;
                else
                  if (sAdcCounter < cFE_CHANNELS - 1) then
                    sHoldCounter    <= x"0001";
                    sDelayCounter   <= (others => '0');
                    sAdcCounter     <= sAdcCounter + 1;
                    sAdcState       <= SER_SHIFT;
                    oMULTI_ADC.SerShClk     <= '1';           
                  else
                    sFreqDivRst     <= '1';
                    sHoldCounter    <= (others => '0');
                    sDelayCounter   <= (others => '0');
                    sAdcCounter     <= (others => '0');
                    sAdcState       <= IDLE;
                    oFLAG.compl     <= '1';
                  end if;
                end if;
              end if;
            end if;
          
          when others =>
            oFLAG.error   <= '1';
            sAdcState     <= IDLE;   
        end case;
        
      end if;
    end if;
  end process;
  

  --- Receiver Data From ASTRA -----------------------------------------------------
  --!Combinatorial assignments
  --!sClkRx <= iCLK;
  
  --!@brief Generate multiple FIFO to sample the ADCs
  FIFO_GENERATE : for i in 0 to cTOTAL_ADCS - 1 generate
    sFifoIn(i).data <= sAdcFifo(i).data;
    sFifoIn(i).wr   <= sAdcFifo(i).wr;
    sFifoIn(i).rd   <= iMULTI_FIFO(i).rd;

    --!@brief FIFO buffer to collect data from the ADC
    --!@brief full and aFull flags are not used, the FIFO is supposed to be empty
    ADC_FIFO : parametric_fifo_dp
      generic map(
        pDEPTH
        pWIDTHW         => cADC_DATA_WIDTH,
        pWIDTHR         => cADC_DATA_WIDTH,
        pUSEDW_WIDTHW   => ceil_log2(cADC_FIFO_DEPTH),
        pUSEDW_WIDTHR   => ceil_log2(cADC_FIFO_DEPTH),
        pSHOW_AHEAD     => "OFF"
        )
      port map(
        iRST    => iRST,
        iCLK_W    => sClkRx,
        iCLK_R    => sClkRx,
        -- Write ports
        oEMPTY_W  => sFifoOut(i).empty,
        oFULL_W   => sFifoOut(i).full,
        oUSEDW_W  => open,
        iWR_REQ => sFifoIn(i).wr,
        iDATA   => sFifoIn(i).data,
        -- Read ports
        oEMPTY_R  => sFifoOut(i).empty,
        oFULL_R   => sFifoOut(i).full,
        oUSEDW_R  => open,
        iRD_REQ => sFifoIn(i).rd,
        oQ      => sFifoOut(i).q
        );
  end generate FIFO_GENERATE;
  
  --!@brief Generate multiple Shift-registers to sample the ADCs
  SR_GENERATE : for i in 0 to cTOTAL_ADCS - 1 generate
    sMultiSr(i).load  <= '0';
    sMultiSr(i).parIn <= (others => '0');
    sMultiSr(i).en    <= sSrEn;
    sMultiSr(i).serIn <= sAdcFpga(i).sData;

    --!@brief Shift register to sample and deserialize the single ADC output
    sampler : shift_register
      generic map(
        pWIDTH => cADC_DATA_WIDTH,
        pDIR   => "LEFT"                  --"RIGHT"
        )
      port map(
        iCLK      => sClkRx,
        iRST      => iRST,
        iEN       => sMultiSr(i).en,
        iLOAD     => sMultiSr(i).load,
        iSHIFT    => sMultiSr(i).serIn,
        iDATA     => sMultiSr(i).parIn,
        oSER_DATA => sMultiSr(i).serOut,
        oPAR_DATA => sMultiSr(i).parOut
        );

    sOutWord(i).data <= sMultiSr(i).parOut;
    sOutWord(i).wr   <= ;
    sOutWord(i).rd   <= ;
  end generate SR_GENERATE;
  
  --!I/O synchronization and buffering
  I/O_SYNCH_GENERATE : for i in 0 to cTOTAL_ADCS - 1 generate
    SER_DATA_SYNCH : sync_stage
      generic map (
        pSTAGES => 2
        )
      port map (
        iCLK  => sClkRx,
        iRST  => '0',
        iD    => iMULTI_ADC.SerData(i),
        oQ    => sDataSynch(i)
        );
    CLOCK_RET_SYNCH : sync_edge
      generic map (
        pSTAGES => 2
        )
      port map (
        iCLK      => sClkRx,
        iRST      => '0',
        iD        => iMULTI_ADC.(i),
        oQ        => open,
        oEDGE_R   => ,
        oEDGE_F   => 
        );
    SER_SEND_RET_SYNCH : sync_stage
      generic map (
        pSTAGES => 2
        )
      port map (
        iCLK  => sClkRx,
        iRST  => '0',
        iD    => i,
        oQ    => sSynch
        );
  end generate SR_GENERATE;


end Behavior;