extends Control
## Opening sequence: a solid navy screen, the logo fading in at the centre, then
## a cross-fade into the main scene. The main scene is instantiated underneath
## the cover while the logo shows, so the mouse is already alive when revealed.
## Drop `assets/logo.png` to replace the bundled emblem.

const AssetLoader=preload("res://ui/AssetLoader.gd")
const PianoAudio=preload("res://audio/PianoAudio.gd")
const MAIN_SCENE_PATH: String="res://Main.tscn"
const NAVY:=Color(0.039,0.122,0.302)
const LOGO_HEIGHT: float=190.0

@export_range(0.0,3.0) var navy_hold: float=0.6
@export_range(0.2,4.0) var logo_fade_in: float=1.6
@export_range(0.5,8.0) var logo_hold: float=2.0
@export_range(0.2,3.0) var logo_fade_out: float=0.8
@export_range(0.2,4.0) var reveal_duration: float=1.2

var custom_logo_paths:=PackedStringArray(["res://assets/logo.png","res://assets/logo.webp","res://assets/logo.jpg"])
var bundled_logo_paths:=PackedStringArray(["res://assets/logo.svg"])
var piano
var main
var wordmark: Label
var overlay: CanvasLayer
var cover: ColorRect
var logo: Control
var sequence: Tween
var revealing: bool=false
var finished: bool=false

func _ready() -> void:
	_build_cover()
	piano=PianoAudio.new()
	piano.name="PianoAudio"
	add_child(piano)
	# Let the navy screen reach the display before the heavier scene loads.
	await get_tree().process_frame
	await get_tree().process_frame
	main=(load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	main.piano=piano
	add_child(main)
	move_child(main,0)
	# The catalogs are registered by the main scene, so the title is resolved afterwards.
	if wordmark!=null:wordmark.text=tr("game_title")
	# Give shaders and the rig a few frames to settle under the cover.
	for i in 4:await get_tree().process_frame
	logo.pivot_offset=logo.size*0.5
	sequence=create_tween()
	sequence.tween_interval(navy_hold)
	sequence.tween_property(logo,"modulate:a",1.0,logo_fade_in).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sequence.parallel().tween_property(logo,"scale",Vector2.ONE,logo_fade_in+0.3).from(Vector2.ONE*0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	sequence.tween_interval(logo_hold)
	sequence.tween_callback(_reveal)

func _build_cover() -> void:
	overlay=CanvasLayer.new()
	overlay.name="Splash"
	overlay.layer=100
	add_child(overlay)
	cover=ColorRect.new()
	cover.name="Cover"
	cover.color=NAVY
	cover.mouse_filter=Control.MOUSE_FILTER_STOP
	overlay.add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.gui_input.connect(_on_cover_input)
	var center:=CenterContainer.new()
	center.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column:=VBoxContainer.new()
	column.name="Logo"
	column.mouse_filter=Control.MOUSE_FILTER_IGNORE
	column.alignment=BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation",14)
	column.modulate.a=0.0
	center.add_child(column)
	logo=column
	var texture:=AssetLoader.load_texture(custom_logo_paths)
	var uses_bundled_logo:=texture==null
	if uses_bundled_logo:texture=AssetLoader.load_texture(bundled_logo_paths)
	if texture!=null:
		var image:=TextureRect.new()
		image.texture=texture
		image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var aspect:=float(texture.get_width())/maxf(1.0,float(texture.get_height()))
		image.custom_minimum_size=Vector2(LOGO_HEIGHT*clampf(aspect,0.5,3.0),LOGO_HEIGHT)
		image.mouse_filter=Control.MOUSE_FILTER_IGNORE
		column.add_child(image)
	if uses_bundled_logo:
		# The wordmark accompanies the bundled emblem only; a custom logo stands alone.
		wordmark=Label.new()
		wordmark.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
		wordmark.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var font:=SystemFont.new()
		font.font_names=PackedStringArray(["Arial","sans-serif"])
		font.font_weight=900
		font.font_italic=true
		wordmark.add_theme_font_override("font",font)
		wordmark.add_theme_font_size_override("font_size",34)
		wordmark.add_theme_color_override("font_color",Color("fff2d5"))
		wordmark.add_theme_color_override("font_outline_color",Color("17132d"))
		wordmark.add_theme_constant_override("outline_size",8)
		column.add_child(wordmark)

func _on_cover_input(event: InputEvent) -> void:
	# A press skips the rest of the logo once the main scene is ready.
	var pressed:bool=(event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if pressed and is_instance_valid(main) and not revealing:_reveal()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and is_instance_valid(main) and not revealing and not finished:
		_reveal()
		get_viewport().set_input_as_handled()

func _reveal() -> void:
	if revealing:return
	revealing=true
	if sequence!=null and sequence.is_valid():sequence.kill()
	cover.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var fade:=create_tween()
	fade.tween_property(logo,"modulate:a",0.0,logo_fade_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.parallel().tween_property(logo,"scale",Vector2.ONE*1.05,logo_fade_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# The opening dialogue and the wake-up hop start exactly as the cover begins to clear.
	fade.tween_callback(main.begin_session)
	fade.tween_property(cover,"modulate:a",0.0,reveal_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.tween_callback(_finish)

func _finish() -> void:
	finished=true
	overlay.queue_free()
