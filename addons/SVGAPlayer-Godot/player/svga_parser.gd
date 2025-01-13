extends Reference
class_name SVGAParser

const svga_proto = preload("res://addons/SVGAPlayer-Godot/proto/svga.pb.gd")


static func parse_svga(data: PoolByteArray) -> Dictionary:
	if data.empty():
		push_error("Empty SVGA data")
		return {}
	
	var movie = svga_proto.MovieEntity.new()
	var result = movie.from_bytes(data)
	if result != svga_proto.PB_ERR.NO_ERRORS:
		push_error("Failed to parse SVGA data: %d" % result)
		return {}
	
	var parsed_data = {
		"version": movie.get_version(),
		"params": {
			"viewBoxWidth": movie.get_params().get_viewBoxWidth(),
			"viewBoxHeight": movie.get_params().get_viewBoxHeight(),
			"fps": movie.get_params().get_fps(),
			"frames": movie.get_params().get_frames()
		},
		"images": movie.get_images(),
		"sprites": []
	}
	
	# Parse sprites
	for sprite in movie.get_sprites():
		var sprite_data = {
			"imageKey": sprite.get_imageKey(),
			"frames": [],
			"matteKey": sprite.get_matteKey()
		}
		
		# Parse frames for each sprite
		for frame in sprite.get_frames():
			var frame_data = {
				"alpha": frame.get_alpha(),
				"transform": _parse_transform(frame.get_transform()),
				"layout": _parse_layout(frame.get_layout()),
				"clipPath": frame.get_clipPath(),
				"shapes": []
			}
			
			# Parse shapes if any
			for shape in frame.get_shapes():
				frame_data.shapes.append(_parse_shape(shape))
				
			sprite_data.frames.append(frame_data)
			
		parsed_data.sprites.append(sprite_data)
	
	return parsed_data


static func _parse_transform(transform) -> Transform2D:
	if transform == null:
		return Transform2D.IDENTITY
	
	# SVGA 使用的是 2D 仿射变换矩阵:
	# | a  c  tx |
	# | b  d  ty |
	# | 0  0  1  |
	var a = transform.get_a()   # scale x
	var b = transform.get_b()   # skew y
	var c = transform.get_c()   # skew x
	var d = transform.get_d()   # scale y
	var tx = transform.get_tx() # translate x
	var ty = transform.get_ty() # translate y
	
	# Godot 的 Transform2D 使用:
	# | x.x  x.y  o.x |
	# | y.x  y.y  o.y |
	return Transform2D(
		Vector2(a, b),     # x basis (column 1)
		Vector2(c, d),     # y basis (column 2)
		Vector2(tx, ty)    # origin (translation)
	)


static func _parse_layout(layout) -> Rect2:
	if layout == null:
		return Rect2()
		
	return Rect2(
		layout.get_x(),
		layout.get_y(),
		layout.get_width(),
		layout.get_height()
	)


static func _parse_shape(shape) -> Dictionary:
	var shape_data = {
		"type": shape.get_type(),
		"styles": _parse_shape_style(shape.get_styles()),
		"transform": _parse_transform(shape.get_transform())
	}
	
	# Parse specific shape data based on type
	if shape.has_shape():
		shape_data.shape = {
			"d": shape.get_shape().get_d()
		}
	elif shape.has_rect():
		var rect = shape.get_rect()
		shape_data.rect = {
			"x": rect.get_x(),
			"y": rect.get_y(),
			"width": rect.get_width(),
			"height": rect.get_height(),
			"cornerRadius": rect.get_cornerRadius()
		}
	elif shape.has_ellipse():
		var ellipse = shape.get_ellipse()
		shape_data.ellipse = {
			"x": ellipse.get_x(),
			"y": ellipse.get_y(),
			"radiusX": ellipse.get_radiusX(),
			"radiusY": ellipse.get_radiusY()
		}
	
	return shape_data


static func _parse_shape_style(style) -> Dictionary:
	if style == null:
		return {}
		
	var style_data = {
		"fill": _parse_color(style.get_fill()),
		"stroke": _parse_color(style.get_stroke()),
		"strokeWidth": style.get_strokeWidth(),
		"lineCap": style.get_lineCap(),
		"lineJoin": style.get_lineJoin(),
		"miterLimit": style.get_miterLimit(),
		"lineDash": [
			style.get_lineDashI(),
			style.get_lineDashII(),
			style.get_lineDashIII()
		]
	}
	
	return style_data


static func _parse_color(color) -> Color:
	if color == null:
		return Color.transparent
		
	return Color(
		color.get_r(),
		color.get_g(),
		color.get_b(),
		color.get_a()
	) 
