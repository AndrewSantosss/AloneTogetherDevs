extends Node

# Signal that fires whenever an item count changes (useful for updating UI)
signal inventory_updated(item_name, quantity)

# Dictionary to store items: { "item_name": quantity }
# We initialize them to 0 so the keys always exist
var inventory = {
	"medkit": 0,
	"candy": 0,
	"ammo": 0
}

# --- ADDING ITEMS ---
func add_item(item_name: String, amount: int = 1):
	if item_name in inventory:
		inventory[item_name] += amount
	else:
		inventory[item_name] = amount
	
	print("Inventory: Added ", amount, " ", item_name, ". Total: ", inventory[item_name])
	emit_signal("inventory_updated", item_name, inventory[item_name])

# --- REMOVING ITEMS ---
# Returns true if the item was successfully removed (meaning the player had enough)
# Returns false if the player didn't have the item
func remove_item(item_name: String, amount: int = 1) -> bool:
	if item_name in inventory and inventory[item_name] >= amount:
		inventory[item_name] -= amount
		print("Inventory: Removed ", amount, " ", item_name, ". Remaining: ", inventory[item_name])
		emit_signal("inventory_updated", item_name, inventory[item_name])
		return true
	
	print("Inventory: Not enough ", item_name, " to remove!")
	return false

# --- HELPER FUNCTIONS ---

# Checks if we have at least 1 of the item
func has_item(item_name: String) -> bool:
	return get_item_count(item_name) > 0

# specific getter for item count to avoid crashes if key missing
func get_item_count(item_name: String) -> int:
	return inventory.get(item_name, 0)

# A shortcut function to try and use an item immediately
func consume_item(item_name: String) -> bool:
	return remove_item(item_name, 1)
