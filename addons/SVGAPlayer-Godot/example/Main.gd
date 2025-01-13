extends Node2D

onready var svga_player = $SVGAPlayer
onready var options = $OptionButton

var svga_res_map = {
	0: "res://addons/SVGAPlayer-Godot/example/svga/image.svga",
}


func _on_Load_pressed() -> void:
	var path = svga_res_map[options.selected]
	svga_player.load_svga(path)
	svga_player.is_loop = true


func _on_Play_pressed() -> void:
	svga_player.play()


func _on_Stop_pressed() -> void:
	svga_player.stop()


func _on_Process_pressed() -> void:
	svga_player.step()


func _on_SVGAPlayer_animation_finished() -> void:
	print("[svga-player] animation finished")


func _on_SVGAPlayer_frame_changed(frame: int) -> void:
	print("[svga-player] frame: %d" % frame)
