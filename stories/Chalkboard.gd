extends Control
## Empty holographic chalkboard that hosts the Stories study content.

const FILL:=Color(0.03,0.065,0.16,0.80)
const CYAN:=Color("60e3cf")
const GOLD:=Color("f2c66d")
const CONTENT_MARGIN: float=28.0
const BRACKET_LENGTH: float=34.0

## Root of `Stories.tscn`; study content is added under its `Content` node.
var content: Control

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	content=preload("res://stories/Stories.tscn").instantiate()
	add_child(content)
	resized.connect(_fit_content)
	_fit_content()

func _fit_content() -> void:
	content.position=Vector2.ONE*CONTENT_MARGIN
	content.size=size-Vector2.ONE*CONTENT_MARGIN*2.0
	queue_redraw()

func _draw() -> void:
	var rect:=Rect2(Vector2.ZERO,size)
	# Soft outer glow, then the translucent slate and its two thin borders.
	for i in 4:
		draw_rect(rect.grow(3.0+float(i)*4.0),Color(CYAN,0.09-0.02*float(i)),false,4.0)
	draw_rect(rect,FILL)
	draw_rect(rect,CYAN,false,2.0)
	var inner:=rect.grow(-8.0)
	draw_rect(inner,Color(GOLD,0.55),false,1.0)
	# Gold brackets mark the four corners.
	for corner in [inner.position,Vector2(inner.end.x,inner.position.y),inner.end,Vector2(inner.position.x,inner.end.y)]:
		var inward:=Vector2(signf(rect.get_center().x-corner.x),signf(rect.get_center().y-corner.y))
		draw_line(corner,corner+Vector2(inward.x*BRACKET_LENGTH,0),GOLD,3.0,true)
		draw_line(corner,corner+Vector2(0,inward.y*BRACKET_LENGTH),GOLD,3.0,true)
