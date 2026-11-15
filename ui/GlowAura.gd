extends Control
## Additive halo and slow rays drawn behind the character when it is radiant.

const RING_COUNT: int=14
const RAY_COUNT: int=12

var strength: float=0.0
var radius: float=200.0
var tint:=Color("9fe8ff")
var clock: float=0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var additive:=CanvasItemMaterial.new()
	additive.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	material=additive

func _process(delta: float) -> void:
	clock+=delta
	queue_redraw()

func _draw() -> void:
	if strength<=0.01:return
	var pulse:=0.88+0.12*sin(clock*2.2)
	for i in RING_COUNT:
		var t:=float(i)/float(RING_COUNT-1)
		draw_circle(Vector2.ZERO,radius*pulse*(1.3-t*0.95),Color(tint,0.065*strength*(0.4+t)))
	for i in RAY_COUNT:
		var direction:=Vector2.from_angle(float(i)*TAU/float(RAY_COUNT)+clock*0.15)
		var reach:=radius*(1.2+0.1*sin(clock*3.0+float(i)))
		draw_line(direction*radius*0.8,direction*reach,Color(tint,0.28*strength),4.0,true)
