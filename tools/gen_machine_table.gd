extends SceneTree
## Probes every piece in MachineKit's grid against the simulated physics and writes
## scripts/machine_table_data.gd. Run after changing the kit, the sim or the piece geometry:
##   Godot --headless --path <project> --script res://tools/gen_machine_table.gd
## It takes a few minutes. tests/test_machine_pieces.gd fails while the table is stale.

func _initialize() -> void:
	MachineProbe.use_table_file = false
	MachineProbe.clear_cache()
	var sigs := MachineKit.all_signatures()
	var t0 := Time.get_ticks_msec()
	var n := 0
	for s in sigs:
		MachineProbe.plan_for(s["piece"], s["belt"])
		n += 1
		if n % 10 == 0:
			print("[gen_machine_table] %d / %d (%.0f s)" % [n, sigs.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	var ok := MachineProbe.save_table()
	print("[gen_machine_table] wrote %d entries, ok=%s, %d sweep runs" % [MachineProbe.table().size(), str(ok), MachineProbe.sweeps_run])
	quit(0 if ok else 1)
