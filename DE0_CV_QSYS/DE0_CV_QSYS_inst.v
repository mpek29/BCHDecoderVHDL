	DE0_CV_QSYS u0 (
		.clk_clk                 (<connected-to-clk_clk>),                 //              clk.clk
		.clk_sdram_clk           (<connected-to-clk_sdram_clk>),           //        clk_sdram.clk
		.keys_wire_export        (<connected-to-keys_wire_export>),        //        keys_wire.export
		.leds_wire_export        (<connected-to-leds_wire_export>),        //        leds_wire.export
		.pll_locked_export       (<connected-to-pll_locked_export>),       //       pll_locked.export
		.reset_reset_n           (<connected-to-reset_reset_n>),           //            reset.reset_n
		.sdram_wire_addr         (<connected-to-sdram_wire_addr>),         //       sdram_wire.addr
		.sdram_wire_ba           (<connected-to-sdram_wire_ba>),           //                 .ba
		.sdram_wire_cas_n        (<connected-to-sdram_wire_cas_n>),        //                 .cas_n
		.sdram_wire_cke          (<connected-to-sdram_wire_cke>),          //                 .cke
		.sdram_wire_cs_n         (<connected-to-sdram_wire_cs_n>),         //                 .cs_n
		.sdram_wire_dq           (<connected-to-sdram_wire_dq>),           //                 .dq
		.sdram_wire_dqm          (<connected-to-sdram_wire_dqm>),          //                 .dqm
		.sdram_wire_ras_n        (<connected-to-sdram_wire_ras_n>),        //                 .ras_n
		.sdram_wire_we_n         (<connected-to-sdram_wire_we_n>),         //                 .we_n
		.seg7_digits_wire_export (<connected-to-seg7_digits_wire_export>), // seg7_digits_wire.export
		.switches_wire_export    (<connected-to-switches_wire_export>)     //    switches_wire.export
	);

