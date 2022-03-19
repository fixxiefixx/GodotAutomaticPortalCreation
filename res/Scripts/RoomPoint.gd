extends Object

class_name RoomPoint

var pos:Vector3;
var room:Room;
var triangle;#Triangle

func _init(pos:Vector3, room:Room, triangle):
	self.pos=pos;
	self.room=room;
	self.triangle=triangle;
