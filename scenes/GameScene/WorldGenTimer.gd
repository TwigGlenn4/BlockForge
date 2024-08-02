extends Node

var start_time:int


func _timer_start():
	start_time = Time.get_ticks_usec()

func _timer_stop():
	var end_time:int = Time.get_ticks_usec()
	print("\t[TIMER]: %.3fms." % [(end_time-start_time)/1000.0] )