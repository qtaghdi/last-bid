class_name SilhouettePortrait
extends Control

@export var tint: Color = UiPalette.GOLD_MUTED

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_tint(value: Color) -> void:
	tint = value
	queue_redraw()

func _draw() -> void:
	var width: float = size.x
	var height: float = size.y
	var center: Vector2 = Vector2(width * 0.5, height * 0.34)
	var radius: float = minf(width, height) * 0.18
	draw_circle(center, radius, UiPalette.with_alpha(tint, 0.82))
	var shoulder_top: float = center.y + radius * 0.65
	var body: PackedVector2Array = PackedVector2Array([
		Vector2(width * 0.2, height * 0.88),
		Vector2(width * 0.28, shoulder_top + radius),
		Vector2(width * 0.4, shoulder_top),
		Vector2(width * 0.6, shoulder_top),
		Vector2(width * 0.72, shoulder_top + radius),
		Vector2(width * 0.8, height * 0.88),
	])
	draw_colored_polygon(body, UiPalette.with_alpha(tint, 0.68))
	draw_arc(center, radius + 2.0, 0.0, TAU, 24, UiPalette.with_alpha(UiPalette.IVORY, 0.24), 1.0)
