extends ProgressBar


# # Called when the node enters the scene tree for the first time.
# func _ready():
# 	pass # Replace with function body.


# # Called every frame. 'delta' is the elapsed time since the previous frame.
# func _process(delta):
# 	pass


func init( max_val ):
	self.hide()
	self.max_value = max_val


func setval( new_val ):
	if !self.visible:
		self.show()
	
	self.value = new_val


func increment( amt ):
	if !self.visible:
		self.show()
	
	self.value += amt


func done():
	self.hide()
	self.value = 0