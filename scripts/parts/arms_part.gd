extends Resource
class_name ArmsPart

## Arms part (腕部パーツ). Adds to AP and carried weight; accuracy and
## blade aptitude affect weapon handling once weapons exist.

@export var part_name: String = ""
@export var maker: String = ""
@export var price: int = 0

@export var ap: int = 0
@export var weight: float = 0.0
@export var en_load: float = 0.0
@export var accuracy: float = 0.0
@export var blade_aptitude: float = 0.0
