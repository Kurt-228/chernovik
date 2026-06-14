extends Button
## Single choice button in dialogue overlay.

var choice_id: String = ""

func setup(id: String, text: String) -> void:
	choice_id = id
	self.text = "→ " + text
