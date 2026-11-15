extends Control
## Glowing ruler that floats beside the character and points at the chalkboard.
## The node origin is the handle end; the ruler extends along `direction`.

const BODY:=Color("ff9a4d")
const EDGE:=Color("ffe0ad")
const INK:=Color("6a2c0c")
const TICK_COUNT: int=12

var length: float=180.0
var direction:=Vector2(-0.88,-0.47)
var clock: float=0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	clock+=delta
	queue_redraw()

func _draw() -> void:
	# A slow bob and sway keep the ruler floating rather than held.
	var axis:=direction.normalized().rotated(sin(clock*1.3)*0.045)
	var normal:=axis.orthogonal()
	var origin:=Vector2(0,sin(clock*1.9)*6.0)
	var tip:=origin+axis*length
	var half:=length*0.07
	for i in 4:
		draw_line(origin,tip,Color(BODY,0.10),half*2.0+8.0+float(i)*9.0,true)
	var outline:=PackedVector2Array([origin+normal*half,tip+normal*half,tip-normal*half,origin-normal*half])
	draw_colored_polygon(outline,BODY)
	outline.append(outline[0])
	draw_polyline(outline,EDGE,2.0,true)
	for i in range(1,TICK_COUNT):
		var point:=origin+axis*length*float(i)/float(TICK_COUNT)
		var tick:=half*(1.15 if i%4==0 else 0.6)
		draw_line(point+normal*half,point+normal*(half-tick),INK,2.0,true)
	draw_circle(tip,half*1.9,Color(BODY,0.12))
	draw_circle(tip,4.0+sin(clock*4.0)*1.2,EDGE)
