extends Resource
class_name CorePart

## Core part (コアパーツ, torso). Biggest single contributor to AP and
## to the arm load-capacity budget. OB-type cores add a burst-move output
## on top of the normal stats; is_ob_type gates whether ob_output matters.

@export var part_name: String = ""
@export var maker: String = ""
@export var price: int = 0

@export var ap: int = 0
@export var weight: float = 0.0
@export var en_load: float = 0.0
@export var real_defense: float = 0.0
@export var energy_defense: float = 0.0
@export var arm_load_capacity: float = 0.0
@export var cooling: float = 0.0
@export var heat_tolerance: float = 0.0
@export var op_slots: int = 0
@export var intercept_performance: float = 0.0

@export var is_ob_type: bool = false
@export var ob_output: float = 0.0
