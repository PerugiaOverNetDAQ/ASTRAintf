--!@file parametric_fifo_dp.vhd
--!@brief Parametric FIFO from the IP-catalog component dpfifo
--!@author Mattia Barbanera, mattia.barbanera@infn.it
--!@date 10/04/2020
--!@version 0.1 - 10/04/2020 - First draft

library ieee;
use ieee.std_logic_1164.all;

library altera;
use altera.all;

library altera_mf;
use altera_mf.all;

--!@brief Parametric FIFO from the IP-catalog component dpfifo
--!@details Multipurpose parametric dual-port dual-clock FIFO
entity parametric_fifo_dp is
  generic(
    pDEPTH        : natural;   --!FIFO number of word; max 131072, power of 2
    pWIDTHW       : natural;            --!Word width (W): max 256, 1-bit step
    pWIDTHR       : natural;            --!Word width (R): max 256, 1-bit step
    pUSEDW_WIDTHW : natural;   --!log2 of pDEPTH (W): max 17, 1-bit step
    pUSEDW_WIDTHR : natural;   --!log2 of pDEPTH (R): max 17, 1-bit step
    pSHOW_AHEAD   : string              --!Showahead enable: "ON" or "OFF"
    );
  port(
    iRST     : in  std_logic;           --!Synchronous reset
    iCLK_W   : in  std_logic;           --!Write clock (W)
    iCLK_R   : in  std_logic;           --!Read clock (R)
    -- Write ports
    oEMPTY_W : out std_logic;           --!Empty flag (W)
    oFULL_W  : out std_logic;           --!Full flag (W)
    oUSEDW_W : out std_logic_vector(pUSEDW_WIDTHW-1 downto 0);  --!Used-words (W)
    iWR_REQ  : in  std_logic;           --!Write request
    iDATA    : in  std_logic_vector(pWIDTHW-1 downto 0);  --!Input data to write
    -- Read ports
    oEMPTY_R : out std_logic;           --!Empty flag (R)
    oFULL_R  : out std_logic;           --!Full flag (R)
    oUSEDW_R : out std_logic_vector(pUSEDW_WIDTHR-1 downto 0);  --!Used-words (R)
    iRD_REQ  : in  std_logic;           --!Read request (ACK if showahead)
    oQ       : out std_logic_vector(pWIDTHR-1 downto 0)  --!Output data to read
    );
end parametric_fifo_dp;

architecture SYN of parametric_fifo_dp is
  component dcfifo_mixed_widths
    generic (
      intended_device_family : string;
      lpm_numwords           : natural;
      lpm_showahead          : string;
      lpm_type               : string;
      lpm_width              : natural;
      lpm_widthu             : natural;
      lpm_widthu_r           : natural;
      lpm_width_r            : natural;
      overflow_checking      : string;
      rdsync_delaypipe       : natural;
      read_aclr_synch        : string;
      underflow_checking     : string;
      use_eab                : string;
      write_aclr_synch       : string;
      wrsync_delaypipe       : natural
      );
    port (
      aclr    : in  std_logic;
      data    : in  std_logic_vector (pWIDTHW-1 downto 0);
      rdclk   : in  std_logic;
      rdreq   : in  std_logic;
      wrclk   : in  std_logic;
      wrreq   : in  std_logic;
      q       : out std_logic_vector (pWIDTHR-1 downto 0);
      rdempty : out std_logic;
      rdfull  : out std_logic;
      rdusedw : out std_logic_vector (pUSEDW_WIDTHR-1 downto 0);
      wrempty : out std_logic;
      wrfull  : out std_logic;
      wrusedw : out std_logic_vector (pUSEDW_WIDTHW-1 downto 0)
      );
  end component;

begin

  dcfifo_mixed_widths_component : dcfifo_mixed_widths
    generic map (
      intended_device_family => "Cyclone V",
      lpm_type               => "dcfifo_mixed_widths",
      lpm_numwords           => pDEPTH,
      lpm_width              => pWIDTHW,
      lpm_width_r            => pWIDTHR,
      lpm_widthu             => pUSEDW_WIDTHW,
      lpm_widthu_r           => pUSEDW_WIDTHR,
      wrsync_delaypipe       => 3,
      rdsync_delaypipe       => 3,
      write_aclr_synch       => "ON",
      read_aclr_synch        => "ON",
      overflow_checking      => "ON",
      underflow_checking     => "ON",
      use_eab                => "ON",
      lpm_showahead          => pSHOW_AHEAD
      )
    port map (
      aclr    => iRST,
      data    => iDATA,
      rdclk   => iCLK_R,
      rdreq   => iRD_REQ,
      wrclk   => iCLK_W,
      wrreq   => iWR_REQ,
      q       => oQ,
      rdempty => oEMPTY_R,
      rdfull  => oFULL_R,
      rdusedw => oUSEDW_R,
      wrempty => oEMPTY_W,
      wrfull  => oFULL_W,
      wrusedw => oUSEDW_W
      );

end SYN;
