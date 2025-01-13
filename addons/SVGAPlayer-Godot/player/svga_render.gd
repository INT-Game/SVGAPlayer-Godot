extends Reference
class_name SVGARender


var _render_node: Node2D


func register(render_node: Node2D):
	_render_node = render_node


func draw_texture(frame: SVGASpriteFrame):
	_render_node.draw_texture(
		frame.texture,
		Vector2.ZERO,
		Color(1, 1, 1, frame.alpha)
	)


func draw_clip_path(frame: SVGASpriteFrame) -> void:
	var points = parse_path_data(frame.clip_path)
	if points.size() < 3:
		return
	
	if frame.texture:
		var color = Color(1, 1, 1, frame.alpha)
		var texture_size = frame.texture.get_size()
	
		# 计算texture和points组成的区域的长宽
		var area_size = calculate_area_size(texture_size, points)
	
		# 计算 UV 坐标
		var uvs = PoolVector2Array()
		for point in points:
			var uv_x = (point.x) / area_size.x
			var uv_y = (point.y) / area_size.y
			uvs.append(Vector2(uv_x, uv_y))
		
		# 创建一个新的 Image
		var image = Image.new()
		image.create(area_size.x, area_size.y, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		image.blit_rect(frame.texture.get_data(), Rect2(0, 0, texture_size.x, texture_size.y), Vector2(0, 0))
		frame.texture.create_from_image(image)
		
		# 使用新的纹理绘制多边形
		_render_node.draw_colored_polygon(points, color, uvs, frame.texture, null, true)


func draw_shape(shape_data: Dictionary) -> void:
	match shape_data.type:
		"SHAPE":
			_render_node.raw_path_shape(shape_data)
		"RECT":
			_render_node.draw_rect_shape(shape_data)
		"ELLIPSE":
			_render_node.draw_ellipse_shape(shape_data)


func draw_path_shape(shape_data: Dictionary) -> void:
	var path = shape_data.path.d
	var style = shape_data.styles
	var trans = SVGAParser._parse_transform(shape_data.transform)
	
	var points = parse_path_data(path)
	if points.empty():
		return
		
	# 应用变换
	for i in range(points.size()):
		points[i] = trans.xform(points[i])
	
	# 绘制填充
	if style.has("fill"):
		_render_node.draw_colored_polygon(points, Color(style.fill))
	
	# 绘制描边
	if style.has("stroke"):
		for i in range(points.size() - 1):
			_render_node.draw_line(points[i], points[i + 1], 
				Color(style.stroke), 
				style.get("strokeWidth", 1.0))


func draw_rect_shape(shape_data: Dictionary) -> void:
	var rect = shape_data.rect
	var style = shape_data.styles
	var trans = SVGAParser._parse_transform(shape_data.transform)
	
	var rect2 = Rect2(rect.x, rect.y, rect.width, rect.height)
	rect2 = trans.xform(rect2)
	
	if style.has("fill"):
		_render_node.draw_rect(rect2, Color(style.fill), true)
	
	if style.has("stroke"):
		_render_node.draw_rect(rect2, Color(style.stroke), false, 
			style.get("strokeWidth", 1.0),
			style.get("cornerRadius", 0.0))


func draw_ellipse_shape(shape_data: Dictionary) -> void:
	var ellipse = shape_data.ellipse
	var style = shape_data.styles
	var trans = SVGAParser._parse_transform(shape_data.transform)
	
	var center = trans.xform(Vector2(ellipse.x, ellipse.y))
	var radius = Vector2(ellipse.radiusX, ellipse.radiusY)
	
	if style.has("fill"):
		_render_node.draw_circle(center, radius.x, Color(style.fill))
	
	if style.has("stroke"):
		# 绘制椭圆轮廓
		var points = []
		var segments = 32
		for i in range(segments + 1):
			var angle = 2 * PI * i / segments
			var point = center + Vector2(
				cos(angle) * radius.x,
				sin(angle) * radius.y
			)
			points.append(point)
		
		for i in range(points.size() - 1):
			_render_node.draw_line(points[i], points[i + 1],
				Color(style.stroke),
				style.get("strokeWidth", 1.0))


func parse_path_data(path_data: String) -> PoolVector2Array:
	path_data = path_data.replace(",", " ")
	path_data = path_data.strip_edges()
	
	# 添加替换命令字母的步骤
	var regex = RegEx.new()
	regex.compile("([a-zA-Z])")
	path_data = regex.sub(path_data, "|||$1 ", true)
	
	var points = PoolVector2Array()
	if path_data.empty():
		return points
	
	var segments = path_data.split("|||")
	var current_point = Vector2()
	
	for segment in segments:
		if segment.empty():
			continue
		
		var first_letter = segment.substr(0, 1)
		var args = segment.substr(1).strip_edges().split(" ")
		
		match first_letter:
			"M": # Move to absolute
				if args.size() >= 2:
					current_point = Vector2(float(args[0]), float(args[1]))
					points.append(current_point)
			"m": # Move to relative
				if args.size() >= 2:
					current_point += Vector2(float(args[0]), float(args[1]))
					points.append(current_point)
			"L": # Line to absolute
				if args.size() >= 2:
					current_point = Vector2(float(args[0]), float(args[1]))
					points.append(current_point)
			"l": # Line to relative
				if args.size() >= 2:
					current_point += Vector2(float(args[0]), float(args[1]))
					points.append(current_point)
			"C": # Cubic Bezier curve absolute
				if args.size() >= 6:
					var control1 = Vector2(float(args[0]), float(args[1]))
					var control2 = Vector2(float(args[2]), float(args[3]))
					var end_point = Vector2(float(args[4]), float(args[5]))
					
					# 计算贝塞尔曲线上的点
					var curve_points = _calculate_bezier_curve(current_point, control1, control2, end_point)
					for p in curve_points:
						points.append(p)
					current_point = end_point
			"c": # Cubic Bezier curve relative
				if args.size() >= 6:
					var control1 = current_point + Vector2(float(args[0]), float(args[1]))
					var control2 = current_point + Vector2(float(args[2]), float(args[3]))
					var end_point = current_point + Vector2(float(args[4]), float(args[5]))
					
					# 计算贝塞尔曲线上的点
					var curve_points = _calculate_bezier_curve(current_point, control1, control2, end_point)
					for p in curve_points:
						points.append(p)
					current_point = end_point
			"Z", "z": # Close path
				if not points.empty():
					points.append(points[0])
	
	return points


func _calculate_bezier_curve(start: Vector2, control1: Vector2, control2: Vector2, end: Vector2, segments: int = 10) -> PoolVector2Array:
	var curve_points = PoolVector2Array()
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var point = _bezier_point(start, control1, control2, end, t)
		curve_points.append(point)
	return curve_points


func _bezier_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 = t * t
	var t3 = t2 * t
	var mt = 1 - t
	var mt2 = mt * mt
	var mt3 = mt2 * mt
	return p0 * mt3 + p1 * 3 * mt2 * t + p2 * 3 * mt * t2 + p3 * t3


func calculate_area_size(texture_size: Vector2, points: PoolVector2Array) -> Vector2:
	var min_x = INF
	var min_y = INF
	var max_x = -INF
	var max_y = -INF
	
	for point in points:
		if point.x < 0:
			if point.x < -texture_size.x / 2:
				min_x = min(min_x, point.x)
			else:
				min_x = min(min_x, -texture_size.x / 2)
		
		if point.y < 0:
			if point.y < -texture_size.y / 2:
				min_y = min(min_y, point.y)
			else:
				min_y = min(min_y, -texture_size.y / 2)
		
		if point.x > 0:
			if point.x > texture_size.x / 2:
				max_x = max(max_x, point.x)
			else:
				max_x = max(max_x, texture_size.x / 2)
		
		if point.y > 0:
			if point.y > texture_size.y / 2:
				max_y = max(max_y, point.y)
			else:
				max_y = max(max_y, texture_size.y / 2)
		
		min_y = min(min_y, -texture_size.y / 2)
		max_y = max(max_y, texture_size.y / 2)
		
		min_x = min(min_x, -texture_size.x / 2)
		max_x = max(max_x, texture_size.x / 2)
	
	# 计算区域的宽度和高度
	var area_width = max_x - min_x
	var area_height = max_y - min_y
	return Vector2(area_width, area_height)
