-- ============================================================================
--   Ver  :| Author            :| Mod. Date :| Changes Made:
--   V1.1 :| T. Rampone        :| 06/04/2017:| minor correction
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.all;

entity DE0_CV_top is
	port(	-- CLOCKS 50 MHz (x4)
			CLOCK2_50 :			in std_logic;
			CLOCK3_50 :			in std_logic;
			CLOCK4_50 :			inout std_logic;
			CLOCK_50 :			in std_logic;
			-- DRAM
			DRAM_ADDR :			out std_logic_vector(12 downto 0);
			DRAM_BA :			out std_logic_vector(1 downto 0);
			DRAM_CAS_N :		out std_logic;
			DRAM_CKE :			out std_logic;
			DRAM_CLK :			out std_logic;
			DRAM_CS_N :			out std_logic;
			DRAM_DQ :			inout std_logic_vector(15 downto 0);
			DRAM_LDQM :			out std_logic;
			DRAM_RAS_N :		out std_logic;
			DRAM_UDQM :			out std_logic;
			DRAM_WE_N :			out std_logic;
			-- GPIO
			GPIO_0 :				inout std_logic_vector(35 downto 0);
			GPIO_1 :				inout std_logic_vector(35 downto 0);
			-- HEX0
			HEX0 :				out std_logic_vector(6 downto 0);
			-- HEX1
			HEX1 :				out std_logic_vector(6 downto 0);
			-- HEX2
			HEX2 :				out std_logic_vector(6 downto 0);
			-- HEX3
			HEX3 :				out std_logic_vector(6 downto 0);
			-- HEX4
			HEX4 :				out std_logic_vector(6 downto 0);
			-- HEX5
			HEX5 :				out std_logic_vector(6 downto 0);
			-- KEY
			KEY :					in std_logic_vector(3 downto 0);
			-- LEDR
			LEDR :				out std_logic_vector(9 downto 0);
			-- PS2
			PS2_CLK :			inout std_logic;
			PS2_CLK2 :			inout std_logic;
			PS2_DAT :			inout std_logic;
			PS2_DAT2 :			inout std_logic;
			-- RESET_N
			RESET_N :			in std_logic;
			-- SD
			SD_CLK :				out std_logic;
			SD_CMD :				inout std_logic;
			SD_DATA :			inout std_logic_vector(3 downto 0);
			-- SW
			SW :					in std_logic_vector(9 downto 0);
			-- VGA
			VGA_B :				out std_logic_vector(3 downto 0);
			VGA_G :				out std_logic_vector(3 downto 0);
			VGA_HS :				out std_logic;
			VGA_R :				out std_logic_vector(3 downto 0);
			VGA_VS :				out std_logic
	);
end DE0_CV_top;

architecture rtl of DE0_CV_top is

-- pll
signal pll_locked : std_logic;

-- seven segment decoder
constant seg7_enable : std_logic_vector(5 downto 0) := "111111";
signal seg7_digits : std_logic_vector(23 downto 0);
signal SEG7_x6_wires : std_logic_vector(41 downto 0);

-- SDRAM
signal sdram_dqm : std_logic_vector(1 downto 0);

component DE0_CV_QSYS is
        port (
            clk_clk                 : in    std_logic                     := 'X';             -- clk
            clk_sdram_clk           : out   std_logic;                                        -- clk
            keys_wire_export        : in    std_logic_vector(3 downto 0)  := (others => 'X'); -- export
            leds_wire_export        : out   std_logic_vector(9 downto 0);                     -- export
            pll_locked_export       : out   std_logic;                                        -- export
            reset_reset_n           : in    std_logic                     := 'X';             -- reset_n
            sdram_wire_addr         : out   std_logic_vector(12 downto 0);                    -- addr
            sdram_wire_ba           : out   std_logic_vector(1 downto 0);                     -- ba
            sdram_wire_cas_n        : out   std_logic;                                        -- cas_n
            sdram_wire_cke          : out   std_logic;                                        -- cke
            sdram_wire_cs_n         : out   std_logic;                                        -- cs_n
            sdram_wire_dq           : inout std_logic_vector(15 downto 0) := (others => 'X'); -- dq
            sdram_wire_dqm          : out   std_logic_vector(1 downto 0);                     -- dqm
            sdram_wire_ras_n        : out   std_logic;                                        -- ras_n
            sdram_wire_we_n         : out   std_logic;                                        -- we_n
            seg7_digits_wire_export : out   std_logic_vector(23 downto 0);                    -- export
            switches_wire_export    : in    std_logic_vector(9 downto 0)  := (others => 'X')  -- export
        );
end component DE0_CV_QSYS;

begin
-- seven segment decoder
HEX5 <= SEG7_x6_wires(41 downto 35);
HEX4 <= SEG7_x6_wires(34 downto 28);
HEX3 <= SEG7_x6_wires(27 downto 21);
HEX2 <= SEG7_x6_wires(20 downto 14);
HEX1 <= SEG7_x6_wires(13 downto 7);
HEX0 <= SEG7_x6_wires(6 downto 0);

-- SDRAM
DRAM_UDQM <= sdram_dqm(1);
DRAM_LDQM <= sdram_dqm(0);

-- QSys module    
u0 : component DE0_CV_QSYS
	port map (
		clk_clk              => CLOCK_50,
		clk_sdram_clk        => DRAM_CLK,
		keys_wire_export     => KEY,
		leds_wire_export     => LEDR,
		pll_locked_export    => pll_locked,
		reset_reset_n        => RESET_N,
		sdram_wire_addr      => DRAM_ADDR,
		sdram_wire_ba        => DRAM_BA,
		sdram_wire_cas_n     => DRAM_CAS_N,
		sdram_wire_cke       => DRAM_CKE,
		sdram_wire_cs_n      => DRAM_CS_N,
		sdram_wire_dq        => DRAM_DQ,
		sdram_wire_dqm       => sdram_dqm,
		sdram_wire_ras_n     => DRAM_RAS_N,
		sdram_wire_we_n      => DRAM_WE_N,
		switches_wire_export => SW,
		seg7_digits_wire_export => seg7_digits
	);

-- Seven seg. decoder
u1 : entity SEG7_LUT_x6
	port map (
		HEXin_x6	=> seg7_digits,
		HEXenable_x6 => seg7_enable,
		SEG7_x6 => SEG7_x6_wires
	);
	

end architecture rtl;