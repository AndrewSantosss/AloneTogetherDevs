extends Node

var scene_path_to_load: String
var loading_screen_instance: Node
var progress: Array = []
var is_loading: bool = false

func load_scene(path: String):
	# --- FIX: VIP PASS FOR SCENE 5 ---
	# Kapag Scene 5 ang pupuntahan, HUWAG NA mag-loading screen.
	# Dumiretso agad para gumana ang cutscene nang walang harang.
	if "Scene5" in path:
		print("SceneLoader: Scene 5 detected! Skipping loading screen...")
		
		# Kung sakaling may loading screen na naiwan, burahin muna
		if is_instance_valid(loading_screen_instance):
			loading_screen_instance.queue_free()
			
		get_tree().change_scene_to_file(path)
		return
	# ---------------------------------

	if is_loading:
		print("SceneLoader: Already loading. Ignoring request.")
		return
		
	scene_path_to_load = path
	
	# Manually load the visual loading screen scene
	# Siguraduhin na tama ang path kung nasaan ang LoadingScreen.tscn mo
	var loading_screen_resource = load("res://LoadingScreen.tscn")
	
	if loading_screen_resource:
		loading_screen_instance = loading_screen_resource.instantiate()
		# Idagdag sa root para makita sa ibabaw ng lahat
		get_tree().root.add_child(loading_screen_instance)
	else:
		print("SceneLoader Error: Could not find LoadingScreen.tscn")
		# Kung wala ang loading screen, subukang mag-load pa rin nang diretso
		get_tree().change_scene_to_file(path)
		return
	
	# Start background loading (Threaded)
	var error = ResourceLoader.load_threaded_request(path)
	if error == OK:
		is_loading = true
		set_process(true)
	else:
		print("SceneLoader Error: Failed to start threaded load. Error code: ", error)
		is_loading = false
		if is_instance_valid(loading_screen_instance):
			loading_screen_instance.queue_free()

func _process(_delta):
	if not is_loading:
		set_process(false)
		return

	# Check status ng loading
	var status = ResourceLoader.load_threaded_get_status(scene_path_to_load, progress)
	
	# Update ProgressBar nang ligtas
	if is_instance_valid(loading_screen_instance):
		if loading_screen_instance.has_node("ProgressBar"):
			loading_screen_instance.get_node("ProgressBar").value = progress[0] * 100
	
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		# Loading complete!
		is_loading = false
		var new_scene = ResourceLoader.load_threaded_get(scene_path_to_load)
		get_tree().change_scene_to_packed(new_scene)
		
		# Tanggalin na ang loading screen
		if is_instance_valid(loading_screen_instance):
			loading_screen_instance.queue_free()
			
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		print("SceneLoader Error: Loading failed or invalid resource.")
		is_loading = false
		if is_instance_valid(loading_screen_instance):
			loading_screen_instance.queue_free()
