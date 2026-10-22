extends Node
## Validator parse GDScript headless.
##   Godot --headless --path . res://tools/CheckScripts.tscn
##
## WAJIB dijalankan sebagai SCENE (bukan --script): mode --script tidak
## mendaftarkan autoload, jadi setiap script yang menyebut GameState/Database
## akan gagal compile secara palsu.
##
## Verdict yang bisa dipercaya = baris "CHECK-FAIL"/"CHECK-OK" di stdout;
## grep juga "SCRIPT ERROR" dari output engine.

func _ready() -> void:
	var files: Array[String] = []
	_scan("res://", files)
	files.sort()
	var failed: Array[String] = []
	for f in files:
		# GDScript.reload() mengembalikan Error dan—berbeda dari load()—tidak
		# memakai cache, jadi kegagalan compile benar-benar terdeteksi.
		var res := load(f)
		if res == null:
			failed.append(f + "  (load gagal)")
			continue
		if res is GDScript:
			var err := (res as GDScript).reload()
			# ERR_ALREADY_IN_USE (22) wajar: script autoload punya instance hidup
			# sehingga tak boleh di-reload. Itu bukan error compile.
			if err != OK and err != ERR_ALREADY_IN_USE:
				failed.append(f + "  (reload err %d)" % err)

	print("\n=== CHECK SCRIPTS ===")
	print("diperiksa: %d file .gd" % files.size())
	if failed.is_empty():
		print("CHECK-OK: semua script ter-compile")
	else:
		print("CHECK-FAIL (%d):" % failed.size())
		for f in failed:
			print("  - %s" % f)
	get_tree().quit(0 if failed.is_empty() else 1)

func _scan(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name.begins_with("."):
			name = d.get_next()
			continue
		var full: String = dir_path.path_join(name) if dir_path != "res://" else "res://" + name
		if d.current_is_dir():
			# tools/ IKUT diperiksa: script tool yang gagal parse bikin scene
			# headless menggantung (quit() tak pernah dipanggil), susah dilacak.
			_scan(full, out)
		elif name.ends_with(".gd"):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()
