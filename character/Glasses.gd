extends Node3D
## Faceted orange spectacles. Coordinates are relative to the Head bone.
var frame_material:StandardMaterial3D
func _ready() -> void:
    frame_material=StandardMaterial3D.new()
    frame_material.albedo_color=Color("ff791f")
    frame_material.roughness=0.27
    frame_material.metallic=0.15
    frame_material.cull_mode=BaseMaterial3D.CULL_DISABLED
    for side in [-1.0,1.0]:
        build_rim(Vector3(side*0.59,0.23,1.13))
        build_arm(Vector3(side*1.16,0.25,1.12),Vector3(side*1.03,0.29,0.18))
    build_arm(Vector3(-0.10,0.29,1.19),Vector3(0.10,0.29,1.19))
func build_arm(a:Vector3,b:Vector3) -> void:
    var mesh:=CylinderMesh.new()
    mesh.top_radius=0.045;mesh.bottom_radius=0.045
    mesh.height=a.distance_to(b);mesh.radial_segments=6
    var part:=MeshInstance3D.new();part.mesh=mesh;part.material_override=frame_material
    add_child(part);part.position=(a+b)*0.5
    part.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
func ring_point(index:int,inner:bool,z:float) -> Vector3:
    var angle:=TAU*float(index)/24.0+PI/24.0
    return Vector3(cos(angle)*(0.51 if inner else 0.60),sin(angle)*(0.49 if inner else 0.58),z)
func triangle(surface:SurfaceTool,a:Vector3,b:Vector3,c:Vector3) -> void:
    surface.add_vertex(a);surface.add_vertex(b);surface.add_vertex(c)
func build_rim(center:Vector3) -> void:
    var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in 24:
        var j: int=(i+1)%24
        for face in [[ring_point(i,false,0.06),ring_point(j,false,0.06),ring_point(j,true,0.06),ring_point(i,true,0.06)],
                     [ring_point(i,false,-0.06),ring_point(j,false,-0.06),ring_point(j,false,0.06),ring_point(i,false,0.06)],
                     [ring_point(i,true,0.06),ring_point(j,true,0.06),ring_point(j,true,-0.06),ring_point(i,true,-0.06)]]:
            triangle(surface,face[0],face[1],face[2]);triangle(surface,face[0],face[2],face[3])
    surface.generate_normals()
    var rim:=MeshInstance3D.new();rim.name="OrangeRim";rim.mesh=surface.commit();rim.material_override=frame_material
    add_child(rim);rim.position=center
    var lens_surface:=SurfaceTool.new();lens_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in 24:
        for point in [Vector3(0,0,0.075),ring_point(i,true,0.045),ring_point((i+1)%24,true,0.045)]:
            lens_surface.set_uv(Vector2(point.x/1.02+0.5,point.y/0.98+0.5))
            lens_surface.add_vertex(point)
    lens_surface.generate_normals()
    var lens:=MeshInstance3D.new();lens.name="ReflectiveLens";lens.mesh=lens_surface.commit()
    var material:=ShaderMaterial.new();material.shader=preload("res://character/glasses_lens.gdshader");material.render_priority=4
    lens.material_override=material;lens.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(lens);lens.position=center
