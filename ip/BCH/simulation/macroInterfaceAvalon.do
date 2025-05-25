transcript quietly

#*********************************************************************************
#****                       SIMULATION PARAMETERS                             ****
#*********************************************************************************
#
set Th 40					;# DEFINE THE CLOCK PERIOD: Th (in ns)
set dt 2					;# DEFINE THE DELAY BEFORE SIGNALS ARE STABILIZED: dt (in ns)
echo "\n *****     SIMULATION PARAMETERS     *****"
echo "==>  Clock frequency: [expr 1e3/$Th] MHz"
echo "==>  Signals stabilized [expr $dt] ns after the clock edge"

#*********************************************************************************
#****                        PERIPHERAL PARAMETERS                            ****
#*********************************************************************************
#
#     ===> AVALON Interconnection Interface
#
set ReadWait 0				;# DEFINE THE NUMBER OF WAIT STATE(S) FOR READ CYCLES
set WriteWait 0				;# DEFINE THE NUMBER OF WAIT STATE(S) FOR WRITE CYCLES
echo "\n *****     AVALON INTERCONNEXION INTERFACE     *****"
echo "==> Read cycles with [expr $ReadWait] wait state(s)"
echo "==> Write cycles with [expr $WriteWait] wait state(s)"
#
#
#     ===> Register Mapping
#          format: set <register_name> <register_number>
#
set Status 0
set SetCtrl 0
set Period 1
set DCycle 2
set NbCycles 3
set ClrCtrl 4
#
#
#     ===> AVALON interface signals <--- connection ---> peripheral ports
#          N. B.: path to the peripheral relative to "ip", levels separated by "/"
#
#          Access path and bus sizes
#
set CheminVersPeripherique /pwm					;# DEFINE THE PATH TO THE PERIPHERAL
set BusAddressSize 3							;# DEFINE THE SIZE OF THE ADDRESS BUS (bits)
set BusDataSize 32								;# DEFINE THE SIZE OF THE DATA BUS (bits)
#
#
#     ===> Signals Connection
#
set HorlogePeripherique Clk						;# DEFINE THE CLOCK SIGNAL
set ResetPeripherique Reset_n					;# DEFINE THE RESET SIGNAL
set AdresseRegistrePeripherique RegsAddr		;# DEFINE THE ADDRESS BUS
set AccesLecturePeripherique ReadPWM			;# DEFINE READ ACCESS SIGNAL
set AccesEcriturePeripherique WritePWM			;# DEFINIR WRITE ACCESS SIGNAL
set BusEcritureDonneesPeripherique DInPWM		;# DEFINE THE INPUT DATA BUS
set BusLectureDonneesPeripherique DOutPWM		;# DEFINE THE OUTPUT DATA BUS
set InterruptRequest IrqPWM						;# DEFINE THE INTERRUPT REQUEST SIGNAL
#
#
#     ===> Polarity of signals
#
set NiveauActif	1								;# DEFINE THE POLARITY OF SIGNALS (EXCEPT RESET)
set NiveauActifReset 0							;# DEFINE POLARITY OF RESET SIGNAL
set DureeReset 2.5								;# DEFINE THE RESET DURATION


#*********************************************************************************
#****              DEFINITION OF SIMULATION CYCLES                            ****
#****                                                                         ****
#****  Read cycle format: {<Clock period number> <Register>}                  ****
#****  Write cycle format: {<Clock period number> <Register> <Value>}         ****
#*********************************************************************************
set CyclesAvalon {
	{20 Period 10#100}
	{25 DCycle 10#0}
	{30 SetCtrl 2#1}
	{1000 DCycle 10#1}
	{2000 DCycle 10#99}
	{3000 DCycle 10#100}
	{4000 ClrCtrl 2#1}
}

#*********************************************************************************
#****              END OF VALUES TO BE DEFINED                               *****
#*********************************************************************************






#*********************************************************************************
#****              GENERATION OF SIGNALS                                     *****
#*********************************************************************************
#
#     Conversion décimal/binaire pour lien entre offset registres en décimal et
#     forçage en format binaire
#     PE : i : valeur décimale à convertir
#          width : nombre de bits du résultat de la conversion
#
proc dec2bin {i {width {}}} {	;#returns the binary representation of $i
								;# width determines the length of the returned string (left truncated or added left 0)
    set res {}
    if {$i<0} {
        set sign -
        set i [expr {abs($i)}]
    } else {
        set sign {}
    }
    while {$i>0} {
        set res [expr {$i%2}]$res
        set i [expr {$i/2}]
    }
    if {$res eq {}} {set res 0}

    if {$width ne {}} {
        append d [string repeat 0 $width] $res
        set res [string range $d [string length $res] end]
    }
    return $sign$res
}
#
#     Valeur signaux inactifs
#
switch $BusDataSize {
	8 { set BusEcritureDonneeInactif 16#XX }
	16 { set BusEcritureDonneeInactif 16#XXXX }
	32 { set BusEcritureDonneeInactif 16#XXXXXXXX }
	default {
		echo "\n !!  Wrong data bus size"
		exit
	}
}

set AdresseRegistrePeripheriqueInactive "2#"
for {set i 1} {$i <= $BusAddressSize} {incr i} { append AdresseRegistrePeripheriqueInactive "X" }
set NiveauInactif [expr $NiveauActif == 1 ? 0: 1]
set NiveauInactifReset [expr $NiveauActifReset == 1 ? 0: 1]
set CycleHorlogeCourant 0

echo "\n *****     INITIAL VALUE OF SIMULATED SIGNALS     *****"
#
#Forçages initiaux et reset
#
force -freeze sim:${CheminVersPeripherique}/$HorlogePeripherique 1 0, 0 [expr $Th/2] ns -r $Th ns
force -freeze sim:${CheminVersPeripherique}/$AccesEcriturePeripherique $NiveauInactif 0
force -freeze sim:${CheminVersPeripherique}/$AccesLecturePeripherique $NiveauInactif 0
force -freeze sim:${CheminVersPeripherique}/$ResetPeripherique $NiveauActifReset 0
force -freeze sim:${CheminVersPeripherique}/$ResetPeripherique $NiveauInactifReset [expr $DureeReset*$Th] ns
echo "==> read/write signals initialized at clear state: [expr $NiveauInactif]"
echo "==> initial Reset applied at state [expr $NiveauInactifReset] during [expr $DureeReset] clock period"

echo "\n *****     SIMULATION STARTS     *****"
for {set i 0} {$i < [llength $CyclesAvalon]} {incr i} {
	set AccessType [llength $[lindex $CyclesAvalon $i]]
	set CycleHorlogeCourant [lindex $CyclesAvalon $i 0]
	set AdresseRegistre [lindex $CyclesAvalon $i 1]
	set AdresseBinaireRegistre "2#"
	set AdresseBinaireRegistre [append AdresseBinaireRegistre [dec2bin [expr $$AdresseRegistre] $BusAddressSize]]
	switch $AccessType {
		2 {										;# Deux arguments = cycle de lecture
			set DateDebutCycle {$CycleHorlogeCourant*$Th+$dt}
			set DateFinCycleRead {($CycleHorlogeCourant+$ReadWait+1)*$Th + $dt}
			echo "Cycle [expr $i + 1] ==> Read ${AdresseRegistre} (Reg. Num.: [expr $$AdresseRegistre]), Access: [expr $DateDebutCycle] -> [expr $DateFinCycleRead] ns"
			force -freeze sim:${CheminVersPeripherique}/$AccesLecturePeripherique $NiveauActif [expr $DateDebutCycle] ns
			force -freeze sim:${CheminVersPeripherique}/$AccesLecturePeripherique $NiveauInactif [expr $DateFinCycleRead] ns
			force -freeze sim:${CheminVersPeripherique}/$AdresseRegistrePeripherique $AdresseBinaireRegistre [expr $DateDebutCycle] ns
			force -freeze sim:${CheminVersPeripherique}/$AdresseRegistrePeripherique $AdresseRegistrePeripheriqueInactive [expr $DateFinCycleRead] ns
		}
		3 {										;# Trois arguments = cycle d'écriture
			set Donnee [lindex $CyclesAvalon $i 2]
			set DateDebutCycle {$CycleHorlogeCourant*$Th+$dt}
			set DateFinCycleWrite {($CycleHorlogeCourant+$WriteWait+1)*$Th + $dt}
			echo "Cycle [expr $i + 1] ==> Write ${AdresseRegistre} (Reg. Num.: [expr $$AdresseRegistre]), Access: [expr $DateDebutCycle] -> [expr $DateFinCycleWrite] ns"
			force -freeze sim:${CheminVersPeripherique}/$AccesEcriturePeripherique $NiveauActif [expr $DateDebutCycle] ns
			force -freeze sim:${CheminVersPeripherique}/$AccesEcriturePeripherique $NiveauInactif [expr $DateFinCycleWrite] ns
			force -freeze sim:${CheminVersPeripherique}/$AdresseRegistrePeripherique $AdresseBinaireRegistre [expr $DateDebutCycle] ns
			force -freeze sim:${CheminVersPeripherique}/$AdresseRegistrePeripherique $AdresseRegistrePeripheriqueInactive [expr $DateFinCycleWrite] ns
			force -freeze sim:${CheminVersPeripherique}/$BusEcritureDonneesPeripherique $Donnee [expr $DateDebutCycle] ns
			force -freeze sim:${CheminVersPeripherique}/$BusEcritureDonneesPeripherique $BusEcritureDonneeInactif [expr $DateFinCycleWrite] ns
		}
		default {
			echo "\n !! Unknown register access"
			exit
		}
	}
}


run [expr ($CycleHorlogeCourant+5)*$Th] ns
echo "\n==> Simulation ends at t = [expr ($CycleHorlogeCourant+10)*$Th] ns\n\n"
