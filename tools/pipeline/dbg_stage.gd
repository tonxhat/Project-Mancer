extends Node
func _ready():
	await get_tree().process_frame
	var r = get_tree().current_scene
	r.get_node("BattleUI").auto_battle = true
	r.get_node("StageSet").stage = OS.get_environment("STAGE")
	if OS.get_environment("DOF") != "1":
		r.dof_enabled = false
