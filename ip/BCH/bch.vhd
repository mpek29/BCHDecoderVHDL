library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ============================================================================
-- Entity Declaration : BCH
-- ============================================================================
entity BCH is
    Port (
        Clk       : in  std_logic;
        Rst_n     : in  std_logic;
        DataIn    : in  std_logic_vector(7 downto 0);
        Addr      : in  std_logic_vector(1 downto 0);
        Rd        : in  std_logic;
        Wr        : in  std_logic;
        DataOut   : out std_logic_vector(7 downto 0);
        Irq       : out std_logic;
        SerialOut : out std_logic
    );
end BCH;

-- ============================================================================
-- Architecture Definition : BCH
-- ============================================================================
architecture bch of BCH is
    -- Signal reset synchronization
    signal Q1        : std_logic := '0';
    signal synRst_n  : std_logic := '0';

    -- Signaux internes BCHStatus
    signal FifoFull  : std_logic := '0';
    signal FifoEmpty  : std_logic := '0';
    signal Done  : std_logic := '0';
    signal BCHStatus : std_logic_vector(7 downto 0);

    -- Signaux internes BCHControl
    signal BCHControl    : std_logic_vector(7 downto 0);
    signal razControl  : std_logic := '0';

    -- Signaux internes Decodeur
    signal RdOut : std_logic_vector(1 downto 0) := "00";
    signal ldCtrl     : std_logic := '0';
    signal wrFifo     : std_logic := '0';
    
    -- Signaux internes FIFO
    signal DataOutFifo  : std_logic_vector(7 downto 0);
    signal ldFifoOut : std_logic := '0';

    -- Signaux ShiftRegister
    signal shift_reg : std_logic_vector(31 downto 0);
    signal serial_out : std_logic;

    -- Signaux Syndrome_Calculator
    signal syndrome : std_logic_vector(9 downto 0);
    signal start_syndrome : std_logic;
    signal nb_stroke : integer range 0 to 31 := 0;
    signal done_syndrome : std_logic;

    -- Signaux Error_Locator
    signal p1 : integer range -1 to 30 := -1; -- commence à -1 (avant le premier élément)
    signal p2 : integer range 0 to 31 := 0;

    -- Signaux Error_Locator
    signal p1          : integer range -1 to 29 := -1;
    signal p2          : integer range 0 to 30 := 0;
    signal no_match    : std_logic := '0';
    signal match_found : std_logic := '0';           -- indicateur de fin de recherche avec succès
    signal search_end_1  : std_logic := '0';           -- indicateur de fin de la premiere recherche
    signal search_end_2  : std_logic := '0';           -- indicateur de fin de la seconde recherche

begin

    -- =========================================================================
    -- Synchronous Process : BCHStatus et BCHControl
    -- =========================================================================
    BCHStatusRegister : process(Clk)
    begin
        if rising_edge(Clk) then
            if synRst_n = '0' then
                BCHStatus <= (others => '0');  -- Reset de BCHStatus
            else
                BCHStatus(2) <= Done;   -- Adresse 6 prend la valeur de Full
                BCHStatus(6) <= FifoFull;   -- Adresse 6 prend la valeur de Full
                BCHStatus(7) <= FifoEmpty;  -- Adresse 7 prend la valeur de Empty
            end if;
        end if;
    end process BCHStatusRegister;

    BCHControlRegister : process(Clk)
    begin
        if rising_edge(Clk) then
            if synRst_n = '0' then
                BCHControl <= (others => '0'); -- Adresse 0 prend la valeur de Control
            else
                if razControl = '1' then
                    BCHControl(0) <= '0'; -- Adresse 0 prend la valeur de Control
                end if;
            end if;
        end if;
    end process BCHControlRegister;

    -- =========================================================================
    -- Combinational Process : Decoder
    -- =========================================================================
    Decoder : process(Addr, Rd, Wr)
    begin
        ldCtrl  <= '0';
        RdOut   <= '1';
        wrFifo  <= '0';

        case Addr is
            when "00" =>
                if Rd = '1' then -- read only
                    RdOut <= '00';
                end if;
            when "01" =>
                if Rd = '1' then -- read
                    RdOut <= '01';
                end if;
                if Wr = '1' then -- write
                    ldCtrl <= '1';
                end if;

            when "10" =>
                if Rd = '1' then -- read
                    RdOut <= '10';
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
    Mux : process(RdOut, BCHStatus, BCHControl)
    begin
        case RdOut is
            when "00" =>
                DataOut <= BCHStatus;
            when "01" =>
                DataOut <= BCHControl;
			when "10" =>
                DataOut <= BCHFifoOut;
            when others =>
                DataOut <= (others => '0');
        end case;
    end process Mux;

    -- =========================================================================
    -- Synchronous Process : ShiftRegister
    -- =========================================================================
    ShiftRegister : process (Clk)
    begin
        if rising_edge(Clk) then
            if LdDec = '1' then
                shift_reg <= D_in;
            else
                shift_reg(30 downto 0) <= shift_reg(6 downto 1);
                shift_reg(31) <= '0';
            end if;
            serial_out <= shift_reg(0);
        end if;
    end process;

    -- =========================================================================
    -- Synchronous Process : Syndrome_Calculator
    -- =========================================================================
    Syndrome_Calculator : process (Clk)
    begin
        if rising_edge(Clk) then
			-- Decompteur avec load au debut du calc
			if start_syndrome = '1' then
				nb_stroke <= 30;
			elsif p2 > 0 then
				nb_stroke <= nb_stroke - 1;
			elsif p2 = 0 then
				done_syndrome <= '1';
			end if;
			
			if nb_stroke >= 0 then
				syndrome(0) <= serial_out;
				syndrome(1) <= serial_out ^ syndrome(0);
				syndrome(2) <= serial_out ^ syndrome(1);
				syndrome(3) <= serial_out ^ syndrome(2);
				syndrome(4) <= serial_out ^ syndrome(3);
				syndrome(5) <= serial_out ^ syndrome(4);
				syndrome(6) <= serial_out ^ syndrome(5);
				syndrome(7) <= serial_out ^ syndrome(6);
				syndrome(8) <= serial_out ^ syndrome(7);
				syndrome(9) <= serial_out ^ syndrome(8);
			end if;
		end if;
    end process;

    -- =========================================================================
    -- Synchronous Process : Error_Locator
    -- =========================================================================

    Error_Locator : process(Clk)
    begin
        if rising_edge(Clk) then
        -- Comparaison type 1 (une seule erreur)
            if compa = "00" then
                -- Decompteur avec load au debut de la recherche
                if start_check_1 = '1' then
                    p2 <= 30;
                elsif p2 > 0 then
                    p2 <= p2 - 1;
                end if;

            if syndrome = SYNDROME_TABLE(p2) then
                search_end_1 <= '1';
                match_found <= '1';
            elsif p2 = 0 then
                search_end_1 <= '1';
                match_found <= '0';
            end if;

        -- Comparaison type 2 (deux erreurs)
        elsif compa = "01" then
        -- Decompteur avec load au debut de la recherche
            if start_check_2 = '1' then
                p2 <= 30;
                p1 <= 29;
            elsif p2 = 0 then
                p1 <= p1 - 1;
                p2 <= 30;
            elsif p2 > 0 then
                p2 <= p2 - 1;
            end if;

            if syndrome = (SYNDROME_TABLE(p1) xor SYNDROME_TABLE(p2)) then
                search_end_2 <= '1';
                match_found <= '1';
            elsif p1 = 0 then
                search_end_2 <= '1';
                match_found <= '0';
            end if;
        end if;
    end process;

    -- =========================================================================
    -- Combinational Process : Error_Corrector
    -- =========================================================================
    Error_Locator : process(match_found)
        variable DataOutFifo_corrected : std_logic_vector(DataOutFifo'range);  -- même taille que D_in
        begin
        -- Copier D_in dans la variable
        DataOutFifo_corrected := DataOutFifo;

        if match_found then
            if search_end_1 = '1' then
                DataOutFifo_corrected(p2) := DataOutFifo_corrected(p2) xor '1';
        end if;
        if search_end_2 = '1' then
            DataOutFifo_corrected(p1) := DataOutFifo_corrected(p2) xor '1';
            DataOutFifo_corrected(p2) := DataOutFifo_corrected(p2) xor '1';
        end if;
    end process;

    -- =========================================================================
    -- Combinational Process : Mux
    -- =========================================================================
    Mux : process(Addr, D_in, DataOutFifo_corrected)
    begin
        case Addr is
            when '0' =>
                D_in <= DataIn;
            when '1' =>
                D_in <= DataOutFifo_corrected;
            when others =>
                D_in <= (others => '0');
        end case;
    end process Mux;

    -- =========================================================================
    -- Synchronous Reset Synchronization
    -- =========================================================================
    SyncReset : process(Clk, Rst_n)
    begin
        if Rst_n = '0' then
            Q1 <= '0';
            synRst_n   <= '0';
        elsif rising_edge(Clk) then
            synRst_n   <= Q1;
            Q1 <= '1';
        end if;
    end process SyncReset;

    -- =========================================================================
    -- Instanciation de la FIFO
    -- =========================================================================
    FIFO : entity work.FIFO_nMots_mBits
        port map (
            Horloge    => Clk,
            -- FSM
            initFifo   => init,
            FifoLevel  => open,
        
            -- Decoder
            WrFifo     => wrFifo,
        
            -- FSM
            RdFifo     => RdFifo,
        
            -- Status
            FifoEmpty  => FifoEmpty,
            FifoFull   => FifoFull,
        
            DataIn     => DataIn,
        
            DataOut    => DataOutFifo   
    );

end architecture uart_fifo;
