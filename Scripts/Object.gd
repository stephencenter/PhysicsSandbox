extends Spatial

var stored_linear : Vector3
var stored_angular : Vector3
var rigid_body : RigidBody

func _ready():
    rigid_body = get_node("RigidBody")
    
func _physics_process(_delta):
    if rigid_body.linear_velocity.y < -200:
        rigid_body.linear_velocity.y = -200
    
func store_velocity():
    stored_linear = rigid_body.linear_velocity
    stored_angular = rigid_body.angular_velocity

func resume_velocity():
    rigid_body.linear_velocity = stored_linear
    rigid_body.angular_velocity = stored_angular
