extends Resource
class_name GeneratorPart

## Generator part (ジェネレータ). en_output is the steady-state supply
## that has to cover every other part's en_load plus whatever the
## booster draws while active; en_capacity/emergency_capacity aren't
## wired into gameplay yet (the current boost gauge model is flat).

@export var part_name: String = ""
@export var maker: String = ""
@export var price: int = 0

@export var weight: float = 0.0
@export var en_output: float = 0.0
@export var en_capacity: float = 0.0
@export var emergency_capacity: float = 0.0
@export var heat: float = 0.0
