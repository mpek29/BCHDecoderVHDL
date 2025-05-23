
module DE0_CV_QSYS (
	clk_clk,
	clk_sdram_clk,
	keys_wire_export,
	leds_wire_export,
	pll_locked_export,
	reset_reset_n,
	sdram_wire_addr,
	sdram_wire_ba,
	sdram_wire_cas_n,
	sdram_wire_cke,
	sdram_wire_cs_n,
	sdram_wire_dq,
	sdram_wire_dqm,
	sdram_wire_ras_n,
	sdram_wire_we_n,
	seg7_digits_wire_export,
	switches_wire_export);	

	input		clk_clk;
	output		clk_sdram_clk;
	input	[3:0]	keys_wire_export;
	output	[9:0]	leds_wire_export;
	output		pll_locked_export;
	input		reset_reset_n;
	output	[12:0]	sdram_wire_addr;
	output	[1:0]	sdram_wire_ba;
	output		sdram_wire_cas_n;
	output		sdram_wire_cke;
	output		sdram_wire_cs_n;
	inout	[15:0]	sdram_wire_dq;
	output	[1:0]	sdram_wire_dqm;
	output		sdram_wire_ras_n;
	output		sdram_wire_we_n;
	output	[23:0]	seg7_digits_wire_export;
	input	[9:0]	switches_wire_export;
endmodule
