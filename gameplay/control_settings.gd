extends RefCounted
signal volume_changed
const ACTIONS={"move_forward":"前進","move_back":"後退","move_left":"左移動","move_right":"右移動","jump":"ジャンプ","slide":"スライディング","dash":"ダッシュ","reload":"リロード","grapple":"スキル1発動","skill_2":"スキル2発動","shoot":"射撃","aim":"照準"}
const DEFAULTS={"move_forward":KEY_W,"move_back":KEY_S,"move_left":KEY_A,"move_right":KEY_D,"jump":KEY_SPACE,"slide":KEY_SHIFT,"dash":KEY_CTRL,"reload":KEY_R,"grapple":KEY_Q,"skill_2":KEY_E,"shoot":-MOUSE_BUTTON_LEFT,"aim":-MOUSE_BUTTON_RIGHT}
var bindings:Dictionary=DEFAULTS.duplicate()
var sensitivity:=1.0
var automatic_reload:=true
var master_volume: float = 1.0:
	set(value):
		master_volume = volume_value(value)
		volume_changed.emit()
var effects_volume: float = 1.0:
	set(value):
		effects_volume = volume_value(value)
		volume_changed.emit()

static func volume_value(value: Variant) -> float:
	if (value is float or value is int) and is_finite(float(value)):
		return clampf(float(value), 0.0, 1.0)
	return 1.0

var path:="user://controls.cfg"
func key_name(action:String) -> String:
	var code:int=bindings[action]
	if code<0:return {1:"マウス左",2:"マウス右",3:"マウス中"}.get(-code,"マウス %d"%-code)
	return OS.get_keycode_string(code)
func assign(action:String,code:int) -> String:
	if not ACTIONS.has(action) or code==0 or code==KEY_ESCAPE:return "Escは取消・ポーズ用です"
	for other in bindings:
		if other!=action and bindings[other]==code:return "「%s」で使用中です"%ACTIONS[other]
	bindings[action]=code;apply();return ""
func apply() -> void:
	for action in bindings:
		if not InputMap.has_action(action):InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var code:int=bindings[action]
		if code>0:
			var event:=InputEventKey.new();event.physical_keycode=code;InputMap.action_add_event(action,event)
		else:
			var event:=InputEventMouseButton.new();event.button_index=-code;InputMap.action_add_event(action,event)
func reset() -> void:
	bindings=DEFAULTS.duplicate();sensitivity=1.0;automatic_reload=true;master_volume=1.0;effects_volume=1.0;apply()
func save() -> Error:
	var config:=ConfigFile.new();config.set_value("controls","bindings",bindings);config.set_value("controls","sensitivity",sensitivity);config.set_value("controls","automatic_reload",automatic_reload)
	config.set_value("audio","master_volume",master_volume)
	config.set_value("audio","effects_volume",effects_volume)
	return config.save(path)
func load_settings() -> void:
	var config:=ConfigFile.new()
	if config.load(path)==OK:
		var stored=config.get_value("controls","bindings",{})
		if stored is Dictionary:
			# Preserve old remaps when the new E default is already in use.
			if not stored.has("skill_2"):
				stored = stored.duplicate()
				for fallback in [KEY_E, KEY_Q, KEY_F, KEY_G, KEY_T, KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N, KEY_M]:
					if not stored.values().has(fallback):
						stored["skill_2"] = fallback
						break
			var candidate:Dictionary={};var used:Array[int]=[];var valid:=true
			for action in DEFAULTS:
				var code=stored.get(action,DEFAULTS[action])
				if not code is int or code==0 or code==KEY_ESCAPE or used.has(code):valid=false;break
				candidate[action]=code;used.append(code)
			if valid:bindings=candidate
		sensitivity=clampf(float(config.get_value("controls","sensitivity",1.0)),.2,3.0)
		automatic_reload=bool(config.get_value("controls","automatic_reload",true))
		master_volume=volume_value(config.get_value("audio","master_volume",1.0))
		effects_volume=volume_value(config.get_value("audio","effects_volume",1.0))
	apply()
