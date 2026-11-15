class_name TailDynamics3D
extends Node
@export var procedural_enabled: bool = true
@export_range(0.0,2.0) var mood_strength: float = 1.0
@export_range(0.0,2.0) var inertia_strength: float = 1.0
@export_range(1.0,35.0) var max_bend_degrees: float = 22.0
@export_range(0,60) var pose_fps: int = 0
var skeleton: Skeleton3D
var motion_source: Node3D
var bones: Array[int] = []
var rest: Array[Transform3D] = []
var controls: Array[Node3D] = []
var offsets: Array[Vector3] = []
var speeds: Array[Vector3] = []
var mood: int = 0
var _head: int = -1
var _head_rest := Transform3D.IDENTITY
var _previous_position := Vector3.ZERO
var _previous_rotation := Quaternion.IDENTITY
var _previous_velocity := Vector3.ZERO
var _acceleration := Vector3.ZERO
var _omega := Vector3.ZERO
var _initialized: bool = false
var _phase: float = 0.0
var _clock: float = 0.0
var _frequency: float = 0.55
var _amplitude := Vector3(0.085,0.012,0.07)
var _lift: float = 0.02
var _curl: float = 0.0
var _spring_frequency: float = 4.0
var _damping: float = 0.72
var _flick: float = 0.0
var _mood_tween: Tween

func _ready() -> void:
    assert(skeleton != null)
    _head = skeleton.find_bone("Head")
    _head_rest = skeleton.get_bone_global_rest(_head)
    var parent := Node3D.new()
    parent.name = "Tail_FK_Controls"
    skeleton.add_child(parent)
    parent.transform = _head_rest
    for i in 8:
        var index := skeleton.find_bone("Tail_%02d" % (i+1))
        assert(index>=0,"Missing tail joint")
        var control := Node3D.new()
        control.name = "FK_Tail_%02d" % (i+1)
        parent.add_child(control)
        control.transform = skeleton.get_bone_rest(index)
        bones.append(index)
        rest.append(skeleton.get_bone_rest(index))
        controls.append(control)
        offsets.append(Vector3.ZERO)
        speeds.append(Vector3.ZERO)
        parent = control
    reset_dynamics()

func set_mood(value: int, duration: float = 0.3) -> void:
    var previous := mood
    mood = clampi(value,0,6)
    if _mood_tween and _mood_tween.is_valid():_mood_tween.kill()
    var pose: Array
    match mood:
        # [frequency, amplitude (x lifts the tip, z sweeps it), lift, curl, spring Hz, damping, flick]
        # Every mood keeps a visible sway so the tail never freezes.
        1: pose = [3.2,Vector3(0.05,0.01,0.095),0.09,0.035,6.5,0.72,0.7]
        2: pose = [0.3,Vector3(0.04,0.004,0.03),-0.08,-0.015,2.8,0.8,0.0]
        3: pose = [1.2,Vector3(0.09,0.012,0.085),0.15,0.05,5.0,0.5,0.0]
        4: pose = [0.45,Vector3(0.055,0.006,0.045),0.025,0.0,4.2,0.7,0.0]
        5: pose = [1.7,Vector3(0.13,0.02,0.14),0.06,0.02,4.8,0.52,0.0]
        6: pose = [0.28,Vector3(0.045,0.004,0.03),-0.05,-0.008,2.4,0.85,0.0]
        _: pose = [0.55,Vector3(0.085,0.012,0.07),0.02,0.0,4.0,0.62,0.0]
    var properties := ["_frequency","_amplitude","_lift","_curl","_spring_frequency","_damping","_flick"]
    _mood_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    for i in properties.size():_mood_tween.tween_property(self,properties[i],pose[i],maxf(duration,0.01))
    if mood == 3 and previous != 3:add_impulse(Vector3(0.7,0,0.2))

func set_fk_rotation(joint: int, degrees: Vector3) -> void:
    var i := clampi(joint,0,7)
    controls[i].quaternion = rest[i].basis.get_rotation_quaternion()*Quaternion.from_euler(degrees*PI/180.0)

func reset_fk() -> void:
    for i in controls.size():controls[i].transform = rest[i]

func add_impulse(impulse: Vector3) -> void:
    for i in speeds.size():speeds[i] += impulse.limit_length(5.0)*(0.12+0.07*i)

func reset_dynamics() -> void:
    for i in offsets.size():offsets[i]=Vector3.ZERO;speeds[i]=Vector3.ZERO
    _previous_velocity = Vector3.ZERO
    _acceleration = Vector3.ZERO
    _omega = Vector3.ZERO
    _initialized = false
    _clock = 0.0

func _physics_process(delta: float) -> void:simulate(delta)

func simulate(delta: float) -> void:
    if delta<=0 or bones.is_empty():return
    var anchor := skeleton.global_transform*skeleton.get_bone_global_pose(_head)
    var rotation := anchor.basis.orthonormalized().get_rotation_quaternion()
    if not _initialized or anchor.origin.distance_to(_previous_position)>3.0 or delta>0.15:
        _previous_position=anchor.origin;_previous_rotation=rotation
        _previous_velocity=Vector3.ZERO;_acceleration=Vector3.ZERO;_omega=Vector3.ZERO
        _initialized=true
        _apply_pose()
        return
    var velocity := (anchor.origin-_previous_position)/delta
    var change := rotation*_previous_rotation.inverse()
    if change.w<0:change=-change
    var omega := change.get_axis()*change.get_angle()/delta if change.get_angle()>0.0001 else Vector3.ZERO
    var filter := 1.0-exp(-16.0*delta)
    _acceleration=_acceleration.lerp(((velocity-_previous_velocity)/delta).limit_length(35.0),filter)
    _omega=_omega.lerp(omega.limit_length(12.0),filter)
    _previous_position=anchor.origin;_previous_rotation=rotation;_previous_velocity=velocity
    var steps := maxi(1,int(ceil(delta/(1.0/120.0))))
    var dt := delta/steps
    for step in steps:
        _phase=fmod(_phase+TAU*_frequency*dt,TAU*100.0)
        for i in 8:
            var along := float(i+1)/8.0
            var phase := _phase-i*0.50
            # A travelling wave runs from base to tip. The vertical and sideways
            # components are a quarter cycle apart, so the tip draws a soft loop
            # instead of a flat pendulum swing; a slower ripple and a long drift
            # keep consecutive cycles from looking identical.
            var wave := sin(phase)
            var side_wave := sin(phase+PI*0.5)
            var flick_wave := (side_wave+0.35*sin(phase*3.0))/1.2
            var sway := lerpf(side_wave,flick_wave,_flick)
            var ripple := sin(phase*2.3+1.7)
            var drift := sin(_phase*0.31)
            var pose := Vector3(_lift+_curl*along,sin(phase*0.7)*_amplitude.y,(sway+0.25*drift)*_amplitude.z)
            pose.x += (wave*0.8+ripple*0.2+drift*0.35)*_amplitude.x
            pose *= (0.2+0.8*along)*mood_strength
            var orientation := (anchor.basis*_head_rest.basis.inverse()*skeleton.get_bone_global_rest(bones[i]).basis).orthonormalized()
            var force := orientation.inverse()*(-_acceleration-velocity*0.25)
            var spin := orientation.inverse()*_omega
            var inertia := (Vector3(force.z,0,-force.x)*0.007-spin*0.018)*(0.15+0.65*along)*inertia_strength
            var limit := deg_to_rad(max_bend_degrees)
            var target := (pose+inertia).limit_length(limit) if procedural_enabled else Vector3.ZERO
            var w := TAU*clampf(_spring_frequency*(1.15-along*0.35),0.5,8.0)
            speeds[i] += ((target-offsets[i])*w*w-speeds[i]*2.0*_damping*w)*dt
            offsets[i] += speeds[i]*dt
            if offsets[i].length()>limit:
                offsets[i]=offsets[i].limit_length(limit)
                speeds[i]*=0.4
    _clock+=delta
    if pose_fps==0 or _clock>=1.0/pose_fps:
        _clock=fmod(_clock,1.0/pose_fps) if pose_fps>0 else 0.0
        _apply_pose()

func _apply_pose() -> void:
    for i in 8:
        var base := rest[i].basis.get_rotation_quaternion()
        var manual := base.inverse()*controls[i].quaternion
        skeleton.set_bone_pose_position(bones[i],rest[i].origin)
        skeleton.set_bone_pose_rotation(bones[i],(base*manual*Quaternion.from_euler(offsets[i])).normalized())
        skeleton.set_bone_pose_scale(bones[i],controls[i].scale.clamp(Vector3.ONE*0.5,Vector3.ONE*1.5))
