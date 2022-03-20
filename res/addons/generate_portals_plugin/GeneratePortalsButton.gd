tool
extends Button

var editor_interface:EditorInterface;
var label_status:Label;
var progress:ProgressBar;

func _ready():
	label_status=$"../LabelStatus";
	progress=$"../ProgressBar";

func _on_Button_pressed():
	var selected_nodes:Array=editor_interface.get_selection().get_selected_nodes();
	if selected_nodes.size() > 0:
		var selected_node = selected_nodes[0];
		if selected_node is Node:
			GeneratePortals(selected_node);

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

func FindNearbyRooms(myRoom:Room, mapNode:Node):#Returns Array of Room
	var testBounds:AABB=getRoomBounds(myRoom);
	testBounds=testBounds.grow(0.01);
	var overlappingRooms=[];
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
			room.owner=get_tree().edited_scene_root;
			room.add_child(child);
			child.owner=get_tree().edited_scene_root;
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
	var l:float=bounds.get_longest_axis_size()/ 2;
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
		if n.length_squared() > 0.0001 && (a.angle_to(b)>0.01):
			n=n.normalized();
			#We have a working normal for the portal.
			#Now we have to determine if we have to flip the normal.
			
			var myCenter:Vector3 = getCenterOfBounds(getRoomBounds(myRoom));
			var otherCenter:Vector3 = getCenterOfBounds(getRoomBounds(otherRoom));
			var directionToOtherRoom = otherCenter - myCenter;
			
			if n.dot(directionToOtherRoom) < 0:
				n = -n;
			
			var portal:Portal=Portal.new();
			#portal.two_way=false;
			
			var bounds:AABB=GenerateBoundsFromRoomPoints(points);
			myRoom.add_child(portal);
			portal.owner=get_tree().edited_scene_root;
			portal.linked_room = otherRoom.get_path();
			var center:Vector3=getCenterOfBounds(bounds);
			portal.points=generatePortalPointsFromBounds(bounds);
			portal.transform.origin=portal.to_local(center);
			var upVector:Vector3=Vector3.UP;
			if n.angle_to(upVector) < 0.1 || n.angle_to(Vector3.DOWN)<0.1:
				upVector=Vector3.FORWARD;
			portal.look_at_from_position(center, center + n, upVector);
			return;
			

func GeneratePortalsForRoom(room:Room, roomTriangles, mapNode:Node)->void:
	var nearbyRooms:Array=FindNearbyRooms(room, mapNode);
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
		
func getAllPortals(mapNode:Node)->Array:
	var portals:Array=[];
	for room in mapNode.get_children():
		for child in room.get_children():
			if child is Portal:
				portals.append(child);
	return portals;

func RemoveDuplicatePortals(mapNode:Node)->void:
	var portals:Array=getAllPortals(mapNode);
	var portalsToRemove={};
	for portal in portals:
		if portalsToRemove.has(portal):
			continue;
		for checkPortal in portals:
			if portal != checkPortal && !portalsToRemove.has(checkPortal):
				if portal.global_transform.origin.distance_to(checkPortal.global_transform.origin) < 0.01:
					portalsToRemove[checkPortal]=true;
	var portalsDeleted:int=0;
	for portal in portalsToRemove.keys():
		portal.queue_free();
		portalsDeleted+=1;
	print_debug("Deleted "+String(portalsDeleted)+" duplicate portals.")

func set_progress(text:String, percent:float)->void:
	print_debug(text);
	label_status.text=text;
	progress.value=percent;

func GeneratePortals(mapNode:Node):
	#ClearPortals(mapNode);
	disabled=true;
	set_progress("Placing rooms",0);
	yield(get_tree(), "idle_frame")
	var rooms = GenerateRooms(mapNode);
	set_progress("Getting room triangles",0);
	yield(get_tree(), "idle_frame")
	var roomTriangles = {};
	for room in rooms:
		roomTriangles[room]=GetRoomTriangles(room);
	set_progress("Generating portals",0);
	yield(get_tree(), "idle_frame")
	for i in range(rooms.size()):
		var room = rooms[i];
		GeneratePortalsForRoom(room,roomTriangles, mapNode);
		set_progress("Generated portals for room "+room.name,(float(i+1)/rooms.size())*100);
		yield(get_tree(), "idle_frame")
	set_progress("Removing duplicate portals",100);
	yield(get_tree(), "idle_frame")
	RemoveDuplicatePortals(mapNode);
	set_progress("Finished",0);
	disabled=false;
	
	
