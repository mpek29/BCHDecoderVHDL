library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity MyFSM is 
    port (
        synRst_n, FifoEmpty, Decod, syndrome_done, search_end, Clk: in std_logic; 
        wrFifo2, LdDec, razDecod, setDone, start_calc, start_check, RdFifo, initFIFO, Cmux0: out std_logic;
        RdOut: in std_logic_vector(1 downto 0);
        FifoLevel: in std_logic_vector(2 downto 0)
    );
end entity MyFSM;

architecture FSM_arch of MyFSM is

    type EtatsME is (Idle, start, Decoding, Errorlocation, EndDecod);

    signal EtatME_cr : EtatsME;
    signal EtatME_sv : EtatsME;
    signal nb_data : std_logic_vector(2 downto 0);

begin

    process(Clk, synRst_n)
    begin
	 
		if synRst_n = '0' then
			EtatME_cr <= Idle;
		elsif rising_edge(Clk) then
			EtatME_cr <= EtatME_sv;
		end if;
		
    end process;

    process(EtatME_cr, Decod, search_end, RdOut, FifoEmpty, FifoLevel, nb_data, syndrome_done)
    begin
        wrFifo2 <= '0';
        LdDec  <= '0';
        razDecod   <= '0';
        setDone     <= '0';
        start_calc <= '0';
        start_check     <= '0';
        RdFifo     <= '0';
        initFIFO     <= '0';
        Cmux0     <= '0';
        nb_data     <= "000";
        EtatME_sv <= EtatME_cr;

        case EtatME_cr is

            when Idle =>
                EtatME_sv <= start;
                initFIFO <= '1';

            when start => 
                if Decod = '0' or FifoEmpty = '1' then
                    EtatME_sv <= start;
                    nb_data <= FifoLevel;
                elsif FifoEmpty = '0' and Decod = '1' then 
                    EtatME_sv <= Decoding;
                    LdDec <= '1'; 
                    RdFifo <= '1';
                elsif nb_data = "000" and RdOut = "01" then 
                    EtatME_sv <= EndDecod;
                    setDone <= '1';
                    razDecod <= '1';
                end if;

            when Decoding => 
                start_calc <= '1';
                if syndrome_done = '0' then 
                    EtatME_sv <= Decoding;
                else 
                    EtatME_sv <= Errorlocation;
                    start_check <= '1';
                end if;

            when Errorlocation => 
                if search_end = '0' then 
                    EtatME_sv <= Errorlocation;
                else 
                    EtatME_sv <= start;
                    Cmux0 <= '1';
                    wrFifo2 <= '1';
                    --nb_data <= std_logic_vector(unsigned(nb_data) - 1);
                end if;

            when EndDecod => 
                if FifoEmpty = '1' then 
                    EtatME_sv <= start;
                elsif FifoEmpty = '0' and RdOut = "01" then 
		    EtatME_sv <= EndDecod;
                    RdFifo <= '1';
                end if;
        end case;
    end process;

end architecture FSM_arch;
