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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$DiceAnimation.hide()
	$GameOver.hide()
	pathPlayer = [
		$PathWalk/Player1,
		$PathWalk/Player2,
		$PathWalk/Player3,
		$PathWalk/Player4
	]
	

func _on_Dice_pressed() -> void:
	if DiceRun != 0: 
		$DiceFace.hide()
		$DiceAnimation.show() #เล่น animation ทอยลูกเต๋า
		$DiceAnimation.play("DiceRolling")
		DiceRun = 0;

func _on_DiceAnimation_animation_finished() -> void:
	$DiceAnimation.stop()
	randomize()
	DiceNumber = (randi() % 6) + 1
	
	$DiceFace.show() #เล่นเสร็จแสดงหน้าลูกเต๋าที่สุ่มได้
	$DiceAnimation.hide()
	$DiceFace.set_frame(DiceNumber-1)
	print("Dice Number = ",DiceNumber)
	print("Player Pose[turn] = ",playerPose[turn])
	print("turn = ",turn)
	
	if PlayerMove[turn]:
		var pos = pathPlayer[turn].position
		var curve = $PathWalk.get_curve()
		var offset = curve.get_closest_offset(pos)
		iniPose = playerPose[turn]
		playerPose[turn] += DiceNumber
		start_timer()
		snake_ladder(playerPose[turn],turn)
		inspect_Winner()
		print("Player Pose หลังเดิน = ",playerPose[turn])
		print("-----------------------------------")
		
	elif DiceNumber in [1,2,3,4,5,6]:
		if PlayerMove[turn] == 0:
			var pos = pathPlayer[turn].position
			var curve = $PathWalk.get_curve()
			var offset = curve.get_closest_offset(pos)
			var pathPoint = curve.sample_baked(offset)
			pathPlayer[turn].position = pathPoint
			
			playerPose[turn] = DiceNumber - 1
			PlayerMove[turn] = 1
			iniPose = 0
			snake_ladder(playerPose[turn],turn)
			start_timer()  # เดินตามแต้มลูกเต๋า
	else:
		_on_Main_timer_on_end()  # ถ้าเคยเดินแล้ว ค่อยเปลี่ยนเทิร์น
	#elif DiceNumber in [1,2,3,4,5,6]:
		#var pos = pathPlayer[turn].position
		#var curve = $PathWalk.get_curve()
		#var offset = curve.get_closest_offset(pos)
		#var pathPoint = curve.sample_baked(offset)
		#pathPlayer[turn].position = pathPoint
		#if PlayerMove[turn] == 0:
			#playerPose[turn] = DiceNumber - 1
			#PlayerMove[turn] = 1
			#iniPose = 0
			#start_timer()
			#return
		#playerPose[turn] = 0
		#PlayerMove[turn] = 1
		#_on_Main_timer_on_end()
		#print("offset = ",offset,", pathPoint = ",pathPoint)
		#print("-----------------------------------")
	#else:
		#_on_Main_timer_on_end()
	
	
	
	
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
	
