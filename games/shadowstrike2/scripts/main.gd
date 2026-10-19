extends Node3D

const BOT_COUNT := 99
const WORLD_SIZE := 170.0
var player
var bots: Array = []
var move_state := Vector2.ZERO
var fire_held := false
var game_over := false
var kills := 0
var zone_radius := 145.0
var zone_timer := 0.0
var plane: Node3D
var drone: Node3D
var rng := RandomNumberGenerator.new()
var status_label: Label
var health_label: Label
var message_label: Label
var zone_ring: MeshInstance3D

func _ready() -> void:
    rng.randomize()
    _make_environment()
    _make_terrain()
    _make_landmarks()
    _spawn_player()
    _spawn_bots()
    _spawn_aircraft()
    _make_hud()

func _process(delta: float) -> void:
    if game_over:
        return
    zone_timer += delta
    if zone_timer >= 18.0:
        zone_timer = 0.0
        zone_radius = max(20.0, zone_radius - 7.0)
        if is_instance_valid(zone_ring):
            zone_ring.scale = Vector3(zone_radius, 1, zone_radius)
    if plane:
        var t := float(Time.get_ticks_msec()) * 0.00007
        plane.position = Vector3(cos(t) * 110.0, 43.0, sin(t) * 110.0)
        plane.look_at(Vector3.ZERO, Vector3.UP)
    if drone and is_instance_valid(player):
        drone.position = player.global_position + Vector3(3.5, 6.0, 2.5)
        drone.rotation.y += delta * 0.7
    if is_instance_valid(player):
        var p: Vector3 = player.global_position
        if Vector2(p.x, p.z).length() > zone_radius:
            player.take_damage(4.0 * delta)
    _update_hud()
    if bots.is_empty() and is_instance_valid(player):
        game_over = true
        message_label.text = "VICTORY  •  LAST SURVIVOR"
        message_label.visible = true

func _make_environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.10, 0.24, 0.42)
    sky_mat.sky_horizon_color = Color(0.72, 0.78, 0.79)
    sky_mat.ground_bottom_color = Color(0.10, 0.13, 0.10)
    sky_mat.ground_horizon_color = Color(0.48, 0.53, 0.46)
    sky.sky_material = sky_mat
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.62, 0.68, 0.77)
    env.ambient_light_energy = 0.8
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_exposure = 1.1
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -32, 0)
    sun.light_energy = 1.35
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 100.0
    add_child(sun)

func _make_terrain() -> void:
    var ground := StaticBody3D.new()
    ground.name = "Terrain"
    var mesh := MeshInstance3D.new()
    var plane_mesh := PlaneMesh.new()
    plane_mesh.size = Vector2(WORLD_SIZE * 2.0, WORLD_SIZE * 2.0)
    mesh.mesh = plane_mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.24, 0.36, 0.22)
    mat.roughness = 1.0
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mesh.material_override = mat
    ground.add_child(mesh)
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = Vector3(WORLD_SIZE * 2.0, 1.0, WORLD_SIZE * 2.0)
    cs.shape = sh
    cs.position.y = -0.5
    ground.add_child(cs)
    add_child(ground)
    # Ground variation: scattered rocks, shrubs and military cover.
    for i in range(65):
        var x := rng.randf_range(-WORLD_SIZE + 10.0, WORLD_SIZE - 10.0)
        var z := rng.randf_range(-WORLD_SIZE + 10.0, WORLD_SIZE - 10.0)
        if Vector2(x, z).length() < 17.0:
            continue
        if i % 3 == 0:
            _make_tree(Vector3(x, 0, z), rng.randf_range(0.8, 1.4))
        elif i % 3 == 1:
            _make_box(Vector3(x, 0.65, z), Vector3(1.6, 1.3, 1.6), Color(0.29, 0.31, 0.27), true)
        else:
            _make_box(Vector3(x, 0.8, z), Vector3(2.6, 1.6, 0.8), Color(0.35, 0.32, 0.23), true)
    # Road and runway markings.
    _make_box(Vector3(0, 0.025, -42), Vector3(14, 0.05, 92), Color(0.19,0.21,0.20), false)
    for i in range(11):
        _make_box(Vector3(0,0.06,-85+i*8), Vector3(0.35,0.025,3.5), Color(0.86,0.84,0.69), false)
    # Safe-zone visual ring.
    zone_ring = MeshInstance3D.new()
    var ring := zone_ring
    var torus := TorusMesh.new()
    torus.inner_radius = 0.12
    torus.outer_radius = 0.22
    ring.mesh = torus
    ring.scale = Vector3(zone_radius, 1, zone_radius)
    ring.position.y = 0.12
    var rm := StandardMaterial3D.new()
    rm.albedo_color = Color(0.1,0.65,1.0,0.8)
    rm.emission_enabled = true
    rm.emission = Color(0.03,0.25,0.8)
    ring.material_override = rm
    ring.name = "SafeZoneRing"
    add_child(ring)

func _make_landmarks() -> void:
    # Small compound with different-sized buildings and rooftop trim.
    for i in range(12):
        var x := rng.randf_range(-65, 65)
        var z := rng.randf_range(-65, 65)
        if Vector2(x,z).length() < 18:
            continue
        var sx := rng.randf_range(5.0, 10.0)
        var sz := rng.randf_range(5.0, 9.0)
        var h := rng.randf_range(3.0, 6.0)
        var wall_color: Color = [Color(0.48,0.44,0.35), Color(0.38,0.41,0.39), Color(0.50,0.48,0.40)][i % 3]
        _make_box(Vector3(x,h/2,z), Vector3(sx,h,sz), wall_color, true)
        _make_box(Vector3(x,h+0.12,z), Vector3(sx+0.35,0.24,sz+0.35), Color(0.19,0.22,0.21), false)
        # Dark doorway / window-like facade detail.
        _make_box(Vector3(x,1.0,z-sz/2-0.03), Vector3(0.9,1.8,0.08), Color(0.08,0.10,0.10), false)
        for wx in [-1.0, 1.0]:
            _make_box(Vector3(x+wx*sx*0.24,2.0,z-sz/2-0.045), Vector3(0.72,0.55,0.06), Color(0.08,0.15,0.17), false)
    # A radar tower.
    _make_box(Vector3(-18,5,-12), Vector3(0.8,10,0.8), Color(0.26,0.29,0.28), true)
    _make_box(Vector3(-18,10.3,-12), Vector3(4.5,0.25,0.25), Color(0.68,0.70,0.67), false)

func _make_box(pos: Vector3, size: Vector3, color: Color, solid: bool) -> Node3D:
    var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
    if solid:
        var col := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        col.shape = shape
        root.add_child(col)
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.88
    mi.material_override = material
    root.add_child(mi)
    root.position = pos
    add_child(root)
    return root

func _make_tree(pos: Vector3, scale_factor: float) -> void:
    _make_box(pos + Vector3(0,1.0*scale_factor,0), Vector3(0.45,2.0,0.45)*scale_factor, Color(0.24,0.16,0.09), false)
    for layer in range(3):
        var crown := MeshInstance3D.new()
        var cone := ConeMesh.new()
        cone.radius = (1.55 - layer*0.28) * scale_factor
        cone.height = 2.0 * scale_factor
        crown.mesh = cone
        var m := StandardMaterial3D.new()
        m.albedo_color = [Color(0.10,0.25,0.12),Color(0.13,0.30,0.14),Color(0.16,0.34,0.16)][layer]
        m.roughness = 1.0
        crown.material_override = m
        crown.position = pos + Vector3(0,(2.1+layer*0.9)*scale_factor,0)
        add_child(crown)

func _spawn_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.set_script(load("res://scripts/player.gd"))
    player.position = Vector3(0, 1.5, 0)
    player.set("main", self)
    add_child(player)

func _spawn_bots() -> void:
    for i in range(BOT_COUNT):
        var bot := CharacterBody3D.new()
        bot.name = "Rival_%03d" % (i + 1)
        bot.set_script(load("res://scripts/bot.gd"))
        var angle := TAU * float(i) / float(BOT_COUNT)
        var radius := rng.randf_range(30.0, 130.0)
        bot.position = Vector3(cos(angle)*radius, 1.2, sin(angle)*radius)
        bot.set("main", self)
        bots.append(bot)
        add_child(bot)

func _spawn_aircraft() -> void:
    plane = Node3D.new()
    plane.name = "TransportPlane"
    _make_aircraft_part(plane, Vector3(0,0,0), Vector3(2.2,1.25,8.0), Color(0.34,0.39,0.34))
    _make_aircraft_part(plane, Vector3(0,0.1,0), Vector3(13,0.18,2.1), Color(0.27,0.32,0.29))
    _make_aircraft_part(plane, Vector3(0,0.15,2.9), Vector3(5,0.16,1.1), Color(0.27,0.32,0.29))
    add_child(plane)
    drone = Node3D.new()
    drone.name = "ReconDrone"
    _make_aircraft_part(drone, Vector3.ZERO, Vector3(0.65,0.22,0.65), Color(0.07,0.08,0.09))
    for x in [-1,1]:
        for z in [-1,1]:
            _make_aircraft_part(drone, Vector3(x*0.55,0,z*0.55), Vector3(1.1,0.06,0.07), Color(0.13,0.14,0.15))
    add_child(drone)

func _make_aircraft_part(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.25
    mat.roughness = 0.55
    mi.material_override = mat
    mi.position = pos
    parent.add_child(mi)

func _make_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var top := ColorRect.new()
    top.position = Vector2(16,14)
    top.size = Vector2(355,95)
    top.color = Color(0.015,0.025,0.035,0.78)
    layer.add_child(top)
    status_label = Label.new()
    status_label.position = Vector2(30,22)
    status_label.add_theme_font_size_override("font_size",20)
    status_label.add_theme_color_override("font_color",Color(0.98,0.79,0.31))
    layer.add_child(status_label)
    health_label = Label.new()
    health_label.position = Vector2(30,59)
    health_label.add_theme_font_size_override("font_size",18)
    health_label.add_theme_color_override("font_color",Color(0.42,1,0.57))
    layer.add_child(health_label)
    var help := Label.new()
    help.text = "WASD move • Right mouse + drag aim • Click fire • Space jump • R reload"
    help.position = Vector2(18,116)
    help.add_theme_font_size_override("font_size",14)
    help.add_theme_color_override("font_color",Color.WHITE)
    layer.add_child(help)
    var cross := Label.new()
    cross.text = "+"
    cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    cross.position = Vector2(-8,-18)
    cross.add_theme_font_size_override("font_size",30)
    cross.add_theme_color_override("font_color",Color(1,1,1,0.85))
    layer.add_child(cross)
    message_label = Label.new()
    message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    message_label.position = Vector2(-250,-70)
    message_label.add_theme_font_size_override("font_size",30)
    message_label.add_theme_color_override("font_color",Color(1,0.79,0.28))
    message_label.visible = false
    layer.add_child(message_label)
    # Touch movement buttons and combat controls.
    var left := _button(layer,"◀",Vector2(28,550),Vector2(76,76))
    left.button_down.connect(func(): move_state.x = -1)
    left.button_up.connect(func(): if move_state.x < 0: move_state.x = 0)
    var right := _button(layer,"▶",Vector2(180,550),Vector2(76,76))
    right.button_down.connect(func(): move_state.x = 1)
    right.button_up.connect(func(): if move_state.x > 0: move_state.x = 0)
    var forward := _button(layer,"▲",Vector2(104,474),Vector2(76,76))
    forward.button_down.connect(func(): move_state.y = 1)
    forward.button_up.connect(func(): if move_state.y > 0: move_state.y = 0)
    var back := _button(layer,"▼",Vector2(104,626),Vector2(76,65))
    back.button_down.connect(func(): move_state.y = -1)
    back.button_up.connect(func(): if move_state.y < 0: move_state.y = 0)
    var fire := _button(layer,"FIRE",Vector2(1080,550),Vector2(155,105))
    fire.button_down.connect(func(): fire_held = true)
    fire.button_up.connect(func(): fire_held = false)
    var jump := _button(layer,"JUMP",Vector2(975,620),Vector2(95,58))
    jump.pressed.connect(func(): if is_instance_valid(player): player.jump_now())
    var reload_btn := _button(layer,"RELOAD",Vector2(1080,475),Vector2(155,58))
    reload_btn.pressed.connect(func(): if is_instance_valid(player): player.reload_weapon())

func _button(layer: CanvasLayer, caption: String, pos: Vector2, size: Vector2) -> Button:
    var b := Button.new()
    b.text = caption
    b.position = pos
    b.size = size
    b.add_theme_font_size_override("font_size",19)
    b.add_theme_color_override("font_color",Color.WHITE)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.025,0.055,0.065,0.78)
    normal.border_width_left = 2
    normal.border_width_right = 2
    normal.border_width_top = 2
    normal.border_width_bottom = 2
    normal.border_color = Color(0.78,0.62,0.27,0.9)
    normal.corner_radius_top_left = 12
    normal.corner_radius_top_right = 12
    normal.corner_radius_bottom_left = 12
    normal.corner_radius_bottom_right = 12
    b.add_theme_stylebox_override("normal",normal)
    layer.add_child(b)
    return b

func _update_hud() -> void:
    if status_label:
        status_label.text = "SHADOW STRIKE  •  ALIVE: %d" % (bots.size() + (1 if is_instance_valid(player) else 0))
    if health_label and is_instance_valid(player):
        health_label.text = "HP: %d   AMMO: %d   KILLS: %d" % [int(player.health), player.ammo, kills]

func bot_killed(bot: Node3D) -> void:
    bots.erase(bot)
    if is_instance_valid(player) and bool(bot.get("was_killed_by_player")):
        kills += 1

func player_died() -> void:
    game_over = true
    message_label.text = "ELIMINATED  •  KILLS: %d" % kills
    message_label.visible = true

func get_combatants() -> Array[Node3D]:
    var result: Array[Node3D] = []
    if is_instance_valid(player):
        result.append(player)
    for bot in bots:
        if is_instance_valid(bot):
            result.append(bot)
    return result
