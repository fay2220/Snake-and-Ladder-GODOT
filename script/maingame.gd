extends Node2D

@onready var turn_label = $TurnLabel
@onready var dice_button = $Dice_Button
@onready var dice_animation = $DiceAnimation
@onready var dice_face = $DiceFace
@onready var game_over = $GameOver
@onready var isHost = $isHost
@onready var dice_label = $DiceLabel
@onready var path_walk = $PathWalk
@onready var path_follow = $PathWalk/PathFollow2D

# Player paths
var player_nodes = {
	1: $PathWalk/PathFollow2D/Player1,
	2: $PathWalk/PathFollow2D/Player2,
	3: $PathWalk/PathFollow2D/Player3,
	4: $PathWalk/PathFollow2D/Player4
}

func _ready():
	if not multiplayer.has_multiplayer_peer():
		return_to_lobby()
		return 
	
	var my_name = Global.my_name
	
	if multiplayer.is_server():
		isHost.text = "🖥️ คุณคือ Host " + my_name
		initialize_game.rpc()
	else:
		isHost.text = "🎮 คุณคือ Client " + my_name
	
	if Global.peer:
		multiplayer.multiplayer_peer = Global.peer
		
	dice_button.pressed.connect(_on_dice_pressed)
	
	await get_tree().create_timer(1.0).timeout
	if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return_to_lobby()
	
	if path_walk.curve == null:
		push_error("Path2D ไม่มี Curve กําหนด!")
		return
	
	path_follow.progress_ratio = 0
	path_follow.rotation = false

@rpc("authority", "call_local", "reliable")
func initialize_game():
	if multiplayer.is_server():
		Global.player_order = Global.players.keys()
		Global.player_order.sort()
		Global.current_turn_index = 0
		update_turn_display.rpc(Global.get_current_turn_id())

@rpc("authority", "call_local", "reliable")
func update_turn_display(current_turn_id: int):
	var is_my_turn = (multiplayer.get_unique_id() == current_turn_id)
	var player_name = Global.players.get(current_turn_id, "Unknown")
	turn_label.text = "🎲 เทิร์นของคุณ!" if is_my_turn else "⏳ รอ %s..." % player_name
	dice_button.disabled = not is_my_turn

func _on_dice_pressed():
	if multiplayer.get_unique_id() != Global.get_current_turn_id():
		return
	
	dice_button.hide()
	dice_button.disabled = true
	dice_face.hide()
	dice_animation.show()
	dice_animation.play("DiceRolling")
	
	await dice_animation.animation_finished
	var roll = randi_range(1, 6)
	dice_label.text = Global.my_name + "🎲 ทอยได้ : " + str(roll)
	
	dice_face.frame = roll - 1
	dice_face.show()
	dice_animation.hide()
	
	send_roll_result.rpc_id(1, multiplayer.get_unique_id(), roll)

@rpc("any_peer", "reliable")
func send_roll_result(player_id: int, roll: int):
	if not multiplayer.is_server():
		return
	print("📨 รับค่าทอยจากผู้เล่น ID:", player_id, " ได้แต้ม:", roll)
	Global.players_point[player_id] = roll
	print(Global.players_point)

func check_snakes_and_ladders(position: int) -> int:
	var special_tiles = {
		3: 22, 5: 8, 11: 26, 17: 4,
		20: 29, 25: 46, 30: 12, 35: 49,
		42: 63, 50: 69, 55: 37, 60: 41,
		70: 89, 75: 53, 80: 99, 87: 24,
		93: 73, 95: 75, 98: 79
	}
	return special_tiles.get(position, position)

@rpc("authority", "call_local", "reliable")
func announce_winner(player_id: int):
	var winner_name = Global.players.get(player_id, "Unknown")
	game_over.text = "🏆 %s ชนะ!" % winner_name
	game_over.show()
	dice_button.disabled = true
	await get_tree().create_timer(5.0).timeout
	return_to_lobby()

func return_to_lobby():
	get_tree().change_scene_to_file("res://Scene/lobby.tscn")
