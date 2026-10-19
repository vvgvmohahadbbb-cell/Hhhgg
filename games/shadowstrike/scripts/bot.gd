extends CharacterBody3D
var world: Node
var target: CharacterBody3D
var bot_health := 100.0
var attack_clock := 0.0
var strafe_sign := 1.0

func setup(w: Node, p: CharacterBody3D, outfit: Color) -> void:
    world=w; target=p
    var torso:=MeshInstance3D.new(); var cap:=CapsuleMesh.new(); cap.radius=0.42; cap.height=1.15
    torso.mesh=cap; torso.position.y=1.04
    var mat:=StandardMaterial3D.new(); mat.albedo_color=outfit; mat.roughness=0.8; torso.material_override=mat; add_child(torso)
    var head:=MeshInstance3D.new(); var sp:=SphereMesh.new(); sp.radius=0.27; sp.height=0.54; head.mesh=sp; head.position.y=1.82
    var skin:=StandardMaterial3D.new(); skin.albedo_color=Color(0.72,0.55,0.42); head.material_override=skin; add_child(head)
    var vest:=MeshInstance3D.new(); var vb:=BoxMesh.new(); vb.size=Vector3(0.62,0.6,0.32); vest.mesh=vb; vest.position=Vector3(0,1.1,-0.02)
    var vm:=StandardMaterial3D.new(); vm.albedo_color=Color(0.1,0.14,0.11); vest.material_override=vm; add_child(vest)
    var col:=CollisionShape3D.new(); var cs:=CapsuleShape3D.new(); cs.radius=0.4; cs.height=1.9; col.shape=cs; col.position.y=0.95; add_child(col)
    strafe_sign=[-1.0,1.0][randi()%2]

func _physics_process(delta: float) -> void:
    if bot_health<=0 or not is_instance_valid(target): return
    var offset:Vector3=target.global_position-global_position
    var dist:=offset.length(); attack_clock-=delta
    if dist>3.5:
        var dir:=offset.normalized()
        if dist<18: dir=(dir+Vector3(-dir.z,0,dir.x)*strafe_sign*0.12).normalized()
        velocity.x=dir.x*(3.0 if dist<25 else 2.3); velocity.z=dir.z*(3.0 if dist<25 else 2.3)
        if not is_on_floor(): velocity.y-=20.0*delta
        move_and_slide(); rotation.y=atan2(-dir.x,-dir.z)
    else:
        velocity.x=0; velocity.z=0
        if attack_clock<=0:
            world.player_hit(4.0); attack_clock=0.9

func take_damage(amount: float) -> void:
    bot_health-=amount
    if bot_health<=0:
        queue_free()
