extends RefCounted
## Comic-style button feel: an elastic pop on press and a light lift on hover.

const PRESS_SCALE: float=1.16
const HOVER_SCALE: float=1.045
const TWEEN_META: StringName=&"juice_tween"
const ATTACHED_META: StringName=&"juice_attached"

static func attach(button: BaseButton,on_click: Callable) -> void:
	if button.has_meta(ATTACHED_META):return
	button.set_meta(ATTACHED_META,true)
	button.pressed.connect(func() -> void:_on_pressed(button,on_click))
	button.mouse_entered.connect(func() -> void:_ease_to(button,HOVER_SCALE,0.14))
	button.mouse_exited.connect(func() -> void:_ease_to(button,1.0,0.2))

static func _on_pressed(button: BaseButton,on_click: Callable) -> void:
	bounce(button)
	if on_click.is_valid():on_click.call()

static func _restart(button: Control) -> Tween:
	var previous: Variant=button.get_meta(TWEEN_META) if button.has_meta(TWEEN_META) else null
	if previous is Tween and previous.is_valid():previous.kill()
	button.pivot_offset=button.size*0.5
	var tween:=button.create_tween()
	button.set_meta(TWEEN_META,tween)
	return tween

## Grows quickly past its size, then settles back with an elastic wobble.
static func bounce(button: Control,peak: float=PRESS_SCALE) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree():return
	var tween:=_restart(button)
	tween.tween_property(button,"scale",Vector2(peak,peak),0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button,"scale",Vector2.ONE,0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

static func _ease_to(button: Control,target: float,duration: float) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree():return
	var base:=button as BaseButton
	if base!=null and base.disabled:return
	var tween:=_restart(button)
	tween.tween_property(button,"scale",Vector2(target,target),duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
