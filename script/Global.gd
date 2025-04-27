extends Node2D

# 🌐 Global Multiplayer State สำหรับเกม
class_name GameGlobal

# ชื่อของผู้เล่นคนนี้ (กำหนดจากเมนู)
var my_name: String = ""

# รายชื่อผู้เล่นทั้งหมด: {peer_id: player_name}
var players: Dictionary = {}
var players_point: Dictionary = {}
var players_turn: Dictionary = {}
var player_order = []

var current_turn_index: int = 0
var player_positions: Dictionary = {}  # {peer_id: position}

func copy_player_id():
	players_point = players.duplicate()
	for id in players_point.keys():
		players_point[id] = 0 

	players_turn = players.duplicate()
	for id in players_turn.keys():
		players_turn[id] = 0 
	
	# สุ่มเลือก 1 key และตั้งค่าเป็น 1
	var random_key = players_turn.keys().pick_random()
	players_turn[random_key] = 1

# ENet peer ที่ใช้เชื่อมต่อกับเซิร์ฟเวอร์
var peer: ENetMultiplayerPeer = null

func _init():
	print("🌍 Global initialized")


# ฟังก์ชันเมื่อมี Client เข้ามา
func add_client(id: int, name: String):
	# หา ID ที่ว่างเริ่มจาก 2
	var new_id = 2
	while players.has(new_id) and new_id <= 4:
		new_id += 1
	
	if new_id > 4:
		print("⚠️ เกมเต็มแล้ว ไม่สามารถเพิ่มผู้เล่นได้")
		return
	
	add_player(new_id, name)
	player_order.append(new_id)
	player_order.sort()  # เรียงลำดับ 1,2,3,4

# เมื่อเพิ่มผู้เล่นใหม่
func add_player(id: int, name: String) -> void:
	players[id] = name
	player_positions[id] = 0


# ลบผู้เล่น (เมื่อ disconnect)
func remove_player(id: int) -> void:
	if players.has(id):
		print("🔴 ลบผู้เล่น: [%d] %s" % [id, players[id]])
		players.erase(id)
		
	if player_positions.has(id):
		player_positions.erase(id)
		
	if player_order.has(id):
		player_order.erase(id)
		


#func get_current_turn_id() -> int:
	#if player_order.size() == 0:
		#return 0
	#return player_order[current_turn_index]
#
#func advance_turn():
	#if player_order.size() == 0:
		#return
	#current_turn_index = (current_turn_index + 1) % player_order.size()
