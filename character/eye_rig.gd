class_name EyeRig2D
extends Node2D

enum EyeExpression { NEUTRAL, ANGRY, SAD, SURPRISED, SQUINT, HAPPY, TIRED }

@export_group("Shape in local pixels")
@export var eye_radii := Vector2(92.0, 66.0)
@export_range(16, 128, 2) var segments: int = 64
@export var iris_radius: float = 39.0
@export var pupil_radius: float = 9.0
@export var max_radius: float = 25.0
@export_group("Graphic style")
@export_enum("Star", "Cross", "Round") var pupil_style: int = 1
@export var iris_color := Color("39cfc7")
@export var pupil_color := Color("543331")
@export var ink_color := Color("281323")
@export var lid_color := Color("ed887d")
@export var look_sensitivity: float = 0.18
@export var look_speed: float = 12.0
@export var highlight_speed: float = 6.0
@export_range(0.0, 0.5) var perspective_amount: float = 0.24
@export_enum("Right:1", "Left:-1") var expression_side: int = 1
@export_group("Blink")
@export var auto_blink: bool = true
@export var blink_interval := Vector2(2.5, 5.5)
@export var close_duration: float = 0.075
@export var open_duration: float = 0.15

@onready var deform: Node2D = $DeformContainer
@onready var sclera: Polygon2D = $DeformContainer/Sclera
@onready var iris: Node2D = $DeformContainer/Sclera/Iris
@onready var highlights: Node2D = $DeformContainer/Sclera/Highlights
@onready var blink_timer: Timer = $BlinkTimer

var expression: EyeExpression = EyeExpression.NEUTRAL
var _target_global := Vector2.ZERO
var _tracking: bool = false
var _rng := RandomNumberGenerator.new()
var _expression_tween: Tween
var _deform_tween: Tween
var _blink_tween: Tween
var _rotation_tween: Tween
var _blink_amount: float = 0.0
var _upper_open: float = 0.95
var _lower_open: float = 0.95
var _upper_tilt: float = 0.0
var _lower_tilt: float = 0.0
var _upper_curve: float = 0.0
var _lower_curve: float = 0.0
var _upper_roundness: float = 0.65
var _lower_roundness: float = 0.85
var _corner_lift: float = 0.10
var _shape_width: float = 1.0
var _iris_shade: Polygon2D
var _smile_close: float = 0.0
var _iris_tint := Color("39cfc7")

func _ready() -> void:
    _rng.randomize()
    sclera.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
    $DeformContainer/Outline.polygon = _ellipse(eye_radii + Vector2(4, 4))
    $DeformContainer/Sclera/Iris/Color.polygon = _ellipse(Vector2.ONE * iris_radius)
    $DeformContainer/Sclera/Iris/Pupil.polygon = _ellipse(Vector2.ONE * pupil_radius)
    _build_graphic_style()
    set_expression(EyeExpression.NEUTRAL, 0.01)
    blink_timer.timeout.connect(_on_blink_timeout)
    _schedule_blink()
    _update_lids()

func _process(delta: float) -> void:
    deform.scale = Vector2(maxf(deform.scale.x, 0.08), maxf(deform.scale.y, 0.08))
    var wanted := Vector2.ZERO
    var radius := maxf(max_radius, 0.0)
    if _tracking:
        wanted = (deform.to_local(_target_global) * look_sensitivity).limit_length(radius)
    var weight := 1.0 - exp(-maxf(look_speed, 0.0) * delta)
    iris.position = iris.position.lerp(wanted, weight).limit_length(radius)
    var ratio := clampf(iris.position.length() / maxf(radius, 0.001), 0.0, 1.0)
    iris.rotation = iris.position.angle() if ratio > 0.001 else 0.0
    iris.scale = Vector2(1.0 - perspective_amount * ratio, 1.0)
    $DeformContainer/Sclera/Iris/Pupil.rotation = -iris.rotation
    if _iris_shade:
        _iris_shade.rotation = -iris.rotation
    highlights.position = highlights.position.lerp(
        iris.position, 1.0 - exp(-maxf(highlight_speed, 0.0) * delta))
    $DeformContainer/Sclera/Iris/Color.color = _iris_tint.darkened(0.22)
    $DeformContainer/Sclera/Iris/Color.get_child(0).color = _iris_tint
    _update_lids()

func look_at_target(target_global: Vector2) -> void:
    _target_global = target_global
    _tracking = true

func reset_look() -> void:
    _tracking = false

func deform_eye(target_scale: Vector2, duration: float = 0.35) -> void:
    if _deform_tween and _deform_tween.is_valid():
        _deform_tween.kill()
    var safe_scale := Vector2(clampf(target_scale.x, 0.15, 3.0), clampf(target_scale.y, 0.15, 3.0))
    _deform_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    _deform_tween.tween_property(deform, "scale", safe_scale, maxf(duration, 0.01))

func rotate_eye(angle_radians: float, duration: float = 0.25) -> void:
    if _rotation_tween and _rotation_tween.is_valid():
        _rotation_tween.kill()
    _rotation_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _rotation_tween.tween_property(deform, "rotation", angle_radians, maxf(duration, 0.01))

func set_expression(value: EyeExpression, duration: float = 0.22) -> void:
    expression = value
    if _expression_tween and _expression_tween.is_valid():
        _expression_tween.kill()
    var pose: Array
    match value:
        EyeExpression.ANGRY: pose = [0.32, 0.87, 0.37, 0.0, 0.01, 0.0, 0.17, 0.80, 0.08, 1.02]
        EyeExpression.SAD: pose = [0.56, 0.72, -0.28, 0.0, 0.0, -0.10, 0.75, 1.1, 0.06, 0.94]
        EyeExpression.SURPRISED: pose = [1.10, 1.03, 0.0, 0.0, 0.0, 0.0, 1.12, 1.0, 0.0, 0.84]
        EyeExpression.SQUINT: pose = [0.20, 0.27, 0.12, 0.0, 0.02, -0.02, 0.20, 0.65, 0.05, 1.03]
        EyeExpression.HAPPY: pose = [0.48, 0.12, -0.02, 0.0, -0.08, -0.35, 0.85, 0.7, 0.16, 1.02]
        EyeExpression.TIRED: pose = [0.09, 0.43, 0.01, 0.0, 0.0, 0.0, 0.12, 0.85, 0.0, 1.0]
        _: pose = [0.20, 0.83, 0.025, 0.0, 0.0, 0.0, 0.15, 0.85, 0.02, 1.0]
    if expression_side == -1:
        pose[0] *= 0.90 if value == EyeExpression.SQUINT else 0.96
        pose[1] *= 0.97
    var properties := ["_upper_open", "_lower_open", "_upper_tilt", "_lower_tilt", "_upper_curve", "_lower_curve", "_upper_roundness", "_lower_roundness", "_corner_lift", "_shape_width"]
    _expression_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    for i in properties.size():
        _expression_tween.tween_property(self, properties[i], pose[i], maxf(duration, 0.01))
    _expression_tween.tween_property(self, "_iris_tint", Color("fa681f") if value == EyeExpression.ANGRY else iris_color, maxf(duration, 0.01))
    _expression_tween.tween_property(self, "_smile_close", 1.0 if value == EyeExpression.HAPPY else 0.0, maxf(duration, 0.01))

func blink() -> void:
    if _blink_tween and _blink_tween.is_running():
        return
    blink_timer.stop()
    _blink_tween = create_tween()
    _blink_tween.tween_property(self, "_blink_amount", 1.0, maxf(close_duration, 0.01)).set_trans(Tween.TRANS_SINE)
    _blink_tween.tween_interval(0.035)
    _blink_tween.tween_property(self, "_blink_amount", 0.0, maxf(open_duration, 0.01)).set_trans(Tween.TRANS_SINE)
    _blink_tween.tween_callback(_schedule_blink)

func _on_blink_timeout() -> void:
    if auto_blink:
        blink()

func _schedule_blink() -> void:
    if auto_blink:
        var minimum := maxf(0.2, minf(blink_interval.x, blink_interval.y))
        blink_timer.start(_rng.randf_range(minimum, maxf(minimum, maxf(blink_interval.x, blink_interval.y))))

func _ellipse(radii: Vector2) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in maxi(segments, 16):
        var angle := TAU * float(i) / maxi(segments, 16)
        points.append(Vector2(cos(angle), sin(angle)) * radii)
    return points

func _update_lids() -> void:
    var top := PackedVector2Array()
    var bottom := PackedVector2Array()
    var outer_top := PackedVector2Array()
    var outer_bottom := PackedVector2Array()
    var count := maxi(segments / 2, 8)
    var openness := (1.0 - clampf(_blink_amount, 0.0, 1.0)) * (1.0 - _smile_close)
    for i in range(count + 1):
        var t := -1.0 + 2.0 * float(i) / count
        var envelope := sqrt(maxf(0.0, 1.0 - t * t))
        var x := t * eye_radii.x * _shape_width
        var height := envelope * eye_radii.y
        var baseline := eye_radii.y * (-_corner_lift * (1.0 - envelope) + _upper_tilt * t * expression_side)
        baseline -= eye_radii.y * 0.65 * envelope * _smile_close
        var upper := eye_radii.y * (-_upper_open * pow(envelope, _upper_roundness) + _upper_curve * envelope * envelope)
        var lower := eye_radii.y * (_lower_open * pow(envelope, _lower_roundness) + _lower_tilt * t * envelope * expression_side + _lower_curve * envelope * envelope)
        upper = minf(upper, -height * 0.02)
        lower = maxf(lower, height * 0.02)
        top.append(Vector2(x, baseline + upper * openness))
        bottom.append(Vector2(x, baseline + lower * openness))
        outer_top.append(Vector2(x, baseline - height))
        outer_bottom.append(Vector2(x, baseline + height))
    var aperture := top.duplicate()
    for i in range(bottom.size() - 2, 0, -1):
        aperture.append(bottom[i])
    sclera.visible = openness > 0.001
    if sclera.visible:
        sclera.polygon = aperture
    var shadow_points := top.duplicate()
    for k in range(top.size()-2, 0, -1):
        shadow_points.append(top[k] + Vector2(0, 7.0))
    $DeformContainer/Sclera/LidShadow.polygon = shadow_points
    $DeformContainer/UpperLid.polygon = _lid_polygon(outer_top, top)
    $DeformContainer/LowerLid.polygon = _lid_polygon(outer_bottom, bottom)
    $DeformContainer/UpperEdge.points = top
    $DeformContainer/LowerEdge.points = bottom
    $DeformContainer/Ink.set_contours(top, bottom, expression_side, ink_color, 1.0 - openness)

func _build_graphic_style() -> void:
    $DeformContainer/Outline.color = ink_color
    $DeformContainer/Outline.visible = false
    $DeformContainer/UpperLid.visible = false
    $DeformContainer/LowerLid.visible = false
    $DeformContainer/UpperEdge.visible = false
    $DeformContainer/LowerEdge.visible = false
    $DeformContainer/UpperLid.color = lid_color
    $DeformContainer/LowerLid.color = lid_color
    $DeformContainer/UpperEdge.default_color = ink_color
    $DeformContainer/LowerEdge.default_color = ink_color
    $DeformContainer/Sclera.color = Color("fff1c7")
    $DeformContainer/Sclera/Iris/Color.color = iris_color.darkened(0.18)
    var iris_fill: Polygon2D = $DeformContainer/Sclera/Iris/Color
    var center := Polygon2D.new()
    center.polygon = _ellipse(Vector2.ONE * iris_radius * 0.94)
    center.color = iris_color
    var shading := ShaderMaterial.new()
    shading.shader = preload("res://character/iris_shading.gdshader")
    shading.set_shader_parameter("radius", iris_radius)
    center.material = shading
    _iris_shade = center
    iris_fill.add_child(center)
    var shadow := Polygon2D.new()
    sclera.add_child(shadow)
    sclera.move_child(shadow, 0)
    shadow.name = "LidShadow"
    shadow.color = Color(0.85, 0.52, 0.22, 0.30)
    var star := PackedVector2Array()
    var rays := 8 if pupil_style == 0 else 4
    for i in rays * 2:
        var angle := TAU * i / (rays * 2) + (PI / 4.0 if pupil_style == 1 else 0.0)
        var radius := pupil_radius * 0.13
        if i % 2 == 0:
            radius = pupil_radius * (0.65 if pupil_style == 0 and i % 4 == 2 else 1.0)
        star.append(Vector2(cos(angle), sin(angle)) * radius)
    $DeformContainer/Sclera/Iris/Pupil.polygon = _ellipse(Vector2.ONE * pupil_radius) if pupil_style == 2 else star
    $DeformContainer/Sclera/Iris/Pupil.color = pupil_color
    $DeformContainer/Sclera/Highlights/Main.polygon = _ellipse(Vector2(2, 5))
    $DeformContainer/Sclera/Highlights/Main.position = Vector2(-24, 7)
    $DeformContainer/Sclera/Highlights/Main.color = Color(0.6, 1, 0.85, 0.4)
    $DeformContainer/Sclera/Highlights/Small.polygon = _ellipse(Vector2(1.5, 2))
    $DeformContainer/Sclera/Highlights/Small.position = Vector2(20, 22)

func _lid_polygon(outside: PackedVector2Array, inside: PackedVector2Array) -> PackedVector2Array:
    var result := outside.duplicate()
    for i in range(inside.size() - 2, 0, -1):
        result.append(inside[i])
    return result
