extends RoomManager


# Called when the node enters the scene tree for the first time.
func _ready():
	GeneratePortals();

func ClearPortals(mapNode:Node)->void:
	for child in mapNode.get_children():
		if child is Portal:
			child.queue_free();
		else:
			ClearPortals(child);
			

func getRoomBounds(room:Room)->AABB:
	var bounds=null;
	for child in room.get_children():
		if child is MeshInstance:
			var meshi:MeshInstance=child;
			if bounds == null:
				bounds = meshi.get_transformed_aabb();
			else:
				bounds=bounds.merge(meshi.get_transformed_aabb());
	if bounds == null:
		bounds=AABB();
	return bounds;

func FindNearbyRooms(myRoom:Room):#Returns Array of Room
	var testBounds:AABB=getRoomBounds(myRoom);
	testBounds=testBounds.grow(0.01);
	var overlappingRooms=[];
	var mapNode:Node = get_node(roomlist);
	for child in mapNode.get_children():
		if child is Room:
			var roomBounds:AABB=getRoomBounds(child);
			if testBounds.intersects(roomBounds) && myRoom != child:
				overlappingRooms.append(child);
	return overlappingRooms;
	


func GenerateRooms(mapNode:Node):#Returns Array of Room
	var rooms = [];
	for child in mapNode.get_children():
		if child is MeshInstance:
			var room = Room.new();
			mapNode.remove_child(child);
			mapNode.add_child(room);
			room.add_child(child);
			rooms.append(room);
	return rooms;

func GetRoomTriangles(room:Room):#Returns Array of Triangle
	var triangles = [];
	for child in room.get_children():
		if child is MeshInstance:
			var meshi:MeshInstance=child;
			var mesh:Mesh=child.mesh;
			for i in range(mesh.get_surface_count()):
				var submesh = mesh.surface_get_arrays(i);
				var vertices:PoolVector3Array=submesh[Mesh.ARRAY_VERTEX];
				var trisIndexes:PoolIntArray=submesh[Mesh.ARRAY_INDEX];
				var j:int=0;
				for tmp in range(trisIndexes.size()/3):
					#convert model to world space
					var p1:Vector3 = meshi.transform.xform(vertices[trisIndexes[j]]);
					var p2:Vector3 = meshi.transform.xform(vertices[trisIndexes[j+1]]);
					var p3:Vector3 = meshi.transform.xform(vertices[trisIndexes[j+2]]);
					var tri:Triangle = Triangle.new(p1,p2,p3);
					tri.room=room;
					triangles.append(tri);
					j+=3;
	return triangles;
				
#uniqueConnectedRoomPoints: Array of RoomPoint
func AddRoomPointToUniquePortalPointsWithPositionCheck(uniqueConnectedRoomPoints:Array, roomPointToAdd:RoomPoint)->void:
	var positionOccupied:bool=false;
	for testPoint in uniqueConnectedRoomPoints:
			if (testPoint.pos-roomPointToAdd.pos).length_squared() < 0.0001:
				positionOccupied=true;
				break;
	if !positionOccupied:
		uniqueConnectedRoomPoints.append(roomPointToAdd);

func GenerateBoundsFromRoomPoints(points:Array)->AABB:
	var bounds:AABB=AABB(points[0].pos,Vector3.ZERO);
	for rp in points:
		bounds=bounds.expand(rp.pos);
	return bounds;

func getCenterOfBounds(bounds:AABB)->Vector3:
	return bounds.position.linear_interpolate(bounds.end,0.5);

func generatePortalPointsFromBounds(bounds:AABB)->PoolVector2Array:
	var points:PoolVector2Array=PoolVector2Array();
	var l:float=bounds.get_longest_axis().length() / 2;
	points.append(Vector2(l,-l));
	points.append(Vector2(l,l));
	points.append(Vector2(-l,l));
	points.append(Vector2(-l,-l));
	return points;

func GeneratePortalFromConnectedRoomPoints(myRoom:Room, otherRoom:Room, points:Array)->void:
	if points.size() < 3:
		return;
	var p1:Vector3=points[0].pos;
	var p2:Vector3=points[1].pos;
	for i in range(2,points.size()):
		var p3:Vector3 = points[i].pos;
		
		var a:Vector3=p2-p1;
		var b:Vector3=p3-p1;
		var n:Vector3=a.cross(b);
		if n.length_squared() > 0.0001:
			n=n.normalized();
			#We have a working normal for the portal.
			#Now we have to determine if we have to flip the normal.
			
			var myCenter:Vector3 = getCenterOfBounds(getRoomBounds(myRoom));
			var otherCenter:Vector3 = getCenterOfBounds(getRoomBounds(otherRoom));
			var directionToOtherRoom = otherCenter - myCenter;
			if n.dot(directionToOtherRoom) < 0:
				n = -n;
			
			var portal:Portal=Portal.new();
			portal.two_way=false;
			portal.linked_room = otherRoom.get_path();
			var bounds:AABB=GenerateBoundsFromRoomPoints(points);
			myRoom.add_child(portal);
			var center:Vector3=getCenterOfBounds(bounds);
			#portal.transform.origin=portal.to_local(getCenterOfBounds(bounds));
			portal.look_at_from_position(center, center + n, Vector3.UP);
			

func GeneratePortalsForRoom(room:Room, roomTriangles)->void:
	var nearbyRooms:Array=FindNearbyRooms(room);
	var triangles:Array=roomTriangles[room];
	for nearbyRoom in nearbyRooms:
		var uniqueConnectedRoomPoints:Array = [];
		var nearbyRoomTriangles:Array=roomTriangles[nearbyRoom];
		for tri in triangles:
			for otherTri in nearbyRoomTriangles:
				var result:FindNeighbourRoomPointsResult = tri.FindNeighbourRoomPoints(otherTri);
				for rp in result.myPoints:
					AddRoomPointToUniquePortalPointsWithPositionCheck(uniqueConnectedRoomPoints,rp);
		GeneratePortalFromConnectedRoomPoints(room,nearbyRoom,uniqueConnectedRoomPoints);
	

func GeneratePortals():
	var mapNode:Node = get_node(roomlist);
	#ClearPortals(mapNode);
	var rooms = GenerateRooms(mapNode);
	var roomTriangles = {};
	
	for room in rooms:
		roomTriangles[room]=GetRoomTriangles(room);
	
	for room in rooms:
		GeneratePortalsForRoom(room,roomTriangles);
		print_debug("Generated portals for room "+room.name);
	
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
