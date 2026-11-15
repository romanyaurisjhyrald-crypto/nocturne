extends Control
var dialogue_rect:=Rect2()
var menu_rect:=Rect2()
var character_center:=Vector2.ZERO
var orbit_radius:float=230.0
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)
func star(center:Vector2,radius:float,color:Color,angle:float=0.0) -> void:
    var points:=PackedVector2Array()
    for i in 8:
        points.append(center+Vector2.from_angle(angle+float(i)*PI/4.0)*(radius if i%2==0 else radius*0.22))
    draw_colored_polygon(points,color)
func _draw() -> void:
    var coral:=Color("ff967d")
    var mint:=Color("68ead1")
    var violet:=Color("bda5ff")
    var cream:=Color("fff0c9")
    # Original collage marks frame the controls without intercepting input.
    draw_colored_polygon(PackedVector2Array([Vector2.ZERO,Vector2(420,0),Vector2(300,210),Vector2(0,250)]),Color(0.12,0.08,0.25,0.78))
    draw_colored_polygon(PackedVector2Array([Vector2(18,62),Vector2(515,32),Vector2(475,160),Vector2(30,177)]),Color("30203f"))
    draw_line(Vector2(24,171),Vector2(455,145),coral,7,true)
    draw_line(Vector2(32,178),Vector2(270,163),violet,3,true)
    star(Vector2(505,67),25,mint,0.18)
    star(Vector2(470,181),13,coral,0.3)
    for y in 12:
        for x in 18:
            var point:=Vector2(23+x*10,215+y*12)
            draw_circle(point,1.8,Color(violet,0.30*(1.0-float(x)/20.0)))
    for i in 9:
        draw_line(Vector2(size.x-255+i*20,22),Vector2(size.x-242+i*20,35),mint,3,true)
    if character_center!=Vector2.ZERO:
        var orbit:=PackedVector2Array()
        for i in 97:
            var angle:=float(i)/96.0*TAU
            orbit.append(character_center+Vector2(cos(angle)*orbit_radius*1.21,sin(angle)*orbit_radius*0.72).rotated(-0.22))
        draw_polyline(orbit,Color(violet,0.35),2,true)
        star(character_center+Vector2(orbit_radius*1.13,-80),23,cream,0.2)
        star(character_center+Vector2(-orbit_radius*1.1,65),16,mint,0.1)
        for i in 5:
            var a:=Vector2(-orbit_radius*1.15-15+i*11,-orbit_radius*0.5+i*7)
            draw_line(character_center+a,character_center+a+Vector2(-20,25),Color(coral,0.7),3,true)
    if dialogue_rect.size.x>0:
        var corner:=dialogue_rect.position
        draw_colored_polygon(PackedVector2Array([corner+Vector2(-15,60),corner+Vector2(-9,-15),corner+Vector2(200,-8),corner+Vector2(175,14)]),coral)
        star(Vector2(dialogue_rect.end.x-12,dialogue_rect.position.y-7),23,mint,0.2)
    draw_line(Vector2(32,size.y-20),Vector2(200,size.y-20),Color(cream,0.4),2,true)
