library cyclonev;
use cyclonev.all;

--synthesis_resources = cyclonev_io_ibuf 1 
library ieee;
use ieee.std_logic_1164.all;

entity differential_rx is
  generic(
    pWIDTH : natural := 1  --Number of input ports (greater than 0)
    );
  port(
    iDATAp : in  std_logic_vector (pWIDTH-1 downto 0);
    iDATAn : in  std_logic_vector (pWIDTH-1 downto 0) := (others => '0');
    oQ     : out std_logic_vector (pWIDTH-1 downto 0)
    );
end differential_rx;

architecture std of differential_rx is

  component cyclonev_io_ibuf
    generic(
      bus_hold          : string := "false";
      differential_mode : string := "false";
      simulate_z_as     : string := "z";
      lpm_type          : string := "cyclonev_io_ibuf"
      );
    port(
      dynamicterminationcontrol : in  std_logic := '0';
      i                         : in  std_logic := '0';
      ibar                      : in  std_logic := '0';
      o                         : out std_logic
      );
  end component;
begin

  rx_gen : for i in 0 to pWIDTH-1 generate
    ibufa : cyclonev_io_ibuf
      generic map (
        bus_hold          => "false",
        differential_mode => "true"
        )
      port map (
        i    => iDATAp(i),
        ibar => iDATAn(i),
        o    => oQ(i)
        );
  end generate rx_gen;

end architecture std;
