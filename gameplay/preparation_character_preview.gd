extends SubViewportContainer
## Isolated studio for the preparation screen's original operator model.
var turntable:Node3D
var elapsed:=0.0
func _ready() -> void:
	name="PreparationCharacterPreview"
	stretch=true
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var viewport:=SubViewport.new();viewport.size=Vector2i(420,300);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE;add_child(viewport)
	var world:=WorldEnvironment.new();var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("0d1724");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("b1c7d0");environment.ambient_light_energy=.7;world.environment=environment;viewport.add_child(world)
	turntable=Node3D.new();viewport.add_child(turntable)
	var model:Node3D=preload("res://assets/player_operator/operator.glb").instantiate();turntable.add_child(model)
	var camera:=Camera3D.new();viewport.add_child(camera);camera.position=Vector3(0,1.15,4);camera.look_at(Vector3(0,.96,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.08;camera.current=true
	var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-35,-35,0);key.light_energy=2;viewport.add_child(key)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-15,130,0);fill.light_color=Color("7fbfc3");fill.light_energy=1.1;viewport.add_child(fill)
	var platform:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.top_radius=.54;cylinder.bottom_radius=.58;cylinder.height=.05;cylinder.radial_segments=48;platform.mesh=cylinder;platform.position.y=-.035
	var material:=StandardMaterial3D.new();material.albedo_color=Color("263a46");material.metallic=.4;platform.material_override=material;viewport.add_child(platform)
func _process(delta:float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(turntable):return
	elapsed+=delta;turntable.rotation.y=.22+sin(elapsed*.35)*.18
