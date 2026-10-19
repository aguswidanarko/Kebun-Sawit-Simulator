extends SceneTree
## Cek dimensi/animasi model. godot --headless -s tools/inspect_model.gd

func _initialize() -> void:
	for path in ["res://assets/models/character/human.glb"]:
		var ps = load(path)
		if ps == null:
			print("GAGAL load: ", path); continue
		var inst = ps.instantiate()
		get_root().add_child(inst)
		var aabb := _node_aabb(inst)
		print("%s  size=(%.2f,%.2f,%.2f) center=(%.2f,%.2f,%.2f)" % [
			path.get_file(), aabb.size.x, aabb.size.y, aabb.size.z,
			aabb.get_center().x, aabb.get_center().y, aabb.get_center().z])
		var ap := _find_anim(inst)
		if ap:
			print("  AnimationPlayer: ", ap.get_animation_list())
		else:
			print("  (tak ada AnimationPlayer)")
		inst.queue_free()
	quit()

func _find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var r := _find_anim(c)
		if r: return r
	return null

func _all(node: Node, out: Array) -> void:
	out.append(node)
	for c in node.get_children():
		_all(c, out)

func _node_aabb(node: Node) -> AABB:
	var arr: Array = []; _all(node, arr)
	var aabb := AABB(); var first := true
	for c in arr:
		if c is MeshInstance3D and c.mesh != null:
			var a: AABB = c.global_transform * c.mesh.get_aabb()
			if first: aabb = a; first = false
			else: aabb = aabb.merge(a)
	return aabb
