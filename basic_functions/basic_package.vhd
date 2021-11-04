--! @file basic_package.vhd
--!@brief Basic functions and components
--!@author Mattia Barbanera, mattia.barbanera@infn.it
--!@author Hikmat Nasimi, hikmat.nasimi@pi.infn.it
--!@date 28/01/2020
--!@version 0.1 - 28/01/2020 -

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_unsigned.all;

--!@brief Basic functions and components
package basic_package is
  -- Functions -----------------------------------------------------------------
  --!@brief Converts integer to std_logic_vector(l-1 downto 0)
  --!@param[in] n Integer to convert into std_logic_vector
  --!@param[in] l length of the output std_logic_vector
  --!@return  Unsigned conversion of n into a std_logic_vector(l-1 downto 0)
  function int2slv (n : integer; l : natural) return std_logic_vector;
  --!@brief Converts std_logic_vector to integer
  --!@param[in] n std_logic_vector to converted into integer
  --!@return  Unsigned conversion of n into an integer value
  function slv2int (n : std_logic_vector) return integer;
  --!@brief Returns the minimum power of 2 grater than or equal to n
  --!@param[in] n Natural to approximate with a power of 2
  --!@return  Minimum power of 2 greater than or equal to n
  function min_pow2_gte (n : natural) return natural;
  --!@brief Returns the ceiling of the logarithm to base 2 of the parameter n
  --!@param n Argument of the logarithm
  --!@return  The minimum integer greater than n
  function ceil_log2 (n : natural) return natural;
  --!Reverse the order of the bits of a std_logic_vector
  --!@param[in] a std_logic_vector to invert
  --!@return  std_logic_vector corresponding to 'a' with reverse bits order
  function reverse_vector (a : in std_logic_vector) return std_logic_vector;

  -- Components ----------------------------------------------------------------
  -- sync_stage ----------------------------------------------------------------
  component sync_stage is
    generic(pSTAGES  : natural);
    port(iCLK, iRST, iD  : in  std_logic;
      oQ : out std_logic);
  end component;
  -- edge_detector -------------------------------------------------------------
  component edge_detector is
    port(iCLK, iRST, iD  : in  std_logic;
      oQ, oEDGE_R, oEDGE_F  : out std_logic);
  end component;
  -- sync_edge -----------------------------------------------------------------
  component sync_edge is
    generic(pSTAGES  : natural);
    port(iCLK, iRST, iD  : in  std_logic;
      oQ, oEDGE_R, oEDGE_F  : out std_logic);
  end component;
  -- counter -------------------------------------------------------------------
  component counter is
    generic(pOVERLAP   : string;
        pBUSWIDTH  : natural);
    port(iCLK, iEN, iRST, iLOAD  : in  std_logic;
       iDATA   : in  std_logic_vector (pBUSWIDTH-1 downto 0);
       oCOUNT  : out std_logic_vector (pBUSWIDTH-1 downto 0);
       oCARRY  : out std_logic);
  end component;
  -- shift_register ------------------------------------------------------------
  component shift_register is
    generic(pWIDTH  : integer;
        pDIR  : string);
    port(iCLK, iEN, iRST, iLOAD, iSHIFT  : in  std_logic;
       iDATA       : in  std_logic_vector(pWIDTH-1 downto 0);
       oSER_DATA   : out std_logic;
       oPAR_DATA   : out std_logic_vector(pWIDTH-1 downto 0));
  end component;
  -- clock_divider -------------------------------------------------------------
  component clock_divider is
    generic(pPOLARITY : std_logic);
    port(iCLK, iRST, iEN : in  std_logic;
       oCLK_OUT, oCLK_OUT_RISING, oCLK_OUT_FALLING : out std_logic;
       iFREQ_DIV   : in  std_logic_vector(15 downto 0);
	   iDUTY_CYCLE : in  std_logic_vector(15 downto 0));
  end component;
  -- parametric_fifo_synch -----------------------------------------------------
  component parametric_fifo_synch is
    generic(pWIDTH, pDEPTH, pUSEDW_WIDTH : natural;
      pAEMPTY_VAL, pAFULL_VAL : natural;
      pSHOW_AHEAD  : string);
    port(iCLK, iRST : in  std_logic;
      oAEMPTY, oEMPTY, oAFULL, oFULL : out std_logic;
      oUSEDW  : out std_logic_vector (pUSEDW_WIDTH-1 downto 0);
      iRD_REQ, iWR_REQ : in  std_logic;
      iDATA   : in  std_logic_vector (pWIDTH-1 downto 0);
      oQ      : out std_logic_vector (pWIDTH-1 downto 0)
      );
  end component;
  -- dp_fifo -------------------------------------------------------------------
  component parametric_fifo_dp is
    generic(pDEPTH, pWIDTHW, pWIDTHR : natural;
      pUSEDW_WIDTHW, pUSEDW_WIDTHR : natural;
      pSHOW_AHEAD : string);
    port(iRST, iCLK_W, iCLK_R : in  std_logic;
      oEMPTY_W, oFULL_W  : out std_logic;
      oUSEDW_W  : out std_logic_vector(pUSEDW_WIDTHW-1 downto 0);
      iWR_REQ   : in  std_logic;
      iDATA     : in  std_logic_vector(pWIDTHW-1 downto 0);
      oEMPTY_R, oFULL_R  : out std_logic;
      oUSEDW_R  : out std_logic_vector(pUSEDW_WIDTHR-1 downto 0);
      iRD_REQ   : in  std_logic;
      oQ        : out std_logic_vector(pWIDTHR-1 downto 0)
      );
  end component;
  -- ALTIOBUF  -----------------------------------------------------------------
component differential_rx is
  generic(pWIDTH : natural := 1);
  port(iDATAp : in  std_logic_vector (pWIDTH-1 downto 0);
       iDATAn : in  std_logic_vector (pWIDTH-1 downto 0);
       oQ     : out std_logic_vector (pWIDTH-1 downto 0));
 end component;
 component STD_FIFO is
 Generic (
		constant DATA_WIDTH  : natural;
		constant FIFO_DEPTH	: natural
	);
	Port (
		CLK		: in  STD_LOGIC;
		RST		: in  STD_LOGIC;
		WriteEn	: in  STD_LOGIC;
		DataIn	: in  STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		ReadEn	: in  STD_LOGIC;
		DataOut	: out STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		Empty	: out STD_LOGIC;
		Full	: out STD_LOGIC
	);

end component;
  -- pulse_generator -----------------------------------------------------------
  component pulse_generator is
    generic(pWIDTH : natural; pPOLARITY : std_logic; pLENGTH   : natural);
    port(iCLK, iRST, iEN  : in  std_logic;
      oPULSE, oPULSE_RISING, oPULSE_FALLING : out std_logic;
      iPERIOD : in  std_logic_vector(pWIDTH-1 downto 0));
  end component;
  -- delay_timer ---------------------------------------------------------------
  component delay_timer is
    port(iCLK, iRST, iSTART  : in  std_logic;
      oBUSY, oOUT : out std_logic;
      iDELAY : in  std_logic_vector(15 downto 0));
  end component;

  -- Types ---------------------------------------------------------------------
  --!Counter interface with load, preset, enable and carry;
  --!Variable length record that needs a subtype to define the length
  --!@bug Quartus standard does not support unconstrained records:
  --!https://stackoverflow.com/questions/7925361/passing-generics-to-record-port-types
  --type tCountInterface is record
  --  preset  : std_logic_vector;
  --  count   : std_logic_vector;
  --  en      : std_logic;
  --  load    : std_logic;
  --  carry   : std_logic;
  --end record tCountInterface;

end basic_package;

package body basic_package is
  -- Functions -----------------------------------------------------------------
  --!Converts integer to std_logic_vector(l-1 downto 0)
  function int2slv (n : integer; l : natural) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(n, l));
  end function;   -- function int2slv

  --!Converts std_logic_vector to integer
  function slv2int (n : std_logic_vector) return integer is
  begin
    return to_integer(unsigned(n));
  end function;   -- function slv2int

  --!Returns the minimum power of 2 grater than or equal to n
  function min_pow2_gte(n : natural) return natural is
  begin
    return natural(2**(ceil(log2(real(n)))));
  end function;   -- function min_pow2_gte

  --!Returns the ceiling of the logarithm to base 2 of the parameter n
  function ceil_log2(n : natural) return natural is
  begin
    return natural(ceil(log2(real(n))));
  end function;   -- function ceil_log2

  --!Reverse the order of the bits of a std_logic_vector
  function reverse_vector (a : in std_logic_vector) return std_logic_vector is
    variable result : std_logic_vector(a'range);
    alias aa        : std_logic_vector(a'reverse_range) is a;
  begin
    for i in aa'range loop
      result(i) := aa(i);
    end loop;
    return result;
  end;  -- function reverse_vector

end package body;
