extends Control

@onready var player_list_label = $NinePatchRect/PlayerListContainer/PlayerListLabel # หรือ RichTextLabel
@onready var exit_button = $NinePatchRect2/Exit_button
@onready var start_button = $NinePatchRect3/StartButton
@onready var countdown_label = $CountdownLabel
@onready var server_closed_label = $ServerClosedLabel
@onready var PlayerListContainer = $NinePatchRect/PlayerListContainer


var is_changing_scene := false
var countdown_timer: Timer
var current_countdown := 5

func _ready():
	countdown_timer = Timer.new()
	add_child(countdown_timer)
	countdown_timer.timeout.connect(_on_countdown_timer_timeout)
	countdown_label.hide()
	server_closed_label.hide()
	
	start_button.visible = multiplayer.is_server()
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(start_exit)
	
	# เฉพาะ Host เท่านั้นที่เพิ่มตัวเอง
	if multiplayer.is_server():
		Global.players[1] = Global.my_name
		update_player_list()

	# เชื่อม signal รอรับชื่อจาก client
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# แสดงข้อความเซิร์ฟเวอร์ปิด (ทำงานทั้ง Host และ Client)
@rpc("authority", "call_local", "reliable")
func notify_server_shutdown(message: String):
	print(message)
	server_closed_label.text = message
	server_closed_label.show()

# ฟังก์ชันจัดการเมื่อ Host ออก
func handle_host_disconnected():
	print("❌ เซิร์ฟเวอร์หลักออกจากเกม")
	show_server_closed_message()
	await get_tree().create_timer(3.0).timeout
	# เปลี่ยนไปหน้าเมนูหลักแทน quit()
	get_tree().change_scene_to_file("res://Scene/main.tscn")

# เมื่อ Host ออกจากเกม
func _exit_tree():
	if is_changing_scene:
		return 

	if multiplayer.is_server() && multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		notify_server_shutdown.rpc("⚠️ เซิร์ฟเวอร์ปิดการเชื่อมต่อ")
		await get_tree().create_timer(0.5).timeout
		multiplayer.multiplayer_peer.close()

func start_exit():
	if multiplayer.is_server():
		Global.players.clear()
		notify_server_shutdown.rpc("เซิร์ฟเวอร์ปิดโดยผู้ดูแล")
		await get_tree().create_timer(3).timeout
	multiplayer.multiplayer_peer.close()
	Global.players.clear()
	get_tree().change_scene_to_file("res://Scene/main.tscn")

# แสดงข้อความบน UI
func show_server_closed_message():
	var msg = "เซิร์ฟเวอร์ปิดการเชื่อมต่อ\nกำลังกลับไปหน้าเมนูหลัก..."
	server_closed_label.text = msg
	server_closed_label.show()


# เมื่อมี client ใหม่เชื่อมต่อ
func _on_peer_connected(id: int):
	
	print("🟢 Player joined: ", id)
	# ถ้าเป็น host (server) ให้ส่งชื่อผู้เล่นทั้งหมดไปให้ client ใหม่
	if multiplayer.is_server():
		# ส่งข้อมูลผู้เล่นทั้งหมดไปให้ client ใหม่
		update_player_list_to_client.rpc_id(id, Global.players)
		# ขอชื่อจาก client ใหม่
		request_player_name.rpc_id(id)
	else:
		Global.players[id] = Global.my_name
		print("➕ Client added self to Global.players")
		update_player_list()  # อัปเดต UI ทันที

# เมื่อ client ตัดการเชื่อมต่อ
func _on_peer_disconnected(id: int):
	print("🔴 Player left: ", id)
	Global.players.erase(id)
	update_player_list()
	
	# ตรวจสอบเงื่อนไขผิด (ต้องไม่ใช่ is_server())
	if id == 1:  # ถ้า ID 1 (Host) ออก
		handle_host_disconnected()
	elif multiplayer.is_server():
		update_player_list_to_all_clients()

@rpc("any_peer", "reliable")
func send_name_to_host(name: String):
	var sender_id = multiplayer.get_remote_sender_id()
	print("📨 Received name from:", sender_id, "Name:", name)
	
	# เพิ่มชื่อผู้เล่นใหม่
	Global.players[sender_id] = name
	update_player_list()

	# Host ส่งรายชื่ออัปเดตไปให้ทุกคน
	if multiplayer.is_server():
		update_player_list_to_all_clients()

# Client ส่งชื่อกลับมาให้ host
@rpc("any_peer", "call_local", "reliable")
func receive_player_name(id: int, name: String):
	Global.players[id] = name
	update_player_list()
	
	# Host อัปเดตให้ client ทุกคนทราบ
	if multiplayer.is_server():
		update_player_list_to_all_clients()

# Host ขอชื่อจาก client ใหม่
@rpc("authority", "call_local", "reliable")
func request_player_name():
	# Client ส่งชื่อของตัวเองกลับไปยัง host พร้อมกับ unique ID
	receive_player_name.rpc_id(1, multiplayer.get_unique_id(), Global.my_name)

# Host ส่งรายชื่อผู้เล่นทั้งหมดไปให้ client ใหม่
@rpc("authority", "call_local", "reliable")
func update_player_list_to_client(players_list: Dictionary):
	Global.players = players_list
	update_player_list()
	
# Host อัปเดตรายชื่อผู้เล่นให้ทุก client
func update_player_list_to_all_clients():
	for peer_id in multiplayer.get_peers():
		update_player_list_to_client.rpc_id(peer_id, Global.players)
	
# อัปเดต UI รายชื่อผู้เล่น
func update_player_list():
	# เคลียร์รายชื่อเก่า
	for child in PlayerListContainer.get_children():
		child.queue_free()
	
	# สร้าง Header
	var header = Label.new()
	header.text = "👥 ผู้เล่นในห้อง %d คน" % Global.players.size()
	header.add_theme_font_size_override("font_size", 18)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PlayerListContainer.add_child(header)
	
	# เรียงลำดับ ID
	var sorted_ids = Global.players.keys()
	sorted_ids.sort()

	for id in sorted_ids:
		var name = Global.players[id]
		var prefix = "👑 " if int(id) == 1 else "🧑 "
		var you = " (คุณ)" if (int(id) == multiplayer.get_unique_id()) else ""
		
		# สร้าง Panel สำหรับพื้นหลังแต่ละคน
		var panel = Panel.new()
		panel.custom_minimum_size = Vector2(0, 40)
		
		# กำหนดสีพื้นหลัง
		var bg_color = Color(0.2, 0.2, 0.2) if int(id) % 2 == 0 else Color(0.25, 0.25, 0.25)
		panel.self_modulate = bg_color
		
		# เน้นผู้เล่นปัจจุบัน
		if int(id) == multiplayer.get_unique_id():
			panel.self_modulate = Color(0.1, 0.3, 0.1)
		
		# สร้างและจัดวาง Label
		var label = Label.new()
		label.text = "%s%s%s" % [prefix, name, you]
		label.add_theme_color_override("font_color", Color.WHITE)
		panel.add_child(label)
		label.position = Vector2(10, 10)
		
		PlayerListContainer.add_child(panel)
		
		# เส้นคั่น (optional)
		var separator = HSeparator.new()
		PlayerListContainer.add_child(separator)

	# ลบเส้นคั่นสุดท้ายทิ้ง
	if PlayerListContainer.get_child_count() > 0:
		var last_child = PlayerListContainer.get_children()[-1]
		if last_child is HSeparator:
			last_child.queue_free()
	
	print("อัปเดตรายชื่อผู้เล่นแล้ว:", Global.players)
# เมื่อกดปุ่ม Start (เรียกจาก host)

func _on_start_pressed():
	Global.copy_player_id()
	print("Players initialized: ", Global.players)
	is_changing_scene = true
	start_countdown.rpc()
	updateGlobalPLayers.rpc(Global.players.duplicate())

@rpc("any_peer", "call_local", "reliable")
func updateGlobalPLayers(players_data: Dictionary):
	Global.players = players_data

@rpc("any_peer", "call_local", "reliable")
func start_countdown():
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
		
	countdown_label.show()
	current_countdown = 2
	countdown_label.text = "เกมจะเริ่มใน %d วินาที..." % current_countdown
	countdown_timer.start(1.0)

func _on_countdown_timer_timeout():
	current_countdown -= 1
	
	if current_countdown > 0:
		countdown_label.text = "เกมจะเริ่มใน %d วินาที..." % current_countdown
		countdown_timer.start(1.0)
	else:
		countdown_label.text = "เริ่มเกม!"
		countdown_timer.start(1.0)
		
		if multiplayer.is_server():
			# บอกทุกคนให้เปลี่ยน Scene
			_change_to_game_scene.rpc()


@rpc("any_peer", "call_local", "reliable")
func _change_to_game_scene():
	if countdown_timer:
		countdown_timer.stop()

	is_changing_scene = true
	
	if Global.peer:
		multiplayer.multiplayer_peer = Global.peer

	get_tree().change_scene_to_file("res://Scene/maingame.tscn")
