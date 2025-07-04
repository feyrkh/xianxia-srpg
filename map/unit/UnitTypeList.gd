extends ItemList

func _ready() -> void:
	for type:MapUnitPosition.PositionType in MapUnitPosition.PositionType.values():
		add_item(MapUnitPosition.PositionType.keys()[type])
		set_item_metadata(item_count - 1, type)
