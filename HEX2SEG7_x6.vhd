library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity SEG7_LUT is
	port(	HEXin	:		in  std_logic_vector(3 downto 0);
			HEXenable :	in  std_logic;
			SEG7 :		out std_logic_vector(6 downto 0)
	);
end SEG7_LUT;


architecture rtl of SEG7_LUT is

begin
--segment is active low
Decod: process(HEXin, HEXenable)
begin
	if HEXenable = '1' then
		case HEXin is
			when "0000" => SEG7 <= "1000000";
			when "0001" => SEG7 <= "1111001";
			when "0010" => SEG7 <= "0100100";
			when "0011" => SEG7 <= "0110000";
			when "0100" => SEG7 <= "0011001";
			when "0101" => SEG7 <= "0010010";
			when "0110" => SEG7 <= "0000010";
			when "0111" => SEG7 <= "1111000";
			when "1000" => SEG7 <= "0000000";
			when "1001" => SEG7 <= "0011000";
			when "1010" => SEG7 <= "0001000";
			when "1011" => SEG7 <= "0000011";
			when "1100" => SEG7 <= "1000110";
			when "1101" => SEG7 <= "0100001";
			when "1110" => SEG7 <= "0000110";
			when "1111" => SEG7 <= "0001110";
			when others => SEG7 <= "XXXXXXX";
		end case;
	else
		SEG7 <= "1111111";
	end if;
end process Decod;

end architecture rtl;


-- 6 x SEG7 instances
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.all;

entity SEG7_LUT_x6 is
	port(	HEXin_x6	:		in  std_logic_vector(23 downto 0);
			HEXenable_x6 :	in  std_logic_vector(5 downto 0);
			SEG7_x6	:		out std_logic_vector(41 downto 0)
	);
end SEG7_LUT_x6;

architecture rtl of SEG7_LUT_x6 is

begin
	-- HEX 0
	u0 : entity SEG7_LUT port map(	HEXin => HEXin_x6(3 downto 0),
									HEXenable => HEXenable_x6(0),
									SEG7 => SEG7_x6(6 downto 0));
	-- HEX 1
	u1 : entity SEG7_LUT port map(	HEXin => HEXin_x6(7 downto 4),
									HEXenable => HEXenable_x6(1),
									SEG7 => SEG7_x6(13 downto 7));
	-- HEX 2
	u2 : entity SEG7_LUT port map(	HEXin => HEXin_x6(11 downto 8),
									HEXenable => HEXenable_x6(2),
									SEG7 => SEG7_x6(20 downto 14));
	-- HEX 3
	u3 : entity SEG7_LUT port map(	HEXin => HEXin_x6(15 downto 12),
									HEXenable => HEXenable_x6(3),
									SEG7 => SEG7_x6(27 downto 21));
	-- HEX 4
	u4 : entity SEG7_LUT port map(	HEXin => HEXin_x6(19 downto 16),
									HEXenable => HEXenable_x6(4),
									SEG7 => SEG7_x6(34 downto 28));
	-- HEX 5
	u5 : entity SEG7_LUT port map(	HEXin => HEXin_x6(23 downto 20),
									HEXenable => HEXenable_x6(5),
									SEG7 => SEG7_x6(41 downto 35));
end architecture rtl;
