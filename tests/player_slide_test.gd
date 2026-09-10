extends SceneTree
const Slide=preload("res://gameplay/player_slide.gd")
var body:CharacterBody3D
var slide
func _init() -> void:call_deferred("run")
func box(p:Vector3,size:Vector3) -> StaticBody3D:
	var b:=StaticBody3D.new();root.add_child(b);b.position=p;var c:=CollisionShape3D.new();var s:=BoxShape3D.new();s.size=size;c.shape=s;b.add_child(c);return b
func step(count:int) -> void:
	for i in count:
		await physics_frame;slide.tick(1.0/60)
		if slide.active:slide.move_slide()
		else:body.velocity.x=0;body.velocity.z=0
		body.velocity.y-=22.0/60;body.move_and_slide();slide.after_move()
func run() -> void:
	box(Vector3(0,-.5,0),Vector3(100,1,100))
	body=CharacterBody3D.new();body.collision_layer=8;body.collision_mask=1;body.floor_snap_length=.65;root.add_child(body);body.position=Vector3(0,.86,0)
	var collider:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.42;capsule.height=1.7;collider.shape=capsule;body.add_child(collider)
	var camera:=Camera3D.new();body.add_child(camera);slide=Slide.new();slide.setup(body,camera)
	await step(10);assert(body.is_on_floor());assert(not slide.start(),"stationary start rejected")
	body.velocity=Vector3(0,0,-8);assert(slide.start());var initial:=body.position
	await step(12);assert(slide.active and slide.low);assert(body.position.distance_to(initial)>1.5);assert(camera.position.y<.1)
	var ceiling:=box(body.position+Vector3(0,.55,0),Vector3(8,.3,8))
	slide.stop();await step(4);assert(slide.low and not slide.can_stand(),"cannot expand through ceiling");assert(not slide.start())
	ceiling.free();await step(4);assert(not slide.low)
	body.velocity=Vector3(8,0,0);assert(slide.start(),"restart immediately after ceiling clears without cooldown");await step(65);assert(not slide.active and not slide.low)
	body.velocity=Vector3(8,0,0);assert(slide.start(),"restart immediately after natural end without cooldown")
	slide.stop();await step(1);body.velocity=Vector3(8,0,0);assert(slide.start(),"restart one frame after cancellation without cooldown")
	slide.stop()
	await step(70);body.position=Vector3(0,4,0);await step(1);body.velocity.x=8;assert(not slide.start(),"air start rejected")
	body.position=Vector3(0,.86,0);await step(15);body.velocity=Vector3(8,0,0);assert(slide.start())
	box(body.position+Vector3(1.2,1,0),Vector3(.3,3,8));await step(15);assert(not slide.active,"wall cancels slide")
	slide.reset();assert(not slide.low and is_equal_approx(camera.position.y,.6))
	var ramp:=box(Vector3(-20,1,0),Vector3(14,.4,8));ramp.rotation.z=.18
	body.position=Vector3(-20,2.2,0);body.velocity=Vector3.ZERO;await step(20)
	assert(body.is_on_floor());body.velocity=Vector3(8,0,0);assert(slide.start());await step(12)
	assert(body.is_on_floor() and slide.active,"uphill stays grounded")
	slide.reset();body.velocity=Vector3(-8,0,0);assert(slide.start());await step(12)
	assert(body.is_on_floor() and slide.active,"downhill stays grounded")
	print("PASS: slide start, motion, low ceiling, immediate restart, air, wall, reset, slopes");quit()
