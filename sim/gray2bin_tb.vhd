library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_unsigned.all;

use work.basic_package.all;


entity gray2bin_tb is

end entity gray2bin_tb;


architecture behav of gray2bin_tb is
  constant cSIZE : natural := 12;
  -- clock period
  constant cCLK_PERIOD : time := 20 ns;
  constant cWR_PERIOD : time := 40 ns;


  signal iCLK : std_logic;
  signal iRST : std_logic;

  signal sB2gWr, sG2bWr, sConvWr : std_logic;
  signal sBin     : std_logic_vector(cSIZE-1 DOWNTO 0);
  signal sGray    : std_logic_vector(cSIZE-1 DOWNTO 0);
  signal sBinConv : std_logic_vector(cSIZE-1 DOWNTO 0);
begin

  gray2binary_i : gray2binary
  generic map (
    pSIZE => cSIZE
  ) port map (
    iCLK  => iCLK,
    iRST  => iRST,
    iWR   => sG2bWr,
    oWR   => sConvWr,
    iGRAY => sGray,
    oBIN  => sBinConv
  );

  binary2gray_i : binary2gray
  generic map (
    pSIZE => cSIZE
  ) port map (
    iCLK  => iCLK,
    iRST  => iRST,
    iWR   => sB2gWr,
    oWR   => sG2bWr,
    iBIN  => sBin,
    oGRAY => sGray
  );

  grayConv_i : entity work.grayConv
  generic map (
    pSIZE => 16
    )
  port map (
    iCLK  => iCLK,
    iRST  => iRST,
    iWR   => sG2bWr,
    oWR   => open,
    iGRAY => sBinConv(3 downto 0) & sGray,
    oBIN  => open
    );

  CLK_PROC : process
  begin
    iCLK <= '1';
    wait for cCLK_PERIOD/2;
    iCLK <= '0';
    wait for cCLK_PERIOD/2;
  end process CLK_PROC;
  iRST <= '1', '0' after 90 ns;

  WR_PROC : process
  begin
    wait for cCLK_PERIOD/2;
    sB2gWr  <= '1';
    wait for cCLK_PERIOD;
    sB2gWr  <= '0';
    wait for cWR_PERIOD-cCLK_PERIOD/2;
  end process WR_PROC;

  STIM_PROC : process(iCLK)
  begin
    if(iCLK'event and iCLK='1') then
      if (iRST = '1') then
        sBin    <= std_logic_vector(to_unsigned(0, sBin'length));
      else
        if (sConvWr = '1') then
          assert (sBin = sBinConv)
            report "Conversion error - Orig: " & to_hstring(sBin) & " - Conv: " & to_hstring(sBinConv)
            severity error;
          assert (sBin /= std_logic_vector(to_unsigned(4095, sBin'length)))
            report "Ended"
            severity failure;
          sBin <= sBin + '1';
        end if;
      end if; --reset
  end if;
  end process;

  --STIM_PROC : process(iCLK)
  --begin
  --  if(iCLK'event and iCLK='1') then
  --    if (iRST = '1') then
  --      sG2bWr  <= '0';
  --      sGray   <= std_logic_vector(to_unsigned(0, sGray'length));
  --    else
  --      sG2bWr <= '1';
  --      if (sConvWr = '1') then
  --        assert (sBinConv /= std_logic_vector(to_unsigned(4095, sGray'length)))
  --          report "Ended"
  --          severity failure;
  --        sGray <= sGray + '1';
  --      end if;
  --    end if; --reset
  --end if;
  --end process;


end architecture behav;
