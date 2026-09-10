extends RefCounted
## Reusable authored geometry for skill effects. No world lights or shadows.
static func material(color: Color, alpha := 1.0, metal := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color=Color(color,alpha); m.emission_enabled=not metal; m.emission=color; m.emission_energy_multiplier=1.3
	m.shading_mode=BaseMaterial3D.SHADING_MODE_PER_PIXEL if metal else BaseMaterial3D.SHADING_MODE_UNSHADED
	m.metallic=.7 if metal else 0; m.roughness=.32
	m.cull_mode=BaseMaterial3D.CULL_DISABLED
	if alpha<1: m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
static func mesh(parent: Node3D, shape: Mesh, mat: Material) -> MeshInstance3D:
	var n:=MeshInstance3D.new(); n.mesh=shape; n.material_override=mat; n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; parent.add_child(n); return n
static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var shape:=BoxMesh.new(); shape.size=size; var n:=mesh(parent,shape,mat); n.position=pos; return n
static func sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var shape:=SphereMesh.new(); shape.radius=radius; shape.height=radius*2; shape.radial_segments=24; shape.rings=12
	var n:=mesh(parent,shape,mat); n.position=pos; return n
static func ring(parent: Node3D, radius: float, width: float, mat: Material) -> MeshInstance3D:
	var shape:=TorusMesh.new(); shape.inner_radius=maxf(.001,radius-width); shape.outer_radius=radius+width; shape.rings=64; shape.ring_segments=6
	return mesh(parent,shape,mat)
static func line(parent: Node3D, a: Vector3, b: Vector3, width: float, mat: Material) -> MeshInstance3D:
	var n:=box(parent,(a+b)*.5,Vector3(width,width,a.distance_to(b)),mat)
	if a.distance_to(b)>.0001: n.quaternion=Quaternion(Vector3.BACK,(b-a).normalized())
	return n
static func polygon(parent: Node3D, points: PackedVector3Array, width: float, mat: Material) -> void:
	var shape:=ImmediateMesh.new();shape.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size():
		var a:=points[i];var b:=points[(i+1)%points.size()]
		var offset:=(b-a).normalized().cross(Vector3.BACK)*width*.5
		var vertices:=[a-offset,a+offset,b-offset,b+offset]
		for k in [0,2,1,1,2,3]:shape.surface_add_vertex(vertices[k])
	shape.surface_end();mesh(parent,shape,mat)
static func hexagon(parent: Node3D, center: Vector3, radius: float, width: float, mat: Material) -> void:
	var points:=PackedVector3Array()
	for i in 6: points.append(center+Vector3(cos(i*TAU/6),sin(i*TAU/6),0)*radius)
	polygon(parent,points,width,mat)
static func spiral(parent: Node3D, arm: int, mat: Material) -> MeshInstance3D:
	var shape:=ImmediateMesh.new(); shape.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 96:
		var vertices:Array[Vector3]=[]
		for j in 2:
			var t:=float(i+j)/96; var r:=.55+t*5.5; var angle:=arm*TAU/3+t*TAU*.95
			var width:=.035+sin(t*PI)*.22
			for side in [-1,1]: vertices.append(Vector3(cos(angle)*(r+width*side),sin(angle)*(r+width*side),sin(t*PI)*.2))
		for k in [0,2,1,1,2,3]:
			shape.surface_set_color(Color(1,1,1,.25+.5*sin(float(i)/96*PI))); shape.surface_add_vertex(vertices[k])
	shape.surface_end()
	return mesh(parent,shape,mat)
static func silhouette(parent: Node3D, mat: Material) -> void:
	# Helmet, chest armor, shoulders, bent arms, pelvis and staggered legs.
	sphere(parent,Vector3(0,.68,0),.17,mat)
	box(parent,Vector3(0,.27,0),Vector3(.43,.5,.24),mat)
	box(parent,Vector3(0,-.08,0),Vector3(.32,.18,.22),mat)
	for side in [-1,1]:
		box(parent,Vector3(side*.29,.37,0),Vector3(.17,.2,.25),mat)
		line(parent,Vector3(side*.29,.3,0),Vector3(side*.32,.04,-.13),.13,mat)
		line(parent,Vector3(side*.32,.04,-.13),Vector3(side*.15,.12,-.38),.11,mat)
		line(parent,Vector3(side*.11,-.12,0),Vector3(side*.15,-.45,side*.10),.16,mat)
		line(parent,Vector3(side*.15,-.45,side*.10),Vector3(side*.16,-.78,side*.18),.13,mat)
		box(parent,Vector3(side*.16,-.79,side*.18-.06),Vector3(.16,.1,.28),mat)
static func dome_material(color: Color) -> ShaderMaterial:
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color;
uniform float clock = 0.0;
void fragment(){
 float rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),3.0);
 float latitude=1.0-smoothstep(0.0,0.0015,abs(UV.y-0.5));
 float sweep=pow(max(0.0,sin(UV.y*9.0-clock*1.7)),22.0);
 ALBEDO=tint.rgb; EMISSION=tint.rgb*0.6;
 ALPHA=0.018+rim*0.28+latitude*0.1+sweep*rim*0.12;
}"""
	var mat:=ShaderMaterial.new(); mat.shader=shader; mat.set_shader_parameter("tint",color); return mat

const SHIELD_HALF := Vector2(1.6,.95)
const SHIELD_RADIUS := .3
const SHIELD_DISTANCE := 1.65
static func shield_contains(point:Vector2) -> bool:
	var q:=point.abs()-(SHIELD_HALF-Vector2.ONE*SHIELD_RADIUS)
	return q.max(Vector2.ZERO).length()+minf(maxf(q.x,q.y),0)-SHIELD_RADIUS<=0

static func shield_material() -> ShaderMaterial:
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float clock=0.0;
uniform vec2 impact_point=vec2(0.0);
uniform float impact_age=10.0;
void fragment(){
 vec2 p=vec2((UV.x-.5)*3.2,(.5-UV.y)*1.9);
 vec2 q=abs(p)-vec2(1.3,.65);
 float d=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-.3;
 if(d>0.0){discard;}
 float rim=exp(d*30.0);
 float broad=exp(d*7.0);
 float flow=pow(.5+.5*sin(p.y*16.0+p.x*3.0-clock*1.4),12.0);
 float dist=length(p-impact_point);
 float hit=exp(-abs(dist-impact_age*2.2)*28.0)*max(0.0,1.0-impact_age*1.7);
 vec3 blue=mix(vec3(.075,.28,.7),vec3(.42,.89,1.0),clamp(rim+hit,0.0,1.0));
 ALBEDO=blue;EMISSION=blue*(.2+rim*.8+hit);
 ALPHA=clamp(.26+broad*.12+rim*.46+flow*.025+hit*.4,0.0,.88);
}"""
	var mat:=ShaderMaterial.new();mat.shader=shader;return mat
