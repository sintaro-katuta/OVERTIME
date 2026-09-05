extends CanvasLayer

signal retry_requested
signal preparation_requested

var title_label: Label
var detail_label: Label
var retry_button: Button
var preparation_button: Button

func _ready() -> void:
	layer = 3
	visible = false
	var overlay := ColorRect.new()
	overlay.color = Color("080e18ed")
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var layout := VBoxContainer.new()
	layout.custom_minimum_size = Vector2(420, 0)
	layout.add_theme_constant_override("separation", 24)
	center.add_child(layout)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color("72a6a0"))
	layout.add_child(title_label)
	detail_label = Label.new()
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(detail_label)
	retry_button = Button.new()
	retry_button.text = "リトライ  ［R］"
	retry_button.custom_minimum_size.y = 60
	retry_button.pressed.connect(func(): retry_requested.emit())
	layout.add_child(retry_button)
	preparation_button = Button.new()
	preparation_button.text = "ゲーム開始準備へ戻る"
	preparation_button.custom_minimum_size.y = 60
	preparation_button.pressed.connect(func(): preparation_requested.emit())
	layout.add_child(preparation_button)

func show_result(title: String, detail: String) -> void:
	title_label.text = title
	detail_label.text = detail
	visible = true
	retry_button.grab_focus()
