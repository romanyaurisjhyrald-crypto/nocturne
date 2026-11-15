extends Node3D
## Adapts the rigged mouse to the existing care and save systems and layers
## squash and stretch, anticipation, follow-through and idle life on top of it.
signal interacted

const JELLY_HZ: float=3.2
const JELLY_DAMPING: float=0.3
const ROLL_HZ: float=2.2
const ROLL_DAMPING: float=0.42
const MAX_ROLL: float=0.12

var emotion: String = "shy"
## Tween-driven pose. `squash` multiplies the rig scale and `lift` raises it.
var squash:=Vector3.ONE
var lift: float=0.0
var lean: float=0.0
var turn: float=0.0
var shake: float=0.0
## Held tilt set by the scene (for example leaning toward the study chalkboard).
var pose_lean_target: float=0.0
var pose_lean: float=0.0
var reaction: Tween
var motion: Tween
var gel: ShaderMaterial
var rig: MouseFace3D
var clock: float=0.0
var previous_position:=Vector2.ZERO
var previous_velocity:=Vector2.ZERO
var motion_initialized:=false
var motion_state: String="idle"
var last_emotion: String=""
var target_yaw: float=0.0
var yaw: float=0.0
## Spring-driven jelly wobble: positive values stretch the body upwards.
var stretch: float=0.0
var stretch_speed: float=0.0
var stretch_target: float=0.0
var roll: float=0.0
var roll_speed: float=0.0
var target_roll: float=0.0
var breath_phase: float=0.0
var idle_timer: float=3.0
var gaze:=Vector2.ZERO
var rng:=RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()
    rig=preload("res://character/Mouse.tscn").instantiate()
    add_child(rig)
    gel=rig.active_comic_material
    gel.set_shader_parameter("base_color",Color("55c9ce"))
    gel.set_shader_parameter("saturation",0.92)
    gel.set_shader_parameter("density",24.0)
    gel.set_shader_parameter("screentone",false)
    var environment:=WorldEnvironment.new()
    var settings:=Environment.new()
    settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    settings.ambient_light_color=Color("bac9e9")
    settings.ambient_light_energy=0.65
    var sky:=Sky.new()
    var material:=ProceduralSkyMaterial.new()
    material.sky_top_color=Color("344660")
    material.sky_horizon_color=Color("b3d7e6")
    material.ground_bottom_color=Color("101528")
    sky.sky_material=material
    settings.sky=sky
    settings.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
    environment.environment=settings
    add_child(environment)
    for parameters in [[Vector3(-32,-25,0),Color("d4f8ff"),1.1],[Vector3(-20,145,0),Color("a685ff"),1.6]]:
        var light:=DirectionalLight3D.new()
        light.rotation_degrees=parameters[0]
        light.light_color=parameters[1]
        light.light_energy=parameters[2]
        add_child(light)

## Volume-preserving scale: taller means thinner and shorter means wider.
func _volume(vertical: float) -> Vector3:
    var lateral:=1.0/sqrt(maxf(vertical,0.2))
    return Vector3(lateral,vertical,lateral)

func _begin() -> void:
    # New tweens start from the current pose, so interrupting never pops.
    for tween in [reaction,motion]:
        if tween!=null and tween.is_valid():tween.kill()
    reaction=create_tween()
    motion=create_tween()

func _squash_key(vertical: float,duration: float,trans: Tween.TransitionType=Tween.TRANS_SINE,easing: Tween.EaseType=Tween.EASE_IN_OUT) -> void:
    reaction.tween_property(self,"squash",_volume(vertical),duration).set_trans(trans).set_ease(easing)

## Every key drives all four channels, so an interrupted move can never leave one stuck.
func _motion_key(duration: float,lift_to: float,lean_to: float,turn_to: float,shake_to: float,trans: Tween.TransitionType=Tween.TRANS_SINE,easing: Tween.EaseType=Tween.EASE_IN_OUT) -> void:
    motion.tween_property(self,"lift",lift_to,duration).set_trans(trans).set_ease(easing)
    motion.parallel().tween_property(self,"lean",lean_to,duration).set_trans(trans).set_ease(easing)
    motion.parallel().tween_property(self,"turn",turn_to,duration).set_trans(trans).set_ease(easing)
    motion.parallel().tween_property(self,"shake",shake_to,duration).set_trans(trans).set_ease(easing)

func stop_reaction() -> void:
    for tween in [reaction,motion]:
        if tween!=null and tween.is_valid():tween.kill()
    squash=Vector3.ONE
    lift=0.0;lean=0.0;turn=0.0;shake=0.0

func is_reacting() -> bool:
    return (reaction!=null and reaction.is_running()) or (motion!=null and motion.is_running())

func react(feeling: String,strength: float=1.0) -> void:
    emotion=feeling
    var side:=1.0 if rng.randf()<0.5 else -1.0
    match feeling:
        "happy":
            _hop(0.3*strength)
            rig.tail_rig.add_impulse(Vector3(3.5,0,1.5))
        "curious":
            _begin()
            _squash_key(0.93,0.1,Tween.TRANS_SINE,Tween.EASE_OUT)
            _squash_key(1.09,0.22,Tween.TRANS_BACK,Tween.EASE_OUT)
            reaction.tween_interval(0.55)
            _squash_key(1.0,0.6,Tween.TRANS_ELASTIC,Tween.EASE_OUT)
            _motion_key(0.1,0.0,0.0,0.0,0.0)
            _motion_key(0.3,0.0,0.09*side,-0.22*side,0.0,Tween.TRANS_BACK,Tween.EASE_OUT)
            motion.tween_interval(0.5)
            _motion_key(0.55,0.0,0.0,0.0,0.0)
            rig.ear_rig.twitch(0 if side>0 else 1,4.5*strength)
            rig.deform_eyes(Vector2(1.06,1.1),0.3)
            motion.tween_callback(rig.deform_eyes.bind(Vector2.ONE,0.4))
        "shy":
            _begin()
            _squash_key(0.87,0.18,Tween.TRANS_SINE,Tween.EASE_OUT)
            reaction.tween_interval(0.45)
            _squash_key(1.04,0.2)
            _squash_key(1.0,0.6,Tween.TRANS_ELASTIC,Tween.EASE_OUT)
            _motion_key(0.18,0.0,-0.05*side,0.3*side,0.01,Tween.TRANS_SINE,Tween.EASE_OUT)
            _motion_key(0.45,0.0,-0.05*side,0.3*side,0.0)
            _motion_key(0.5,0.0,0.0,0.0,0.0,Tween.TRANS_BACK,Tween.EASE_OUT)
            rig.ear_rig.flap(1.8*strength)
        "tired":
            _begin()
            # A slow yawn: stretch up, sag, then recover without any snap.
            _squash_key(1.07,0.55)
            _squash_key(0.86,0.6)
            _squash_key(1.0,0.9)
            _motion_key(0.55,0.0,0.03*side,0.0,0.0)
            _motion_key(0.6,0.0,-0.05*side,0.0,0.0)
            _motion_key(0.9,0.0,0.0,0.0,0.0)
            rig.ear_rig.flap(1.2*strength)
        "sad":
            _begin()
            # A slow sag with the head turned aside; nothing snaps.
            _squash_key(0.9,0.5)
            reaction.tween_interval(0.5)
            _squash_key(1.0,0.9)
            _motion_key(0.5,0.0,-0.06*side,0.12*side,0.0)
            _motion_key(0.5,0.0,-0.06*side,0.12*side,0.0)
            _motion_key(0.9,0.0,0.0,0.0,0.0)
            rig.ear_rig.flap(1.0*strength)
        "angry":
            _begin()
            _squash_key(0.88,0.08,Tween.TRANS_QUAD,Tween.EASE_OUT)
            _squash_key(1.13,0.12,Tween.TRANS_BACK,Tween.EASE_OUT)
            reaction.tween_interval(0.35)
            _squash_key(1.0,0.55,Tween.TRANS_ELASTIC,Tween.EASE_OUT)
            _motion_key(0.08,0.0,0.0,0.0,0.0)
            _motion_key(0.12,0.0,0.0,0.0,0.035*strength,Tween.TRANS_QUAD,Tween.EASE_OUT)
            _motion_key(0.35,0.0,0.0,0.0,0.028*strength)
            _motion_key(0.3,0.0,0.0,0.0,0.0)
            rig.ear_rig.flap(-2.5*strength)
            rig.tail_rig.add_impulse(Vector3(2.0,0,4.0))
        _:
            _begin()
            _squash_key(0.9,0.1,Tween.TRANS_SINE,Tween.EASE_OUT)
            _squash_key(1.0,0.55,Tween.TRANS_ELASTIC,Tween.EASE_OUT)
            _motion_key(0.2,0.0,0.0,0.0,0.0)
            rig.ear_rig.flap(1.5*strength)

## Anticipation crouch, stretched launch, squashed landing and an elastic settle.
func _hop(height: float) -> void:
    _begin()
    _squash_key(0.8,0.13,Tween.TRANS_SINE,Tween.EASE_OUT)
    _squash_key(1.15,0.1,Tween.TRANS_QUAD,Tween.EASE_OUT)
    _squash_key(1.0,0.16)
    _squash_key(1.06,0.18,Tween.TRANS_QUAD,Tween.EASE_IN)
    _squash_key(0.78,0.07,Tween.TRANS_QUAD,Tween.EASE_OUT)
    _squash_key(1.0,0.65,Tween.TRANS_ELASTIC,Tween.EASE_OUT)
    _motion_key(0.13,0.0,0.0,0.0,0.0)
    motion.tween_callback(rig.ear_rig.flap.bind(3.0))
    _motion_key(0.22,height,0.0,0.0,0.0,Tween.TRANS_QUAD,Tween.EASE_OUT)
    _motion_key(0.22,0.0,0.0,0.0,0.0,Tween.TRANS_QUAD,Tween.EASE_IN)
    motion.tween_callback(_touch_down)
    _motion_key(0.11,height*0.2,0.0,0.0,0.0,Tween.TRANS_QUAD,Tween.EASE_OUT)
    _motion_key(0.11,0.0,0.0,0.0,0.0,Tween.TRANS_QUAD,Tween.EASE_IN)

func _touch_down() -> void:
    rig.ear_rig.flap(3.5)
    rig.tail_rig.add_impulse(Vector3(-3.0,0,1.0))

## Wake-up used when the splash reveals the scene: rise from a crouch, then hop.
func greet() -> void:
    _begin()
    squash=_volume(0.84)
    rig.blink()
    _squash_key(1.1,0.38,Tween.TRANS_BACK,Tween.EASE_OUT)
    _squash_key(1.0,0.5,Tween.TRANS_ELASTIC,Tween.EASE_OUT)
    reaction.tween_callback(_hop.bind(0.22))
    _motion_key(0.3,0.0,0.0,0.0,0.0)
    rig.ear_rig.flap(-3.0)

func on_grabbed() -> void:
    stop_reaction()
    stretch_speed+=3.0
    rig.ear_rig.flap(-2.5)
    rig.deform_eyes(Vector2(1.1,1.16),0.35)

func on_thrown(_velocity: Vector2) -> void:
    stretch_speed+=2.4
    rig.tail_rig.add_impulse(Vector3(3.0,0,2.0))
    rig.deform_eyes(Vector2.ONE,0.4)

func on_impact(speed: float) -> void:
    var power:=clampf(speed/1900.0,0.15,1.0)
    stretch_speed-=2.5+5.0*power
    rig.ear_rig.flap(2.0+4.0*power)
    rig.tail_rig.add_impulse(Vector3(-2.0-2.0*power,0,3.0*power))
    if power>0.3:rig.blink()

func on_landed() -> void:
    stretch_speed-=2.6
    rig.ear_rig.flap(2.2)
    rig.deform_eyes(Vector2.ONE,0.4)

## Points the eyes toward a screen-space direction (x right, y down, about -1..1).
func look_toward(direction: Vector2) -> void:
    var wanted:=direction.limit_length(1.0)
    if emotion=="tired":wanted*=0.35
    if wanted.distance_to(gaze)<0.01:return
    gaze=wanted
    rig.set_gaze(gaze)

func set_motion(point: Vector2,state: String) -> void:
    var delta:=maxf(get_process_delta_time(),0.001)
    motion_state=state
    if not motion_initialized or state=="idle":
        previous_position=point
        previous_velocity=Vector2.ZERO
        motion_initialized=true
        target_yaw=0.0
        target_roll=0.0
        stretch_target=0.0
        return
    var velocity:Vector2=(point-previous_position)/delta
    var change:Vector2=(velocity-previous_velocity).limit_length(800.0)
    # Ears and tail trail behind screen-space acceleration.
    rig.ear_rig.add_impulse(Vector3(0,0,change.x*0.005))
    rig.ear_rig.flap(-change.y*0.005)
    rig.tail_rig.add_impulse(Vector3(change.y,0,change.x)*0.004)
    target_yaw=clampf(velocity.x/4000.0,-0.16,0.16)
    # The top of the body lags behind sideways motion and stretches along fast vertical motion.
    target_roll=clampf(velocity.x*0.0001,-MAX_ROLL,MAX_ROLL)
    stretch_target=clampf((absf(velocity.y)-absf(velocity.x)*0.6)/1900.0,-0.6,1.0)*0.12
    previous_velocity=velocity
    previous_position=point

func _idle_gesture() -> void:
    match rng.randi_range(0,4):
        0:
            rig.ear_rig.twitch(rng.randi_range(0,1),rng.randf_range(3.0,5.0))
        1:
            rig.ear_rig.flap(-2.0)
            stretch_speed+=0.6
        2:
            if emotion in ["angry","tired","sad"]:return
            var side:=1.0 if rng.randf()<0.5 else -1.0
            _begin()
            _squash_key(0.97,0.5)
            _squash_key(1.0,0.7)
            _motion_key(0.6,0.0,0.035*side,-0.08*side,0.0)
            _motion_key(0.9,0.0,0.0,0.0,0.0)
        3:
            rig.tail_rig.add_impulse(Vector3(4.0,0,1.5))
        4:
            if emotion=="happy":_hop(0.14)
            else:rig.blink()

func _process(delta: float) -> void:
    var step:=minf(delta,1.0/30.0)
    clock+=step
    # Jelly spring: impulses ring out as a volume-preserving wobble.
    var w:=TAU*JELLY_HZ
    stretch_speed+=((stretch_target-stretch)*w*w-stretch_speed*2.0*JELLY_DAMPING*w)*step
    stretch=clampf(stretch+stretch_speed*step,-0.3,0.2)
    var roll_w:=TAU*ROLL_HZ
    roll_speed+=((target_roll-roll)*roll_w*roll_w-roll_speed*2.0*ROLL_DAMPING*roll_w)*step
    roll=clampf(roll+roll_speed*step,-0.2,0.2)
    # Breathing never stops; it slows and deepens when tired and quickens when angry.
    var breath_rate:=0.16 if emotion=="tired" else 0.42 if emotion=="angry" else 0.27
    breath_phase=fmod(breath_phase+TAU*breath_rate*step,TAU*2.0)
    var breath:=sin(breath_phase)*(0.024 if emotion=="tired" else 0.016)
    var vertical:=maxf(0.5,1.0+stretch+breath)
    var lateral:=1.0/sqrt(vertical)
    rig.scale=Vector3(squash.x*lateral,squash.y*vertical,squash.z*lateral)
    rig.position=Vector3(sin(clock*52.0)*shake,lift,0.0)
    yaw=lerpf(yaw,target_yaw+turn,1.0-exp(-step*8.0))
    pose_lean=lerpf(pose_lean,pose_lean_target,1.0-exp(-step*5.0))
    rig.rotation=Vector3(0.0,yaw,roll+lean+pose_lean+sin(breath_phase*0.5+0.8)*0.01)
    idle_timer-=step
    if idle_timer<=0.0:
        idle_timer=rng.randf_range(2.6,6.0)
        if motion_state=="idle" and not is_reacting():_idle_gesture()
    if emotion!=last_emotion:
        var states:Dictionary={"shy":0,"happy":5,"curious":3,"tired":6,"angry":1,"sad":2}
        rig.set_mood(states.get(emotion,0),0.25)
        # [droop, forward, asymmetry] ear pose for each emotion.
        var ears:Dictionary={"shy":[0.055,0.06,0.0],"happy":[-0.05,0.0,0.0],"curious":[-0.02,0.02,0.07],"tired":[0.1,0.03,0.0],"angry":[-0.03,-0.11,0.0],"sad":[0.12,0.05,0.0]}
        var pose:Array=ears.get(emotion,[0.0,0.0,0.0])
        rig.ear_rig.set_pose(pose[0],pose[1],pose[2],0.45)
        last_emotion=emotion
