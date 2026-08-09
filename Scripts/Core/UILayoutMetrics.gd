extends RefCounted
class_name UILayoutMetrics

const MARGIN := 10.0
const MIN_NAV_WIDTH := 168.0
const MAX_NAV_WIDTH := 238.0
const MIN_DASHBOARD_WIDTH := 285.0
const MAX_DASHBOARD_WIDTH := 440.0
const TOP_BAR_HEIGHT := 64.0


static func calculate(viewport: Vector2, hud_height: float) -> Dictionary:
	var dashboard_width := clampf(viewport.x * 0.24, MIN_DASHBOARD_WIDTH, MAX_DASHBOARD_WIDTH)
	var nav_width := clampf(viewport.x * 0.145, MIN_NAV_WIDTH, MAX_NAV_WIDTH)
	var content_top := TOP_BAR_HEIGHT + MARGIN
	var content_height := maxf(300.0, viewport.y - hud_height - content_top - MARGIN)
	return {
		"nav_width": nav_width,
		"nav_rect": Rect2(MARGIN, content_top, nav_width, content_height),
		"dashboard_width": dashboard_width,
		"dashboard_rect": Rect2(viewport.x - dashboard_width - MARGIN, content_top, dashboard_width, content_height),
		"grid_rect": Rect2(MARGIN * 2.0 + nav_width, content_top, maxf(1.0, viewport.x - dashboard_width - nav_width - MARGIN * 4.0), content_height),
	}
