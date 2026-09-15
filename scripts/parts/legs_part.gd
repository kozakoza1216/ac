extends Resource
class_name LegsPart

## Legs part (脚部パーツ). Sets load_capacity, the budget the rest of
## the build's weight is checked against, plus turning/jump performance.
## Non-biped types (reverse-joint, quad, tank) commonly omit turning/jump
## in the source data -- left at 0 for those where not documented.

enum LegType { BIPED, REVERSE_JOINT, QUAD, TANK }

@export var part_name: String = ""
@export var maker: String = ""
@export var price: int = 0
@export var leg_type: LegType = LegType.BIPED

@export var ap: int = 0
@export var weight: float = 0.0
@export var load_capacity: float = 0.0
@export var en_load: float = 0.0
@export var real_defense: float = 0.0
@export var energy_defense: float = 0.0
@export var turning_performance: float = 0.0
@export var jump_performance: float = 0.0
