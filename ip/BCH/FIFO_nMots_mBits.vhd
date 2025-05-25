library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity FIFO_nMots_mBits is 
  generic (DATA_WIDTH : integer := 8;
           FIFO_SIZE : integer := 3);
	port(Horloge, initFifo, WrFifo, RdFifo : in std_logic;
	     DataIn : in std_logic_vector(DATA_WIDTH-1 downto 0);
	     DataOut : out std_logic_vector(DATA_WIDTH-1 downto 0);
	     FifoLevel : out std_logic_vector(FIFO_SIZE downto 0);
	     FifoEmpty, FifoFull : out std_logic);
end entity FIFO_nMots_mBits;

architecture rtl of FIFO_nMots_mBits is
	signal adrFifo : integer range 0 to 2**FIFO_SIZE; --nombre de mots + position débordement
	type memory is array(0 to 2**FIFO_SIZE-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
	signal Fifo : memory;
begin
MyFifo : process(Horloge)
variable FifoAccess : std_logic_vector(1 downto 0);
begin
	if (rising_edge(Horloge)) then
	  if initFifo = '1' then     --raz du compteur d'adresse
	    adrFifo <= 0;
	  else
	    FifoAccess := WrFifo&RdFifo;
	    case FifoAccess is
	      when "10" =>                     --ECRITURE SEULE:
	        if adrFifo < 2**FIFO_SIZE then
	          Fifo(adrFifo) <= DataIn;       --FIFO <- DataIn
	          adrFifo <= adrFifo+1;        --compteur d'adresse incrémenté
	        end if;
	      when "01" =>                     --LECTURE SEULE:
	        if adrFifo > 0 then
	          for i in 1 to 2**FIFO_SIZE-1 loop
	             Fifo(i-1) <= Fifo(i);        --décalage
	          end loop;
	          adrFifo <= adrFifo-1;        --compteur d'adresse décrémenté
	        end if;
	      when "11" =>                     --ECRITURE & LECTURE:
	        for i in 1 to 2**FIFO_SIZE-1 loop
	          Fifo(i-1) <= Fifo(i);        --décalage
	        end loop;
	        Fifo(adrFifo-1) <= DataIn;     --FIFO <- DataIn, décalage, adr ne change pas
	      when others => NULL;
	    end case;    
	  end if;	
	end if;
end process MyFifo;
	
FifoEmpty <=  '1' when adrFifo = 0 else       --pile vide = adr à 0
              '0';

FifoFull <= '1' when adrFifo = 2**FIFO_SIZE else --pile pleine = toutes les adresses utilisées
            '0';

DataOut <= Fifo(0);   --port de sortie = bas de la pile

FifoLevel <= std_logic_vector(TO_UNSIGNED(adrFifo, FIFO_SIZE+1));

end architecture rtl;