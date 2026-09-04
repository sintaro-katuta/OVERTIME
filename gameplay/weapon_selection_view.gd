## Selection-only presentation for the preparation screen (Issue #4).
class_name WeaponSelectionView
extends HBoxContainer

signal custom_requested(weapon_id: String)
signal launch_requested

const WeaponCatalogData = preload("res://gameplay/weapon_catalog.gd")
const ProgressionConfigData = preload("res://gameplay/progression_config.gd")
const PREVIEW_SPAN := 3.40

var progression: RefCounted
var focused_weapon_id := "vanguard_556"
var preview: WeaponPreview

func setup(state: RefCounted) -> void:
	progression = state
	var saved_id := str(progression.preparation_view().selected_weapon_id)
	if not saved_id.is_empty():
		focused_weapon_id = saved_id
	refresh()

func _ready() -> void:
	add_theme_constant_override("separation", 20)

func _refresh_requested() -> void:
	refresh()

func refresh() -> void:
	if not is_node_ready() or progression == null:
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var view: Dictionary = progression.preparation_view()
	var weapon_data := WeaponCatalogData.weapon(focused_weapon_id)
	var weapon_state: Dictionary = progression.weapon_progress(focused_weapon_id)
	var selected_skin_id: String = progression.selected_skin_id_for(focused_weapon_id)
	var selected_skin := WeaponCatalogData.skin(focused_weapon_id, selected_skin_id)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(460, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	add_child(left)
	var heading := _label("出撃武器", 25, Color("72a6a0"))
	left.add_child(heading)
	preview = WeaponPreview.new()
	preview.weapon_name = str(weapon_data.display_name)
	preview.weapon_id = focused_weapon_id
	preview.model_path = str(selected_skin.get("model_path", weapon_data.model_path))
	preview.custom_minimum_size = Vector2(0, 120)
	left.add_child(preview)
	var level := int(weapon_state.level)
	var xp := int(weapon_state.xp)
	var xp_text := "Lv.%02d  ／  XP %d / %d" % [level, xp, ProgressionConfigData.weapon_xp_required(level)]
	if level >= ProgressionConfigData.WEAPON_LEVEL_CAP:
		xp_text = "Lv.%02d  ／  MAX LEVEL" % level
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 14)
	left.add_child(name_row)
	var name_label := _label(str(weapon_data.display_name), 24, Color("eef8ff"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_label)
	var progress_label := _label(xp_text, 16, Color("d7e6ff"))
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(progress_label)
	var status_label := _label("%s  ／  %s" % [_fire_mode_label(str(weapon_data.fire_mode)), "解放済み" if bool(weapon_state.unlocked) else "ロック中"], 16, Color("72a6a0") if bool(weapon_state.unlocked) else Color("c7d2e0"))
	left.add_child(status_label)
	var progress_bar := ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(0, 18)
	progress_bar.max_value = 1.0 if level >= ProgressionConfigData.WEAPON_LEVEL_CAP else maxf(1.0, ProgressionConfigData.weapon_xp_required(level))
	progress_bar.value = progress_bar.max_value if level >= ProgressionConfigData.WEAPON_LEVEL_CAP else xp
	left.add_child(progress_bar)
	var radar := RadarChart.new()
	radar.stats = _performance_values(weapon_data)
	radar.custom_minimum_size = Vector2(0, 126)
	left.add_child(radar)
	var attachments := _label("アタッチメント  ／  解放 %d / 50　装備 %d / 3" % [
		(progression.unlocked_attachment_ids(focused_weapon_id) as Array).size(),
		(weapon_state.equipped_attachment_ids as Array).size(),
	], 16, Color("c7d2e0"))
	left.add_child(attachments)
	var skin_name := "標準外観" if selected_skin.is_empty() else str(selected_skin.display_name)
	var skin_label := _label("スキン  ／  %s" % skin_name, 16, Color("c7d2e0"))
	left.add_child(skin_label)
	var available_skins: Array[String] = progression.available_skin_ids(focused_weapon_id)
	if available_skins.size() > 1:
		var skin_button := Button.new()
		skin_button.text = "スキンを切替"
		skin_button.custom_minimum_size = Vector2(190, 38)
		skin_button.pressed.connect(_cycle_skin)
		left.add_child(skin_button)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	left.add_child(action_row)
	var equip := Button.new()
	equip.text = "出撃武器に設定" if bool(weapon_state.unlocked) else "ロック中"
	equip.disabled = not bool(weapon_state.unlocked)
	equip.custom_minimum_size = Vector2(190, 44)
	equip.pressed.connect(_equip_focused)
	action_row.add_child(equip)
	var custom := Button.new()
	custom.text = "アタッチメント編集"
	custom.disabled = not bool(weapon_state.unlocked)
	custom.custom_minimum_size = Vector2(190, 44)
	custom.pressed.connect(custom_requested.emit.bind(focused_weapon_id))
	action_row.add_child(custom)
	var launch := Button.new()
	launch.text = "出撃"
	launch.disabled = str(view.selected_weapon_id).is_empty()
	launch.custom_minimum_size = Vector2(150, 44)
	launch.pressed.connect(launch_requested.emit)
	action_row.add_child(launch)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(370, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 5)
	add_child(right)
	right.add_child(_label("武器一覧  ／  9", 25, Color("72a6a0")))
	for data in view.weapons:
		var state: Dictionary = data.progress
		var item := Button.new()
		var unlocked_state := bool(state.unlocked)
		var marker := " ✓" if str(view.selected_weapon_id) == str(data.id) else ""
		item.text = ("%s  Lv.%02d%s" % [str(data.display_name), int(state.level), marker]) if unlocked_state else "LOCK  %s" % str(data.display_name)
		item.disabled = not unlocked_state
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.custom_minimum_size = Vector2(0, 34)
		item.pressed.connect(_focus_weapon.bind(str(data.id)))
		right.add_child(item)

func _focus_weapon(weapon_id: String) -> void:
	focused_weapon_id = weapon_id
	refresh()

func _equip_focused() -> void:
	if progression.select_weapon(focused_weapon_id):
		progression.save_to_file()
		refresh()

func _cycle_skin() -> void:
	var skins: Array[String] = progression.available_skin_ids(focused_weapon_id)
	var current: String = progression.selected_skin_id_for(focused_weapon_id)
	var next_index := (skins.find(current) + 1) % skins.size()
	if progression.select_skin(focused_weapon_id, skins[next_index]):
		progression.save_to_file()
		refresh()

func _performance_values(data: Dictionary) -> Array[float]:
	var recoil_scores := {"small": 0.90, "baseline_vertical": 0.72, "burst_recovery": 0.68, "strong_vertical_horizontal": 0.45, "large_single": 0.40, "very_large_single": 0.28, "pump_recovery": 0.56}
	var reload_seconds := float(data.reload.seconds)
	return [
		clampf(float(data.damage.body) / 100.0, 0.0, 1.0),
		clampf(float(data.fire_rate.shots_per_second) / 20.0, 0.0, 1.0),
		clampf(float(data.magazine.capacity) / 20.0, 0.0, 1.0),
		float(recoil_scores.get(str(data.recoil.profile), 0.50)),
		clampf(1.0 - (reload_seconds - 0.55) / 1.65, 0.0, 1.0),
	]

func _fire_mode_label(fire_mode: String) -> String:
	return {"full_auto": "フルオート", "semi_auto": "セミオート", "burst": "3点バースト", "bolt_action": "ボルトアクション", "pump_action": "ポンプアクション"}.get(fire_mode, fire_mode)

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text_value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result

class WeaponPreview extends SubViewportContainer:
	var weapon_name := ""
	var weapon_id := ""
	var model_path := ""
	var turntable: Node3D
	func _ready() -> void:
		stretch = true
		var viewport := SubViewport.new()
		viewport.size = Vector2i(640, 280)
		viewport.own_world_3d = true
		# The preview is intentionally isolated from the playable stage behind the menu.
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color("08111c")
		var world_environment := WorldEnvironment.new()
		world_environment.environment = environment
		viewport.add_child(world_environment)
		turntable = Node3D.new()
		viewport.add_child(turntable)
		var camera := Camera3D.new()
		# A close orthographic-like product shot: the shared 3.40-unit span fills
		# the preview rather than appearing as a distant object.
		camera.position = Vector3(0, 0, 1.8)
		camera.current = true
		viewport.add_child(camera)
		var key_light := DirectionalLight3D.new()
		key_light.light_energy = 1.8
		key_light.rotation_degrees = Vector3(-35, -30, 0)
		viewport.add_child(key_light)
		var rim_light := OmniLight3D.new()
		rim_light.light_color = Color("72a6a0")
		rim_light.light_energy = 2.4
		rim_light.omni_range = 6.0
		rim_light.position = Vector3(-1.5, 1.2, 2.0)
		viewport.add_child(rim_light)
		var scene := load(model_path) as PackedScene
		if scene == null:
			return
		var model := scene.instantiate() as Node3D
		if model == null:
			return
		# Vanguard is authored along Z; the other source packs use X as their barrel
		# axis. Their 180° yaw keeps that axis horizontal and puts the muzzle left.
		model.rotation_degrees = Vector3(0, 90, 0) if weapon_id == "vanguard_556" else Vector3(0, 180, 0)
		turntable.add_child(model)
		call_deferred("_fit_model", model)
	func _fit_model(model: Node3D) -> void:
		var bounds := _model_bounds(model)
		var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		if longest <= 0.0001:
			return
		# Every source model is centered and scaled to the same turntable span.
		var scale_factor := PREVIEW_SPAN / longest
		model.scale = Vector3.ONE * scale_factor
		model.position = -bounds.get_center() * scale_factor

	func _model_bounds(node: Node, parent_transform := Transform3D.IDENTITY) -> AABB:
		var transform := parent_transform
		if node is Node3D:
			transform = parent_transform * (node as Node3D).transform
		var has_bounds := false
		var result := AABB()
		if node is MeshInstance3D:
			result = transform * (node as MeshInstance3D).get_aabb()
			has_bounds = true
		for child in node.get_children():
			if not child is Node3D:
				continue
			var child_bounds := _model_bounds(child, transform)
			if child_bounds.size.length_squared() <= 0.000001:
				continue
			result = result.merge(child_bounds) if has_bounds else child_bounds
			has_bounds = true
		return result

class RadarChart extends Control:
	var stats: Array[float] = []
	const LABELS := ["ダメージ", "連射速度", "弾倉", "反動", "リロード"]
	func _ready() -> void:
		queue_redraw()
	func _draw() -> void:
		if stats.size() != 5:
			return
		var center := Vector2(size.x * 0.5, size.y * 0.52)
		var radius := minf(size.y * 0.34, size.x * 0.18)
		for step in [0.33, 0.66, 1.0]:
			var ring := PackedVector2Array()
			for index in 5:
				ring.append(_point(center, radius * step, index))
			draw_polyline(ring + PackedVector2Array([ring[0]]), Color("294657"), 1.0, true)
		var values := PackedVector2Array()
		for index in 5:
			var edge := _point(center, radius, index)
			draw_line(center, edge, Color("294657"), 1.0, true)
			values.append(_point(center, radius * stats[index], index))
		draw_colored_polygon(values, Color("72a6a066"))
		draw_polyline(values + PackedVector2Array([values[0]]), Color("8ed6ce"), 2.0, true)
		var font := ThemeDB.fallback_font
		for index in 5:
			var label_position := _point(center, radius + 20.0, index) - Vector2(30, -4)
			draw_string(font, label_position, LABELS[index], HORIZONTAL_ALIGNMENT_CENTER, 60.0, 12, Color("c7d2e0"))
	func _point(center: Vector2, distance: float, index: int) -> Vector2:
		var angle := -PI * 0.5 + TAU * float(index) / 5.0
		return center + Vector2(cos(angle), sin(angle)) * distance
