extends Resource
class_name BoosterPart

## Booster part (ブースター). thrust/boost_accel drive dash & air-boost
## power; boost_en_drain and boost_heat only apply while actually
## boosting (not part of the build's steady-state EN/heat budget).

@export var part_name: String = ""
@export var maker: String = ""
@export var price: int = 0

@export var weight: float = 0.0
@export var en_load: float = 0.0
@export var thrust: float = 0.0
@export var boost_en_drain: float = 0.0
@export var boost_accel: float = 0.0
@export var boost_heat: float = 0.0
