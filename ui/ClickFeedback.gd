extends CanvasLayer
## Pointer feedback drawn above everything: a pop where the user clicks and a
## pulsing marker that follows the pointer while it is held down.
## Drop `assets/click.png` and `assets/hold_click.png` to replace the bundled art.

const AssetLoader=preload("res://ui/AssetLoader.gd")
var click_paths:=PackedStringArray(["res://assets/click.png","res://assets/click.webp","res://assets/click.svg"])
var hold_paths:=PackedStringArray(["res://assets/hold_click.png","res://assets/hold_click.webp","res://assets/hold_click.svg"])
const NO_POINTER: int=-2
const MOUSE_POINTER: int=-1
const HOLD_DELAY: float=0.28
const MARK_SIZE: float=88.0

var click_texture: Texture2D
var hold_texture: Texture2D
var pointer_id: int=NO_POINTER
var pointer_position:=Vector2.ZERO
var held_time: float=0.0
var hold_mark: Sprite2D
var hold_pulse: Tween
var click_count: int=0
var hold_count: int=0

func _ready() -> void:
	layer=110
	process_mode=Node.PROCESS_MODE_ALWAYS
	click_texture=AssetLoader.load_texture(click_paths)
	hold_texture=AssetLoader.load_texture(hold_paths)
	set_process(false)

func _input(event: InputEvent) -> void:
	# Observes input without consuming it, so gameplay and GUI are unaffected.
	if event is InputEventMouseButton:
		if event.button_index!=MOUSE_BUTTON_LEFT or event.device==InputEvent.DEVICE_ID_EMULATION:return
		if event.pressed:_press(event.position,MOUSE_POINTER)
		else:_release(MOUSE_POINTER)
	elif event is InputEventScreenTouch:
		if event.pressed and not event.canceled:_press(event.position,event.index)
		else:_release(event.index)
	elif event is InputEventMouseMotion:
		if pointer_id==MOUSE_POINTER:pointer_position=event.position
	elif event is InputEventScreenDrag:
		if pointer_id==event.index:pointer_position=event.position

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT or what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release(pointer_id)

func _base_scale(texture: Texture2D) -> float:
	return MARK_SIZE/maxf(1.0,float(maxi(texture.get_width(),texture.get_height())))

func _press(point: Vector2,id: int) -> void:
	if pointer_id!=NO_POINTER and pointer_id!=id:return
	_release(pointer_id)
	pointer_id=id
	pointer_position=point
	held_time=0.0
	set_process(true)
	click_count+=1
	if click_texture==null:return
	var mark:=Sprite2D.new()
	mark.texture=click_texture
	mark.position=point
	var base:=_base_scale(click_texture)
	mark.scale=Vector2.ONE*base*0.3
	mark.rotation=randf_range(-0.35,0.35)
	add_child(mark)
	var tween:=mark.create_tween()
	tween.tween_property(mark,"scale",Vector2.ONE*base,0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(mark,"rotation",0.0,0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(mark,"scale",Vector2.ONE*base*1.3,0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(mark,"modulate:a",0.0,0.24)
	tween.tween_callback(mark.queue_free)

func _process(delta: float) -> void:
	if pointer_id==NO_POINTER:
		set_process(false)
		return
	held_time+=delta
	if hold_mark==null and held_time>=HOLD_DELAY:_show_hold()
	if hold_mark!=null:
		hold_mark.position=hold_mark.position.lerp(pointer_position,1.0-exp(-delta*28.0))
		hold_mark.rotation+=delta*1.4

func _show_hold() -> void:
	hold_count+=1
	if hold_texture==null:return
	hold_mark=Sprite2D.new()
	hold_mark.texture=hold_texture
	hold_mark.position=pointer_position
	var base:=_base_scale(hold_texture)
	hold_mark.scale=Vector2.ONE*base*0.35
	hold_mark.modulate.a=0.0
	add_child(hold_mark)
	hold_pulse=hold_mark.create_tween()
	hold_pulse.tween_property(hold_mark,"scale",Vector2.ONE*base,0.38).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	hold_pulse.parallel().tween_property(hold_mark,"modulate:a",1.0,0.12)
	hold_pulse.tween_callback(_start_pulse.bind(hold_mark,base))

func _start_pulse(mark: Sprite2D,base: float) -> void:
	if mark!=hold_mark:return
	hold_pulse=mark.create_tween().set_loops()
	hold_pulse.tween_property(mark,"scale",Vector2.ONE*base*1.14,0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hold_pulse.tween_property(mark,"scale",Vector2.ONE*base,0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _release(id: int) -> void:
	if pointer_id==NO_POINTER or pointer_id!=id:return
	pointer_id=NO_POINTER
	set_process(false)
	if hold_mark==null:return
	var mark:=hold_mark
	hold_mark=null
	if hold_pulse!=null and hold_pulse.is_valid():hold_pulse.kill()
	var tween:=mark.create_tween()
	tween.tween_property(mark,"scale",mark.scale*1.45,0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(mark,"modulate:a",0.0,0.22)
	tween.tween_callback(mark.queue_free)
