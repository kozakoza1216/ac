extends Resource
class_name RadiatorPart

## Radiator part (冷却装置). cooling_performance is checked against
## (generator heat + booster boost heat) * 2, per the source material's
## documented heat-management formula -- see ACBuild.is_overheating().

@export var part_name: String = ""
@export var maker: String = ""
@export var price: int = 0

@export var weight: float = 0.0
@export var en_load: float = 0.0
@export var cooling_performance: float = 0.0
