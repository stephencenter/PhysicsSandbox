extends KinematicBody

# Constant
const PLAYER_GRAVITY = -100
const MAX_HORIZONTAL_SPEED = 20
const JUMP_FORCE = 40
const ACCELERATION_RATE = 4.5
const DEACCELERATION_RATE = 16
const MAX_SLOPE_ANGLE = 40
const OBJECT_THROW_FORCE = 150
const OBJECT_GRAB_DISTANCE = 10
const OBJECT_GRAB_RAY_DISTANCE = 15
const OBJECT_FREEZE_RAY_DISTANCE = 50
var MOUSE_SENSITIVITY = 0.15

var current_velocity = Vector3()
var grabbed_object : RigidBody = null
var mouse_event : InputEventMouseMotion = null
var grab_rotation = Vector3()

var camera
var rotation_helper

func _ready():
    rotation_helper = $Rotation_Helper
    camera = $Rotation_Helper/Camera
    
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    
func _physics_process(delta):
    var movement_direction = process_input(delta)
    process_movement(delta, movement_direction)
    
func process_input(_delta):
    var movement_direction = Vector3()
    
    # Walk
    if any_walk_keys_pressed():
        movement_direction = action_walk_around()
    
    # Jump
    if Input.is_action_just_pressed("movement_jump"):
        action_jump()
            
    # Toggle Mouselook
    if Input.is_action_just_pressed("ui_cancel"):
        action_toggle_mouselook()
            
    # Grab and ungrab target object
    if Input.is_action_just_pressed("interact"):
        action_grab_ungrab()
            
    # Throw held object
    if Input.is_action_just_pressed("throw_object"):
        action_throw_object()
    
    # Freeze target object
    if Input.is_action_just_pressed("freeze_object"):
        action_freeze_at_crosshair()
        
    # Rotate target object
    if Input.is_action_pressed("rotate_object"):
        action_rotate_at_crosshair()
        
    update_grab_position()
    
    return movement_direction
                
func process_movement(delta, movement_direction):
    movement_direction.y = 0
    movement_direction = movement_direction.normalized()
    current_velocity.y += delta*PLAYER_GRAVITY
    
    var horizontal_velocity = current_velocity
    horizontal_velocity.y = 0
    
    var target = movement_direction
    target *= MAX_HORIZONTAL_SPEED
    
    var current_acceleration
    if movement_direction.dot(horizontal_velocity) > 0:
        current_acceleration = ACCELERATION_RATE
    else:
        current_acceleration = DEACCELERATION_RATE
    
    if is_grounded():
        current_velocity.y = max(0, current_velocity.y)   
    
    horizontal_velocity = horizontal_velocity.linear_interpolate(target, current_acceleration*delta)
    current_velocity.x = horizontal_velocity.x
    current_velocity.z = horizontal_velocity.z
    current_velocity = move_and_slide(current_velocity, Vector3(0, 1, 0), 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))
    
func _input(event):
    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        if Input.is_action_pressed("rotate_object"):
            mouse_event = event
            return         
            
        rotation_helper.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY))
        self.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))
        var camera_rot = rotation_helper.rotation_degrees
        camera_rot.x = clamp(camera_rot.x, -80, 80)
        rotation_helper.rotation_degrees = camera_rot

# HELPER METHODS
func any_walk_keys_pressed() -> bool:
    var answer = Input.is_action_pressed("movement_right") or \
                 Input.is_action_pressed("movement_left") or \
                 Input.is_action_pressed("movement_forward") or \
                 Input.is_action_pressed("movement_backward")
                
    return answer
    
func get_object_at_crosshair(max_distance) -> Dictionary:
    var state = get_world().direct_space_state
    var center_position = get_viewport().size / 2
    var ray_from = camera.project_ray_origin(center_position)
    var ray_to = ray_from + camera.project_ray_normal(center_position) * max_distance
    var ray_result = state.intersect_ray(ray_from, ray_to, [self])
    
    return ray_result

func update_grab_position():
    if grabbed_object != null:
        grabbed_object.global_transform.origin = camera.global_transform.origin + (-camera.global_transform.basis.z.normalized() * OBJECT_GRAB_DISTANCE)  
        grabbed_object.rotation = rotation + grab_rotation
        
# ACTION METHODS
func action_grab_ungrab():
    if grabbed_object == null:
        var ray_result = get_object_at_crosshair(OBJECT_GRAB_RAY_DISTANCE)  
        
        if !ray_result.empty():
            if ray_result["collider"] is RigidBody:
                grabbed_object = ray_result["collider"]
                grabbed_object.mode = RigidBody.MODE_STATIC
                grabbed_object.collision_layer = 0
                grabbed_object.collision_mask = 0
                grab_rotation = Vector3()
    
    else:
        grabbed_object.mode = RigidBody.MODE_RIGID
        grabbed_object.collision_layer = 1
        grabbed_object.collision_mask = 1
        grabbed_object = null
        
func action_throw_object():
    if grabbed_object == null:
        return
        
    grabbed_object.mode = RigidBody.MODE_RIGID
    grabbed_object.apply_impulse(Vector3(0, 0, 0), -camera.global_transform.basis.z.normalized() * OBJECT_THROW_FORCE)
    grabbed_object.collision_layer = 1
    grabbed_object.collision_mask = 1
    grabbed_object = null
        
func action_freeze_at_crosshair():
    if grabbed_object == null:  
        var ray_result = get_object_at_crosshair(OBJECT_FREEZE_RAY_DISTANCE)          
        
        if !ray_result.empty() && ray_result["collider"] is RigidBody:
            if ray_result["collider"].mode == RigidBody.MODE_STATIC:
                ray_result["collider"].mode = RigidBody.MODE_RIGID
            else:
                ray_result["collider"].mode = RigidBody.MODE_STATIC
                
    else:
        grabbed_object.collision_layer = 1
        grabbed_object.collision_mask = 1
        grabbed_object = null
        
func action_toggle_mouselook():
    if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
            
    else:
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)  

func action_jump():
    if is_grounded():
        current_velocity.y = JUMP_FORCE    

func action_rotate_at_crosshair():
    # Determine which object to rotate
    var the_object

    if grabbed_object == null:  
        var ray_result = get_object_at_crosshair(OBJECT_FREEZE_RAY_DISTANCE)
        if !ray_result.empty() && ray_result["collider"] is RigidBody:
            if ray_result["collider"].mode == RigidBody.MODE_STATIC:
                the_object = ray_result["collider"]
                
    else:
        the_object = grabbed_object
        
    if the_object == null:
        return
        
    # Determine how much to rotate the object
    var cam_xform = camera.get_global_transform()
    var rotation_vector = Vector2()
    
    if any_walk_keys_pressed():
        if Input.is_action_pressed("movement_forward"):
            rotation_vector.x += 1
        if Input.is_action_pressed("movement_backward"):
            rotation_vector.x -= 1
        if Input.is_action_pressed("movement_left"):
            rotation_vector.y -= 1
        if Input.is_action_pressed("movement_right"):
            rotation_vector.y += 1
        
        rotation_vector.x *= -0.03
        rotation_vector.y *= 0.03
            
    elif mouse_event is InputEventMouseMotion:
        rotation_vector.x = deg2rad(mouse_event.relative.y * MOUSE_SENSITIVITY)
        rotation_vector.y = deg2rad(mouse_event.relative.x * MOUSE_SENSITIVITY)
        mouse_event = null
        
    # Rotate the object
    var before = the_object.rotation
    the_object.rotate(cam_xform.basis[0], rotation_vector.x)
    the_object.rotate(cam_xform.basis[1], rotation_vector.y)
    grab_rotation += the_object.rotation - before    
    
func action_walk_around() -> Vector3: 
    var movement_direction = Vector3()
    
    if Input.is_action_pressed("rotate_object"):
        return movement_direction
        
    var cam_xform = camera.get_global_transform()
    var input_movement_vector = Vector2()
    
    if Input.is_action_pressed("movement_forward"):
        input_movement_vector.y += 1
    if Input.is_action_pressed("movement_backward"):
        input_movement_vector.y -= 1
    if Input.is_action_pressed("movement_left"):
        input_movement_vector.x -= 1
    if Input.is_action_pressed("movement_right"):
        input_movement_vector.x += 1

    input_movement_vector = input_movement_vector.normalized()
    movement_direction += -cam_xform.basis.z * input_movement_vector.y
    movement_direction += cam_xform.basis.x * input_movement_vector.x
    
    return movement_direction

func is_grounded() -> bool:
    var ray = $Feet_CollisionShape/RayCast
    return ray.is_colliding()
