abstract class_name TileBasedInputController extends InputController

@warning_ignore("unused_signal")
signal on_cursor_position_updated(pos:Vector2i)

abstract func on_tile_hovered(tile:MapTile) -> void
abstract func on_tile_unhovered(tile:MapTile) -> void
abstract func on_cell_hovered(x:int, y:int) -> void
abstract func on_cell_unhovered(x:int, y:int) -> void
abstract func on_tile_left_click(tile:MapTile) -> void
abstract func on_tile_right_click(tile:MapTile) -> void
abstract func on_cell_left_click(x:int, y:int) -> void
abstract func on_cell_right_click(x:int, y:int) -> void
