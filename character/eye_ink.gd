extends Node2D
var _top := PackedVector2Array()
var _bottom := PackedVector2Array()
var _side: int = 1
var _ink := Color("281323")
var _blink: float = 0.0

func set_contours(top: PackedVector2Array, bottom: PackedVector2Array, side: int, ink: Color, blink: float) -> void:
    _top = top
    _bottom = bottom
    _side = side
    _ink = ink
    _blink = blink
    queue_redraw()

func _draw() -> void:
    if _top.size() < 3: return
    var stroke := PackedVector2Array()
    for i in _top.size():
        var t := float(i) / (_top.size() - 1)
        var outer_weight := (1.0 - t) if _side == 1 else t
        var thickness := (2.0 + 7.5 * sin(PI * t) + 3.0 * outer_weight) * (0.95 + 0.07 * sin(t * 23.0))
        stroke.append(_top[i] - Vector2(0, thickness))
    for i in range(_top.size() - 1, -1, -1):
        stroke.append(_top[i] + Vector2(0, 0.8))
    draw_colored_polygon(stroke, _ink)
    for pass_index in 3:
        var scratch := PackedVector2Array()
        for k in range(3 + pass_index, _top.size() - 3 - pass_index):
            var shift := -5.0 - pass_index * 2.0 + sin(k * 1.7 + pass_index) * 0.55
            scratch.append(_top[k] + Vector2(0, shift))
        draw_polyline(scratch, Color(0.42,0.18,0.17,0.45), 0.7, true)
    var n := _top.size()
    var index := 0 if _side == 1 else n - 1
    var next := 2 if _side == 1 else n - 3
    var corner := _top[index]
    var outward := (corner - _top[next]).normalized()
    var tip := corner + outward * 25.0 + Vector2(0,-3)
    draw_colored_polygon(PackedVector2Array([corner + Vector2(0,2),tip, _top[next] - Vector2(0,8)]), _ink)
    var p := _top[3 if _side == 1 else n - 4]
    draw_line(p - Vector2(0,8), corner + outward * 14.0 - Vector2(0,11), _ink, 1.4, true)
    if _blink < 0.95:
        var line := PackedVector2Array()
        for i in range(1,n-1):
            var t := float(i)/(n-1)
            if (_side == 1 and t < 0.88) or (_side == -1 and t > 0.12): line.append(_bottom[i])
        draw_polyline(line, _ink, 2.0, true)
        var lower_outer := _bottom[4 if _side == 1 else n-5]
        draw_line(lower_outer, lower_outer + Vector2(-_side*6,5),_ink,1.5,true)
    var accent := PackedVector2Array()
    for i in range(5,12):
        var k := i if _side == 1 else n - i - 1
        accent.append(_top[k] - Vector2(0,14))
    draw_polyline(accent, Color(_ink,0.35),1.0,true)
