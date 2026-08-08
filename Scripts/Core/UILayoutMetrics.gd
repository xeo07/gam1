extends RefCounted
class_name UILayoutMetrics

const MARGIN := 16.0
const MIN_DASHBOARD_WIDTH := 380.0
const MAX_DASHBOARD_WIDTH := 600.0


static func calculate(viewport: Vector2, hud_height: float) -> Dictionary:
	var dashboard_width := clampf(viewport.x * 0.43, MIN_DASHBOARD_WIDTH, MAX_DASHBOARD_WIDTH)
	var content_height := maxf(300.0, viewport.y - hud_height - MARGIN * 2.0)
	return {
		"dashboard_width": dashboard_width,
		"dashboard_rect": Rect2(viewport.x - dashboard_width - MARGIN, MARGIN, dashboard_width, content_height),
		"grid_rect": Rect2(MARGIN, MARGIN, maxf(1.0, viewport.x - dashboard_width - MARGIN * 3.0), content_height),
	}
