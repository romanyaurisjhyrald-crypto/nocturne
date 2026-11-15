extends Control
## Real screen-space rigid-body physics drives the existing 3D presentation.
signal thrown(streak: int)
signal tapped
signal grabbed
signal wall_hit(speed: float)
signal returned_home

const WALL_THICKNESS: float=28.0
const RETURN_DELAY: float=2.4
const RETURN_DURATION: float=0.85
const STREAK_WINDOW: float=9.0
const MAX_SPEED: float=1900.0
var actor: RigidBody2D
var walls: Array[StaticBody2D]=[]
var bounds:=Rect2()
var home:=Vector2.ZERO
var radius: float=75.0
var state: String="idle"
var input_enabled: bool=true
var throw_streak: int=0
var impact_count: int=0
var flight_remaining: float=0.0
var streak_remaining: float=0.0
var return_tween: Tween
var press_position:=Vector2.ZERO
var drag_offset:=Vector2.ZERO
var drag_target:=Vector2.ZERO
var pointer_id: int=-2
var drag_distance: float=0.0
var samples: Array[Vector3]=[]
var impact_light: float=0.0
var angry: bool=false

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	actor=RigidBody2D.new()
	actor.name="MousePhysics"
	actor.freeze=true
	actor.freeze_mode=RigidBody2D.FREEZE_MODE_KINEMATIC
	actor.lock_rotation=true
	actor.gravity_scale=0.52
	actor.linear_damp=0.16
	actor.continuous_cd=RigidBody2D.CCD_MODE_CAST_SHAPE
	actor.contact_monitor=true
	actor.max_contacts_reported=8
	var material:=PhysicsMaterial.new()
	material.bounce=0.84
	material.friction=0.06
	actor.physics_material_override=material
	var collider:=CollisionShape2D.new()
	collider.shape=CircleShape2D.new()
	actor.add_child(collider)
	add_child(actor)
	actor.body_entered.connect(_on_body_entered)
	for i in range(4):
		var wall:=StaticBody2D.new()
		wall.name="Wall%d" % i
		var shape:=CollisionShape2D.new()
		shape.shape=RectangleShape2D.new()
		wall.add_child(shape)
		add_child(wall)
		walls.append(wall)

func configure(rect: Rect2,home_position: Vector2,body_radius: float) -> void:
	if actor==null:return
	if return_tween!=null and return_tween.is_running():return_tween.kill()
	var old_state:=state
	var relative:=Vector2(0.5,0.5) if bounds.size==Vector2.ZERO else (actor.position-bounds.position)/bounds.size
	bounds=rect.grow(-2.0)
	radius=clampf(body_radius,18.0,minf(bounds.size.x,bounds.size.y)*0.44)
	(actor.get_child(0).shape as CircleShape2D).radius=radius
	home=_clamp_point(home_position)
	var t:float=WALL_THICKNESS
	var boxes:Array=[
		Rect2(bounds.position-Vector2(t,t),Vector2(bounds.size.x+t*2,t)),
		Rect2(Vector2(bounds.position.x-t,bounds.end.y),Vector2(bounds.size.x+t*2,t)),
		Rect2(bounds.position-Vector2(t,0),Vector2(t,bounds.size.y)),
		Rect2(Vector2(bounds.end.x,bounds.position.y),Vector2(t,bounds.size.y))
	]
	for i in range(4):
		walls[i].position=boxes[i].get_center()
		(walls[i].get_child(0).shape as RectangleShape2D).size=boxes[i].size
	if old_state=="idle":
		actor.freeze=true;actor.linear_velocity=Vector2.ZERO;actor.position=home
	else:
		actor.position=_clamp_point(bounds.position+relative*bounds.size)
		if old_state in ["held","returning"]:start_return()
	state="idle" if old_state=="idle" else state
	queue_redraw()

func _clamp_point(point: Vector2) -> Vector2:
	var safe:Rect2=bounds.grow(-radius-2.0)
	return Vector2(clampf(point.x,safe.position.x,safe.end.x),clampf(point.y,safe.position.y,safe.end.y))

func _input(event: InputEvent) -> void:
	# An owned pointer remains captured over UI; new presses go through GUI first.
	if not input_enabled or actor==null:
		cancel_hold()
		return
	var local_event:InputEvent=make_input_local(event)
	if event is InputEventMouseButton and event.device!=InputEvent.DEVICE_ID_EMULATION:
		if event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and pointer_id==-1:
			end_hold(local_event.position,-1)
	elif event is InputEventMouseMotion and event.device!=InputEvent.DEVICE_ID_EMULATION and pointer_id==-1:
		move_hold(local_event.position,-1)
	elif event is InputEventScreenTouch and pointer_id==event.index:
		if event.canceled:cancel_hold();get_viewport().set_input_as_handled()
		elif not event.pressed:end_hold(local_event.position,event.index)
	elif event is InputEventScreenDrag and pointer_id==event.index:
		move_hold(local_event.position,event.index)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or actor==null:return
	var local_event:InputEvent=make_input_local(event)
	if event is InputEventMouseButton and event.device!=InputEvent.DEVICE_ID_EMULATION:
		if event.button_index==MOUSE_BUTTON_LEFT and event.pressed:begin_hold(local_event.position,-1)
	elif event is InputEventScreenTouch and event.pressed and not event.canceled:
		begin_hold(local_event.position,event.index)

func begin_hold(point: Vector2,id: int) -> bool:
	if pointer_id!=-2 or not bounds.has_point(point) or point.distance_to(actor.position)>radius*1.08:return false
	if return_tween!=null and return_tween.is_running():return_tween.kill()
	pointer_id=id;press_position=point;drag_distance=0
	drag_offset=actor.position-point;drag_target=actor.position
	samples.clear();_sample(point)
	actor.freeze=true;actor.linear_velocity=Vector2.ZERO
	state="held"
	grabbed.emit()
	get_viewport().set_input_as_handled()
	return true

func move_hold(point: Vector2,id: int) -> void:
	if state!="held" or pointer_id!=id:return
	drag_distance=maxf(drag_distance,point.distance_to(press_position))
	drag_target=_clamp_point(point+drag_offset)
	_sample(point)
	get_viewport().set_input_as_handled()

func end_hold(point: Vector2,id: int) -> void:
	if state!="held" or pointer_id!=id:return
	move_hold(point,id)
	_sample(point)
	pointer_id=-2
	var velocity:=Vector2.ZERO
	if samples.size()>1:
		var first:Vector3=samples[0]
		var last:Vector3=samples[-1]
		var duration:float=maxf(0.016,last.z-first.z)
		velocity=(Vector2(last.x,last.y)-Vector2(first.x,first.y))/duration
	if drag_distance<10.0:
		tapped.emit();start_return();return
	if velocity.length()<120.0:
		start_return();return
	launch(velocity.limit_length(MAX_SPEED))
	get_viewport().set_input_as_handled()

func _sample(point: Vector2) -> void:
	var now:float=float(Time.get_ticks_msec())/1000.0
	samples.append(Vector3(point.x,point.y,now))
	while samples.size()>2 and now-samples[0].z>0.13:samples.pop_front()

func launch(velocity: Vector2) -> void:
	if return_tween!=null and return_tween.is_running():return_tween.kill()
	pointer_id=-2
	actor.freeze=false;actor.sleeping=false
	actor.linear_velocity=velocity.limit_length(MAX_SPEED)
	state="flying";flight_remaining=RETURN_DELAY
	if streak_remaining<=0:throw_streak=0
	throw_streak+=1;streak_remaining=STREAK_WINDOW
	thrown.emit(throw_streak)

func _physics_process(delta: float) -> void:
	impact_light=maxf(0.0,impact_light-delta*2.5)
	streak_remaining=maxf(0.0,streak_remaining-delta)
	if streak_remaining<=0:throw_streak=0
	if state=="idle":actor.position=home
	if state=="held":actor.position=actor.position.move_toward(drag_target,2400.0*delta)
	if state=="flying":
		flight_remaining-=delta
		# This is a recovery guard; normal bounce response comes from Godot physics.
		if flight_remaining<=0 or not bounds.grow(radius).has_point(actor.position):start_return()
	queue_redraw()

func start_return() -> void:
	if actor==null:return
	if return_tween!=null and return_tween.is_running():return_tween.kill()
	pointer_id=-2;state="returning"
	actor.freeze=true;actor.linear_velocity=Vector2.ZERO
	return_tween=create_tween()
	return_tween.tween_property(actor,"position",home,RETURN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return_tween.tween_callback(_finish_return)

func _finish_return() -> void:
	actor.position=home;state="idle"
	returned_home.emit()

func cancel_hold() -> void:
	if state=="held":start_return()

func reset_streak() -> void:
	throw_streak=0;streak_remaining=0

func _on_body_entered(_body: Node) -> void:
	if state!="flying":return
	impact_count+=1;impact_light=1.0
	wall_hit.emit(actor.linear_velocity.length())

func _draw() -> void:
	# Screen edges are physical boundaries, not a visible enclosure.
	pass
