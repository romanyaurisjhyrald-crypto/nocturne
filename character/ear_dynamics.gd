class_name EarDynamics3D
extends Node
@export var enabled: bool = true
@export_range(0.5,8.0) var frequency_hz: float = 3.5
@export_range(0.1,1.25) var damping_ratio: float = 0.55
@export_range(0.0,2.0) var inertia_strength: float = 1.0
@export_range(0.0,45.0) var max_bend_degrees: float = 24.0
@export_range(0.0,0.4) var stretch_amount: float = 0.16
@export_range(0,60) var pose_fps: int = 0
var skeleton: Skeleton3D
var motion_source: Node3D
var controls: Array[Node3D] = []
var bones: Array[int] = []
var rest: Array[Transform3D] = []
var offsets: Array[Vector3] = []
var speeds: Array[Vector3] = []
var _previous_position := Vector3.ZERO
var _previous_rotation := Quaternion.IDENTITY
var _previous_velocity := Vector3.ZERO
var _previous_omega := Vector3.ZERO
var _acceleration := Vector3.ZERO
var _angular_acceleration := Vector3.ZERO
var _stretch: float = 0.0
var _stretch_speed: float = 0.0
var _clock: float = 0.0
var _initialized: bool = false
var _head_index: int = -1
## Expressive pose added to the spring target, in radians per joint.
## Positive droop lowers both ears outward; positive forward folds them toward the viewer;
## asymmetry lowers the right ear while raising the left one.
var pose_droop: float = 0.0
var pose_forward: float = 0.0
var pose_asymmetry: float = 0.0
var _pose_tween: Tween
var _idle_phase: float = 0.0

func _ready() -> void:
    assert(skeleton != null and motion_source != null)
    var fk := Node3D.new()
    fk.name = "Ear_FK_Controls"
    skeleton.add_child(fk)
    var head := skeleton.find_bone("Head")
    _head_index = head
    fk.transform = skeleton.get_bone_global_rest(head)
    for side in ["L","R"]:
        var parent: Node3D = fk
        for i in 4:
            var name := "Ear_%s_%02d" % [side,i+1]
            var index := skeleton.find_bone(name)
            assert(index >= 0,"Missing bone: " + name)
            var control := Node3D.new()
            control.name = "FK_"+name
            parent.add_child(control)
            control.transform = skeleton.get_bone_rest(index)
            control.set_meta("usage","Rotate locally for FK; positive local Y scale stretches the bone.")
            controls.append(control)
            bones.append(index)
            rest.append(skeleton.get_bone_rest(index))
            offsets.append(Vector3.ZERO)
            speeds.append(Vector3.ZERO)
            parent = control
    reset_dynamics()

func _physics_process(delta: float) -> void:
    simulate(delta)

func reset_dynamics() -> void:
    for i in offsets.size():
        offsets[i] = Vector3.ZERO
        speeds[i] = Vector3.ZERO
    _stretch = 0.0
    _stretch_speed = 0.0
    _acceleration = Vector3.ZERO
    _angular_acceleration = Vector3.ZERO
    _previous_velocity = Vector3.ZERO
    _previous_omega = Vector3.ZERO
    var anchor := _motion_transform()
    _previous_position = anchor.origin
    _previous_rotation = anchor.basis.orthonormalized().get_rotation_quaternion()
    _initialized = false
    _clock = 0.0

func set_fk_rotation(side: String, joint: int, degrees: Vector3) -> void:
    var i := (0 if side.to_upper() == "L" else 4) + clampi(joint,0,3)
    var delta := Quaternion.from_euler(degrees * PI / 180.0)
    controls[i].quaternion = rest[i].basis.get_rotation_quaternion() * delta

func set_ear_stretch(side: String, factor: float) -> void:
    var i := 0 if side.to_upper() == "L" else 4
    var safe := clampf(factor,0.6,1.5)
    controls[i].scale = Vector3(1.0/sqrt(safe),safe,1.0/sqrt(safe))

func reset_fk() -> void:
    for i in controls.size(): controls[i].transform = rest[i]

func set_pose(droop: float, forward: float, asymmetry: float, duration: float = 0.35) -> void:
    if _pose_tween and _pose_tween.is_valid():_pose_tween.kill()
    _pose_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _pose_tween.tween_property(self,"pose_droop",droop,maxf(duration,0.01))
    _pose_tween.tween_property(self,"pose_forward",forward,maxf(duration,0.01))
    _pose_tween.tween_property(self,"pose_asymmetry",asymmetry,maxf(duration,0.01))

## Symmetric kick: positive values throw both ears down and outward, negative values perk them up.
func flap(amount: float) -> void:
    for i in speeds.size():
        var side := -1.0 if i < 4 else 1.0
        speeds[i].z += -side * amount * (0.3 + 0.25 * (i % 4))

## Quick flick of a single ear (0 = left, 1 = right) that the spring then settles.
func twitch(side_index: int, amount: float = 4.0) -> void:
    var first := clampi(side_index,0,1) * 4
    var side := -1.0 if first == 0 else 1.0
    for joint in 4:
        speeds[first+joint].z += side * amount * (0.2 + 0.3 * joint)
        speeds[first+joint].x += amount * 0.08 * joint

func add_impulse(local_impulse: Vector3) -> void:
    for i in speeds.size():
        var amount := 0.15 + 0.2 * (i % 4)
        speeds[i] += local_impulse.limit_length(10.0) * amount

func simulate(delta: float) -> void:
    if delta <= 0.0 or bones.is_empty():return
    var anchor := _motion_transform()
    var position := anchor.origin
    var rotation := anchor.basis.orthonormalized().get_rotation_quaternion()
    if not _initialized or position.distance_to(_previous_position) > 3.0 or delta > 0.15:
        _previous_position = position
        _previous_rotation = rotation
        _previous_velocity = Vector3.ZERO
        _previous_omega = Vector3.ZERO
        _initialized = true
        _apply_pose()
        return
    var velocity := (position-_previous_position)/delta
    var change := rotation * _previous_rotation.inverse()
    if change.w < 0.0: change = -change
    var omega := change.get_axis() * change.get_angle() / delta if change.get_angle() > 0.0001 else Vector3.ZERO
    var inverse := anchor.basis.orthonormalized().inverse()
    var acceleration := inverse * ((velocity-_previous_velocity)/delta).limit_length(35.0)
    var angular_accel := inverse * ((omega-_previous_omega)/delta).limit_length(45.0)
    var filter := 1.0-exp(-18.0*delta)
    _acceleration = _acceleration.lerp(acceleration,filter)
    _angular_acceleration = _angular_acceleration.lerp(angular_accel,filter)
    var local_velocity := inverse*velocity
    var local_omega := inverse*omega
    _previous_position = position
    _previous_rotation = rotation
    _previous_velocity = velocity
    _previous_omega = omega
    var steps := maxi(1,int(ceil(delta/(1.0/120.0))))
    var dt := delta/steps
    for step in steps:
        for i in bones.size():
            var joint := i % 4
            var side := -1.0 if i < 4 else 1.0
            var strength := (0.12+joint*0.23)*inertia_strength
            var drive := Vector3(
                -_acceleration.z*0.018-_acceleration.y*0.006-_angular_acceleration.x*0.012-local_velocity.z*0.003,
                -local_omega.y*0.008*side,
                _acceleration.x*0.012-_angular_acceleration.z*0.01-side*_acceleration.y*0.007)
            var target := (drive*strength).limit_length(deg_to_rad(max_bend_degrees)) if enabled else Vector3.ZERO
            if enabled:
                # Mood pose plus a slow breathing sway keep the ears alive at rest.
                var droop := pose_droop + side*pose_asymmetry + sin(_idle_phase+side*0.9)*0.014
                target += Vector3(pose_forward,0.0,-side*droop)*(0.55+0.15*joint)
            var w := TAU*clampf(frequency_hz*(1.20-joint*0.12),0.5,8.0)
            speeds[i] += ((target-offsets[i])*w*w - speeds[i]*2.0*damping_ratio*w)*dt
            offsets[i] += speeds[i]*dt
            var limit := deg_to_rad(max_bend_degrees)
            if offsets[i].length()>limit:
                offsets[i] = offsets[i].limit_length(limit)
                speeds[i] *= 0.45
        var stretch_target := clampf(_acceleration.y*0.005,-stretch_amount,stretch_amount) if enabled else 0.0
        var sw := TAU*3.0
        _stretch_speed += ((stretch_target-_stretch)*sw*sw-_stretch_speed*2.0*0.7*sw)*dt
        _stretch = clampf(_stretch+_stretch_speed*dt,-0.25,0.25)
    _idle_phase = fmod(_idle_phase+delta*1.9,TAU)
    _clock += delta
    if pose_fps == 0 or _clock >= 1.0/pose_fps:
        _clock = fmod(_clock,1.0/pose_fps) if pose_fps>0 else 0.0
        _apply_pose()

func _apply_pose() -> void:
    var length_scale := pow(maxf(0.6,1.0+_stretch),0.25) if enabled else 1.0
    for i in bones.size():
        var rest_rotation := rest[i].basis.get_rotation_quaternion()
        var fk_delta := rest_rotation.inverse()*controls[i].quaternion
        var spring := Quaternion.from_euler(offsets[i]) if enabled else Quaternion.IDENTITY
        skeleton.set_bone_pose_position(bones[i],rest[i].origin)
        skeleton.set_bone_pose_rotation(bones[i],(rest_rotation*fk_delta*spring).normalized())
        var safe_scale := controls[i].scale.clamp(Vector3.ONE*0.4,Vector3.ONE*1.8)
        skeleton.set_bone_pose_scale(bones[i],safe_scale*Vector3(1.0/sqrt(length_scale),length_scale,1.0/sqrt(length_scale)))

func _motion_transform() -> Transform3D:
    if _head_index >= 0:
        return skeleton.global_transform*skeleton.get_bone_global_pose(_head_index)
    return motion_source.global_transform
