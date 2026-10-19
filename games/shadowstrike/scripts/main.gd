extends Node3D

const BOT_SCRIPT = preload("res://scripts/bot.gd")
const BOT_COUNT := 99
const GROUND_TEX = preload("res://assets/textures/ground_detail.png")
const SHOT_AUDIO = preload("res://assets/audio/rifle.wav")
const HIT_AUDIO = preload("res://assets/audio/hit.wav")
const ENGINE_AUDIO = preload("res://assets/audio/engine.wav")
const ZONE_AUDIO = preload("res://assets/audio/zone.wav")
var player: CharacterBody3D
var bots: Array[CharacterBody3D] = []
var health := 100.0
var kills := 0
var zone_radius := 110.0
var elapsed := 0.0
var move_vec := Vector2.ZERO
var fire_requested := false
var hud: Label
var status: Label
var hpbar: ProgressBar
var fire_sound: AudioStreamPlayer
var hit_sound: AudioStreamPlayer
var engine_sound: AudioStreamPlayer
var zone_sound: AudioStreamPlayer
var fire_cooldown := 0.0
var zone_stage := 0
var game_over := false
var magazine := 30
var reserve_ammo := 120
var reload_time := 0.0
var reload_in_progress := false
var ammo_label: Label
var toast_label: Label

func _ready() -> void:
    randomize()
    _make_world()
    _make_player()
    _make_audio()
    _make_vehicles()
    for i in BOT_COUNT:
        _spawn_bot(i)
    _make_ui()
    _update_hud()

func _make_world() -> void:
    var envnode := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = Sky.new()
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.70,0.75,0.81)
    env.ambient_light_energy = 0.9
    envnode.environment = env
    add_child(envnode)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48,-28,0)
    sun.light_energy = 1.3
    sun.shadow_enabled = true
    add_child(sun)
    var ground := StaticBody3D.new()
    var mesh := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(260,260)
    mesh.mesh = plane
    var gm := StandardMaterial3D.new()
    gm.albedo_texture = GROUND_TEX
    gm.uv1_scale = Vector3(32,32,1)
    gm.roughness = 1.0
    mesh.material_override = gm
    ground.add_child(mesh)
    var col := CollisionShape3D.new()
    var cs := BoxShape3D.new()
    cs.size = Vector3(260,0.5,260)
    col.shape = cs
    col.position.y = -0.25
    ground.add_child(col)
    add_child(ground)
    # asphalt roads
    for i in 5:
        _box_prop(Vector3(0,0.03,-80+i*40),Vector3(260,0.07,7),Color(0.15,0.17,0.18),false)
        _box_prop(Vector3(-80+i*40,0.035,0),Vector3(7,0.07,260),Color(0.15,0.17,0.18),false)
    # city
    for i in 55:
        var x := randf_range(-100,100)
        var z := randf_range(-100,100)
        if Vector2(x,z).length() < 20: continue
        var sx := randf_range(5,12)
        var sz := randf_range(5,12)
        var h := randf_range(4,16)
        var b := StaticBody3D.new()
        var bm := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = Vector3(sx,h,sz)
        bm.mesh = box
        bm.position.y = h/2
        var mat := StandardMaterial3D.new()
        mat.albedo_color = [Color(0.48,0.45,0.39),Color(0.32,0.39,0.43),Color(0.57,0.48,0.36),Color(0.39,0.43,0.37)][i%4]
        mat.roughness = 0.92
        bm.material_override = mat
        b.add_child(bm)
        var roof := MeshInstance3D.new()
        var rb := BoxMesh.new()
        rb.size = Vector3(sx*1.06,0.22,sz*1.06)
        roof.mesh = rb
        roof.position.y = h+0.11
        var rm := StandardMaterial3D.new()
        rm.albedo_color = Color(0.16,0.19,0.19)
        roof.material_override = rm
        b.add_child(roof)
        var bc := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = box.size
        bc.shape = bs
        bc.position.y = h/2
        b.add_child(bc)
        b.position = Vector3(x,0,z)
        add_child(b)
    # scattered rocks and trees
    for i in 50:
        var x := randf_range(-115,115); var z := randf_range(-115,115)
        if i%2==0:
            var trunk := _box_prop(Vector3(x,1.1,z),Vector3(0.55,2.2,0.55),Color(0.28,0.19,0.12),false)
            var crown := MeshInstance3D.new()
            var cone := SphereMesh.new()
            cone.radius = randf_range(1.4,2.4); cone.height = cone.radius*1.8
            crown.mesh = cone; crown.position = Vector3(x,3.2,z)
            var cm := StandardMaterial3D.new(); cm.albedo_color=Color(0.13,0.30,0.16)
            crown.material_override=cm; add_child(crown)
        else:
            var rock := MeshInstance3D.new()
            var sphere := SphereMesh.new()
            sphere.radius=randf_range(0.6,1.8); sphere.height=sphere.radius*1.4
            rock.mesh=sphere; rock.position=Vector3(x,0.5,z); rock.scale=Vector3(1.3,0.8,1)
            var rmat:=StandardMaterial3D.new(); rmat.albedo_color=Color(0.32,0.34,0.31)
            rock.material_override=rmat; add_child(rock)

func _box_prop(pos: Vector3, size: Vector3, color: Color, collision: bool) -> Node3D:
    var root: Node3D = StaticBody3D.new() if collision else Node3D.new()
    var mi:=MeshInstance3D.new()
    var bm:=BoxMesh.new(); bm.size=size; mi.mesh=bm
    var mat:=StandardMaterial3D.new(); mat.albedo_color=color; mat.roughness=0.82
    mi.material_override=mat; root.add_child(mi)
    if collision:
        var c:=CollisionShape3D.new(); var s:=BoxShape3D.new(); s.size=size; c.shape=s; root.add_child(c)
    root.position=pos; add_child(root)
    return root

func _make_vehicles() -> void:
    # decorative drivable-looking props (visual only in this prototype)
    for i in 5:
        var x := [-38.0,31.0,56.0,-64.0,78.0][i]
        var z := [22.0,-45.0,61.0,52.0,-18.0][i]
        _make_car(Vector3(x,0,z),i%2==0)
    _make_tank(Vector3(42,0,30))
    _make_plane(Vector3(-18,0.1,-48))
    _make_drone(Vector3(17,7,10))

func _make_car(pos: Vector3, green: bool) -> void:
    var root:=Node3D.new(); root.position=pos; add_child(root)
    var color:=Color(0.15,0.32,0.22) if green else Color(0.38,0.39,0.41)
    _vehicle_box(root,Vector3(0,0.9,0),Vector3(2.1,0.75,4.0),color)
    _vehicle_box(root,Vector3(0,1.55,-0.15),Vector3(1.65,0.7,1.9),Color(0.12,0.19,0.22))
    for side in [-1.0,1.0]:
        for front in [-1.0,1.0]:
            var wheel:=MeshInstance3D.new()
            var cyl:=CylinderMesh.new(); cyl.top_radius=0.38; cyl.bottom_radius=0.38; cyl.height=0.25
            wheel.mesh=cyl; wheel.rotation_degrees.z=90
            wheel.position=Vector3(side*1.05,0.55,front*1.25)
            var wm:=StandardMaterial3D.new(); wm.albedo_color=Color(0.07,0.07,0.07); wheel.material_override=wm
            root.add_child(wheel)

func _make_tank(pos: Vector3) -> void:
    var root:=Node3D.new(); root.position=pos; add_child(root)
    _vehicle_box(root,Vector3(0,0.8,0),Vector3(3.0,0.9,4.2),Color(0.25,0.31,0.20))
    _vehicle_box(root,Vector3(0,1.45,-0.1),Vector3(1.8,0.55,1.8),Color(0.19,0.25,0.16))
    _vehicle_box(root,Vector3(0,1.55,-1.45),Vector3(0.22,0.22,2.7),Color(0.12,0.15,0.12))
    for side in [-1.0,1.0]:
        _vehicle_box(root,Vector3(side*1.58,0.62,0),Vector3(0.22,0.7,3.8),Color(0.09,0.11,0.09))

func _make_plane(pos: Vector3) -> void:
    var root:=Node3D.new(); root.position=pos; root.rotation_degrees.y=28; add_child(root)
    _vehicle_box(root,Vector3(0,0,0),Vector3(1.0,0.7,7.0),Color(0.69,0.70,0.63))
    _vehicle_box(root,Vector3(0,0.05,0),Vector3(10.0,0.18,1.5),Color(0.49,0.53,0.48))
    _vehicle_box(root,Vector3(0,0.1,2.8),Vector3(4.0,0.16,0.8),Color(0.49,0.53,0.48))
    _vehicle_box(root,Vector3(0,0.15,-3.0),Vector3(3.1,0.15,0.7),Color(0.49,0.53,0.48))

func _make_drone(pos: Vector3) -> void:
    var root:=Node3D.new(); root.position=pos; add_child(root)
    _vehicle_box(root,Vector3.ZERO,Vector3(0.65,0.22,0.65),Color(0.12,0.14,0.13))
    for side in [-1.0,1.0]:
        for fore in [-1.0,1.0]:
            _vehicle_box(root,Vector3(side*0.75,0,fore*0.75),Vector3(1.2,0.06,0.08),Color(0.10,0.11,0.11))
            var rotor:=MeshInstance3D.new(); var cy:=CylinderMesh.new(); cy.top_radius=0.27; cy.bottom_radius=0.27; cy.height=0.04
            rotor.mesh=cy; rotor.position=Vector3(side*1.25,0.1,fore*1.25)
            var rm:=StandardMaterial3D.new(); rm.albedo_color=Color(0.06,0.07,0.07); rotor.material_override=rm
            root.add_child(rotor)

func _vehicle_box(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
    var mi:=MeshInstance3D.new(); var b:=BoxMesh.new(); b.size=size; mi.mesh=b; mi.position=pos
    var m:=StandardMaterial3D.new(); m.albedo_color=color; m.roughness=0.7; mi.material_override=m; root.add_child(mi)

func _make_player() -> void:
    player=CharacterBody3D.new(); player.name="Player"; player.position=Vector3(0,1,0)
    _humanoid(player,Color(0.10,0.33,0.72),true)
    var cam:=Camera3D.new(); cam.position=Vector3(0,4.8,8.5); cam.rotation_degrees=Vector3(-22,0,0); cam.current=true
    player.add_child(cam); add_child(player)

func _humanoid(root: Node3D, outfit: Color, collider: bool) -> void:
    var torso:=MeshInstance3D.new(); var cap:=CapsuleMesh.new(); cap.radius=0.44; cap.height=1.2
    torso.mesh=cap; torso.position.y=1.05
    var mat:=StandardMaterial3D.new(); mat.albedo_color=outfit; mat.roughness=0.75; torso.material_override=mat; root.add_child(torso)
    var head:=MeshInstance3D.new(); var sp:=SphereMesh.new(); sp.radius=0.28; sp.height=0.56
    head.mesh=sp; head.position.y=1.85
    var skin:=StandardMaterial3D.new(); skin.albedo_color=Color(0.72,0.55,0.42); head.material_override=skin; root.add_child(head)
    var vest:=MeshInstance3D.new(); var vb:=BoxMesh.new(); vb.size=Vector3(0.65,0.62,0.36)
    vest.mesh=vb; vest.position=Vector3(0,1.12,-0.02)
    var vm:=StandardMaterial3D.new(); vm.albedo_color=Color(0.11,0.15,0.12); vest.material_override=vm; root.add_child(vest)
    if collider:
        var col:=CollisionShape3D.new(); var cs:=CapsuleShape3D.new(); cs.radius=0.44; cs.height=1.9
        col.shape=cs; col.position.y=0.95; root.add_child(col)

func _make_audio() -> void:
    fire_sound=AudioStreamPlayer.new(); fire_sound.stream=SHOT_AUDIO; fire_sound.volume_db=-4; add_child(fire_sound)
    hit_sound=AudioStreamPlayer.new(); hit_sound.stream=HIT_AUDIO; hit_sound.volume_db=-3; add_child(hit_sound)
    engine_sound=AudioStreamPlayer.new(); engine_sound.stream=ENGINE_AUDIO; engine_sound.volume_db=-15; add_child(engine_sound)
    zone_sound=AudioStreamPlayer.new(); zone_sound.stream=ZONE_AUDIO; zone_sound.volume_db=-8; add_child(zone_sound)

func _spawn_bot(i: int) -> void:
    var bot: CharacterBody3D=CharacterBody3D.new(); bot.set_script(BOT_SCRIPT)
    bot.position=Vector3(randf_range(-108,108),1,randf_range(-108,108))
    if bot.position.length()<18: bot.position.x+=28
    bot.name="Bot_%02d" % i; add_child(bot)
    var outfits: Array[Color]=[Color(0.68,0.18,0.12),Color(0.22,0.36,0.22),Color(0.62,0.43,0.18),Color(0.28,0.29,0.39),Color(0.34,0.34,0.30)]
    bot.setup(self,player,outfits[i%outfits.size()]); bots.append(bot)

func _make_ui() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 5
    add_child(layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_PASS
    layer.add_child(root)

    # Clean, high-contrast top HUD panels
    var top_panel := PanelContainer.new()
    top_panel.position = Vector2(16, 14)
    top_panel.custom_minimum_size = Vector2(310, 96)
    top_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.065, 0.88), Color(0.25, 0.78, 0.65, 0.8)))
    root.add_child(top_panel)
    var top_col := VBoxContainer.new()
    top_col.add_theme_constant_override("separation", 4)
    top_panel.add_child(top_col)
    hud = Label.new()
    hud.add_theme_font_size_override("font_size", 18)
    hud.add_theme_color_override("font_color", Color(0.92, 0.98, 0.96))
    top_col.add_child(hud)
    hpbar = ProgressBar.new()
    hpbar.custom_minimum_size = Vector2(270, 14)
    hpbar.max_value = 100
    hpbar.value = 100
    hpbar.show_percentage = false
    hpbar.add_theme_stylebox_override("background", _panel_style(Color(0.12, 0.15, 0.16), Color(0.12, 0.15, 0.16)))
    hpbar.add_theme_stylebox_override("fill", _panel_style(Color(0.15, 0.83, 0.48), Color(0.15, 0.83, 0.48)))
    top_col.add_child(hpbar)
    status = Label.new()
    status.text = "OFFLINE SURVIVAL  /  STAY INSIDE THE ZONE"
    status.add_theme_font_size_override("font_size", 12)
    status.add_theme_color_override("font_color", Color(0.67, 0.83, 0.82))
    top_col.add_child(status)

    var title := Label.new()
    title.text = "SHADOW STRIKE"
    title.anchor_left = 0.5
    title.anchor_right = 0.5
    title.position = Vector2(-125, 16)
    title.add_theme_font_size_override("font_size", 24)
    title.add_theme_color_override("font_color", Color(0.96, 0.72, 0.27))
    root.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "LAST ZONE  •  OFFLINE OPS"
    subtitle.anchor_left = 0.5
    subtitle.anchor_right = 0.5
    subtitle.position = Vector2(-100, 45)
    subtitle.add_theme_font_size_override("font_size", 11)
    subtitle.add_theme_color_override("font_color", Color(0.8, 0.86, 0.85))
    root.add_child(subtitle)

    var right_panel := PanelContainer.new()
    right_panel.anchor_left = 1.0
    right_panel.anchor_right = 1.0
    right_panel.position = Vector2(-190, 14)
    right_panel.custom_minimum_size = Vector2(174, 48)
    right_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.065, 0.88), Color(0.25, 0.78, 0.65, 0.8)))
    root.add_child(right_panel)
    var right_label := Label.new()
    right_label.text = "99 HOSTILE BOTS\nSURVIVE TO WIN"
    right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    right_label.add_theme_font_size_override("font_size", 14)
    right_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.91))
    right_panel.add_child(right_label)

    ammo_label = Label.new()
    ammo_label.anchor_left = 1.0
    ammo_label.anchor_right = 1.0
    ammo_label.anchor_top = 1.0
    ammo_label.anchor_bottom = 1.0
    ammo_label.position = Vector2(-230, -74)
    ammo_label.add_theme_font_size_override("font_size", 21)
    ammo_label.add_theme_color_override("font_color", Color(1.0, 0.83, 0.37))
    root.add_child(ammo_label)

    toast_label = Label.new()
    toast_label.anchor_left = 0.5
    toast_label.anchor_right = 0.5
    toast_label.position = Vector2(-170, 92)
    toast_label.custom_minimum_size = Vector2(340, 34)
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast_label.add_theme_font_size_override("font_size", 18)
    toast_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32))
    root.add_child(toast_label)

    # Center reticle
    var reticle := Label.new()
    reticle.text = "+"
    reticle.anchor_left = 0.5
    reticle.anchor_right = 0.5
    reticle.anchor_top = 0.5
    reticle.anchor_bottom = 0.5
    reticle.position = Vector2(-8, -18)
    reticle.add_theme_font_size_override("font_size", 30)
    reticle.add_theme_color_override("font_color", Color(0.85, 1.0, 0.88, 0.9))
    root.add_child(reticle)

    var fire := _make_action_button(root, "FIRE", Vector2(-138, -160), Vector2(112, 104), true)
    fire.anchor_left = 1.0; fire.anchor_right = 1.0; fire.anchor_top = 1.0; fire.anchor_bottom = 1.0
    fire.button_down.connect(func(): fire_requested = true)
    fire.button_up.connect(func(): fire_requested = false)
    var jump := _make_action_button(root, "JUMP", Vector2(-262, -122), Vector2(100, 70), false)
    jump.anchor_left = 1.0; jump.anchor_right = 1.0; jump.anchor_top = 1.0; jump.anchor_bottom = 1.0
    jump.pressed.connect(_jump)
    var reload := _make_action_button(root, "RELOAD", Vector2(-260, -205), Vector2(98, 54), false)
    reload.anchor_left = 1.0; reload.anchor_right = 1.0; reload.anchor_top = 1.0; reload.anchor_bottom = 1.0
    reload.pressed.connect(_reload)
    var restart := _make_action_button(root, "RESTART", Vector2(-124, 72), Vector2(108, 40), false)
    restart.anchor_left = 1.0; restart.anchor_right = 1.0
    restart.pressed.connect(func(): get_tree().reload_current_scene())

func _panel_style(bg: Color, border_color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border_color
    style.set_border_width_all(1)
    style.set_corner_radius_all(10)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    return style

func _make_action_button(parent: Control, caption: String, pos: Vector2, dimensions: Vector2, primary: bool) -> Button:
    var button := Button.new()
    button.text = caption
    button.position = pos
    button.size = dimensions
    button.add_theme_font_size_override("font_size", 20 if primary else 15)
    var normal_color := Color(0.12, 0.48, 0.39, 0.92) if primary else Color(0.06, 0.10, 0.12, 0.90)
    var edge_color := Color(0.39, 0.94, 0.72, 0.95) if primary else Color(0.36, 0.59, 0.57, 0.8)
    button.add_theme_stylebox_override("normal", _panel_style(normal_color, edge_color))
    button.add_theme_stylebox_override("hover", _panel_style(Color(0.18, 0.58, 0.46, 0.98), edge_color))
    button.add_theme_stylebox_override("pressed", _panel_style(Color(0.04, 0.28, 0.24, 0.98), edge_color))
    button.add_theme_color_override("font_color", Color(0.96, 1.0, 0.98))
    parent.add_child(button)
    return button

func _input(event: InputEvent) -> void:
    var size:=get_viewport().get_visible_rect().size
    if event is InputEventScreenTouch:
        if event.pressed and event.position.x<size.x*0.46:
            move_vec=(event.position-Vector2(105,size.y-115)).limit_length(85)/85.0
        elif not event.pressed: move_vec=Vector2.ZERO
    elif event is InputEventScreenDrag and event.position.x<size.x*0.46:
        move_vec=(event.position-Vector2(105,size.y-115)).limit_length(85)/85.0
    elif event is InputEventKey and event.pressed and event.keycode==KEY_SPACE:
        fire_requested=true

func _process(delta: float) -> void:
    if game_over: return
    elapsed+=delta; fire_cooldown=max(0,fire_cooldown-delta)
    if reload_in_progress:
        reload_time -= delta
        if reload_time <= 0.0:
            var needed := 30 - magazine
            var loaded := min(needed, reserve_ammo)
            magazine += loaded
            reserve_ammo -= loaded
            reload_in_progress = false
            _show_toast("MAGAZINE READY")
    if not is_instance_valid(player): return
    var inp:=move_vec
    if Input.is_key_pressed(KEY_A): inp.x-=1
    if Input.is_key_pressed(KEY_D): inp.x+=1
    if Input.is_key_pressed(KEY_W): inp.y-=1
    if Input.is_key_pressed(KEY_S): inp.y+=1
    var dir:=Vector3(inp.x,0,inp.y).normalized()
    player.velocity.x=dir.x*7.5; player.velocity.z=dir.z*7.5
    if not player.is_on_floor(): player.velocity.y-=22.0*delta
    player.move_and_slide()
    if dir.length()>0.1: player.rotation.y=atan2(-dir.x,-dir.z)
    if (fire_requested or Input.is_key_pressed(KEY_SPACE)) and fire_cooldown<=0:
        _shoot(); fire_cooldown=0.22
    zone_radius=max(14.0,110.0-elapsed*0.45)
    if Vector2(player.position.x,player.position.z).length()>zone_radius:
        health-=delta*8.0
        if int(elapsed/10.0)>zone_stage:
            zone_stage=int(elapsed/10.0)
            if not zone_sound.playing: zone_sound.play()
    health=clamp(health,0,100)
    _update_hud()
    if health<=0:
        health=0
        game_over=true
        status.text="ELIMINATED • PRESS RESTART"
        fire_requested=false
    elif bots.is_empty():
        game_over=true
        status.text="VICTORY • YOU ARE THE LAST SURVIVOR!"
        fire_requested=false

func _shoot() -> void:
    if reload_in_progress:
        return
    if magazine <= 0:
        _show_toast("EMPTY — TAP RELOAD")
        return
    magazine -= 1
    var best: CharacterBody3D=null; var best_dist:=38.0
    var forward: Vector3=-player.global_transform.basis.z
    for b in bots:
        if not is_instance_valid(b) or b.bot_health<=0: continue
        var offset: Vector3=b.global_position-player.global_position; var dist:=offset.length()
        if dist<best_dist and forward.dot(offset.normalized())>0.15:
            best=b; best_dist=dist
    if best:
        if not fire_sound.playing: fire_sound.play()
        best.take_damage(25.0)
        if not hit_sound.playing: hit_sound.play()
        if best.bot_health<=0:
            kills+=1
            bots.erase(best)
            best.queue_free()
            _show_toast("TARGET ELIMINATED  +1")

func _reload() -> void:
    if game_over or reload_in_progress or magazine >= 30 or reserve_ammo <= 0:
        return
    reload_in_progress = true
    reload_time = 1.35
    fire_requested = false
    _show_toast("RELOADING...")

func _show_toast(message: String) -> void:
    if toast_label:
        toast_label.text = message

func player_hit(damage: float) -> void:
    if not game_over:
        health=max(0.0, health-damage)

func _jump() -> void:
    if is_instance_valid(player) and player.is_on_floor() and not game_over:
        player.velocity.y=7.0

func _update_hud() -> void:
    if hud: hud.text="HP %d     KILLS %d     BOTS %d     ZONE %dm" % [int(health),kills,bots.size(),int(zone_radius)]
    if hpbar: hpbar.value=health
    if ammo_label:
        ammo_label.text = ("RELOADING..." if reload_in_progress else "AMMO  %02d / %03d" % [magazine, reserve_ammo])
