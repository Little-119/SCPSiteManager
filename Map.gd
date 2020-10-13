extends Node2D
class_name Map

const max_size := Vector3(512,512,32)
var size: Vector3 setget set_size
var cells_matrix := [] # Z(-levels), then Y, then X
var cells := [] # 1D list of all cells in map

var current_zlevel: int = 0

var astar := AStar.new() # Let us meet again as stars.

func set_size(newsize: Vector3) -> void:
	size = newsize
	# warning-ignore:narrowing_conversion
	cells_matrix.resize(clamp(size.z,cells_matrix.size(),max_size.z))
	for zn in size.z:
		var y := []
		# warning-ignore:narrowing_conversion
		y.resize(clamp(size.y,y.size(),max_size.y))
		for yn in size.y:
			var x := []
			# warning-ignore:narrowing_conversion
			x.resize(clamp(size.x,x.size(),max_size.x))
			for xn in size.x:
				if x[xn] is Cell:
					continue
				var nc: Cell = Cell.new()
				cells.append(nc)
				x[xn] = nc
				nc.cell_position = Vector3(xn,yn,zn)
				# don't know why this produces an unsafe property access warning
				# warning-ignore:unsafe_property_access
				nc.map = self
				nc.point_id = astar.get_point_count()
				astar.add_point(nc.point_id,nc.cell_position,1)
				add_child(nc)
			y[yn] = x
		cells_matrix[zn] = y
	update()

func _init(newsize: Vector3 = Vector3(64,64,1)) -> void:
	size = newsize
	z_index = -1
	name = "Map"

func get_pixel_size() -> Vector2:
	var cell_size = Constants.cell_size
	return Vector2(size.x * cell_size,size.y * cell_size)

func _ready() -> void:
	# warning-ignore:narrowing_conversion
	astar.reserve_space(size.x*size.y*size.z)
	
	set_size(size)
	
	for cell in cells:
		for adj_cell in cell.get_eight_adjacent_cells():
			if not adj_cell.is_default_cell:
				astar.connect_points(cell.point_id,adj_cell.point_id)
	
	get_cell(Vector3(5,5,1)).add_thing(PlayerControlledActor)
	# warning-ignore:unsafe_property_access
	$"/root/Game".maps.append(self)

func get_cell(pos: Vector3) -> Cell: # get cell with cell_position
	if pos.x >= 0 and pos.y >= 0 and pos.z >= 0 and cells_matrix.size() > pos.z and cells_matrix[pos.z].size() > pos.y and cells_matrix[pos.z][pos.y].size() > pos.x:
		return cells_matrix[pos.z][pos.y][pos.x]
	else:
		# warning-ignore:unsafe_property_access
		return $"/root/Game".default_cell

func get_cell_or_null(pos: Vector3) -> Cell:
	var c: Cell = get_cell(pos)
	if c.is_default_cell:
		return null
	else:
		return c

func clamp_to_cell_grid(num: float) -> int:
	return (((num as int) - abs((num as int) % Constants.cell_size))/Constants.cell_size) as int

func get_cell_from_position(from_position: Vector2,z:int = 0) -> Cell:
	var rounded_position = Vector3.ZERO
	rounded_position.x = clamp_to_cell_grid(from_position.x)
	rounded_position.y = clamp_to_cell_grid(from_position.y)
	rounded_position.z = z
	return get_cell(rounded_position)

func get_cell_from_screen_position(from_position: Vector2,z:int = 0) -> Cell: # get cell from local screen position
	from_position += ($"/root/Player/Camera2D" as Camera2D).position
	return get_cell_from_position(from_position,z)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		#var local_pos: Vector2 = ($"/root/Player/Camera2D" as Camera2D).position + (event as InputEventMouse).position
		var cell_at_pos: Cell = get_cell_from_screen_position((event as InputEventMouse).position,current_zlevel)
		if event is InputEventMouseMotion:
			update()
			if cell_at_pos and (not cell_at_pos.is_default_cell):
				cell_at_pos.on_mouseonto()
		
		if event is InputEventMouseButton:
			if (event as InputEventMouseButton).pressed:
				if cell_at_pos and (not cell_at_pos.is_default_cell):
					match (event as InputEventMouseButton).button_index:
						1:
							cell_at_pos.on_left_click()
							# can't specify that Player is a Player while it's a Singleton
							# warning-ignore:unsafe_property_access
							if $"/root/Player".mousetool:
								# warning-ignore:unsafe_property_access
								$"/root/Player".mousetool.tool_lclick_oncell(cell_at_pos)
						2:
							cell_at_pos.on_right_click()

func view_zlevel(z: int = 0) -> void: # change map view to a different z-level
	# warning-ignore:narrowing_conversion
	z = clamp(z,0,cells_matrix.size()-1)
	current_zlevel = z
	for cell in cells:
		cell.zlevel_update(z)

func view_zlevel_incr(delta: int) -> void: # change map view to a different z-level, based on the one we're currently looking at
	view_zlevel(current_zlevel + delta)

func _draw() -> void:
	# as said above, can't specify that Player is a Player while it's a Singleton
	# warning-ignore:unsafe_property_access
	if $"/root/Player".mousetool:
		# warning-ignore:unsafe_method_access
		var mousepos: Vector2 = $"/root/Player".get_mouse_position()
		var cell: Cell = get_cell_from_position(mousepos,current_zlevel)
		if not cell.is_default_cell:
			var box_pos: Vector2 = cell.position
			draw_rect(Rect2(box_pos,Vector2.ONE * cell.scale.x * 32),Color.white,false)
