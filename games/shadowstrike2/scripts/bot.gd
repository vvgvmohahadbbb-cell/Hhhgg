extends CharacterBody3D

var health := 100.0
var main
var speed := 3.0
var attack_timer := 0.0
var think_timer := 0.0
var strafe_sign := 1.0
var rng := RandomNumberGenerator.new()
var was_killed_by_player := false
var target: Node3D

func _ready() -> void:
    rng.randomize()
    speed = rng.randf_range(2.4,3.6)
    var col := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.38
    cap.height = 1.65
    col.shape = cap
    col.position.y = 0.83
    add_child(col)
    _part(Vector3(0,0.9,0),Vector3(0.66,0.9,0.38),Color(rng.randf_range(0.22,0.45),rng.randf_range(0.16,0.29),rng.randf_range(0.10,0.20)))
    _part(Vector3(0,1.58,0),Vector3(0.38,0.38,0.38),Color(0.55,0.42,0.31),true)
    _part(Vector3(0,0.86,0.25),Vector3(0.43,0.58,0.2),Color(0.18,0.20,0.17))

func _part(pos: Vector3, size: Vector3, color: Color, sphere: bool = false) -> void:
    var mi := MeshInstance3D.new()
    if sphere:
        var sm := SphereMesh.new()
        sm.radius = size.x*0.5
        sm.height = size.y
        mi.mesh = sm
    else:
        var bm := BoxMesh.new()
        bm.size = size
        mi.mesh = bm
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.85
    mi.material_override = mat
    mi.position = pos
    add_child(mi)

func _physics_process(delta: float) -> void:
    if not main or main.game_over:
        return
    attack_timer -= delta
    think_timer -= delta
    if think_timer <= 0.0 or not is_instance_valid(target):
        target = _choose_target()
        think_timer = rng.randf_range(0.45,1.0)
    if not is_instance_valid(target):
        return
    var offset := target.global_position - global_position
    offset.y = 0
    var distance := offset.length()
    if distance > 8.0:
        var dir := offset.normalized()
        var strafe := Vector3(-dir.z,0,dir.x) * strafe_sign * 0.18
        velocity.x = (dir.x + strafe.x) * speed
        velocity.z = (dir.z + strafe.z) * speed
        if distance > 0.1:
            look_at(Vector3(target.global_position.x,global_position.y,target.global_position.z),Vector3.UP)
    else:
        velocity.x = 0
        velocity.z = 0
        if distance > 0.1:
            look_at(Vector3(target.global_position.x,global_position.y,target.global_position.z),Vector3.UP)
    if not is_on_floor():
        velocity.y -= 18.0 * delta
    move_and_slide()
    if distance < 38.0 and attack_timer <= 0.0:
        attack_timer = rng.randf_range(0.65,1.35)
        # Bot-versus-bot and bot-versus-player combat.
        var accuracy := 0.58 if distance < 18.0 else 0.28
        if rng.randf() < accuracy and target.has_method("take_damage"):
            target.call("take_damage", rng.randf_range(5.0,11.0), self)

func _choose_target() -> Node3D:
    var candidates: Array[Node3D] = main.get_combatants()
    var best: Node3D = null
    var best_distance := 999999.0
    for candidate in candidates:
        if candidate == self or not is_instance_valid(candidate):
            continue
        var d := global_position.distance_to(candidate.global_position)
        if d < best_distance:
            best_distance = d
            best = candidate
    return best

func take_damage(amount: float, attacker: Node = null) -> void:
    health -= amount
    if attacker and attacker.name == "Player":
        was_killed_by_player = true
    if health <= 0.0:
        if main:
            main.bot_killed(self)
        queue_free()
