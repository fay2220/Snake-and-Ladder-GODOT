extends Control

@onready var host_button = $NinePatchRect/NinePatchRect/HostButton
@onready var join_button = $NinePatchRect/NinePatchRect/JoinButton
@onready var name_input = $NinePatchRect/NinePatchRect/NameInput
@onready var ip_input = $NinePatchRect/NinePatchRect/IPInput

const PORT := 12345

func _ready():
	host_button.pressed.connect(start_host)
	join_button.pressed.connect(start_join)

# 🟢 HOST
func start_host():
	var name = name_input.text.strip_edges()

	if name.is_empty():
		print("⚠️ กรุณากรอกชื่อก่อนสร้างห้อง")
		return
	
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	print("✅ Hosting server on port %s" % PORT)
	
	# ตรวจจับ client
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	# ส่งชื่อ host เก็บไว้ใน singleton (ถ้ามี)
	Global.my_name = name  # สมมุติว่าคุณมี Global.gd เป็น singleton

	# โหลด scene ห้อง
	get_tree().change_scene_to_file("res://Scene/RoomScene.tscn")
	print("Hosting Name" % Global.my_name)
	

func _on_peer_connected(id: int):
	print("🟢 Client connected with peer ID:", id)
	

func _on_peer_disconnected(id: int):
	print("🔴 Client disconnected with peer ID:", id)
	Global.remove_player(id) 
	
# 🔵 CLIENT
func start_join():
	var name = name_input.text.strip_edges()
	var SERVER_IP = ip_input.text.strip_edges()
	
	if name.is_empty():
		print("⚠️ กรุณากรอกชื่อก่อนเข้าห้อง")
		return
	if SERVER_IP.is_empty():
		print("⚠️ กรุณากรอกชื่อก่อนเข้าห้อง")
		return

	var peer = ENetMultiplayerPeer.new()
	peer.create_client(SERVER_IP, PORT)
	multiplayer.multiplayer_peer = peer
	print("🔄 Joining server at %s:%s..." % [SERVER_IP, PORT])

	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)  

	# โหลดห้อง (RoomScene)
	Global.my_name = name 
	get_tree().change_scene_to_file("res://Scene/RoomScene.tscn")

func _on_connected():
	print("✅ Connected to server!")
	
	# ตั้งชื่อก่อนส่งไปหา Host
	var id = multiplayer.get_unique_id()
	var player_name = name_input.text.strip_edges()
	
	Global.my_name = player_name
	
	# 1. ส่งชื่อไปหา Host ก่อน
	send_name_to_host.rpc_id(1, player_name)
	
	# 2. รอ 1 เฟรมเพื่อให้แน่ใจว่าส่งข้อมูลเสร็จ
	await get_tree().process_frame
	
	# 3. ค่อยเปลี่ยน Scene
	get_tree().change_scene_to_file("res://Scene/RoomScene.tscn")
	
	
func _on_connection_failed():
	print("❌ Failed to connect to server.")

# 📨 RPC ส่งชื่อไปยัง Host
@rpc("any_peer", "call_local", "reliable")
func send_name_to_host(name: String):
	var sender_id = multiplayer.get_remote_sender_id()
	print("📨 ได้รับชื่อจาก client: %s (ID: %s)" % [name, sender_id])
	
	# เก็บใน Global ของ Host
	if multiplayer.is_server():
		Global.players[sender_id] = name


func _process(delta):
	# ตรวจสอบการเชื่อมต่อของ Host
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			handle_connection_lost()
			set_process(false)  # หยุดการเรียก _process

func handle_connection_lost():
	print("⚠️ การเชื่อมต่อกับเซิร์ฟเวอร์ขาดหาย")
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://menu.tscn")
