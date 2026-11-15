extends Control
## Large tears that well up under each eye and fall. The node origin is the face centre.

const TEAR:=Color("bfeaff")
const RIM:=Color("4d8fc4")
const SHINE:=Color("ffffff")
const DROPS_PER_EYE: int=3

## 0 hides the tears, 1 shows them fully; `intensity` eases toward the target.
var target_intensity: float=0.0
var intensity: float=0.0
var eye_offset:=Vector2(47,17)
var drop_radius: float=15.0
var fall_distance: float=150.0
var clock: float=0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	clock+=delta
	intensity=move_toward(intensity,target_intensity,delta*1.6)
	queue_redraw()

func _draw() -> void:
	if intensity<=0.01:return
	for side in [-1.0,1.0]:
		var eye:=Vector2(eye_offset.x*side,eye_offset.y)
		draw_circle(eye+Vector2(side*drop_radius*0.5,drop_radius*0.5),drop_radius*0.62*intensity,Color(TEAR,0.85*intensity))
		for i in DROPS_PER_EYE:
			var phase:=fmod(clock*0.55+float(i)/float(DROPS_PER_EYE)+(0.17 if side>0.0 else 0.0),1.0)
			var fall:=phase*phase
			var center:=eye+Vector2(side*drop_radius*(0.6+fall*1.3),drop_radius+fall*fall_distance)
			var alpha:=intensity*(1.0-smoothstep(0.75,1.0,phase))
			_draw_tear(center,drop_radius*(0.55+0.45*minf(phase*4.0,1.0)),alpha)

func _draw_tear(center: Vector2,radius: float,alpha: float) -> void:
	if alpha<=0.01:return
	# A pointed top and a round belly.
	var points:=PackedVector2Array([center+Vector2(0,-radius*2.1)])
	for i in 13:
		var angle:=lerpf(-PI/6.0,PI+PI/6.0,float(i)/12.0)
		points.append(center+Vector2(cos(angle),sin(angle))*radius)
	draw_colored_polygon(points,Color(TEAR,alpha*0.92))
	points.append(points[0])
	draw_polyline(points,Color(RIM,alpha),2.0,true)
	draw_circle(center+Vector2(-radius*0.32,-radius*0.15),radius*0.24,Color(SHINE,alpha))
