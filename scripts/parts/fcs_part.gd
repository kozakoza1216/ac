extends Resource
class_name FcsPart

## FCS part (火器管制システム). Governs lock-on behavior; doesn't
## contribute AP, only weight/EN load plus targeting stats.

@export var part_name: String = ""
@export var maker: String = ""
@export var price: int = 0

@export var weight: float = 0.0
@export var en_load: float = 0.0
@export var anti_ecm: float = 0.0
@export var sight_type: String = ""
@export var lock_count: int = 0
@export var lock_time: float = 0.0
@export var missile_lock_time: float = 0.0
@export var max_lock_range: float = 0.0
@export var avg_lock_range: float = 0.0
@export var parallel_processing: float = 0.0
