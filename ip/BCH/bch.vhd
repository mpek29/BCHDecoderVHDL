library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ============================================================================
-- Entity Declaration : BCH
-- ============================================================================
entity BCH is
    Port (
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

-- ============================================================================
-- Architecture Definition : BCH
-- ============================================================================
architecture bch_arch of BCH is
    -- Signal reset synchronization
    signal synRst_n0      : std_logic ;
    signal synRst_n  : std_logic ;

    -- Signaux internes BCHStatus
    signal FifoFull  : std_logic := '0';
    signal FifoEmpty  : std_logic := '0';
    signal Done  : std_logic := '0';
    signal BCHStatus : std_logic_vector(7 downto 0);

    -- Signaux internes BCHControl
    signal BCHControl    : std_logic_vector(7 downto 0);		-- On en a pas besoin les autres bits seront mis � z�ro lors de l'affectation des valeurs
    signal razControl  : std_logic := '0';

    -- Signaux internes Decodeur
    signal RdOut : std_logic_vector(1 downto 0) := "00";
    signal ldCtrl     : std_logic := '0';
    signal wrFifo     : std_logic := '0';
    
    
    -- Signaux internes FIFO
    signal BCHFIFOout  : std_logic_vector(31 downto 0);
    signal ldFifoOut : std_logic := '0';
    signal initFIFO : std_logic;
    signal BCHFIFOin : std_logic_vector(31 downto 0);
    signal FifoLevel : std_logic_vector(2 downto 0);
    -- Signaux ShiftRegister
    signal shift_reg : std_logic_vector(30 downto 0);
    signal b0 : std_logic;

    -- Signaux Syndrome_Calculator
    signal syndrome : std_logic_vector(9 downto 0);
    signal start_calc : std_logic;
    signal nb_stroke : integer range 0 to 31 := 0;
    signal done_syndrome : std_logic;

    -- Signaux Error_Locator
    signal p1          : integer;
    signal p2          : integer;
    signal no_match    : std_logic := '0';
    signal match_found : std_logic_vector(1 downto 0) := "00";
    signal search_end  : std_logic := '0';           -- indicateur de fin de la premiere recherche
    signal error : std_logic_vector(7 downto 0);
    signal pre_Decoded  : std_logic_vector(31 downto 0);
    signal Decoded  : std_logic_vector(31 downto 0);

    -- Signaux internes FSM
    signal LdDec    : std_logic := '0';
    signal compa    : std_logic := '0';
    signal start_check_1    : std_logic := '0';
    signal start_check_2   : std_logic := '0';
    signal razDecod,razDone,setDone, Cmux0 : std_logic;

    -- Table des syndromes (ROM)
    type syndrome_table_type is array (0 to 31) of std_logic_vector(9 downto 0);
    constant SYNDROME_TABLE : syndrome_table_type := (
        "0000000001","0000000010", "0000000100", "0000001000", "0000010000",
        "0000100000", "0001000000", "0010000000", "0100000000", "1000000000",
        "0010110111", "0101101110", "1011011100", "0100001111", "1000011110",
        "0010001011", "0100010110", "1000101100", "0011101111", "0111011110",
        "1110111100", "1111001111", "1100101001", "1011100101", "0101111101",
        "1011111010", "0101000011", "1010000110", "0110111011", "1101110110",
        "1001011011"
    );

begin

    -- =========================================================================
    -- Synchronous Process : BCHStatus et BCHControl
    -- =========================================================================
    BCHStatusRegister : process(Clk, synRst_n)
    begin
        if rising_edge(Clk) then
            if synRst_n = '0' then
                BCHStatus <= (others => '0');  -- Reset de BCHStatus
            elsif razDone = '1' then
                Done <= '0';
            elsif setDone = '1' then 
                Done <= '0';
            
            end if;
            BCHStatus <= (1 => Done, 6 => FIFOFull, 7 => FIFOEmpty, others => '0');   -- Adresse 2 prend la valeur de Full 

        end if;
    end process BCHStatusRegister;

    BCHControlRegister : process(Clk,synRst_n)
    begin
        if rising_edge(Clk) then
            if synRst_n = '0' then
                BCHControl <= (others => '0'); -- Adresse 0 prend la valeur de Control
            
            elsif ldCtrl = '1' then 
                IrqEn <= BCHFIFOin(1);
		Decod <= BCHFIFOin(0);
            elsif razDecod = '1' then 
                Decod <= '0';
           
            end if;
             BCHControl <= (0 => Decod, 1 => IrqEn, others => '0');
        end if;
    end process BCHControlRegister;


    -- =========================================================================
    -- Combinational Process : Decoder
    -- =========================================================================
    Decoder : process(Addr, Rd, Wr)
    begin
        case Addr is
            when "00" => -- Status
                if Rd = '1' then -- read only
                    RdOut <= "00";
                end if;
            when "01" => -- Control
                if Rd = '1' then -- read
                    RdOut <= "01";
                end if;
                if Wr = '1' then -- write
                    -- a completer
                end if;

            when "10" => -- fifo
                if Rd = '1' then -- read
                    RdOut <= "10";
                end if;
                if Wr = '1' then -- write
                    ldFifoOut <= '1';
                end if;

            when others =>
                null;
        end case;
    end process Decoder;

    -- =========================================================================
    -- Combinational Process : Mux
    -- =========================================================================
    Mux1 : process(RdOut, BCHStatus, BCHControl,BCHFIFOout)
    begin
        case RdOut is
            when "00" =>
                D_out <= BCHStatus;
            when "11" =>
                D_out <= BCHControl;
            when "01" =>
                D_out <= BCHFIFOout;
            when others =>
                D_out <= (others => 'X');
        end case;
    end process Mux1;

    -- =========================================================================
    -- Combinational Process : Mux0
    -- =========================================================================
    Mux0 : process(Cmux0,D_In,Decod)
    begin
        case Cmux0 is
            when '0' =>
                BCHFIFOin <= D_In;
            when '1' =>
                BCHFIFOin <= Decod;
            when others => BCHFIFOin <= (others => 'X');
        
        end case;
    end process Mux0;

    -- =========================================================================
    -- Synchronous Process : ShiftRegister
    -- =========================================================================
    ShiftRegister : process (Clk)
    begin
        if rising_edge(Clk) then
            if LdDec = '1' then
                shift_reg <= BCHFIFOout;
            else
                b0 <= shift_reg(0);
                shift_reg(29 downto 0) <= shift_reg(30 downto 1);
		        shift_reg(30) <= '0';
            end if;
           
        end if;
    end process;

    -- =========================================================================
    -- Synchronous Process : Syndrome_Calculator
    -- =========================================================================
    Syndrome_Calculator : process (Clk)
    begin
        if rising_edge(Clk) then
            -- Decompteur
            if start_calc = '1' then
                nb_stroke <= 31;
			
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
                nb_stroke <= nb_stroke - 1;
            end if;

            if nb_stroke = 0 then
                done_syndrome <= '1';
            end if;
        end if;
    end process;

    -- =========================================================================
    -- Synchronous Process : Error_Locator
    -- =========================================================================

    Error_Locator : process(Clk)
    begin
        if rising_edge(Clk) then
            if start_check = '1' then
                if syndrome = "0000000000" then
                    error <= ( others => '0');
                else 
                    p1 <= 0;
                    p2 <= 1;
                end if;
            end if;

            elsif p2 = 30 then 
                p1 <= p1+1;
                p2 <= p1+1;

            elsif p2 < 31 then
                -- check 1
                if (SYNDROME_TABLE(p2 - 1) - syndrome) =  0 then 
                    search_end = '1';
                    match_found = "01";
                    error <= (0 => '1', others => '0');
                -- check 2
                if p1 > 0 then
                    if (SYNDROME_TABLE(p2 - 1) xor SYNDROME_TABLE(p1 - 1)) - syndrome =  0 then 
                        search_end = '1'
                        match_found = "11"
                        error <= (1 => '1', others => '0');
                p2 <= p2+1;
            if p1 = 29 then
                error <= (1 => '1', 0 => '1', others => '0');
                search_end = '1';

            
    end process;

    -- =========================================================================
    -- Combinational Process : Error_Corrector
    -- =========================================================================
    Error_Corrector : process(BCHFIFOout, match_found, error)
    begin
        pre_Decoded <= BCHFIFOout;
        case match_found is
            when "01" =>
                pre_Decoded(p2) <= BCHFIFOout(p2) xor '1';
            when "11" =>
                pre_Decoded(p1) <= BCHFIFOout(p2) xor '1';
                pre_Decoded(p2) <= BCHFIFOout(p2) xor '1';
            when others =>
                pre_Decoded <= (others => '0');
        end case;
        Decoded <= error & pre_Decoded(22 downto 0);
    end process;

    -- =========================================================================
    -- Synchronous Reset Synchronization
    -- =========================================================================
    SyncReset : process(Clk, Rst_n)
    begin
        if Rst_n = '0' then
            synRst_n0 <= '0';
            synRst_n   <= '0';
        elsif rising_edge(Clk) then
            synRst_n0   <= '1';
            synRst_n <= synRst_n0;
        end if;
    end process SyncReset;

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
            WrFifo     => wrFifo,
        
            -- FSM
            RdFifo     => RdFifo,
        
            -- Status
            FifoEmpty  => FifoEmpty,
            FifoFull   => FifoFull,
        
            DataIn     => BCHFIFOin,
        
            DataOut    => BCFIFOout   
    );
    -- =========================================================================
    -- Irq_BCH_n
    -- =========================================================================
	if rising_edge(Clk)
		if IrqEn = '1' then 
			Irq_BCH_n <= Done ;
end architecture bch_arch;
