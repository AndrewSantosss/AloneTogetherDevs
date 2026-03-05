extends Node

var scene_path_to_load: String
var loading_screen_instance: Node
var progress: Array = []
var is_loading: bool = false
var fake_timer: float = 0.0

# --- RANDOM TIPS LIST ---
var tips = [
	"Always check your health, press I to open inventory and use Medkit",
	"You can sprint using Shift key",
	"You can change camera using C",
	"You can change from melee to shotgun and vice versa using scroll wheel",
	"Fun Fact: The Game is based in Olongapo City, the hometown of the developers!"
]

func load_scene(path: String):
	# --- FIX: VIP PASS FOR SCENE 5 ---
	if "Scene5" in path:
		print("SceneLoader: Scene 5 detected! Skipping loading screen...")
		
		if is_instance_valid(loading_screen_instance):
			loading_screen_instance.queue_free()
			
		get_tree().change_scene_to_file(path)
		return
	# ---------------------------------

	if is_loading:
		print("SceneLoader: Already loading. Ignoring request.")
		return
		
	scene_path_to_load = path
	fake_timer = 0.0 # Reset ang timer sa simula ng load
	
	var loading_screen_resource = load("res://LoadingScreen.tscn")
	
	if loading_screen_resource:
		loading_screen_instance = loading_screen_resource.instantiate()
		get_tree().root.add_child(loading_screen_instance)
		
		# --- RANDOM TIP LOGIC ---
		# Sinisigurado na may TipLabel node sa loob ng LoadingScreen.tscn
		if loading_screen_instance.has_node("TipLabel"):
			randomize()
			var random_tip = tips[randi() % tips.size()]
			loading_screen_instance.get_node("TipLabel").text = random_tip
	else:
		print("SceneLoader Error: Could not find LoadingScreen.tscn")
		get_tree().change_scene_to_file(path)
		return
	
	var error = ResourceLoader.load_threaded_request(path)
	if error == OK:
		is_loading = true
		set_process(true)
	else:
		print("SceneLoader Error: Failed to start threaded load. Error code: ", error)
		is_loading = false
		if is_instance_valid(loading_screen_instance):
			loading_screen_instance.queue_free()

func _process(delta):
	if not is_loading:
		set_process(false)
		return

	# Dagdagan ang timer base sa delta time
	fake_timer += delta

	# Check status ng loading
	var status = ResourceLoader.load_threaded_get_status(scene_path_to_load, progress)
	
	# Update ProgressBar nang ligtas base sa actual progress
	if is_instance_valid(loading_screen_instance):
		if loading_screen_instance.has_node("ProgressBar"):
			# Pinagsasama ang actual loading at fake timer para sa smooth bar
			var actual_prog = progress[0] if progress.size() > 0 else 0.0
			var displayed_prog = min(actual_prog, fake_timer / 5.0) 
			loading_screen_instance.get_node("ProgressBar").value = displayed_prog * 100
	
	# Lilipat lang kung LOADED na ang file AT lumipas na ang 3 SECONDS
	if status == ResourceLoader.THREAD_LOAD_LOADED and fake_timer >= 3.0:
		is_loading = false
		var new_scene = ResourceLoader.load_threaded_get(scene_path_to_load)
		get_tree().change_scene_to_packed(new_scene)
		
		if is_instance_valid(loading_screen_instance):
			loading_screen_instance.queue_free()
			
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		print("SceneLoader Error: Loading failed or invalid resource.")
		is_loading = false
		if is_instance_valid(loading_screen_instance):
			loading_screen_instance.queue_free()
