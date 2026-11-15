extends Control
## Visual novel controller with JSON-backed English and Spanish localization.

@export_range(10.0, 90.0) var characters_per_second: float = 34.0
@export_range(0.0, 100.0) var starting_trust: float = 18.0
@export_range(0.0, 100.0) var starting_energy: float = 72.0
@export var enable_save: bool = true
@export var enable_sound: bool = true

const CYAN := Color("60e3cf")
const WHITE := Color("fff2d5")
const MUTED := Color("a5b7cd")
const SAMPLE_RATE := 11025.0
const SAVE_PATH := "user://lumien_nocturne.cfg"
const DialogueBank = preload("res://Dialogues.gd")
const PAGE_CHAR_LIMIT: int = 190
const PianoAudio = preload("res://audio/PianoAudio.gd")
const ClickFeedback = preload("res://ui/ClickFeedback.gd")
const ButtonJuice = preload("res://ui/ButtonJuice.gd")
const Chalkboard = preload("res://stories/Chalkboard.gd")
const PointerRuler = preload("res://stories/PointerRuler.gd")
const TearOverlay = preload("res://ui/TearOverlay.gd")
const GlowAura = preload("res://ui/GlowAura.gd")
## Trust thresholds: talking unlocks first, then lessons, then the full glow.
const TALK_TRUST: float = 35.0
const TEACH_TRUST: float = 65.0
const RADIANT_TRUST: float = 90.0
const PASSIVE_TRUST_RATE: float = 0.3
const DEMO_TRUST_STEP: float = 18.0
const LESSON_COUNT: int = 8
const STAGE_DIALOGUES: Array[String] = ["","talk_unlocked_dialogue","teach_unlocked_dialogue","radiant_dialogue"]
const DEMO_INTERACTIONS: Array[String] = ["pet","feed","observe","talk","teach"]

@onready var character = $Stage/View/World/Character
@onready var bubbles: CPUParticles2D = $Bubbles
@onready var background: TextureRect = $Background
@onready var title: VBoxContainer = $Interface/Title
@onready var indicators: VBoxContainer = $Interface/Indicators
@onready var commands: VBoxContainer = $Interface/Commands
@onready var dialogue: PanelContainer = $Interface/Dialogue
@onready var text: RichTextLabel = $Interface/Dialogue/Margin/Content/Text
@onready var speaker: Label = $Interface/Dialogue/Margin/Content/Header/Speaker
@onready var advance: Button = $Interface/Dialogue/Margin/Content/Header/Continue
@onready var hint: Label = $Interface/Dialogue/Margin/Content/Hint
@onready var trust_bar: ProgressBar = $Interface/Indicators/Trust
@onready var energy_bar: ProgressBar = $Interface/Indicators/Energy
@onready var specimen: Label = $Interface/Specimen
@onready var sound_button: Button = $Interface/Sound
@onready var voice: AudioStreamPlayer = $Voice

var trust: float = 18.0
var energy: float = 72.0
var talks: int = 0
var story_step: int = 0
var is_typing: bool = false
var writer: Tween
var cooldown: float = 0.0
var clock: float = 0.0
var save_timer: float = 0.0
var save_path: String = SAVE_PATH
var audio_playback: AudioStreamGeneratorPlayback
var tone_age: float = 1.0
var tone_phase: float = 0.0
var tone_pitch: float = 600.0
var rng := RandomNumberGenerator.new()
var modal: Control
var modal_panel: PanelContainer
var modal_body: VBoxContainer
var drag_active: bool = false
var drag_moved: bool = false
var drag_distance: float = 0.0
var dialogue_bags: Dictionary = {}
var dialogue_last: Dictionary = {}
var last_dialogue_id: String = ""
var dialogue_pages: PackedStringArray = PackedStringArray()
var dialogue_page: int = 0
var dialogue_speaker: String = "speaker_lumien"
var current_dialogue_key: String = ""
var playfield
var rest_position:=Vector2.ZERO
var throw_counter: Label
var total_throws: int=0
var anger_remaining: float=0.0
var resting_body_color:=Color("86bed4")
var anger_color_tween: Tween
var custom_background_enabled: bool=false
var background_dialog: FileDialog
var background_dialog_open: bool=false
var background_storage_path: String = "user://custom_background.png"
const CUSTOM_BACKGROUND_PATH: String="user://custom_background.png"
var localization = preload("res://Localization.gd").new()
## Shared piano node. The splash scene injects its own so music continues across the transition.
var piano
var click_feedback: CanvasLayer
## Stories study screen: chalkboard on the left, character and ruler on the right.
var study_mode: bool=false
var study_board: Control
var study_ruler: Control
var study_back: Button
var study_ruler_offset:=Vector2.ZERO
var lesson_index: int=0
var story_reader
var lesson_title: Label
var lesson_body: Label
## Abandonment arc: grey and crying at low trust, colour returns, then it glows.
var abandoned: bool=false
var abandonment: float=0.0
var radiance: float=0.0
var trust_stage: int=0
## -1 follows the story; 0 and 1 are the judges' manual off and on.
var tears_forced: int=-1
var tear_burst: float=0.0
var tears: Control
var aura: Control
var vitality: ShaderMaterial
var gaze_hold: float=0.0
var gaze_target:=Vector2.ZERO
var close_key_presses: int=0
var closing: bool=false
var demo_panel: PanelContainer
var demo_status: Label
var demo_tears_button: Button
var demo_step: int=0


func _ready() -> void:
	localization.initialize()
	_add_art_disclosure()
	rng.randomize()
	trust = starting_trust
	energy = starting_energy
	_load_state()
	_add_demo_button()
	_style_ui()
	_style_expressive_ui()
	_setup_background()
	_restore_custom_background()
	_setup_particles()
	_setup_audio()
	_setup_playfield()
	_setup_feel()
	_setup_abandonment()
	$Interface/Utility/Demo.pressed.connect(_toggle_demo_panel)
	# The close button is answered with a goodbye before the game quits.
	get_tree().auto_accept_quit=false
	$Interface/Commands/Converse.pressed.connect(func(): perform_action("talk"))
	$Interface/Commands/Pet.pressed.connect(func(): perform_action("pet"))
	$Interface/Commands/Feed.pressed.connect(func(): perform_action("feed"))
	$Interface/Commands/Observe.pressed.connect(func(): perform_action("observe"))
	$Interface/Commands/Stories.pressed.connect(_open_stories)
	character.interacted.connect(func(): perform_action("touch"))
	advance.pressed.connect(_advance_dialogue)
	sound_button.pressed.connect(_toggle_sound)
	resized.connect(_layout)
	get_window().size_changed.connect(_update_canvas_scale)
	_update_canvas_scale()
	_layout()
	_update_stats()
	_set_sound_label()
	DisplayServer.window_set_title(tr("window_title"))
	say("speaker_narrator", "intro_dialogue")

func _setup_feel() -> void:
	# Piano audio, pointer feedback and elastic buttons.
	if not is_instance_valid(piano):
		piano=PianoAudio.new()
		piano.name="PianoAudio"
		add_child(piano)
	piano.set_enabled(enable_sound)
	click_feedback=ClickFeedback.new()
	click_feedback.name="ClickFeedback"
	add_child(click_feedback)
	for button in find_children("*","BaseButton",true,false):
		ButtonJuice.attach(button,_play_click)
	get_tree().node_added.connect(_on_node_added)
	playfield.returned_home.connect(character.on_landed)

func _on_node_added(node: Node) -> void:
	# Buttons created later (modals, settings) get the same feel.
	if node is BaseButton and is_ancestor_of(node):ButtonJuice.attach(node,_play_click)

func _play_click() -> void:
	# Deferred so the Sound toggle is judged by its new state.
	if is_instance_valid(piano):piano.play_click.call_deferred()

## Restarts the opening so it plays from its first frame once the splash reveals the scene.
func begin_session() -> void:
	say("speaker_narrator","intro_dialogue")
	character.greet()

func glass_style(fill: Color,border: Color,radius: int=8) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=fill; style.border_color=border
	style.set_border_width_all(2); style.set_corner_radius_all(mini(radius,3))
	style.content_margin_left=22; style.content_margin_right=22
	style.content_margin_top=11; style.content_margin_bottom=11
	style.shadow_color=Color("070e20"); style.shadow_size=2; style.shadow_offset=Vector2(5,5)
	style.anti_aliasing=true
	return style

func _style_ui() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font_size=18
	ui_theme.set_color("font_color","Label",WHITE)
	ui_theme.set_color("default_color","RichTextLabel",WHITE)
	$Interface.theme=ui_theme
	var serif:=SystemFont.new()
	serif.font_names=PackedStringArray(["Arial","sans-serif"])
	serif.font_weight=900
	serif.font_italic=true
	$Interface/Title/Name.add_theme_font_override("font",serif)
	$Interface/Title/Name.add_theme_font_size_override("font_size",64)
	$Interface/Title/Name.add_theme_color_override("font_color",Color("fff2d5"))
	$Interface/Title/Subtitle.add_theme_color_override("font_color",CYAN)
	$Interface/Title/Subtitle.add_theme_font_size_override("font_size",13)
	title.add_theme_constant_override("separation",7)
	commands.add_theme_constant_override("separation",9)
	$Interface/Commands/Section.add_theme_font_size_override("font_size",11)
	$Interface/Commands/Section.add_theme_color_override("font_color",Color("c4d5df"))
	for button in [commands.get_node("Converse"),commands.get_node("Pet"),commands.get_node("Feed"),commands.get_node("Observe"),commands.get_node("Stories"),advance,sound_button]:
		_style_button(button)
	for entry in [["Converse","talk"],["Pet","pet"],["Feed","feed"],["Observe","observe"],["Stories","stories"]]:
		var command:Button=commands.get_node(entry[0])
		command.icon=load("res://assets/"+entry[1]+".svg")
		command.add_theme_constant_override("h_separation",16)
	for button in commands.get_children():
		if button is Button: button.custom_minimum_size.y=48
	for button in $Interface/Utility.get_children():
		_style_button(button)
		button.custom_minimum_size=Vector2(94,36)
		button.add_theme_font_size_override("font_size",13)
	$Interface/Utility.add_theme_constant_override("separation",8)
	for bar in [trust_bar,energy_bar]:
		bar.custom_minimum_size.y=5
		var base:=StyleBoxFlat.new()
		base.bg_color=Color(0.035,0.075,0.12,0.8)
		base.border_color=Color(0.42,0.60,0.70,0.3)
		base.set_border_width_all(1); base.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("background",base)
		var fill:=StyleBoxFlat.new()
		fill.bg_color=Color("9fc9d9") if bar==trust_bar else Color("8cb3c9")
		fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("fill",fill)
	for label in [$Interface/Indicators/TrustLabel,$Interface/Indicators/EnergyLabel,specimen,$Interface/Ambience]:
		label.add_theme_font_size_override("font_size",11)
		label.add_theme_color_override("font_color",MUTED)
	indicators.add_theme_constant_override("separation",9)
	dialogue.add_theme_stylebox_override("panel",glass_style(Color("f6e9cf"),Color("17213b"),10))
	$Interface/Dialogue/Margin.add_theme_constant_override("margin_left",16)
	$Interface/Dialogue/Margin.add_theme_constant_override("margin_right",16)
	$Interface/Dialogue/Margin/Content.add_theme_constant_override("separation",8)
	speaker.add_theme_font_override("font",serif)
	speaker.add_theme_color_override("font_color",Color("934750"))
	text.add_theme_color_override("default_color",Color("19223b"))
	speaker.add_theme_font_size_override("font_size",21)
	var reading_font:=SystemFont.new()
	reading_font.font_names=PackedStringArray(["Arial","sans-serif"])
	text.add_theme_font_override("normal_font",reading_font)
	text.add_theme_font_size_override("normal_font_size",23)
	text.add_theme_constant_override("line_separation",8)
	text.visible_characters_behavior=TextServer.VC_CHARS_AFTER_SHAPING
	hint.add_theme_font_size_override("font_size",12)
	hint.add_theme_color_override("font_color",Color("48546c"))
	advance.custom_minimum_size=Vector2(130,34)
	advance.add_theme_font_size_override("font_size",12)
	sound_button.custom_minimum_size.y=32
	sound_button.add_theme_font_size_override("font_size",12)
	$Interface/Utility/Background.pressed.connect(_choose_background)
	$Interface/Utility/Settings.pressed.connect(_open_settings)
	$Interface/Utility/Save.pressed.connect(func(): _save_state(); _toast(tr("save_confirmation")))
	$Stage.gui_input.connect(_stage_input)
	$Stage/View/World/Camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	$Stage/View/World/Camera.size=5.8
	$Stage/View/World/Camera.position=Vector3(0,1.32,8)
	$Stage/View/World/Camera.look_at(Vector3(0,1.32,0))

func _setup_contact_shadow() -> void:
	var plane:=MeshInstance3D.new()
	var mesh:=PlaneMesh.new(); mesh.size=Vector2(1.4,1.15); plane.mesh=mesh
	plane.position.y=-0.025
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
void fragment(){
 float d=length((UV-0.5)*2.0);
 float shadow=1.0-smoothstep(0.16,0.98,d);
 ALBEDO=vec3(0.02,0.04,0.065);
 ALPHA=shadow*shadow*0.62;
}"""
	var material:=ShaderMaterial.new(); material.shader=shader; plane.material_override=material
	$Stage/View/World.add_child(plane)

func _style_button(button: Button) -> void:
	button.custom_minimum_size.y=56
	button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color",WHITE)
	button.add_theme_color_override("font_hover_color",Color("f2f7fa"))
	button.add_theme_color_override("font_pressed_color",CYAN)
	button.add_theme_stylebox_override("normal",glass_style(Color("17213b"),Color("5c758f")))
	button.add_theme_stylebox_override("hover",glass_style(Color("643a56"),Color("ff967d")))
	button.add_theme_stylebox_override("pressed",glass_style(Color(0.04,0.10,0.16,0.98),CYAN))
	button.add_theme_stylebox_override("focus",glass_style(Color(0,0,0,0),Color(0.77,0.88,0.94,0.8)))

func _setup_background() -> void:
	background.texture=preload("res://assets/laboratory.png")
	var star_material:=ShaderMaterial.new()
	star_material.shader=preload("res://assets/laboratory.gdshader")
	background.material=star_material
	background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
void fragment(){
 vec2 uv=UV;
 float left=(1.0-smoothstep(0.05,0.45,uv.x))*0.60;
 float bottom=smoothstep(0.58,1.0,uv.y)*0.60;
 float top=(1.0-smoothstep(0.0,0.22,uv.y))*0.38;
 float vignette=smoothstep(0.30,0.78,length((uv-0.5)*vec2(1.1,1.0)))*0.25;
 COLOR=vec4(0.015,0.030,0.055,clamp(left+bottom+top+vignette,0.0,0.82));
}"""
	var material:=ShaderMaterial.new(); material.shader=shader
	$Atmosphere.material=material

func _setup_particles() -> void:
	var image := Image.create(24,24,false,Image.FORMAT_RGBA8)
	for y in range(24):
		for x in range(24):
			var p := Vector2(x-11.5,y-11.5)
			var d := p.length()
			var ring := exp(-pow((d-8.0)/0.85,2.0))*0.5
			var glint := exp(-p.distance_squared_to(Vector2(-3.5,-5.0))/3.0)*0.7
			image.set_pixel(x,y,Color(0.67,0.83,0.93,clampf(ring+glint,0,0.8)))
	bubbles.texture = ImageTexture.create_from_image(image)
	bubbles.amount = 18
	bubbles.lifetime = 22.0
	bubbles.preprocess = 8.0
	bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bubbles.direction = Vector2.UP
	bubbles.spread = 9.0
	bubbles.gravity = Vector2.ZERO
	bubbles.initial_velocity_min = 10.0
	bubbles.initial_velocity_max = 23.0
	bubbles.scale_amount_min = 0.2
	bubbles.scale_amount_max = 0.45
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.18,0.8,1.0])
	gradient.colors = PackedColorArray([Color(1,1,1,0),Color(1,1,1,0.55),Color(1,1,1,0.40),Color(1,1,1,0)])
	bubbles.color_ramp = gradient
	bubbles.emitting = true

func _update_canvas_scale() -> void:
	var window:=get_window()
	var target:=Vector2i(720,1280) if window.size.x<window.size.y else Vector2i(1440,900)
	if window.content_scale_size!=target:window.content_scale_size=target

func _layout() -> void:
	var w:=size.x; var h:=size.y
	var portrait:=w<h*1.05
	var margin:=32.0 if portrait else 66.0
	# Offset keeps the title where it sat before the chapter line above it was removed.
	title.position=Vector2(margin,62)
	title.size=Vector2(w-margin*2,150)
	indicators.position=Vector2(w-margin-220,202 if portrait else 46)
	indicators.size=Vector2(220,106)
	commands.position=Vector2(margin,266 if portrait else 238)
	commands.size=Vector2(183 if portrait else 235,304)
	var panel_height:=270.0 if portrait else 220.0
	dialogue.position=Vector2(margin,h-panel_height-74)
	dialogue.size=Vector2(w-margin*2,panel_height)
	var old_position:=Vector2(w*0.30,305) if portrait else Vector2(w*0.32,170)
	var old_size:=Vector2(w*0.69,maxf(260,h-panel_height-445)) if portrait else Vector2(w*0.62,maxf(260,h-panel_height-260))
	rest_position=old_position+old_size*Vector2(0.5,0.48)
	var tile_size:=clampf(old_size.y*1.35,378.0,minf(w,h)*0.88)
	if study_mode:
		rest_position=Vector2(w*0.62,h-330) if portrait else Vector2(w*0.80,h*0.52)
		var board_rect:=Rect2(margin,250,w-margin*2,rest_position.y-tile_size*0.27-250) if portrait else Rect2(margin,232,w*0.60-margin,h-316)
		study_board.position=board_rect.position
		study_board.size=board_rect.size
		study_back.position=Vector2(margin,h-62)
		study_back.size=Vector2(150,36)
		study_ruler.length=tile_size*0.34
		study_ruler.direction=Vector2(-0.5,-0.86) if portrait else Vector2(-0.88,-0.47)
		study_ruler_offset=tile_size*(Vector2(-0.19,-0.11) if portrait else Vector2(-0.24,0.11))
	$Stage.size=Vector2.ONE*tile_size
	$Stage.position=rest_position-$Stage.size*0.5
	specimen.position=Vector2(w*0.43,h-panel_height-107) if portrait else Vector2(w*0.57,h-panel_height-115)
	sound_button.position=Vector2(w-margin-124,146 if portrait else 134)
	sound_button.size=Vector2(124,34)
	$Interface/Utility.position=Vector2(w-margin-432,h-58)
	$Interface/Utility.size=Vector2(432,31)
	$Interface/Ambience.position=Vector2(margin,h-43)
	$Interface/Ambience.visible=not portrait and not study_mode
	$Frame.dialogue_rect=Rect2() if study_mode else Rect2(dialogue.position,dialogue.size)
	$Frame.menu_rect=Rect2(commands.position,commands.size)
	$Frame.character_center=rest_position
	$Frame.orbit_radius=$Stage.size.x*0.43
	bubbles.position=Vector2(w*0.6,h*0.62)
	bubbles.emission_rect_extents=Vector2(w*0.35,h*0.18)
	text.add_theme_font_size_override("normal_font_size",21 if portrait else 23)
	for label in [$Interface/Title/Subtitle,$Interface/Indicators/TrustLabel,$Interface/Indicators/EnergyLabel,specimen]:
		label.add_theme_font_size_override("font_size",14 if portrait else 12)
	if is_instance_valid(throw_counter):throw_counter.add_theme_font_size_override("font_size",14 if portrait else 12)
	$Frame.queue_redraw()
	if is_instance_valid(modal): _layout_modal()
	if is_instance_valid(demo_panel):
		demo_panel.position=Vector2(margin,196) if portrait else Vector2(540,14)
		demo_panel.size=Vector2(w-margin*2-236 if portrait else w-margin-236-540,0)
	if is_instance_valid(playfield): _configure_playfield.call_deferred()

func _process(delta: float) -> void:
	clock += delta
	cooldown = maxf(0,cooldown-delta)
	energy = minf(100.0,energy+delta*0.28)
	if energy < 24 and cooldown <= 0 and anger_remaining<=0: character.emotion = "tired"
	if energy < 24 and anger_remaining<=0: _set_mood("tired")
	if anger_remaining>0:
		anger_remaining=maxf(0.0,anger_remaining-delta)
		character.emotion="angry"
		_set_mood("angry")
		if anger_remaining<=0:_calm_down()
	if anger_remaining<=0 and cooldown<=0:
		if _is_sad():
			character.emotion="sad"
			_set_mood("sad")
		elif character.emotion=="sad":
			character.emotion="shy"
			_set_mood("shy")
	if is_instance_valid(playfield):
		playfield.input_enabled=not is_instance_valid(modal) and not background_dialog_open
		_sync_physics_visual()
		var pointer:Vector2=get_local_mouse_position()-playfield.actor.position
		gaze_hold=maxf(0.0,gaze_hold-delta)
		character.look_toward(gaze_target if gaze_hold>0 else pointer/maxf($Stage.size.x*0.9,1.0))
		_update_abandonment(delta)
		throw_counter.text=tr("throw_counter") % [total_throws,mini(playfield.throw_streak,3)]
		if study_mode:study_ruler.position=playfield.actor.position+study_ruler_offset
	_update_stats()
	_refill_audio()
	save_timer += delta
	if save_timer > 12.0:
		save_timer=0
		_save_state()

func perform_action(action: String) -> void:
	if anger_remaining>0:
		say("speaker_lumien","angry_dialogue")
		return
	if is_instance_valid(playfield):playfield.reset_streak()
	if cooldown>0 or action not in ["talk","pet","feed","observe","touch"]: return
	cooldown=0.85
	match action:
		"talk":
			trust+=6; talks+=1; energy-=3
		"pet","touch":
			trust+=4 if action=="pet" else 2
			energy-=1
		"feed":
			trust+=3; energy+=18
		"observe":
			trust+=1; energy+=5
	trust=clampf(trust,0,100)
	energy=clampf(energy,0,100)
	var category: String="pet" if action=="touch" else action
	# Once abandoned, talking is about what being left behind felt like.
	if category=="talk" and abandoned: category="memory"
	if energy<24: category="tired"
	var entry: Dictionary=_next_dialogue(category)
	var feeling: String=entry.get("emotion","curious")
	if category=="pet" and trust<35: feeling="shy"
	character.react(feeling,0.6 if feeling=="tired" else 1.0)
	_set_mood(feeling)
	play_bloop(620 if feeling=="happy" else 480)
	say("speaker_lumien",entry.get("text_key","fallback_dialogue"))
	_update_stats()
	_save_state()

func _next_dialogue(category: String) -> Dictionary:
	var entries: Array=DialogueBank.BANK[category]
	var remaining: Array=dialogue_bags.get(category,[]).duplicate()
	var valid: Array=[]
	for item in remaining:
		if item is int and item>=0 and item<entries.size() and not valid.has(item): valid.append(item)
	remaining=valid
	if remaining.is_empty():
		for i in range(entries.size()): remaining.append(i)
		for i in range(remaining.size()-1,0,-1):
			var j:=rng.randi_range(0,i)
			var temp: int=remaining[i]; remaining[i]=remaining[j]; remaining[j]=temp
		if remaining.size()>1 and remaining.back()==dialogue_last.get(category,-1):
			var temp: int=remaining[0]; remaining[0]=remaining[-1]; remaining[-1]=temp
	var selected: int=remaining.pop_back()
	dialogue_bags[category]=remaining
	dialogue_last[category]=selected
	var entry: Dictionary=entries[selected]
	last_dialogue_id=entry["id"]
	return entry

func say(who: String,line: String) -> void:
	dialogue_speaker=who
	current_dialogue_key=line
	dialogue_pages=_paginate_dialogue(tr(line))
	dialogue_page=0
	_show_dialogue_page()

func _paginate_dialogue(line: String) -> PackedStringArray:
	var pages:=PackedStringArray()
	var page: String=""
	for word in line.split(" ",false):
		var candidate: String=word if page.is_empty() else page+" "+word
		if candidate.length()>PAGE_CHAR_LIMIT and not page.is_empty():
			var boundary: int=-1
			for mark in [".","!","?","…"]: boundary=maxi(boundary,page.rfind(mark))
			if boundary>=int(PAGE_CHAR_LIMIT*0.4):
				pages.append(page.left(boundary+1))
				var tail: String=page.substr(boundary+1).strip_edges()
				page=word if tail.is_empty() else tail+" "+word
			else:
				pages.append(page)
				page=word
		else: page=candidate
	if not page.is_empty(): pages.append(page)
	if pages.is_empty(): pages.append("")
	return pages

func _show_dialogue_page() -> void:
	if writer!=null and writer.is_running(): writer.kill()
	speaker.text=tr(dialogue_speaker)
	text.text=dialogue_pages[dialogue_page]
	text.visible_ratio=0.0
	is_typing=true
	advance.text=tr("complete_button")
	hint.text=tr("page_hint") % [dialogue_page+1,dialogue_pages.size()] if dialogue_pages.size()>1 else tr("interaction_hint")
	var count:=text.get_parsed_text().length()
	writer=create_tween()
	writer.tween_property(text,"visible_ratio",1.0,maxf(0.2,float(count)/characters_per_second))
	writer.tween_callback(_typing_finished)

func _typing_finished() -> void:
	is_typing=false
	advance.text=tr("read_more_button") if dialogue_page<dialogue_pages.size()-1 else tr("continue_button")

func _advance_dialogue() -> void:
	if is_typing:
		if writer != null: writer.kill()
		text.visible_ratio=1.0
		_typing_finished()
		return
	if dialogue_page<dialogue_pages.size()-1:
		dialogue_page+=1
		_show_dialogue_page()
		return
	var lines := [
		"story_seed",
		"story_lights",
		"story_silence"
	]
	say("speaker_narrator",lines[story_step % lines.size()])
	story_step += 1
	_save_state()

func _update_stats() -> void:
	trust_bar.value = trust
	energy_bar.value = energy
	$Interface/Indicators/TrustLabel.text=tr("trust_value") % roundi(trust)
	$Interface/Indicators/EnergyLabel.text=tr("energy_value") % roundi(energy)

func _setup_audio() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = SAMPLE_RATE
	generator.buffer_length = 0.12
	voice.stream = generator
	voice.volume_db = -9.0
	voice.play()
	audio_playback = voice.get_stream_playback() as AudioStreamGeneratorPlayback
	voice.stream_paused = not enable_sound
	_refill_audio()

func play_bloop(pitch: float = 580.0) -> void:
	if not enable_sound: return
	tone_age=0.0
	tone_phase=0.0
	tone_pitch=pitch+rng.randf_range(-25,25)

func _refill_audio() -> void:
	if audio_playback == null or not enable_sound: return
	var frames := audio_playback.get_frames_available()
	for i in range(frames):
		var value := 0.0
		if tone_age < 0.40:
			var attack := minf(tone_age/0.014,1.0)
			var envelope := attack*pow(maxf(0.0,1.0-tone_age/0.40),2.8)
			var frequency := tone_pitch*(0.67+0.55*exp(-tone_age*15.0))
			tone_phase=fmod(tone_phase+TAU*frequency/SAMPLE_RATE,TAU)
			value=(sin(tone_phase)+0.16*sin(tone_phase*2.0))*envelope*0.30
			tone_age+=1.0/SAMPLE_RATE
		audio_playback.push_frame(Vector2(value,value))

func _toggle_sound() -> void:
	enable_sound=not enable_sound
	voice.stream_paused=not enable_sound
	if is_instance_valid(piano):piano.set_enabled(enable_sound)
	if not enable_sound: tone_age=1.0
	_set_sound_label()
	_save_state()

func _set_sound_label() -> void:
	sound_button.text=tr("sound_on") if enable_sound else tr("sound_off")

func _save_state() -> void:
	if not enable_save: return
	var config := ConfigFile.new()
	config.set_value("slime","trust",trust)
	config.set_value("slime","energy",energy)
	config.set_value("slime","talks",talks)
	config.set_value("slime","story_step",story_step)
	config.set_value("slime","sound",enable_sound)
	config.set_value("preferences","language",localization.locale)
	config.set_value("care","abandoned",abandoned)
	config.set_value("playfield","total_throws",total_throws)
	config.set_value("background","custom",custom_background_enabled)
	config.set_value("dialogues","bags",dialogue_bags)
	config.set_value("dialogues","last",dialogue_last)
	if character!=null and character.gel!=null:
		config.set_value("look","saturation",character.gel.get_shader_parameter("saturation"))
		config.set_value("look","density",character.gel.get_shader_parameter("density"))
		config.set_value("look","base_color",_get_body_color())
		config.set_value("look","screentone",character.gel.get_shader_parameter("screentone"))
	config.set_value("look","type_speed",characters_per_second)
	config.set_value("look","sky_blue_theme",true)
	config.save(save_path)

func _load_state() -> void:
	if not enable_save: return
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		var previous_name: String=localization.migration.get("previous_application_name","")
		var previous_path: String=OS.get_user_data_dir().get_base_dir().path_join(previous_name).path_join(save_path.get_file())
		if previous_name.is_empty() or config.load(previous_path)!=OK: return
	localization.set_language(str(config.get_value("preferences","language","es")))
	abandoned=bool(config.get_value("care","abandoned",false))
	total_throws=maxi(0,int(config.get_value("playfield","total_throws",0)))
	custom_background_enabled=bool(config.get_value("background","custom",false))
	trust=clampf(float(config.get_value("slime","trust",starting_trust)),0,100)
	energy=clampf(float(config.get_value("slime","energy",starting_energy)),0,100)
	talks=maxi(0,int(config.get_value("slime","talks",0)))
	story_step=maxi(0,int(config.get_value("slime","story_step",0)))
	enable_sound=bool(config.get_value("slime","sound",enable_sound))
	var stored_bags=config.get_value("dialogues","bags",{})
	var stored_last=config.get_value("dialogues","last",{})
	if stored_bags is Dictionary: dialogue_bags=localization.migrate_action_keys(stored_bags)
	if stored_last is Dictionary: dialogue_last=localization.migrate_action_keys(stored_last)
	characters_per_second=clampf(float(config.get_value("look","type_speed",34)),10,90)
	if character!=null and character.gel!=null:
		character.gel.set_shader_parameter("saturation",clampf(float(config.get_value("look","saturation",0.92)),0.5,1.6))
		character.gel.set_shader_parameter("density",clampf(float(config.get_value("look","density",24.0)),8,40))
		character.gel.set_shader_parameter("base_color",config.get_value("look","base_color",Color("86bed4")))
		character.gel.set_shader_parameter("screentone",bool(config.get_value("look","screentone",true)))
		var legacy_flag: String=localization.migration.get("previous_theme_flag","")
		var has_sky_theme: bool=bool(config.get_value("look","sky_blue_theme",config.get_value("look",legacy_flag,false)))
		if not has_sky_theme:
			character.gel.set_shader_parameter("base_color",Color("86bed4"))
			character.gel.set_shader_parameter("saturation",0.92)

func _set_mood(feeling: String) -> void:
	var moods={"shy":tr("mood_shy"),"happy":tr("mood_happy"),"curious":tr("mood_curious"),"tired":tr("mood_tired"),"angry":tr("mood_angry"),"sad":tr("mood_sad")}
	specimen.text=moods.get(feeling,tr("specimen_label"))

func _stage_input(_event: InputEvent) -> void:
	# Pointer capture and touch ownership are handled by Playfield.gd.
	pass

func _hit_character(point: Vector2) -> bool:
	var camera: Camera3D=$Stage/View/World/Camera
	var origin:=camera.project_ray_origin(point)
	var direction:=camera.project_ray_normal(point)
	var offset:=origin-Vector3(0,0.5+character.lift,0)
	var b:=offset.dot(direction)
	var c:=offset.dot(offset)-0.25
	return b*b-c>=0 and b<0

func _toast(message: String) -> void:
	hint.text=message
	var tween:=create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(func(): hint.text=tr("interaction_hint"))

func _open_modal(title_text: String) -> void:
	if is_instance_valid(modal): modal.free()
	drag_active=false
	if is_instance_valid(playfield):
		playfield.cancel_hold()
		playfield.input_enabled=false
	modal=Control.new(); add_child(modal); modal.z_index=30
	modal.theme=$Interface.theme
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade:=ColorRect.new(); shade.color=Color(0.025,0.005,0.06,0.85)
	modal.add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_panel=PanelContainer.new(); modal.add_child(modal_panel)
	modal_panel.add_theme_stylebox_override("panel",glass_style(Color("142330"),Color("688ca2"),12))
	var margin:=MarginContainer.new(); modal_panel.add_child(margin)
	for key in ["margin_left","margin_right","margin_top","margin_bottom"]: margin.add_theme_constant_override(key,12)
	var content:=VBoxContainer.new(); margin.add_child(content); content.add_theme_constant_override("separation",14)
	var label:=Label.new(); label.text=title_text; label.add_theme_font_size_override("font_size",27); label.add_theme_color_override("font_color",CYAN); content.add_child(label)
	var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; content.add_child(scroll)
	modal_body=VBoxContainer.new(); modal_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL; modal_body.add_theme_constant_override("separation",14); scroll.add_child(modal_body)
	var close:=Button.new(); close.text=tr("return_button"); _style_button(close); close.pressed.connect(_close_modal); content.add_child(close)
	_layout_modal()

func _layout_modal() -> void:
	modal_panel.size=Vector2(minf(620,size.x-72),minf(620,size.y-100))
	modal_panel.position=(size-modal_panel.size)*0.5

func _close_modal() -> void:
	if is_instance_valid(modal): modal.queue_free()
	_save_state()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_instance_valid(modal):
		_close_modal(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and study_mode:
		_set_study_mode(false); get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_X and not is_instance_valid(modal):
		# He notices the X being pressed and takes it as a goodbye.
		_react_sadly("close_key_dialogue_%d" % (close_key_presses%3+1))
		close_key_presses+=1
		get_viewport().set_input_as_handled()

func _modal_text(value: String, font_size: int=18) -> Label:
	var label:=Label.new(); label.text=value
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",WHITE)
	modal_body.add_child(label)
	return label

func _open_stories() -> void:
	if not study_mode:_set_study_mode(true)

func _build_study_screen() -> void:
	study_board=Chalkboard.new()
	study_board.name="StudyBoard"
	$Interface.add_child(study_board)
	study_ruler=PointerRuler.new()
	study_ruler.name="StudyRuler"
	$Interface.add_child(study_ruler)
	study_back=Button.new()
	study_back.name="StudyBack"
	# A translation key: the button resolves it through the active catalog.
	study_back.text="stories_back_button"
	_style_button(study_back)
	study_back.custom_minimum_size=Vector2(150,36)
	study_back.add_theme_font_size_override("font_size",13)
	study_back.add_theme_stylebox_override("normal",_graphic_style("night"))
	study_back.add_theme_stylebox_override("hover",_graphic_style("violet"))
	study_back.add_theme_color_override("font_hover_color",Color("14213b"))
	study_back.pressed.connect(func(): _set_study_mode(false))
	$Interface.add_child(study_back)
	story_reader=preload("res://stories/StoryLibrary.gd").new()
	study_board.content.get_node("Content").add_child(story_reader)
	story_reader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	story_reader.chapter_changed.connect(func(value:int):lesson_index=value)
	lesson_title=story_reader.heading
	lesson_body=story_reader.narrative
	_show_lesson()

func _show_lesson() -> void:
	if is_instance_valid(story_reader):story_reader.show_chapter(lesson_index)

func _next_lesson() -> void:
	lesson_index=(lesson_index+1)%LESSON_COUNT
	_show_lesson()
	if anger_remaining<=0:character.react("curious")
	play_bloop(640)

## Built in code so saving Main.tscn from the editor can never drop it.
func _add_demo_button() -> void:
	if $Interface/Utility.has_node("Demo"):return
	var button:=Button.new()
	button.name="Demo"
	button.text="demo_button"
	$Interface/Utility.add_child(button)

func _setup_abandonment() -> void:
	vitality=ShaderMaterial.new()
	vitality.shader=preload("res://character/vitality.gdshader")
	$Stage.material=vitality
	aura=GlowAura.new()
	aura.name="GlowAura"
	add_child(aura)
	tears=TearOverlay.new()
	tears.name="Tears"
	$Interface.add_child(tears)
	trust_stage=_stage_for(trust)
	abandonment=_abandonment_target()

func _stage_for(value: float) -> int:
	return 3 if value>=RADIANT_TRUST else 2 if value>=TEACH_TRUST else 1 if value>=TALK_TRUST else 0

func _abandonment_target() -> float:
	return 1.0-smoothstep(8.0,TEACH_TRUST,trust) if abandoned else 0.0

func _is_crying() -> bool:
	if tears_forced>=0:return tears_forced==1
	return tear_burst>0 or (abandoned and trust<TALK_TRUST)

func _is_sad() -> bool:
	return tears_forced==1 or tear_burst>0 or (abandoned and trust<TALK_TRUST)

## Drives the grey-to-colour-to-glow arc, the tears and the trust unlocks.
func _update_abandonment(delta: float) -> void:
	if abandoned and not is_instance_valid(modal):trust=minf(100.0,trust+delta*PASSIVE_TRUST_RATE)
	tear_burst=maxf(0.0,tear_burst-delta)
	abandonment=move_toward(abandonment,_abandonment_target(),delta*0.9)
	radiance=move_toward(radiance,smoothstep(TEACH_TRUST-5.0,RADIANT_TRUST,trust),delta*0.8)
	vitality.set_shader_parameter("abandonment",abandonment)
	vitality.set_shader_parameter("glow",radiance)
	vitality.set_shader_parameter("pulse",sin(clock*2.2))
	var tile:float=$Stage.size.x
	tears.target_intensity=1.0 if _is_crying() else 0.0
	tears.position=playfield.actor.position
	tears.eye_offset=Vector2(0.083,0.035)*tile
	tears.drop_radius=tile*0.028
	tears.fall_distance=tile*0.26
	aura.position=playfield.actor.position+Vector2(0,tile*0.03)
	aura.radius=tile*0.46
	aura.strength=radiance
	aura.tint=_get_body_color().lightened(0.35)
	var stage:=_stage_for(trust)
	if stage>trust_stage:
		if anger_remaining<=0:
			character.react("shy" if stage==1 else "happy")
			_set_mood("shy" if stage==1 else "happy")
		play_bloop(600.0+float(stage)*60.0)
		say("speaker_lumien",STAGE_DIALOGUES[stage])
	trust_stage=stage
	_set_lock(commands.get_node("Converse"),trust<TALK_TRUST,"command_talk","command_talk_locked",TALK_TRUST)
	_set_lock(commands.get_node("Stories"),trust<TEACH_TRUST,"command_stories","command_stories_locked",TEACH_TRUST)
	if is_instance_valid(demo_panel) and demo_panel.visible:
		var stage_key: String="demo_stage_abandoned" if abandoned and stage==0 else ["demo_stage_shy","demo_stage_talk","demo_stage_teach","demo_stage_radiant"][stage]
		demo_status.text=tr("demo_status") % [roundi(trust),tr(stage_key)]
		demo_tears_button.text="demo_tears_on" if _is_crying() else "demo_tears_off"

func _set_lock(button: Button,locked: bool,key: String,locked_key: String,threshold: float) -> void:
	var label: String=tr(locked_key) % roundi(threshold) if locked else key
	if button.text!=label:button.text=label
	if button.disabled!=locked:
		button.disabled=locked
		button.modulate.a=0.6 if locked else 1.0

## Looks toward the window's close button, tears up and answers with a melancholic line.
func _react_sadly(line_key: String) -> void:
	gaze_target=Vector2(0.95,-0.75)
	gaze_hold=2.4
	tear_burst=4.5
	if anger_remaining<=0:
		character.react("sad")
		_set_mood("sad")
	play_bloop(300)
	say("speaker_lumien",line_key)

func _toggle_demo_panel() -> void:
	if is_instance_valid(demo_panel):demo_panel.visible=not demo_panel.visible
	else:_build_demo_panel()
	_layout()

func _build_demo_panel() -> void:
	demo_panel=PanelContainer.new()
	demo_panel.name="DemoPanel"
	demo_panel.add_theme_stylebox_override("panel",glass_style(Color(0.05,0.08,0.17,0.93),Color("f2c66d"),6))
	$Interface.add_child(demo_panel)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	demo_panel.add_child(column)
	var heading:=Label.new()
	heading.text="demo_title"
	heading.add_theme_font_size_override("font_size",12)
	heading.add_theme_color_override("font_color",Color("f2c66d"))
	column.add_child(heading)
	demo_status=Label.new()
	demo_status.add_theme_font_size_override("font_size",13)
	column.add_child(demo_status)
	var row:=HFlowContainer.new()
	row.add_theme_constant_override("h_separation",6)
	row.add_theme_constant_override("v_separation",6)
	column.add_child(row)
	for entry in [["Abandon","demo_abandon_button",_demo_simulate_abandonment],["Advance","demo_advance_button",_demo_advance_time],["Tears","demo_tears_off",_demo_toggle_tears],["Interaction","demo_interaction_button",_demo_try_interaction]]:
		var button:=Button.new()
		button.name=entry[0]
		button.text=entry[1]
		_style_button(button)
		button.custom_minimum_size=Vector2(0,34)
		button.alignment=HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size",13)
		button.pressed.connect(entry[2])
		row.add_child(button)
	demo_tears_button=row.get_node("Tears")

## Judges' shortcut: grey, dull, sad and crying at once, with everything locked again.
func _demo_simulate_abandonment() -> void:
	if study_mode:_set_study_mode(false)
	if anger_remaining>0:
		anger_remaining=0.0
		playfield.angry=false
		character.gel.set_shader_parameter("base_color",resting_body_color)
	abandoned=true
	trust=0.0
	energy=maxf(energy,45.0)
	tears_forced=-1
	trust_stage=0
	abandonment=1.0
	radiance=0.0
	character.react("sad")
	_set_mood("sad")
	say("speaker_lumien","abandoned_dialogue")
	_save_state()

## Judges' shortcut: skips ahead in time, which raises trust by one visible step.
func _demo_advance_time() -> void:
	tears_forced=-1
	trust=minf(100.0,trust+DEMO_TRUST_STEP)
	energy=minf(100.0,energy+8.0)
	play_bloop(520.0+trust*1.5)
	_save_state()

func _demo_toggle_tears() -> void:
	tears_forced=0 if _is_crying() else 1
	if tears_forced==1 and anger_remaining<=0:character.react("sad")

## Judges' shortcut: runs the next interaction in turn, ignoring the trust locks.
func _demo_try_interaction() -> void:
	var step: String=DEMO_INTERACTIONS[demo_step%DEMO_INTERACTIONS.size()]
	demo_step+=1
	if step=="teach":
		if study_mode:_next_lesson()
		else:_set_study_mode(true)
		return
	if study_mode:_set_study_mode(false)
	cooldown=0.0
	perform_action(step)

## Swaps the care screen (commands and dialogue) for the study chalkboard and back.
func _set_study_mode(enabled: bool) -> void:
	if study_mode==enabled:return
	study_mode=enabled
	if not enabled and is_instance_valid(story_reader):story_reader.stop_audio()
	if not is_instance_valid(study_board):_build_study_screen()
	for node in [commands,dialogue,specimen]:node.visible=not enabled
	for node in [study_board,study_ruler,study_back]:node.visible=enabled
	var portrait:=size.x<size.y*1.05
	character.pose_lean_target=(0.05 if portrait else 0.13) if enabled else 0.0
	if enabled and anger_remaining<=0:
		character.react("happy")
		_set_mood("happy")
	_layout()
	# Glide to the new resting spot instead of jumping there.
	var previous:Vector2=playfield.actor.position
	_configure_playfield()
	if playfield.state=="idle":
		playfield.actor.position=previous
		playfield.start_return()

func _slider(title_text: String, min_value: float, max_value: float, step: float, value: float, callback: Callable) -> void:
	_modal_text(title_text,14)
	var slider:=HSlider.new(); slider.min_value=min_value; slider.max_value=max_value
	slider.step=step; slider.value=value; slider.custom_minimum_size.y=30
	slider.value_changed.connect(callback); modal_body.add_child(slider)

func _open_settings() -> void:
	_open_modal(tr("settings_title"))
	_modal_text(tr("settings_description"),16)
	_modal_text(tr("language_label"),14)
	var language_selector:=OptionButton.new()
	language_selector.name="LanguageSelector"
	language_selector.custom_minimum_size.y=42
	language_selector.add_item(tr("language_spanish"))
	language_selector.add_item(tr("language_english"))
	language_selector.select(0 if localization.locale=="es" else 1)
	language_selector.item_selected.connect(func(index: int): _change_language.call_deferred(localization.LANGUAGE_CODES[index]))
	modal_body.add_child(language_selector)
	_modal_text(tr("body_color_label"),14)
	var color_picker:=ColorPickerButton.new()
	color_picker.name="BodyColorPicker"
	color_picker.custom_minimum_size.y=42
	color_picker.edit_alpha=false
	color_picker.color=_get_body_color()
	color_picker.color_changed.connect(_change_body_color)
	modal_body.add_child(color_picker)
	_modal_text(tr("background_heading"),14)
	var upload:=Button.new();upload.text=tr("upload_background");_style_button(upload)
	upload.pressed.connect(_choose_background);modal_body.add_child(upload)
	var reset:=Button.new();reset.text=tr("reset_background");_style_button(reset)
	reset.pressed.connect(_reset_background);modal_body.add_child(reset)
	var palettes:=HBoxContainer.new(); palettes.add_theme_constant_override("separation",8); modal_body.add_child(palettes)
	for option in [[tr("palette_amethyst"),Color("86bed4")],[tr("palette_plum"),Color("9bb9d5")],[tr("palette_indigo"),Color("7d9fc4")]]:
		var color: Color=option[1]
		var button:=Button.new(); button.text=option[0]; _style_button(button)
		button.add_theme_font_size_override("font_size",14)
		button.add_theme_color_override("font_color",color.lightened(0.45))
		button.pressed.connect(func(): _change_body_color(color))
		palettes.add_child(button)
	_slider(tr("gel_saturation"),0.5,1.6,0.05,float(character.gel.get_shader_parameter("saturation")),func(value:float):character.gel.set_shader_parameter("saturation",value))
	_slider(tr("dot_density"),8,40,1,float(character.gel.get_shader_parameter("density")),func(value:float):character.gel.set_shader_parameter("density",value))
	_slider(tr("dialogue_speed"),10,90,1,characters_per_second,func(value:float):characters_per_second=value)
	var check:=CheckButton.new(); check.text=tr("comic_pattern"); check.button_pressed=bool(character.gel.get_shader_parameter("screentone"))
	check.add_theme_color_override("font_color",WHITE); modal_body.add_child(check)
	check.toggled.connect(func(enabled:bool):character.gel.set_shader_parameter("screentone",enabled))
	var quality:=CheckButton.new(); quality.text=tr("low_resolution"); quality.button_pressed=$Stage.stretch_shrink==2
	quality.add_theme_color_override("font_color",WHITE); modal_body.add_child(quality)
	quality.toggled.connect(func(enabled:bool): $Stage.stretch_shrink=2 if enabled else 1)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED] and is_instance_valid(playfield):playfield.cancel_hold()
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_state()
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_inside_tree():
		# First press: a sad goodbye, then the game closes. A second press closes at once.
		if closing:
			get_tree().quit()
			return
		closing=true
		if is_instance_valid(modal):_close_modal()
		if study_mode:_set_study_mode(false)
		_react_sadly("farewell_dialogue")
		get_tree().create_timer(2.8).timeout.connect(func(): get_tree().quit())

func _change_body_color(color: Color) -> void:
	color.a=1.0
	resting_body_color=color
	if anger_remaining<=0:
		if anger_color_tween!=null and anger_color_tween.is_running():anger_color_tween.kill()
		character.gel.set_shader_parameter("base_color",color)
	save_timer=11.65

func _change_language(code: String) -> void:
	localization.set_language(code)
	DisplayServer.window_set_title(tr("window_title"))
	_update_stats()
	_set_sound_label()
	_set_mood(character.emotion)
	if not current_dialogue_key.is_empty(): say(dialogue_speaker,current_dialogue_key)
	if is_instance_valid(lesson_title):_show_lesson()
	_save_state()
	_open_settings()

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):get_tree().node_added.disconnect(_on_node_added)
	get_tree().auto_accept_quit=true
	if is_instance_valid(voice):
		voice.stream_paused=false
		voice.stop()
		voice.stream=null
	audio_playback=null
	localization.dispose()

func _setup_playfield() -> void:
	resting_body_color=character.gel.get_shader_parameter("base_color")
	playfield=preload("res://Playfield.gd").new()
	playfield.name="Playfield"
	add_child(playfield)
	playfield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	playfield.z_index=1
	playfield.thrown.connect(_on_character_thrown)
	playfield.tapped.connect(func(): perform_action("touch"))
	playfield.grabbed.connect(_on_character_grabbed)
	playfield.wall_hit.connect(_on_wall_hit)
	throw_counter=Label.new()
	throw_counter.name="ThrowCounter"
	throw_counter.mouse_filter=Control.MOUSE_FILTER_IGNORE
	throw_counter.add_theme_font_size_override("font_size",12)
	throw_counter.add_theme_color_override("font_color",MUTED)
	$Interface.add_child(throw_counter)
	_configure_playfield.call_deferred()

func _configure_playfield() -> void:
	if not is_instance_valid(playfield):return
	# The circle encloses the ears and tail; the transparent tile adds padding.
	var body_radius:float=$Stage.size.x*0.43
	playfield.configure(Rect2(Vector2.ZERO,size),rest_position,body_radius)
	throw_counter.position=indicators.position+Vector2(0,indicators.size.y+14) if size.x<size.y*1.05 else Vector2(size.x-290,182)
	_sync_physics_visual()

func _sync_physics_visual() -> void:
	if playfield.actor==null:return
	$Stage.position=playfield.actor.position-$Stage.size*0.5
	character.set_motion(playfield.actor.position,playfield.state)

func _on_character_grabbed() -> void:
	if character.reaction!=null and character.reaction.is_running():character.reaction.kill()
	character.squash=Vector3.ONE;character.lift=0
	character.on_grabbed()
	if anger_remaining<=0:character.emotion="curious";_set_mood("curious")

func _on_character_thrown(streak: int) -> void:
	total_throws+=1
	character.on_thrown(playfield.actor.linear_velocity)
	if streak>=3:
		_start_anger()
	elif anger_remaining<=0:
		character.emotion="curious";_set_mood("curious")
		say("speaker_lumien","throw_dialogue")
	play_bloop(530)
	_save_state()

func _on_wall_hit(speed: float) -> void:
	character.on_impact(speed)
	if speed>150:play_bloop(clampf(290+speed*0.08,290,470))

func _start_anger() -> void:
	if anger_remaining<=0 and not (anger_color_tween!=null and anger_color_tween.is_running()):
		resting_body_color=character.gel.get_shader_parameter("base_color")
	if anger_color_tween!=null and anger_color_tween.is_running():anger_color_tween.kill()
	anger_remaining=5.0
	playfield.angry=true
	character.emotion="angry";_set_mood("angry")
	character.gel.set_shader_parameter("base_color",Color("e58d82"))
	character.react("angry")
	say("speaker_lumien","angry_dialogue")

func _calm_down() -> void:
	character.react("shy",0.7)
	_set_mood("shy")
	playfield.angry=false;playfield.reset_streak()
	var current:Color=character.gel.get_shader_parameter("base_color")
	anger_color_tween=create_tween()
	anger_color_tween.tween_method(_apply_color_transition,current,resting_body_color,0.7).set_trans(Tween.TRANS_SINE)
	say("speaker_lumien","calm_dialogue")

func _apply_color_transition(color: Color) -> void:
	if anger_remaining<=0:character.gel.set_shader_parameter("base_color",color)

func _get_body_color() -> Color:
	if anger_remaining>0 or (anger_color_tween!=null and anger_color_tween.is_running()):return resting_body_color
	return character.gel.get_shader_parameter("base_color")

func _choose_background() -> void:
	if background_dialog_open:return
	if is_instance_valid(playfield):playfield.cancel_hold();playfield.input_enabled=false
	if not is_instance_valid(background_dialog):
		background_dialog=FileDialog.new()
		background_dialog.access=FileDialog.ACCESS_FILESYSTEM
		background_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
		background_dialog.use_native_dialog=true
		add_child(background_dialog)
		background_dialog.file_selected.connect(_load_background)
		background_dialog.canceled.connect(func():background_dialog_open=false)
	background_dialog.title=tr("background_dialog_title")
	background_dialog.clear_filters()
	background_dialog.add_filter("*.png,*.jpg,*.jpeg,*.webp",tr("image_filter"))
	background_dialog_open=true
	background_dialog.popup_centered_ratio(0.8)

func _load_background(path: String) -> bool:
	background_dialog_open=false
	var image:=Image.new()
	if image.load(path)!=OK or image.is_empty():
		_toast(tr("background_error"));return false
	var longest:int=maxi(image.get_width(),image.get_height())
	if longest>2560:
		var factor:float=2560.0/float(longest)
		image.resize(maxi(1,roundi(image.get_width()*factor)),maxi(1,roundi(image.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGBA8)
	if image.save_png(background_storage_path)!=OK:
		_toast(tr("background_save_error"));return false
	background.texture=ImageTexture.create_from_image(image)
	background.material=null
	custom_background_enabled=true
	_save_state()
	_toast(tr("background_loaded"))
	return true

func _restore_custom_background() -> void:
	if not custom_background_enabled:return
	var image:=Image.new()
	if image.load(background_storage_path)==OK and not image.is_empty():
		background.texture=ImageTexture.create_from_image(image)
		background.material=null
	else:custom_background_enabled=false

func _reset_background() -> void:
	custom_background_enabled=false
	_setup_background()
	_save_state()
	_toast(tr("background_reset"))


func _graphic_style(palette: String) -> StyleBoxTexture:
	var style:=StyleBoxTexture.new()
	style.texture=load("res://assets/panel_"+palette+".svg")
	style.texture_margin_left=26;style.texture_margin_right=30
	style.texture_margin_top=14;style.texture_margin_bottom=18
	style.content_margin_left=20;style.content_margin_right=22
	style.content_margin_top=9;style.content_margin_bottom=12
	return style

func _style_expressive_ui() -> void:
	var heading:Label=$Interface/Title/Name
	heading.add_theme_font_size_override("font_size",78)
	heading.add_theme_color_override("font_outline_color",Color("17132d"))
	heading.add_theme_constant_override("outline_size",14)
	heading.add_theme_color_override("font_shadow_color",Color("ff806f"))
	heading.add_theme_constant_override("shadow_offset_x",5)
	heading.add_theme_constant_override("shadow_offset_y",6)
	heading.rotation=-0.045
	commands.add_theme_constant_override("separation",10)
	var names: Array[String]=["Converse","Pet","Feed","Observe","Stories"]
	var palette: Array[String]=["mint","coral","cream","violet","mint"]
	for i in names.size():
		var button:Button=commands.get_node(names[i])
		button.custom_minimum_size.y=52
		button.add_theme_font_size_override("font_size",19)
		button.add_theme_constant_override("h_separation",11)
		button.add_theme_color_override("font_color",Color("14213b"))
		button.add_theme_color_override("font_hover_color",Color("14213b"))
		button.add_theme_color_override("font_pressed_color",Color("14213b"))
		button.add_theme_stylebox_override("normal",_graphic_style(palette[i]))
		button.add_theme_stylebox_override("hover",_graphic_style("cream"))
		button.add_theme_stylebox_override("pressed",_graphic_style("violet"))
		button.add_theme_stylebox_override("disabled",_graphic_style("night"))
		button.add_theme_color_override("font_disabled_color",Color("c4d5df"))
		button.rotation=-0.025 if i%2==0 else 0.018
	var paper:=StyleBoxTexture.new()
	paper.texture=load("res://assets/dialogue_paper.svg")
	paper.texture_margin_left=32;paper.texture_margin_right=40
	paper.texture_margin_top=30;paper.texture_margin_bottom=35
	paper.content_margin_left=24;paper.content_margin_right=24
	paper.content_margin_top=18;paper.content_margin_bottom=20
	dialogue.add_theme_stylebox_override("panel",paper)
	for bar in [trust_bar,energy_bar]:
		bar.custom_minimum_size.y=10
		var fill:=StyleBoxFlat.new()
		fill.bg_color=Color("68ead1") if bar==trust_bar else Color("ff967d")
		fill.skew=Vector2(-0.3,0)
		bar.add_theme_stylebox_override("fill",fill)
	for button in [advance,sound_button,$Interface/Utility/Background,$Interface/Utility/Settings,$Interface/Utility/Save,$Interface/Utility/Demo]:
		button.add_theme_stylebox_override("normal",_graphic_style("night"))
		button.add_theme_stylebox_override("hover",_graphic_style("violet"))
		button.add_theme_color_override("font_hover_color",Color("14213b"))

func _add_art_disclosure() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var label := Label.new()
	label.text = "art_ai_disclosure"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	label.position = Vector2(8, -24)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
