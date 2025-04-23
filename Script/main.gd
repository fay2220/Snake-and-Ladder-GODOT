extends Node2D

var DiceRun = 1
var DicePosition = [1038,182]
var DiceNumber = 0
var PlayerMove = [0, 0, 0, 0]
var scalePlayer = [0, 0, 0, 0]
var turn = 0
var iniPose = 0

var playerPose = [0,0,0,0]
var ladderPose = [5,14,42,53,64,75]
var ladderGoes = [58,49,60,72,83,94]
var snakePose = [38,45,51,76,91,97]
var snakeGoes = [20,7,10,54,73,61]
signal timer_on_end
var p1
var p2

var pathPlayer = []
@onready var dice_animation = $DiceAnimation 
@onready var dice_button = $DiceFace/Button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Global.peer:
		multiplayer.multiplayer_peer = Global.peer
	else:
		print("ไม่มี peer จาก Global")
		
	if has_node("DiceAnimation"):
		$DiceAnimation.hide()
	if has_node("GameOver"):
		$GameOver.hide()
	
	for i in range(1, 5):
		var player_path = "PathWalk/Player%d" % i
		if has_node(player_path):
			var player_node = get_node(player_path)
			pathPlayer.append(player_node)
		else:
			pathPlayer.append(null)  
			
	# Sync การควบคุมเฉพาะผู้เล่นของตัวเอง (client แต่ละเครื่อง)
	var my_id = multiplayer.get_unique_id()
	if Global.players.has(my_id):
		var my_index = get_player_index_by_id(my_id)
		if my_index >= 0:
			print("คุณควบคุม Player%d: %s" % [my_index + 1, Global.players[my_id]])
		else:
			print("ไม่พบ Player ID ใน Global.players")
	else:
		print("ไม่มีชื่อผู้เล่นใน Global.players")
		
func get_player_index_by_id(id: int) -> int:
	var index = 0
	for player_id in Global.players.keys():
		if player_id == id:
			return index
		index += 1
	return -1
	

func _on_Dice_pressed() -> void:
	if DiceRun != 0: 
		$DiceFace.hide()
		$DiceAnimation.show()
		$DiceAnimation.play("DiceRolling")
		DiceRun = 0

		# ขอให้ host ทอยให้
		var host_id = multiplayer.get_peers()[0]
		print("Host id = ",host_id)
		request_roll_dice.rpc_id(host_id, multiplayer.get_unique_id())
		
func _on_DiceAnimation_animation_finished() -> void:
	if is_multiplayer_authority():
		$DiceAnimation.hide()
		$DiceFace.show()
		$DiceFace.set_frame(DiceNumber - 1)
		print("[HOST] Rolled =", DiceNumber, "turn =", turn)
		sync_dice_result.rpc(DiceNumber, turn) 
		
	else:
		# Client ที่ไม่ใช่ authority ให้โชว์ DiceFace ตรงนี้เลยเพื่อความชัวร์
		$DiceAnimation.hide()
		$DiceFace.show()
		$DiceFace.set_frame(DiceNumber - 1)
	DiceRun = 1
	print("multiplayer unique ID = ",multiplayer.get_unique_id())
	print("Dice Number = ",DiceNumber)
	print("Player Pose[turn] = ",playerPose[turn])
	print("turn = ",turn)
	print("______________________________________")
	
@rpc("reliable", "any_peer")
func sync_dice_result(dice: int, synced_turn: int):
	DiceNumber = dice
	turn = synced_turn
	var pos = pathPlayer[turn].position
	var curve = $PathWalk.get_curve()
	var offset = curve.get_closest_offset(pos)
	print("SYNCED - Dice = %d, Turn = %d" % [DiceNumber, turn])
	
	if PlayerMove[turn]:
		iniPose = playerPose[turn]
		playerPose[turn] += DiceNumber
		start_timer()
		snake_ladder(playerPose[turn], turn)
		inspect_Winner()
		_on_Main_timer_on_end()
	elif DiceNumber in [1, 2, 3, 4, 5, 6]:
		var pathPoint = curve.sample_baked(offset)
		pathPlayer[turn].position = pathPoint
		playerPose[turn] = DiceNumber - 1
		PlayerMove[turn] = 1
		iniPose = 0
		snake_ladder(playerPose[turn], turn)
		start_timer()
		
	else:
		_on_Main_timer_on_end()
		
@rpc("reliable", "authority")
func request_roll_dice(requester_id):
	randomize()
	DiceNumber = (randi() % 6) + 1
	sync_dice_result.rpc(DiceNumber, requester_id)


func check_position(turn,pose):
	var set = []
	for x in range(playerPose.size()):
		for y in range(playerPose.size() - x - 1):
			if playerPose[x] == playerPose[y+x+1]:
				set.append(y+x+1)
				if set.find(x) != 1:
					set.append(x)
					
	var reset = [0,1,2,3]				
	if set.size() > 1:
		for x1 in range(set.size()):
			reset.erase(set[x1])
			if set[x1] == 0:
				if scalePlayer[0] == 0:
					$PathWalk/Player1.position.x += -15
					$PathWalk/Player1.scale = Vector2(0.05, 0.05)
					scalePlayer[0] = 1
			elif set[x1] == 1:
				if scalePlayer[1] == 0:
					$PathWalk/Player2.position.y += -15
					$PathWalk/Player2.scale = Vector2(0.05, 0.05)
					scalePlayer[1] = 1
			elif set[x1] == 2:
				if scalePlayer[2] == 0:
					$PathWalk/Player3.position.x += 15
					$PathWalk/Player3.scale = Vector2(0.05, 0.05)
					scalePlayer[2] = 1
			elif set[x1] == 3:
				if scalePlayer[3] == 0:
					$PathWalk/Player4.position.y += 15
					$PathWalk/Player4.scale = Vector2(0.05, 0.05)
					scalePlayer[3] = 1
	
	if reset.size() > 0:
		for x1 in range(reset.size()):
			if reset[x1] == 0:
				if scalePlayer[0] == 1:
					$PathWalk/Player1.scale = Vector2(0.094, 0.094)
					scalePlayer[0] = 0
			elif reset[x1] == 1:
				if scalePlayer[1] == 1:
					$PathWalk/Player2.scale = Vector2(0.094, 0.094)
					scalePlayer[1] = 0
			elif reset[x1] == 2:
				if scalePlayer[2] == 1:
					$PathWalk/Player3.scale = Vector2(0.094, 0.094)
					scalePlayer[x1] = 0
			elif reset[x1] == 3:
				if scalePlayer[3] == 1:
					$PathWalk/Player4.scale = Vector2(0.094, 0.094)
					scalePlayer[3] = 0

func snake_ladder(pose,player):
	var snake = snakePose.find(pose+1,0)
	var ladder = ladderPose.find(pose+1,0)
	if snake != -1:
		playerPose[player] = snakeGoes[snake] - 1
		iniPose = pose  # จุดเริ่มต้นการเดิน (ยังเป็นจุดก่อนงู)
		start_timer() 
		print("🐍 Snake found! playerPose[player] = ", playerPose[player])
		return

		#playerPose[player] = snakeGoes[snake] - 1
		#var pathPoint = $PathWalk.get_curve().get_point_position(playerPose[player]) #เข้าถึง Curve2D ที่อยู่ใน PathWalk แล้ว ดึงจุดแรกในเส้นทาง (ตำแหน่ง index = 0)
		#pathPlayer[player].position = pathPoint
		#print("snake = ",snake)
		#print("playerPose[player] in snake= ",snakeGoes[snake] - 1)
		#print("pathPoint Snake = ",pathPoint)
		#
	if ladder != -1:
		playerPose[player] = ladderGoes[ladder] - 1
		iniPose = pose  # จุดเริ่มต้นการเดินขึ้นบันได
		start_timer()
		print("playerPose[player] in ladder = ",ladderGoes[ladder] - 1)
	
func start_timer():
	$Timer.start(0.1)	

func _on_timer_timeout() -> void:
	# เดินหน้า
	if iniPose < playerPose[turn]:
		iniPose += 1
	# ถอยหลัง
	elif iniPose > playerPose[turn]:
		iniPose -= 1
	var pathPoint = $PathWalk.get_curve().get_point_position(iniPose) 
	pathPlayer[turn].position = pathPoint
	
	if iniPose == playerPose[turn]:
		$Timer.stop()
		emit_signal("timer_on_end")


func _on_Main_timer_on_end() -> void:
	check_position(turn,playerPose[turn])
	DiceRun = 1
	turn += 1
	if turn == 4:
		turn = 0

func inspect_Winner() -> void:
	if playerPose[turn] > 99:
		print("We got a winner,The winner is Player",turn+1)
		GameOver()

func GameOver() -> void:
	$GameOver.show()
	$DiceFace.stop()
	$BG.modulate = Color(0, 0, 0, 0.4)
	$Map.modulate = Color(0, 0, 0, 0.4)
	$DiceFace.modulate = Color(0, 0, 0, 0.4)
	
