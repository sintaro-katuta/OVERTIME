extends VBoxContainer
const Design = preload("res://gameplay/ui/interface_theme.gd")
const Catalog = preload("res://gameplay/skills/skill_catalog.gd")
const PREVIEW_DIRECTORY := "res://assets/skill_previews/"
var main: Node
var focused_skill := "grapple"
var message := ""
var name_buttons: Dictionary = {}
var equip_buttons: Array[Button] = []
var detail_title: Label
var detail_description: Label
var cooldown_label: Label
var status_label: Label
var pause_button: Button
var video: VideoStreamPlayer
var video_frame: AspectRatioContainer

func setup(host: Node) -> void:
	main = host
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not main.skills.selected[0].is_empty(): focused_skill = main.skills.selected[0]
	build()
	show_skill(focused_skill)

func build() -> void:
	add_theme_constant_override("separation", 12)
	Design.text(self, "出撃スキル", 25)
	var body := HBoxContainer.new()
	body.name = "SkillBrowser"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	add_child(body)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 260
	list.add_theme_constant_override("separation", 8)
	body.add_child(list)
	for id in Catalog.IDS:
		var button := Button.new()
		button.text = Catalog.DATA[id].name
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 52
		button.add_theme_font_size_override("font_size", 19)
		button.pressed.connect(show_skill.bind(id))
		list.add_child(button)
		name_buttons[id] = button

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Design.plate(Color("142329ec"), Color("344b4f"), 1, 16))
	body.add_child(panel)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	panel.add_child(detail)
	var heading := HBoxContainer.new()
	detail.add_child(heading)
	detail_title = Design.text(heading, "", 24)
	detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cooldown_label = Design.text(heading, "", 14, Design.MUTED)
	cooldown_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	detail_description = Design.text(detail, "", 16, Design.MUTED)
	detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	video_frame = AspectRatioContainer.new()
	video_frame.ratio = 16.0 / 9.0
	video_frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
	video_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	video_frame.custom_minimum_size.y = 160
	detail.add_child(video_frame)
	var background := ColorRect.new()
	background.color = Color("09151c")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_frame.add_child(background)
	video = VideoStreamPlayer.new()
	video.name = "SkillVideo"
	video.expand = true
	video.loop = true
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_frame.add_child(video)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	detail.add_child(actions)
	var caption := Design.text(actions, "実際の挙動", 14, Design.MUTED)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pause_button = Button.new()
	pause_button.text = "一時停止"
	pause_button.pressed.connect(toggle_preview)
	actions.add_child(pause_button)
	for slot in 2:
		var button := Button.new()
		button.custom_minimum_size.y = 38
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Design.primary(button)
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(equip_skill.bind(slot))
		actions.add_child(button)
		equip_buttons.append(button)

	var footer := HBoxContainer.new()
	add_child(footer)
	status_label = Design.text(footer, "", 14, Design.ACCENT)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var back := Button.new()
	back.text = "出撃準備へ →"
	back.pressed.connect(main.select_preparation_tab.bind("play"))
	footer.add_child(back)

func show_skill(id: String) -> void:
	if not Catalog.DATA.has(id): return
	focused_skill = id
	var data: Dictionary = Catalog.DATA[id]
	detail_title.text = data.name
	detail_title.add_theme_color_override("font_color", data.color)
	detail_description.text = data.description
	cooldown_label.text = "再使用まで %.1f秒" % data.cooldown
	for skill_id in name_buttons:
		var button: Button = name_buttons[skill_id]
		button.add_theme_stylebox_override("normal", Design.plate(Color("294441") if skill_id == id else Color("17282e"), data.color if skill_id == id else Color("30464a"), 1, 16))
		button.add_theme_color_override("font_color", data.color if skill_id == id else Design.TEXT)
	video.stop()
	video.stream = load(PREVIEW_DIRECTORY + id + ".ogv") as VideoStream
	video.paused = false
	video.play()
	pause_button.text = "一時停止"
	refresh_equipment()

func refresh_equipment() -> void:
	for slot in 2:
		var id: String = main.skills.selected[slot]
		var key: String = main.control_settings.key_name("grapple" if slot == 0 else "skill_2")
		var current: bool = id == focused_skill
		var other: bool = main.skills.selected[1-slot] == focused_skill
		var button := equip_buttons[slot]
		button.text = "%s 装備中 · 外す" % key if current else "%s に装備" % key
		button.disabled = other
		button.tooltip_text = "同じスキルは2枠に装備できません" if other else "%s から外す" % key if current else "%s の %s と入れ替え" % [key, Catalog.DATA[id].name] if not id.is_empty() else "%s に装備" % key
		button.add_theme_stylebox_override("normal", Design.plate(Color("294441") if current else Design.ACCENT, Design.ACCENT))
		button.add_theme_color_override("font_color", Design.ACCENT if current else Color("10292b"))
	status_label.text = message if not message.is_empty() else "装備完了 — 出撃できます" if main.skills.valid_selection() else "異なるスキルを2個装備してください。出撃後の変更はできません。"

func toggle_preview() -> void:
	video.paused = not video.paused
	pause_button.text = "再生" if video.paused else "一時停止"

func equip_skill(slot: int) -> void:
	var id := "" if main.skills.selected[slot] == focused_skill else focused_skill
	var result: Error = main.skills.select_skill(slot, id)
	message = "保存できませんでした。現在の装備は反映されています。" if result != OK else ""
	refresh_equipment()

func _exit_tree() -> void:
	if is_instance_valid(video): video.stop()
