class_name MouseFace3D
extends Node3D
const MODEL_PATH = "res://character/mouse_face.glb"
const EYE = preload("res://character/EyeRig.tscn")
@export var auto_blink: bool = true
@export var comic_material: ShaderMaterial = preload("res://character/Slime.tres")
@export var use_comic_material: bool = true
var active_comic_material: ShaderMaterial
var body_surfaces: Array[MeshInstance3D] = []
var eyes: Array[EyeRig2D] = []
var eye_surfaces: Array[MeshInstance3D] = []
var viewports: Array[SubViewport] = []
var expression: int = 0
var _timer: Timer
var _rng := RandomNumberGenerator.new()
var ear_rig: EarDynamics3D
var ear_skeleton: Skeleton3D
var tail_rig: TailDynamics3D
var crystal_surfaces: Array[MeshInstance3D] = []
var bubble_surfaces: Array[MeshInstance3D] = []
var crystal_material: ShaderMaterial
var _color_tween: Tween

func _ready() -> void:
    _rng.randomize()
    var model := (load(MODEL_PATH) as PackedScene).instantiate()
    add_child(model)
    active_comic_material = comic_material.duplicate() as ShaderMaterial
    crystal_material = preload("res://character/Crystal.tres").duplicate() as ShaderMaterial
    for item in model.find_children("*", "MeshInstance3D", true, false):
        item.lod_bias = 100.0
        if item.name.begins_with("Crystal_"):
            item.material_override = crystal_material
            crystal_surfaces.append(item)
            continue
        if item.name.begins_with("Bubble_"):
            var bubble_mat := StandardMaterial3D.new()
            bubble_mat.albedo_color = Color(0.32,0.78,0.81)
            bubble_mat.roughness = 0.08
            bubble_mat.metallic = 0.35
            bubble_mat.emission_enabled = true
            bubble_mat.emission = Color(0.04,0.12,0.14)
            item.material_override = bubble_mat
            bubble_surfaces.append(item)
            continue
        if not item.name.begins_with("EyeSurface"):
            var base_material := StandardMaterial3D.new()
            base_material.albedo_color = Color(0.72,0.72,0.72)
            base_material.roughness = 0.95
            item.material_override = active_comic_material if use_comic_material else base_material
            body_surfaces.append(item)
    for side in ["L", "R"]:
        var surface := model.find_child("EyeSurface_" + side + "*", true, false) as MeshInstance3D
        assert(surface != null, "Missing eye surface " + side)
        eye_surfaces.append(surface)
        var viewport := SubViewport.new()
        viewport.name = "EyeViewport_" + side
        viewport.size = Vector2i(512,512)
        viewport.transparent_bg = true
        viewport.disable_3d = true
        viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        add_child(viewport)
        viewports.append(viewport)
        var eye := EYE.instantiate() as EyeRig2D
        eye.auto_blink = false
        eye.expression_side = 1 if side == "L" else -1
        eye.position = Vector2(256,256)
        eye.scale = Vector2.ONE * 2.0
        viewport.add_child(eye)
        eyes.append(eye)
        var material := StandardMaterial3D.new()
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.render_priority = 3
        material.cull_mode = BaseMaterial3D.CULL_DISABLED
        material.albedo_texture = viewport.get_texture()
        material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
        surface.material_override = material
        surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _timer = Timer.new()
    _timer.one_shot = true
    add_child(_timer)
    _timer.timeout.connect(_on_timer)
    _schedule_blink()
    ear_skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
    ear_rig = EarDynamics3D.new()
    ear_rig.name = "EarDynamics"
    ear_rig.skeleton = ear_skeleton
    ear_rig.motion_source = self
    add_child(ear_rig)
    tail_rig = TailDynamics3D.new()
    tail_rig.name = "TailDynamics"
    tail_rig.skeleton = ear_skeleton
    tail_rig.motion_source = self
    add_child(tail_rig)
    tail_rig.set_mood(expression,0.01)
    var attachment:=BoneAttachment3D.new()
    attachment.name="GlassesAttachment"
    attachment.bone_name="Head"
    ear_skeleton.add_child(attachment)
    var glasses:=Node3D.new()
    glasses.name="OrangeGlasses"
    glasses.set_script(preload("res://character/Glasses.gd"))
    attachment.add_child(glasses)

func set_expression(value: int, duration: float = 0.22) -> void:
    expression = clampi(value, 0, 6)
    for eye in eyes: eye.set_expression(expression, duration)
    if tail_rig:tail_rig.set_mood(expression,duration)
    if crystal_material:
        var colors := [Color("35e2ed"),Color("ff9b27"),Color("ad63ec"),Color("c681ff"),Color("ffbc52"),Color("ffbd44"),Color("875ecf")]
        if _color_tween: _color_tween.kill()
        _color_tween = create_tween()
        _color_tween.tween_property(crystal_material,"shader_parameter/mood_color",colors[expression],maxf(duration,0.01))

func blink() -> void:
    for eye in eyes: eye.blink()

func set_mood(value: int, duration: float = 0.3) -> void:
    set_expression(value,duration)

func set_gaze(direction: Vector2) -> void:
    var limited := direction.limit_length(1.0)
    for eye in eyes:
        eye.look_at_target(eye.deform.to_global(limited * eye.max_radius / maxf(eye.look_sensitivity,0.001)))

func look_at_target(target_global: Vector3) -> void:
    var local_target := to_local(target_global) - Vector3(0,0.85,0.7)
    set_gaze(Vector2(local_target.x,-local_target.y) / maxf(absf(local_target.z),0.5))

func deform_eyes(target_scale: Vector2, duration: float = 0.35) -> void:
    for eye in eyes: eye.deform_eye(target_scale,duration)

func _schedule_blink() -> void:
    if auto_blink: _timer.start(_rng.randf_range(2.5,5.5))

func _on_timer() -> void:
    if auto_blink:
        blink()
        _schedule_blink()
