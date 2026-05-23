extends SceneTree
## Бенчмарк генератора: Project → Run или
## godot --headless --path game -s res://scripts/dev/bench_level_gen.gd


func _initialize() -> void:
	var levels: PackedInt32Array = PackedInt32Array([1, 5, 10, 15])
	for lvl in levels:
		var t0: int = Time.get_ticks_msec()
		var data: Array = LevelGenerator.generate(lvl, 42)
		var ms: int = Time.get_ticks_msec() - t0
		print("level %d: %d tiles in %d ms" % [lvl, data.size(), ms])
	quit()
