extends Node2D
class_name SVGAPlayer

# SVGA Properties
var _total_frames: int = 0
var _fps: float = 30
var _images: Dictionary = {}
var _sprites: Array = []
var _view_box: Rect2 = Rect2()

var _render: SVGARender = preload("res://addons/SVGAPlayer-Godot/player/svga_render.gd").new()

# Control Params
var _current_frame: float = 0
var _is_playing: bool = false
var is_loop: bool = false

# Signals
signal frame_changed(frame)
signal animation_finished()


func _ready():
	_render.register(self)
	set_process(false)


func load_svga(path: String) -> void:
	var file = File.new()
	if file.open(path, File.READ) != OK:
		push_error("[svga-player] Failed to open SVGA file, path: %s" % path)
		return
	
	var compressed_data = file.get_buffer(file.get_len())
	file.close()
	
	# Decompress SVGA data
	var decompressed_data = compressed_data.decompress_dynamic(-1, File.COMPRESSION_DEFLATE) 
	if decompressed_data.empty():
		push_error("[svga-player] Failed to decompress SVGA data")
		return
	
	_reset_svga_data()
	_parse_svga_data(decompressed_data)
	print("[svga-player] Load completed...")


func _reset_svga_data():
	_total_frames = 0
	_fps = 0
	_images.clear()
	_sprites.clear()
	_view_box = Rect2()
	_current_frame = 0
	_is_playing = false
	is_loop = false
	set_process(false)


func _parse_svga_data(data: PoolByteArray) -> void:
	var parsed_data = SVGAParser.parse_svga(data)
	if parsed_data.empty():
		return
		
	# Set basic properties
	_fps = parsed_data.params.fps
	_total_frames = parsed_data.params.frames
	_view_box = Rect2(
		0, 
		0, 
		parsed_data.params.viewBoxWidth,
		parsed_data.params.viewBoxHeight
	)
	
	# Load images
	_images.clear()
	for key in parsed_data.images:
		var image = Image.new()
		var image_data = parsed_data.images[key]
		image.load_png_from_buffer(image_data)
		var texture = ImageTexture.new()
		texture.create_from_image(image)
		_images[key] = texture
	
	# Process sprites
	_sprites.clear()
	for sprite_data in parsed_data.sprites:
		var sprite_frames = []
		var image_key = sprite_data.imageKey
		
		for frame_data in sprite_data.frames:
			var sprite_frame = SVGASpriteFrame.new()
			if image_key in _images:
				sprite_frame.texture = _images[image_key]
			sprite_frame.sprite_name = image_key
			sprite_frame.trans = frame_data.transform
			sprite_frame.alpha = frame_data.alpha
			
			# 处理形状
			if frame_data.has("shapes"):
				sprite_frame.shapes = frame_data.shapes
				
			# 处理剪切路径
			if frame_data.has("clipPath"):
				sprite_frame.clip_path = frame_data.clipPath
				
			sprite_frames.append(sprite_frame)
			
		_sprites.append(sprite_frames)


func play():
	if _total_frames > 0:
		_is_playing = true
		set_process(true)


func stop():
	_is_playing = false
	set_process(false)


func step(delta: float = 1 /_fps):
	_current_frame += _fps * delta
	if _current_frame >= _total_frames:
		if is_loop:
			_current_frame = 0
		else:
			_current_frame = _total_frames
			stop()
			
		emit_signal("animation_finished")
	
	update()
	emit_signal("frame_changed", floor(_current_frame))


func _process(delta):
	if not _is_playing:
		return
	step(delta)


func _draw():
	if _sprites.empty():
		return

	var frame = floor(_current_frame)
	if frame < 0 || frame >= _total_frames:
		return

	# Draw each sprite for the current frame
	for sprite in _sprites:
		if frame < sprite.size():
			var sprite_frame: SVGASpriteFrame = sprite[frame]
			draw_set_transform_matrix(sprite_frame.trans)
			
			if sprite_frame.clip_path.length() > 0:
				_render.draw_clip_path(sprite_frame)
			elif sprite_frame.texture:
#				_render.draw_texture(sprite_frame)
				draw_texture(
					sprite_frame.texture,
					Vector2.ZERO,
					Color(1, 1, 1, sprite_frame.alpha)
				)
