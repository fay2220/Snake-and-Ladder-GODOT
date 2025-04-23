extends Node

#ชื่อของผู้เล่นคนนี้ (กำหนดจากหน้าเมนู)
var my_name: String = ""

#เก็บรายชื่อผู้เล่นทั้งหมดในรูปแบบ [id] = name
var players: Dictionary = {}

#ตัวจัดการการเชื่อมต่อ (Host หรือ Client)
var peer: ENetMultiplayerPeer = null

#เรียกเมื่อ script ถูกโหลด (ครั้งเดียว)
func _init():
	print("🌍 Global initialized")  # ใช้ตรวจสอบว่าทำงานจริง

#เพิ่มผู้เล่นใหม่ลงใน Dictionary (Host เท่านั้นที่ใช้)
func add_player(id: int, name: String) -> void:
	players[id] = name
	print("🟢 เก็บผู้เล่นใน Global: [%d] %s" % [id, name])

#ลบผู้เล่นออก (กรณี disconnect)
func remove_player(id: int) -> void:
	if players.has(id):
		print("🔴 ลบผู้เล่นออกจาก Global: [%d] %s" % [id, players[id]])
		players.erase(id)

#เคลียร์รายชื่อทั้งหมด (เช่น ตอนออกจากห้อง)
func clear_players() -> void:
	print("♻️ เคลียร์รายชื่อผู้เล่นทั้งหมด")
	players.clear()
