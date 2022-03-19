tool
extends Button

var editor_interface:EditorInterface;

func _on_Button_pressed():
	print("Hello from the main screen plugin!");
	var selected_nodes:Array=editor_interface.get_selection().get_selected_nodes();
	if selected_nodes.size() > 0:
		var selected_node = selected_nodes[0];
		if selected_node is PortalCreator:
			selected_node.GeneratePortals();
