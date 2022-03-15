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
use work.user_package.all;


--!@copydoc ADC_INT_driver.vhd
entity ADC_INT_driver is
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
    --!ADC Main Commands
    oFAST_CLK       : out std_logic;     --!Input of ADC fast clock (25-100 MHz)
    oRST_DIG        : out std_logic;     --!Reset of the ADC, counter and serializer
    oADC_CONV       : out std_logic;     --!Digital pulse to start the conversion of the ADC
    --!Serializer Command/Data
    iMULTI_ADC      : in  tMultiAstraAdc2Fpga;  --!Signals from the ADCs to the FPGA
    oMULTI_ADC      : out tFpga2AstraAdc;       --!Signals from the FPGA to the ADCs
    --!Word in output
    iMULTI_FIFO_RE  : in  std_logic_vector (cTOTAL_ADCS-1 downto 0);   --!Read request
    oMULTI_FIFO     : out tMultiAdcFifoOut      --!Output data, empty and full FIFO
    );
end ADC_INT_driver;


--!@copydoc ADC_INT_driver.vhd
architecture Behavior of ADC_INT_driver is
  --!FSM states
  type tAdcStatus is (IDLE, ADC_RST, ADC_CONV, SER_SHIFT, SER_LOAD, SER_SEND);
  signal sAdcState : tAdcStatus;

  --!FSM counter
  signal sHoldCounter       : std_logic_vector(15 downto 0);  --!Signals duration
  signal sDelayCounter      : std_logic_vector(15 downto 0);  --!Delay between signals
  signal sAdcCounter        : std_logic_vector(4 downto 0);   --!ADC select

  --!Clock_divider Interface
  signal sFreqDivRst        : std_logic;    --!Reset
  signal sFastClockR        : std_logic;    --!Output rising edge
  signal sFastClockF        : std_logic;    --!Output falling edge
  signal sClkRx				      : std_logic;	  --!Receiver clock
  
  --!ASTRA output signal interface
  signal sSerDataSynch      : std_logic_vector(cTOTAL_ADCS-1 downto 0);   --!Input data from serializer bit stream, synchronized
  signal sClkRetSynch       : std_logic_vector(cTOTAL_ADCS-1 downto 0);   --!Return clock from ASTRA
  signal sClkRetSynchR      : std_logic_vector(cTOTAL_ADCS-1 downto 0);   --!Rising edge of return clock from ASTRA
  signal sClkRetSynchF      : std_logic_vector(cTOTAL_ADCS-1 downto 0);   --!Falling edge of return clock from ASTRA
  signal sSerSendRetSynch   : std_logic_vector(cTOTAL_ADCS-1 downto 0);   --!Return SER_SEND from ASTRA, synchronized
  
  --!MultiShift register interface
  signal sMultiSr : tMultiShiftRegIntf;
  
  --!Internal MultiFIFO Interface
  signal sFifoIn  : tMultiAdcFifoIn;
  
  
begin
  --- Clock Management -------------------------------------------------------------
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
    
  --!PLL with "auto-reset" ON (automatically self-resets the PLL on loss of lock)
	generate_fast_clock_1 : pll
	port map(
    refclk   =>	iCLK,
    rst      =>	sFreqDivRst,
		outclk_0 =>	open,     --!Fast clock (25 MHz)
    outclk_1 =>	open,     --!FSM clock (50 MHz)
    outclk_2 =>	open,     --!Receiver clock (100 MHz)
    outclk_3 =>	open,     --!(200 MHz)
		locked   => open	
		);
    
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
        oFLAG			      <= ('0', '0', '1', '0');	  --!reset FLAG = '1'
        oRST_DIG        <= '0';
        oADC_CONV       <= '0';
        oMULTI_ADC.SerShClk   <= '0';
        oMULTI_ADC.SerLoad    <= '0';
        oMULTI_ADC.SerSend    <= '0';        
      elsif (iCTRL.en = '1') then
        --!default values, to be overwritten when necessary
        sFreqDivRst     <= '0';
        oFLAG			      <= ('1', '0', '0', '0');	  --!busy FLAG = '1'
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
              sAdcState       <= ADC_RST;
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
              sAdcState       <= SER_SHIFT;
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
  sClkRx <= iCLK;
  
  --!I/O synchronization and buffering
  SYNCH_GENERATE : for i in 0 to cTOTAL_ADCS - 1 generate
    --!Return Clock from TFH
    CLOCK_RET_SYNCH : sync_edge
      generic map (
        pSTAGES => 2
        )
      port map (
        iCLK      => sClkRx,
        iRST      => '0',
        iD        => iMULTI_ADC(i).ClkRet,
        oQ        => sClkRetSynch(i),
        oEDGE_R   => sClkRetSynchR(i),
        oEDGE_F   => sClkRetSynchF(i)
        );
    --!Return SER_SEND from TFH
    SER_SEND_RET_SYNCH : sync_stage
      generic map (
        pSTAGES => 2
        )
      port map (
        iCLK  => sClkRx,
        iRST  => '0',
        iD    => iMULTI_ADC(i).SerSendRet,
        oQ    => sSerSendRetSynch(i)
        );
    --!ADC Data from serializer
    SER_DATA_SYNCH : sync_stage
      generic map (
        pSTAGES => 2
        )
      port map (
        iCLK  => sClkRx,
        iRST  => '0',
        iD    => iMULTI_ADC(i).SerData,
        oQ    => sSerDataSynch(i)
        );
  end generate SYNCH_GENERATE;
  
  --!Generate multiple Shift-registers to sample the ADCs
  SR_GENERATE : for i in 0 to cTOTAL_ADCS - 1 generate
    --!Combinatorial assignments
    sMultiSr(i).en    <= sClkRetSynchR(i) or sClkRetSynchF(i) when (sSerSendRetSynch(i) = '1') else
                         '0';

    --!Shift register to sample and deserialize the single ADC output
    SAMPLER : shift_register
      generic map(
        pWIDTH => cADC_DATA_WIDTH,
        pDIR   => "LEFT"                  --"RIGHT"
        )
      port map(
        iCLK      => sClkRx,
        iRST      => iRST,
        iEN       => sMultiSr(i).en,
        iLOAD     => '0',
        iSHIFT    => sSerDataSynch(i),
        iDATA     => (others => '0'),
        oSER_DATA => open,
        oPAR_DATA => sFifoIn(i).data
        );
  end generate SR_GENERATE;
  
  --!Generate multiple FIFO to synchronize data with ASTRA main clock
  FIFO_GENERATE : for i in 0 to cTOTAL_ADCS - 1 generate
    WRITE_WORD : edge_detector
    port map(
      iCLK      => sClkRx,
      iRST      => '0',
      iD        => sSerSendRetSynch(i),
      oQ        => open,
      oEDGE_R   => open,
      oEDGE_F   => sFifoIn(i).wr
    ); 

    --!Full and aFull flags are not used, the FIFO is supposed to be empty
    ADC_FIFO : parametric_fifo_dp
      generic map(
        pDEPTH          => cADC_MULTIFIFO_DEPTH,
        pWIDTHW         => cADC_DATA_WIDTH,
        pWIDTHR         => cADC_DATA_WIDTH,
        pUSEDW_WIDTHW   => ceil_log2(cADC_MULTIFIFO_DEPTH),
        pUSEDW_WIDTHR   => ceil_log2(cADC_MULTIFIFO_DEPTH),
        pSHOW_AHEAD     => "OFF"
        )
      port map(
        iRST      => iRST,
        iCLK_W    => sClkRx,
        iCLK_R    => sClkRx,
        --Write ports
        oEMPTY_W  => open,
        oFULL_W   => open,
        oUSEDW_W  => open,
        iWR_REQ   => sFifoIn(i).wr,
        iDATA     => sMultiSr(i).parOut,
        --Read ports
        oEMPTY_R  => oMULTI_FIFO(i).empty,
        oFULL_R   => oMULTI_FIFO(i).full,
        oUSEDW_R  => open,
        iRD_REQ   => iMULTI_FIFO_RE(i),
        oQ        => oMULTI_FIFO(i).q
        );        
  end generate FIFO_GENERATE;
  
  
end Behavior;