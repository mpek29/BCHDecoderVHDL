library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.all;

entity BCH is
    port (
        Clk       : in  std_logic;
        Reset_n     : in  std_logic;
        D_In      : in  std_logic_vector(31 downto 0);
        Addr      : in  std_logic_vector(1 downto 0);
        Rd        : in  std_logic;
        Wr        : in  std_logic;
        D_Out     : out std_logic_vector(31 downto 0);
        Irq_BCH_n : out std_logic
    );
end BCH;

architecture bch_arch of BCH is

    signal synRst_n0      : std_logic ;
    signal synRst_n  : std_logic ;

    signal FifoFull  : std_logic ;
    signal FifoEmpty  : std_logic ;
    signal Done  : std_logic ;
    signal BCHStatus : std_logic_vector(7 downto 0);

    signal BCHControl    : std_logic_vector(7 downto 0);
    signal razControl  : std_logic ;

    signal RdOut : std_logic_vector(1 downto 0);
    signal ldCtrl     : std_logic ;
    signal wrFifo1     : std_logic ;

    signal BCHFifoOut  : std_logic_vector(31 downto 0);
    signal initFIFO : std_logic;
    signal BCHFifoIn : std_logic_vector(31 downto 0);
    signal FifoLevel : std_logic_vector(2 downto 0);
    signal rdFIFO : std_logic;

    signal shift_reg : std_logic_vector(30 downto 0);
    signal b0 : std_logic;

    signal syndrome : std_logic_vector(9 downto 0);
    signal start_calc : std_logic;
    signal nb_stroke : integer range 0 to 32;
    signal syndrome_done : std_logic;  -- Signal de fin de calcul
    signal last_cycle : std_logic;

    signal p1          : integer range 0 to 32 ;
    signal p2          : integer range 0 to 32;
    signal no_match    : std_logic ;
    signal match_found : std_logic_vector(1 downto 0);
    signal search_end  : std_logic ;
    signal error : std_logic_vector(7 downto 0);
    signal pre_Decoded  : std_logic_vector(31 downto 0);
    signal Decoded  : std_logic_vector(31 downto 0);

    signal LdDec    : std_logic ;
    signal razDecod,razDone,setDone, Cmux0 : std_logic;
    signal p : integer range 0 to 31;
    signal nb_data : std_logic_vector (2 downto 0);
    signal wrFifo2 : std_logic ;

    type syndrome_table_type is array (0 to 30) of std_logic_vector(9 downto 0);
    constant SYNDROME_TABLE : syndrome_table_type := (
        "0000000001","0000000010", "0000000100", "0000001000", "0000010000",
        "0000100000", "0001000000", "0010000000", "0100000000", "1000000000",
        "0010110111", "0101101110", "1011011100", "0100001111", "1000011110",
        "0010001011", "0100010110", "1000101100", "0011101111", "0111011110",
        "1110111100", "1111001111", "1100101001", "1011100101", "0101111101",
        "1011111010", "0101000011", "1010000110", "0110111011", "1101110110",
        "1001011011"
    );

    signal IrqEn    : std_logic ;
    signal Decod    : std_logic ;
    signal start_check : std_logic ;
    signal WrFifo : std_logic;
    

begin

    -- =========================================================================
    -- Synchronous Process : BCHStatus et BCHControl
    -- =========================================================================
    BCHStatusRegister : process(Clk, synRst_n)
    begin
			if synRst_n = '0' then
				BCHStatus <= (others => '0');  -- Reset de BCHStatus
			elsif rising_edge(clk) then
            if razDone = '1' then
                Done <= '0';
            elsif setDone = '1' then 
                Done <= '1';
            end if;
            BCHStatus <= (1 => Done, 6 => FIFOFull, 7 => FIFOEmpty, others => '0');   -- Adresse 2 prend la valeur de Full 

        end if;
    end process BCHStatusRegister;

    BCHControlRegister : process(Clk, synRst_n)
    begin
			if synRst_n = '0' then
				BCHControl <= (others => '0');  -- Reset de BCHStatus
			elsif rising_edge(clk) then
            if ldCtrl = '1' then 
                IrqEn <= BCHFifoIn(1);
		        Decod <= BCHFifoIn(0);
            elsif razDecod = '1' then 
                Decod <= '0';
            end if;
				
            BCHControl <= (0 => Decod, 1 => IrqEn, others => '0');
        end if;
    end process BCHControlRegister;


    -- =========================================================================
    -- Combinational Process : XOR for wrFifo
    -- =========================================================================
    Wrprocess : process(wrFifo1,wrFifo2)
    begin 
        wrFifo <= wrFifo2 xor wrFifo1;
    end process Wrprocess;


    -- =========================================================================
    -- Combinational Process : Decoder
    -- =========================================================================
    Decoder : process(Addr, Rd, Wr)

    begin
        ldCtrl <= '0';
        wrFifo1 <= '0';
        RdOut <= (others => '0');
        razDone <= '0';
        case Addr is
            when "00" => -- Status
                if Rd = '1' then -- read only
                    RdOut <= "00";
                        razDone <= '1';
                end if;
            when "01" => -- Control
                if Rd = '1' then -- read
                    RdOut <= "10";
                end if;
                if Wr = '1' then -- write
                    ldCtrl <= '1';
                end if;

            when "10" => -- fifo
                if Rd = '1' then -- read
                    RdOut <= "01";
                end if;
                if Wr = '1' then -- write
                    wrFifo1  <= '1';
                end if;

            when others =>
                null;
        end case;
    end process Decoder;

    -- =========================================================================
    -- Combinational Process : Mux
    -- =========================================================================
    Mux1 : process(RdOut, BCHStatus, BCHControl, BCHFifoOut)
    begin
        case RdOut is
            when "00" =>
                D_out <= (23 downto 0 => '0') & BCHStatus;
            when "11" =>
                D_out <=(23 downto 0 => '0') & BCHControl;
            when "01" =>
                D_out <= BCHFifoOut;
            when others =>
                D_out <= (others => 'X');
        end case;
    end process Mux1;

    -- =========================================================================
    -- Combinational Process : Mux0
    -- =========================================================================
    Mux0 : process(Cmux0,D_In,Decoded)
    begin
        case Cmux0 is
            when '0' =>
                BCHFifoIn <= D_In;
            when '1' =>
                BCHFifoIn <= Decoded;
            when others => BCHFifoIn <= (others => 'X');
        
        end case;
    end process Mux0;

    -- =========================================================================
    -- Synchronous Process : ShiftRegister
    -- =========================================================================
    ShiftRegister : process (clk, synRst_n)
    begin
			if synRst_n = '0' then
                shift_reg <= (others => '0');
			elsif rising_edge(clk) then
            if LdDec = '1' then
                shift_reg <= BCHFifoOut(30 downto 0);
            else
                b0 <= shift_reg(0);
                shift_reg(29 downto 0) <= shift_reg(30 downto 1);
		        shift_reg(30) <= '0';
            end if;
           
        end if;
    end process ShiftRegister;

    -- =========================================================================
    -- Synchronous Process : Syndrome_Calculator
    -- =========================================================================
    Syndrome_Calculator : process (Clk, synRst_n)
    begin
        if synRst_n = '0' then
            syndrome <= (others => '0');
            nb_stroke <= 0;
            syndrome_done <= '0';
            last_cycle <= '0';
        elsif rising_edge(Clk) then
            if start_calc = '1' then
                nb_stroke <= 31;
                syndrome_done <= '0';
                last_cycle <= '0';
            end if;

            if nb_stroke > 0 then
                syndrome(0) <= b0;
                syndrome(1) <= syndrome(0);
                syndrome(2) <= syndrome(1);
                syndrome(3) <= b0 xor syndrome(2);
                syndrome(4) <= syndrome(3);
                syndrome(5) <= b0 xor syndrome(4);
                syndrome(6) <= b0 xor syndrome(5);
                syndrome(7) <= syndrome(6);
                syndrome(8) <= b0 xor syndrome(7);
                syndrome(9) <= b0 xor syndrome(8);

                if nb_stroke = 1 then
                    last_cycle <= '1';  -- Marqueur pour activer syndrome_done au prochain cycle
                else
                    last_cycle <= '0';
                end if;

                nb_stroke <= nb_stroke - 1;
            else
                last_cycle <= '0';
            end if;

            -- Active le signal de fin un cycle après le dernier calcul
            if last_cycle = '1' then
                syndrome_done <= '1';
            end if;
        end if;
    end process Syndrome_Calculator;


    -- =========================================================================
    -- Synchronous Process : Error_Locator
    -- =========================================================================

    Error_Locator : process(Clk, synRst_n)
    begin
        if synRst_n = '0' then
            error <= (others => '0');
	        p1 <= 0;
            p2 <= 0;
            search_end <= '0';
            match_found <= "10";
        elsif rising_edge(clk) then
            if start_check = '1' then
                p1 <= 0;
                p2 <= 1;
            end if;
            
            if syndrome_done = '1' then -- verifie que notre syndrome contient bien une valeur calcule et pas celle par defaut
                if syndrome = "0000000000" then
                    error <= (others => '0');
                    search_end <= '1';
                    match_found <= "00";
                elsif p1 > 29 then
                    -- rien de trouvé
                    error <= (1 => '1', 0 => '1', others => '0');
                    search_end <= '1';
                elsif (SYNDROME_TABLE(p2 - 1) = syndrome) then
                    -- une erreur trouvée
                    search_end <= '1';
                    match_found <= "01";
                    error <= (0 => '1', others => '0');
                elsif p1 > 0 and p2 > 0 then
                    if std_logic_vector(unsigned(SYNDROME_TABLE(p2 - 1)) xor unsigned(SYNDROME_TABLE(p1 - 1))) = syndrome then
                        -- deux erreurs trouvées
                        search_end <= '1';
                        match_found <= "11";
                        error <= (1 => '1', others => '0');
                    end if;
                end if;
            end if;

            -- on continue à balayer
            p2 <= p2 + 1;
            if p2 > 30 then
                -- Si p2 a balayé tout le tableau, on décale p1 et recommence à balayer
                p1 <= p1 + 1;
                p2 <= p1 + 1;
            end if;
        end if;
    end process Error_Locator;


    -- =========================================================================
    -- Combinational Process : Error_Corrector
    -- =========================================================================
    Error_Corrector : process(BCHFifoOut, match_found, error,p1,p2)
    begin
        pre_Decoded <= BCHFifoOut;
        case match_found is
            when "01" =>
                pre_Decoded(p2) <= BCHFifoOut(p2) xor '1';
            when "11" =>
                pre_Decoded(p1) <= BCHFifoOut(p2) xor '1';
                pre_Decoded(p2) <= BCHFifoOut(p2) xor '1';
            when others =>
                pre_Decoded <= (others => '0');
        end case;
        Decoded <= error & pre_Decoded(23 downto 0);
    end process Error_Corrector;

    -- =========================================================================
    -- Synchronous Reset Synchronization
    -- =========================================================================
    SyncReset : process(Clk, Reset_n)
    begin
        if Reset_n = '0' then
            synRst_n0 <= '0';
            synRst_n   <= '0';
        elsif rising_edge(Clk) then
            synRst_n0   <= '1';
            synRst_n <= synRst_n0;
        end if;
    end process SyncReset;

    -- =========================================================================
    -- Irq_BCH_n
    -- =========================================================================
    Irq_Process : process(Clk)
    begin
        if rising_edge(Clk) then
            if IrqEn = '1' then 
                Irq_BCH_n <= Done;
            else
                Irq_BCH_n <= '1'; -- ou '0' selon logique inverse
            end if;
        end if;
    end process Irq_Process;

    -- =========================================================================
    -- Instanciation de la FIFO
    -- =========================================================================
    FIFO : entity work.FIFO_nMots_mBits
        generic map (  	DATA_WIDTH => 32,
           		FIFO_SIZE => 2 )
        port map (
            Horloge    => Clk,
            -- FSM
            initFifo   => initFIFO,
            FifoLevel  => FifoLevel,
        
            -- Decoder
            WrFifo     => WrFifo,
        
            -- FSM
            RdFifo     => RdFifo,
        
            -- Status
            FifoEmpty  => FifoEmpty,
            FifoFull   => FifoFull,
        
            DataIn     => BCHFifoIn,
        
            DataOut    => BCHFifoOut   
    );
    

	FSM : entity work.myfsm
		port map (
		synRst_n => synRst_n,
		
		FifoEmpty => FifoEmpty,

		Decod => Decod,

		search_end => search_end, 

		Clk => Clk,

		wrFifo2 => wrFifo2,

		LdDec => LdDec,

		razDecod => razDecod,

		setDone => setDone,

		start_calc => start_calc,

		start_check => start_check,

		RdFifo => RdFifo,

		initFIFO => initFIFO,

		Cmux0 => Cmux0,

		RdOut => RdOut,

		FifoLevel => FifoLevel
			);

end architecture bch_arch;
