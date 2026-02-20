extends Node

# This array remembers every unique cutscene ID the player has watched
var viewed_content = []

# Call this to check if a cutscene has been seen
func has_seen(id: String) -> bool:
	return id in viewed_content

# Call this to mark a cutscene as seen so it doesn't play again
func mark_as_seen(id: String):
	if not id in viewed_content:
		viewed_content.append(id)
