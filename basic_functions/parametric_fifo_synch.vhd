--!@file parametric_fifo_synch.vhd
--!@brief Parametric FIFO from the IP-catalog component scfifo
--!@author Mattia Barbanera, mattia.barbanera@infn.it
--!@date 10/04/2020
--!@version 0.1 - 10/04/2020 - First draft

library ieee;
use ieee.std_logic_1164.all;

library altera;
use altera.all;

library altera_mf;
use altera_mf.all;

--!@brief Parametric FIFO from the IP-catalog component scfifo
--!@details Multipurpose parametric FIFO with synchronous reset
entity parametric_fifo_synch is
  generic(
    pWIDTH       : natural;  --!Word width: max 256, 1-bit step
    pDEPTH       : natural;  --!FIFO number of word; max 131072, power of 2
    pUSEDW_WIDTH : natural;  --!log2 of pDEPTH: max 17, 1-bit step
    pAEMPTY_VAL  : natural;  --!Almost-Empty value: (0<AEMPTYV<AFV)
    pAFULL_VAL   : natural;  --!Almost-Full value: (AEMPTYV<AFULLV<numwords)
    pSHOW_AHEAD  : string    --!Showahead enable: "ON" or "OFF"
    );
  port(
    iCLK    : in  std_logic; --!Main clock
    iRST    : in  std_logic; --!Synchronous reset
    -- control interface
    oAEMPTY : out std_logic; --!Almost empty flag
    oEMPTY  : out std_logic; --!Empty flag
    oAFULL  : out std_logic; --!Almost full flag
    oFULL   : out std_logic; --!Full flag
    oUSEDW  : out std_logic_vector (pUSEDW_WIDTH-1 downto 0); --!Used-words cnt
    iRD_REQ : in  std_logic; --!Read request (ACK if showahead)
    iWR_REQ : in  std_logic; --!Write request
    -- data interface
    iDATA   : in  std_logic_vector (pWIDTH-1 downto 0); --!Input data to write
    oQ      : out std_logic_vector (pWIDTH-1 downto 0)  --!Output data to read
    );
end parametric_fifo_synch;

architecture SYN of parametric_fifo_synch is
  component scfifo
    generic (
      add_ram_output_register : string;
      almost_empty_value      : natural;
      almost_full_value       : natural;
      intended_device_family  : string;
      lpm_numwords            : natural;
      lpm_showahead           : string;
      lpm_type                : string;
      lpm_width               : natural;
      lpm_widthu              : natural;
      overflow_checking       : string;
      underflow_checking      : string;
      use_eab                 : string
      );
    port (
      clock        : in  std_logic;
      usedw        : out std_logic_vector (pUSEDW_WIDTH-1 downto 0);
      empty        : out std_logic;
      full         : out std_logic;
      q            : out std_logic_vector (pWIDTH-1 downto 0);
      wrreq        : in  std_logic;
      sclr         : in  std_logic;
      almost_empty : out std_logic;
      almost_full  : out std_logic;
      data         : in  std_logic_vector (pWIDTH-1 downto 0);
      rdreq        : in  std_logic
      );
  end component;

begin
  scfifo_component : scfifo
    generic map (
      add_ram_output_register => "ON",
      almost_empty_value      => pAEMPTY_VAL,
      almost_full_value       => pAFULL_VAL,
      intended_device_family  => "Cyclone V",
      lpm_numwords            => pDEPTH,
      lpm_showahead           => pSHOW_AHEAD,
      lpm_type                => "scfifo",
      lpm_width               => pWIDTH,
      lpm_widthu              => pUSEDW_WIDTH,
      overflow_checking       => "ON",
      underflow_checking      => "ON",
      use_eab                 => "ON"
      )
    port map (
      clock        => iCLK,
      data         => iDATA,
      rdreq        => iRD_REQ,
      sclr         => iRST,
      wrreq        => iWR_REQ,
      usedw        => oUSEDW,
      empty        => oEMPTY,
      full         => oFULL,
      q            => oQ,
      almost_empty => oAEMPTY,
      almost_full  => oAFULL
      );

end SYN;
