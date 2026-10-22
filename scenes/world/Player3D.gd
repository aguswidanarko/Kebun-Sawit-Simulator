extends CharacterBody3D
## Karakter pemain orang-ketiga — model CC0 Quaternius "Animated Human" (glb).
## Gerak WASD/panah + joystick sentuh; animasi Idle/Walk otomatis.

const SPEED := 6.0
const GRAVITY := 20.0
const TURN := 12.0
const MODEL := "res://assets/models/character/human.glb"
const HEIGHT := 1.7

var joystick: Vector2 = Vector2.ZERO
var _anim: AnimationPlayer
var _cur_anim := ""
var _busy := 0.0   # detik tersisa animasi "bekerja"/emote (mengunci gerak)
var _busy_key := "Working"   # nama klip yg diputar selama _busy > 0

func do_work(seconds: float = 1.2) -> void:
	_busy_key = "Working"
	_busy = seconds

## Putar emote kosmetik (lihat GameState.applied_emote_anim_key()). anim_key
## dicocokkan via substring (lihat _anim_named) — kalau kostum yg dipakai tak
## punya klip serupa, otomatis diam saja (no-op aman, tak error).
func do_emote(anim_key: String, seconds: float = 2.0) -> void:
	_busy_key = anim_key
	_busy = seconds

func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.35; cap.height = 1.7
	col.shape = cap; col.position.y = 0.85
	add_child(col)

	var mp := GameState.character_model() if GameState else MODEL
	var ps = load(mp) if ResourceLoader.exists(mp) else load(MODEL)
	if ps != null:
		var m: Node3D = ps.instantiate()
		add_child(m)
		_fit_height(m, HEIGHT)
		m.rotation.y = PI            # hadap menjauh kamera (3rd person)
		_anim = _find_anim(m)
		if _anim:
			_setup_loop_modes()
			_play("Idle")
	else:
		_fallback_capsule()

func _physics_process(delta: float) -> void:
	if _busy > 0.0:
		_busy -= delta
		velocity.x = 0.0; velocity.z = 0.0
		velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
		_play(_busy_key)
		move_and_slide()
		return
	var iv := _input_vector()
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	velocity.x = iv.x * SPEED
	velocity.z = iv.y * SPEED
	var moving := iv.length() > 0.08
	if moving:
		# atan2(-x, -y): kedua sumbu dinegasikan karena model dasar menghadap
		# TERBALIK dari arah jalannya (lihat m.rotation.y = PI di _ready()).
		rotation.y = lerp_angle(rotation.y, atan2(-iv.x, -iv.y), TURN * delta)
	_play("Walk" if moving else "Idle")
	move_and_slide()

func _input_vector() -> Vector2:
	var v := Vector2.ZERO
	v.x = Input.get_axis("ui_left", "ui_right")
	v.y = Input.get_axis("ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_A): v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): v.x += 1.0
	if Input.is_physical_key_pressed(KEY_W): v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): v.y += 1.0
	v += joystick
	return v.limit_length(1.0)

# --- animasi ---

## Klip yang harus berulang selama kondisinya bertahan. Klip lain (Working,
## emote kosmetik) sengaja sekali jalan.
const LOOPING_CLIPS := ["idle", "walk", "run"]

## Animasi hasil impor .glb default-nya loop_mode = NONE, jadi "Walk" berhenti
## sendiri di frame terakhir sementara pemain masih bergerak — inilah penyebab
## kaki membeku / karakter tampak melayang. Dipanggil sekali di _ready().
func _setup_loop_modes() -> void:
	if _anim == null:
		return
	for a in _anim.get_animation_list():
		var clip := _anim.get_animation(a)
		if clip == null:
			continue
		var lower := a.to_lower()
		var should_loop := false
		for k in LOOPING_CLIPS:
			if k in lower:
				should_loop = true
				break
		clip.loop_mode = Animation.LOOP_LINEAR if should_loop else Animation.LOOP_NONE

func _play(key: String) -> void:
	if _anim == null:
		return
	# Jangan restart klip yang sama tiap frame (gerakannya akan tersendat),
	# TAPI kalau klipnya sudah berhenti ia wajib diputar ulang — pengaman
	# kedua kalau ada klip yang lolos dari _setup_loop_modes().
	if _cur_anim == key and _anim.is_playing():
		return
	var name := _anim_named(key)
	if name != "":
		_anim.play(name)
		_cur_anim = key

func _anim_named(key: String) -> String:
	if _anim == null:
		return ""
	for a in _anim.get_animation_list():
		if key.to_lower() in a.to_lower():
			return a
	return ""

func _find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var r := _find_anim(c)
		if r: return r
	return null

# --- util skala & fallback ---
func _fit_height(inst: Node3D, target_h: float) -> void:
	var aabb := _local_aabb(inst)
	if target_h > 0.0 and aabb.size.y > 0.0001:
		var s: float = target_h / aabb.size.y
		inst.scale = Vector3(s, s, s)
		inst.position.y = -aabb.position.y * s

func _local_aabb(inst: Node) -> AABB:
	var aabb := AABB(); var first := true
	for m in _meshes(inst):
		var a: AABB = _rel_xform(inst, m) * m.mesh.get_aabb()
		if first: aabb = a; first = false
		else: aabb = aabb.merge(a)
	return aabb

func _rel_xform(root: Node, node: Node3D) -> Transform3D:
	var t := Transform3D(); var n: Node = node
	while n != null and n != root:
		if n is Node3D: t = (n as Node3D).transform * t
		n = n.get_parent()
	return t

func _meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node)
	for c in node.get_children():
		out.append_array(_meshes(c))
	return out

func _fallback_capsule() -> void:
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new(); cm.radius = 0.35; cm.height = 1.7
	body.mesh = cm; body.position.y = 0.85
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.2, 0.5, 0.9)
	body.material_override = mat
	add_child(body)
