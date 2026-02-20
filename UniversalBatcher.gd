@tool
extends Node3D

@export var bake: bool = false : set = _start_bake
@export var reset: bool = false : set = _reset_visuals

func _start_bake(value):
	if not value: return
	
	print("--- BATCHER V3 (Materials): Starting ---")
	
	# 1. Cleanup
	var old = get_node_or_null("BatchedResults")
	if old: old.free()
	
	# 2. Collect Data
	# Dictionary format: { [Mesh, Material]: [List of Nodes] }
	# We group by BOTH Mesh and Material so trees with different textures don't mix.
	var groups = {}
	var nodes = _get_all_mesh_instances(self)
	
	# 3. Sort Nodes
	for node in nodes:
		if node.get_parent().name == "BatchedResults" or node.name.begins_with("Batch_"): continue
		
		var m = node.mesh
		if not m: continue
		
		# Get the material (Prioritize Override, then Surface)
		var mat = node.get_active_material(0) 
		
		# Create a grouping key
		var key = [m, mat]
		
		if not groups.has(key): groups[key] = []
		groups[key].append(node)
	
	# 4. Generate Batches
	var container = Node3D.new()
	container.name = "BatchedResults"
	add_child(container)
	container.owner = get_tree().edited_scene_root
	
	for key in groups.keys():
		var mesh_res = key[0]
		var mat_res = key[1]
		var list = groups[key]
		
		if list.size() < 2: continue
		
		# Setup MultiMesh
		var mm = MultiMesh.new()
		mm.mesh = mesh_res
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.instance_count = list.size()
		# Huge bounding box to prevent flickering
		mm.custom_aabb = AABB(Vector3(-10000, -1000, -10000), Vector3(20000, 2000, 20000))
		
		# Setup Instance
		var mmi = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = "Batch_" + (mesh_res.resource_name if mesh_res.resource_name else "Object")
		
		# --- CRITICAL FIX: APPLY MATERIAL / SHADER ---
		if mat_res:
			mmi.material_override = mat_res
			# Ensure shader works for shadows if needed
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		else:
			# If grass, turn off shadow to save FPS
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
		container.add_child(mmi)
		mmi.owner = get_tree().edited_scene_root
		
		# Calculate Transforms
		var my_transform_inverse = global_transform.affine_inverse()
		
		for i in range(list.size()):
			var node = list[i]
			var local_t = my_transform_inverse * node.global_transform
			mm.set_instance_transform(i, local_t)
			node.visible = false

	print("--- Batching Complete with Shaders! ---")

func _get_all_mesh_instances(parent) -> Array:
	var res = []
	for c in parent.get_children():
		if c is MeshInstance3D and c.visible: res.append(c)
		if c.get_child_count() > 0: res.append_array(_get_all_mesh_instances(c))
	return res

func _reset_visuals(value):
	if not value: return
	if get_node_or_null("BatchedResults"): get_node("BatchedResults").queue_free()
	for n in _get_all_mesh_instances(self): n.visible = true
	print("Reset Done.")
