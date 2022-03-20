extends Object

class_name Triangle

var vertices = []; #Array of Vector3
var neighbours = []; #Array of Triangle
var room:Room;

func CalcArea()->float:
	var a:float=(vertices[0]-vertices[1]).length();
	var b:float=(vertices[1]-vertices[2]).length();
	var c:float=(vertices[2]-vertices[0]).length();
	var s:float=(a+b+c)*0.5;
	return sqrt(s*(s-a)*(s-b)*(s-c));


func _init(v1:Vector3, v2:Vector3, v3:Vector3):
	vertices.append(v1);
	vertices.append(v2);
	vertices.append(v3);

func isNeighbour(other:Triangle)->bool:
	for i in range(3):
		for j in range(3):
			if (vertices[i] - other.vertices[j]).length_squared() < 0.0001:
				return true;
	return false;

func FindNeighbourRoomPoints(other:Triangle)->FindNeighbourRoomPointsResult:
	var result:FindNeighbourRoomPointsResult=FindNeighbourRoomPointsResult.new();
	for i in range(3):
		for j in range(3):
			if (vertices[i] - other.vertices[j]).length_squared() < 0.0001:
				result.myPoints.append(RoomPoint.new(vertices[i], room, self));
				result.otherPoints.append(RoomPoint.new(other.vertices[j], other.room,other));
	return result;

func getNormal()->Vector3:
	var v1:Vector3=vertices[0]-vertices[1];
	var v2:Vector3=vertices[0]-vertices[2];
	var norm = v1.cross(v2).normalized();
	return norm;


