extends CharacterBody3D

var health := 100.0
var ammo := 30
var reserve_ammo := 180
var speed := 7.0
var jump_velocity := 6.2
var gravity := 18.0
var fire_cooldown := 0.0
var reload_timer := 0.0
var main
var camera: Camera3D
var yaw := 0.0
var pitch := -0.10
var last_touch := Vector2.ZERO
var weapon_root: Node3D
var muzzle_flash: OmniLight3D
var muzzle_timer := 0.0

func _ready() -> void:
    var col := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.42
    capsule.height = 1.8
    col.shape = capsule
    col.position.y = 0.9
    add_child(col)
    # Player silhouette: layered tactical torso, head and backpack.
    _add_body_part(Vector3(0,1.0,0), Vector3(0.72,0.95,0.42), Color(0.12,0.22,0.20))
    _add_body_part(Vector3(0,1.72,0), Vector3(0.42,0.42,0.42), Color(0.68,0.52,0.38), true)
    _add_body_part(Vector3(0,0.9,0.28), Vector3(0.46,0.65,0.22), Color(0.20,0.23,0.20))
    _add_body_part(Vector3(0.43,1.12,0), Vector3(0.22,0.72,0.24), Color(0.16,0.20,0.18))
    _add_body_part(Vector3(-0.43,1.12,0), Vector3(0.22,0.72,0.24), Color(0.16,0.20,0.18))
    camera = Camera3D.new()
    camera.position = Vector3(0,2.65,6.4)
    camera.rotation.x = -0.20
    camera.current = true
    add_child(camera)
    _build_rifle()

func _build_rifle() -> void:
    # Low-poly rifle silhouette attached to the over-shoulder camera.
    weapon_root = Node3D.new()
    weapon_root.name = "RifleModel"
    weapon_root.position = Vector3(0.62, -0.48, -1.05)
    weapon_root.rotation_degrees = Vector3(2, -3, 0)
    camera.add_child(weapon_root)
    _weapon_box(Vector3(0, 0, 0), Vector3(0.16, 0.18, 0.62), Color(0.12,0.14,0.13))
    _weapon_box(Vector3(0, -0.01, -0.48), Vector3(0.07, 0.07, 0.52), Color(0.07,0.08,0.08))
    _weapon_box(Vector3(0, -0.02, -0.78), Vector3(0.045, 0.045, 0.18), Color(0.22,0.23,0.21))
    _weapon_box(Vector3(0, -0.19, 0.20), Vector3(0.13, 0.30, 0.17), Color(0.16,0.18,0.16))
    _weapon_box(Vector3(0, 0.12, -0.05), Vector3(0.05, 0.10, 0.16), Color(0.05,0.06,0.06))
    _weapon_box(Vector3(0, 0.13, -0.47), Vector3(0.055, 0.05, 0.09), Color(0.05,0.06,0.06))
    muzzle_flash = OmniLight3D.new()
    muzzle_flash.light_color = Color(1.0, 0.55, 0.16)
    muzzle_flash.light_energy = 2.8
    muzzle_flash.omni_range = 3.0
    muzzle_flash.position = Vector3(0, 0, -0.98)
    muzzle_flash.visible = false
    weapon_root.add_child(muzzle_flash)

func _weapon_box(pos: Vector3, size: Vector3, color: Color) -> void:
    var mi := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.35
    mat.roughness = 0.42
    mi.material_override = mat
    mi.position = pos
    weapon_root.add_child(mi)

func _add_body_part(pos: Vector3, size: Vector3, color: Color, sphere: bool = false) -> void:
    var mi := MeshInstance3D.new()
    if sphere:
        var sm := SphereMesh.new()
        sm.radius = size.x * 0.5
        sm.height = size.y
        mi.mesh = sm
    else:
        var bm := BoxMesh.new()
        bm.size = size
        mi.mesh = bm
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.82
    mi.material_override = mat
    mi.position = pos
    add_child(mi)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        yaw -= event.relative.x * 0.003
        pitch = clamp(pitch - event.relative.y * 0.0025, -0.65, 0.25)
        rotation.y = yaw
        camera.rotation.x = pitch
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        fire_weapon()
    elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
        reload_weapon()
    elif event is InputEventScreenTouch:
        last_touch = event.position
    elif event is InputEventScreenDrag:
        if event.position.x > get_viewport().get_visible_rect().size.x * 0.36:
            yaw -= event.relative.x * 0.004
            pitch = clamp(pitch - event.relative.y * 0.003, -0.65, 0.25)
            rotation.y = yaw
            camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
    if muzzle_timer > 0.0:
        muzzle_timer -= delta
        if muzzle_timer <= 0.0 and is_instance_valid(muzzle_flash):
            muzzle_flash.visible = false
    if fire_cooldown > 0.0:
        fire_cooldown -= delta
    if reload_timer > 0.0:
        reload_timer -= delta
        if reload_timer <= 0.0:
            var take: int = min(30 - ammo, reserve_ammo)
            ammo += take
            reserve_ammo -= take
    var input_dir := Vector2.ZERO
    input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
    input_dir.y = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
    if main:
        input_dir += main.move_state
    input_dir = input_dir.normalized()
    var dir := (transform.basis * Vector3(input_dir.x, 0, -input_dir.y)).normalized()
    velocity.x = dir.x * speed
    velocity.z = dir.z * speed
    if not is_on_floor():
        velocity.y -= gravity * delta
    elif Input.is_action_just_pressed("jump"):
        velocity.y = jump_velocity
    if main and main.fire_held:
        fire_weapon()
    move_and_slide()

func jump_now() -> void:
    if is_on_floor():
        velocity.y = jump_velocity

func reload_weapon() -> void:
    if reload_timer <= 0.0 and ammo < 30 and reserve_ammo > 0:
        reload_timer = 1.35

func fire_weapon() -> void:
    if fire_cooldown > 0.0 or reload_timer > 0.0:
        return
    if ammo <= 0:
        reload_weapon()
        return
    fire_cooldown = 0.14
    ammo -= 1
    if is_instance_valid(muzzle_flash):
        muzzle_flash.visible = true
        muzzle_timer = 0.045
    if is_instance_valid(weapon_root):
        weapon_root.position.z = -0.98
    var from := camera.global_position
    var direction := -camera.global_transform.basis.z
    var query := PhysicsRayQueryParameters3D.create(from, from + direction * 110.0)
    query.exclude = [self]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty() and hit.collider and hit.collider.has_method("take_damage"):
        hit.collider.take_damage(34.0, self)

func take_damage(amount: float, _attacker: Node = null) -> void:
    health -= amount
    if health <= 0.0:
        health = 0.0
        if main:
            main.player_died()
        queue_free()
