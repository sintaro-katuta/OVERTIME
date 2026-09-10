extends RefCounted
const DURATION:=.85
const START_SPEED:=13.0
const FRICTION:=10.0
var active:=false
var low:=false
var remaining:=0.0
var heading:=Vector3.ZERO
var speed:=0.0
var body:CharacterBody3D
var collider:CollisionShape3D
var camera:Camera3D
func setup(p:CharacterBody3D,c:Camera3D) -> void:
	body=p;camera=c
	for child in body.get_children():
		if child is CollisionShape3D:collider=child;break
	collider.shape=collider.shape.duplicate()
	if not InputMap.has_action("slide"):
		InputMap.add_action("slide")
		for key in [KEY_SHIFT]:
			var event:=InputEventKey.new();event.physical_keycode=key;InputMap.action_add_event("slide",event)
func start() -> bool:
	var horizontal:=Vector3(body.velocity.x,0,body.velocity.z)
	if active or low or not body.is_on_floor() or horizontal.length()<5.5:return false
	heading=horizontal.normalized();speed=clampf(horizontal.length()+5,START_SPEED,18);remaining=DURATION;active=true;low=true
	collider.shape.height=1.0;collider.position.y=-.35
	return true
func can_stand() -> bool:
	var shape:=CapsuleShape3D.new();shape.radius=.42;shape.height=1.7
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform=body.global_transform;query.transform.origin+=Vector3(0,.025,0);query.collision_mask=body.collision_mask;query.exclude=[body.get_rid()]
	return body.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func stop() -> void:
	active=false
func reset() -> void:
	active=false;low=false;remaining=0
	collider.shape.height=1.7;collider.position.y=0;camera.position.y=.6
func tick(delta:float) -> void:
	if active:
		remaining-=delta
		speed=maxf(0,speed-FRICTION*delta)
		if remaining<=0 or speed<5 or not body.is_on_floor():stop()
	if low and not active and can_stand():
		low=false;collider.shape.height=1.7;collider.position.y=0
	camera.position.y=move_toward(camera.position.y,-.12 if low else .6,delta*5)
func move_slide() -> void:
	body.velocity.x=heading.x*speed;body.velocity.z=heading.z*speed
	if body.is_on_floor():
		var downhill:=Vector3.DOWN.slide(body.get_floor_normal())
		body.velocity.x+=downhill.x*1.5;body.velocity.z+=downhill.z*1.5
func after_move() -> void:
	if active and (body.is_on_wall() or Vector2(body.velocity.x,body.velocity.z).length()<2):stop()
