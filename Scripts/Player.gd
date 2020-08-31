extends KinematicBody

# Constant
const PLAYER_GRAVITY = -100
const MAX_HORIZONTAL_SPEED = 20
const NOCLIP_VERT_SPEED = 20
const JUMP_FORCE = 40
const ACCELERATION_RATE = 4.5
const DEACCELERATION_RATE = 16
const MAX_SLOPE_ANGLE = 40
const OBJECT_THROW_FORCE = 750
const ACTION_RANGE_SHORT = 8
const ACTION_RANGE_MID = 50
const ACTION_RANGE_LONG = 250
var MOUSE_SENSITIVITY = 0.15

var grab_distance : float = 10
var current_velocity : Vector3
var grabbed_object : RigidBody
var mouse_event : InputEventMouseMotion
var grab_rotation : Vector3
var noclip : bool = false
var counter = 0

var camera : Camera
var rotation_helper

onready var the_world = get_parent()
onready var object_cube = load("res://Objects/cube.tscn")
onready var object_sphere = load("res://Objects/sphere.tscn")
onready var object_plank = load("res://Objects/plank.tscn")
var point_helper : MeshInstance
var point_helper2 : MeshInstance
var point_helper3 : MeshInstance

func _ready():
    rotation_helper = $Rotation_Helper
    camera = $Rotation_Helper/Camera   
    point_helper = $PointHelpers/PointHelper
    point_helper2 = $PointHelpers/PointHelper2
    point_helper3 = $PointHelpers/PointHelper3
    
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    
func _physics_process(delta):
    var movement_direction = process_input(delta)
    if noclip:
        process_movement_noclip(delta, movement_direction)
    else:
        process_movement(delta, movement_direction)
        
    update_grab_position()
    update_infohud()
    show_error()
    
func process_input(_delta):
    var movement_direction = Vector3()
    
    # Walk
    if any_movement_keys_pressed():
        movement_direction = action_move_around()
    
    # Jump
    if Input.is_action_just_pressed("movement_jump") and !noclip:
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
        action_freeze_object()
        
    # Rotate target object
    if Input.is_action_pressed("rotate_object"):
        action_rotate_object()
    
    # Scale target object
    if Input.is_action_pressed("scale_object"):
        action_scale_object()
        
    # Alter target object's gravity
    elif Input.is_action_pressed("alter_gravity"):
        action_alter_gravity()
    
    # Push/Pull target object
    else:
        if Input.is_action_just_released("increase_distance"):
            action_change_grab_distance()
            
        if Input.is_action_just_released("decrease_distance"):
            action_change_grab_distance()
    
    if Input.is_action_just_pressed("reset_grab"):
        if grabbed_object != null:
            grab_distance = ACTION_RANGE_SHORT*grabbed_object.get_parent_spatial().scale.x
    
    if Input.is_action_just_pressed("create_object"):
        action_create_object(object_cube)
        
    if Input.is_action_just_pressed("test_hotkey"):
        action_create_object(object_plank)
        
    if Input.is_action_just_pressed("test_hotkey2"):
        action_create_object(object_sphere)
        
    if Input.is_action_just_pressed("vanish_object"):
        action_vanish_object()
    
    if Input.is_action_just_pressed("respawn"):
        global_transform.origin = Vector3(0, 0, 0)
        current_velocity = Vector3(0, 0, 0)
    
    if Input.is_action_just_pressed("reset_velocity"):
        action_reset_velocity()
        
    if Input.is_action_just_pressed("toggle_noclip"):
        action_toggle_noclip()
    
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
    else:
        current_velocity.y = max(-200, current_velocity.y) 
    
    horizontal_velocity = horizontal_velocity.linear_interpolate(target, current_acceleration*delta)
    current_velocity.x = horizontal_velocity.x
    current_velocity.z = horizontal_velocity.z
    current_velocity = move_and_slide(current_velocity, Vector3(0, 1, 0), 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))

func process_movement_noclip(delta, movement_direction):
    movement_direction = movement_direction.normalized()
    
    var target = movement_direction
    if Input.is_action_pressed("sprint"):
        target *= MAX_HORIZONTAL_SPEED*4
    else:
        target *= MAX_HORIZONTAL_SPEED*2
    
    current_velocity = current_velocity.linear_interpolate(target, 20*delta)
    current_velocity = move_and_slide(current_velocity, Vector3(0, 1, 0), 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))
 
func _input(event):
    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        if Input.is_action_pressed("rotate_object"):
            mouse_event = event
            return         
            
        rotation_helper.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY))
        self.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))
        var camera_rot = rotation_helper.rotation_degrees
        camera_rot.x = clamp(camera_rot.x, -85, 85)
        rotation_helper.rotation_degrees = camera_rot

# HELPER METHODS
func is_grounded() -> bool:
    var ray = $Feet_CollisionShape/RayCast
    return ray.is_colliding() or is_on_floor()
    
func any_movement_keys_pressed() -> bool:
    var answer = Input.is_action_pressed("movement_right") or \
                 Input.is_action_pressed("movement_left") or \
                 Input.is_action_pressed("movement_forward") or \
                 Input.is_action_pressed("movement_backward")
                 
    return answer
    
func get_object_at_crosshair(max_distance : float, ignored : Array = []) -> Dictionary:
    var state = get_world().direct_space_state
    var center_position = get_viewport().size / 2
    var ray_from = camera.project_ray_origin(center_position)
    var ray_to = ray_from + camera.project_ray_normal(center_position) * max_distance
    var ray_result = state.intersect_ray(ray_from, ray_to, [self] + ignored)
    
    return ray_result
    
func get_crosshair_or_grabbed(max_distance: float, ignored : Array = []) -> RigidBody:
    if grabbed_object != null:
        return grabbed_object
        
    var ray_result = get_object_at_crosshair(max_distance, ignored)
    if !ray_result.empty() and ray_result["collider"] is RigidBody:
        return ray_result["collider"]
    
    return null

func update_grab_position():
    if grabbed_object != null:
        # Fix grab distance
        grab_distance = clamp(grab_distance, ACTION_RANGE_SHORT, ACTION_RANGE_LONG)
        
        # Update the grabbed object's position and rotation
        var desired_position = -camera.global_transform.basis.z.normalized() * grab_distance + camera.global_transform.origin
        var delta = desired_position - grabbed_object.global_transform.origin
        
        var o_size : Vector3 = grabbed_object.get_node("MeshInstance").get_aabb().size
        o_size *= grabbed_object.get_parent_spatial().scale.x
        var size = o_size
        size = size.rotated(Vector3(1, 0, 0), grabbed_object.rotation.x)
        size = size.rotated(Vector3(0, 1, 0), grabbed_object.rotation.y)
        size = size.rotated(Vector3(0, 0, 1), grabbed_object.rotation.z)
        size.x = max(abs(size.x), min(o_size.x, o_size.z))
        size.y = max(abs(size.y), o_size.y)
        size.z = max(abs(size.z), min(o_size.x, o_size.z))
    
        var state = get_world().direct_space_state
        var ray_start = grabbed_object.global_transform.origin
        
        # x ray
        if !noclip:
            var x_ray_end : Vector3 = ray_start + Vector3(delta.x + sign(delta.x)*size.x*0.5, 0, 0)            
            var x_ray_result = state.intersect_ray(ray_start, x_ray_end, [self, grabbed_object])
            if !x_ray_result.empty() and (x_ray_result["collider"] is PhysicsBody):
                delta.x = sign(delta.x)*(ray_start.distance_to(x_ray_result["position"]) - size.x*0.5)
                
            # y ray
            var y_ray_end : Vector3 = ray_start + Vector3(0, delta.y + sign(delta.y)*size.y*0.5, 0)
            var y_ray_result = state.intersect_ray(ray_start, y_ray_end, [self, grabbed_object])
            if !y_ray_result.empty() and (y_ray_result["collider"] is PhysicsBody):
                delta.y = sign(delta.y)*(ray_start.distance_to(y_ray_result["position"]) - size.y*0.5)
            
            # z ray
            var z_ray_end : Vector3 = ray_start + Vector3(0, 0, delta.z + sign(delta.z)*size.z*0.5)
            var z_ray_result = state.intersect_ray(ray_start, z_ray_end, [self, grabbed_object])
            if !z_ray_result.empty() and (z_ray_result["collider"] is PhysicsBody):
                delta.z = sign(delta.z)*(ray_start.distance_to(z_ray_result["position"]) - size.z*0.5)
            
        grabbed_object.global_transform.origin += delta
        grabbed_object.rotation = rotation + grab_rotation
        
        var cam_point = camera.global_transform.origin
        var obj_distance = cam_point.distance_to(grabbed_object.global_transform.origin)
            
        if Input.is_action_just_released("decrease_distance"):
            grab_distance = obj_distance

func update_infohud():
    var the_object = get_crosshair_or_grabbed(ACTION_RANGE_LONG)
        
    if the_object == null:
        $HUD/InfoHUD/Position.set_text("")
        $HUD/InfoHUD/Rotation.set_text("")
        $HUD/InfoHUD/Scale.set_text("")
        $HUD/InfoHUD/Gravity.set_text("")
        $HUD/InfoHUD/IsFrozen.set_text("")
        $HUD/InfoHUD/Distance.set_text("")
        $HUD/InfoHUD/Velocity.set_text("")
        
        return
    
    $HUD/InfoHUD/Position.set_text("Position: %s" % the_object.global_transform.origin)
    $HUD/InfoHUD/Rotation.set_text("Rotation: %s" % grab_rotation)
    $HUD/InfoHUD/Scale.set_text("Scale: %s" % the_object.get_parent_spatial().scale)
    $HUD/InfoHUD/Gravity.set_text("Gravity: %s" % the_object.gravity_scale)
    $HUD/InfoHUD/Velocity.set_text("Velocity: %s" % the_object.linear_velocity)
    
    var cam_point = camera.global_transform.origin
    var obj_point = the_object.global_transform.origin
    $HUD/InfoHUD/Distance.set_text("Distance: %s" % cam_point.distance_to(obj_point))
    
    if the_object.mode == RigidBody.MODE_STATIC:
        $HUD/InfoHUD/IsFrozen.set_text("IsFrozen: Yes")
    else:
        $HUD/InfoHUD/IsFrozen.set_text("IsFrozen: No")
    
func show_error(message = null):    
    var label = $HUD/ErrorHUD/Error
    if message != null:
        label.set_text(label.get_text() + message + "\n")
        $HUD/ErrorHUD/Timer.wait_time = 3
        $HUD/ErrorHUD/Timer.start()
        
        
    if $HUD/ErrorHUD/Timer.time_left == 0:
        label.set_text("")
       
# ACTION METHODS
func action_grab_ungrab():
    if grabbed_object == null:
        var ray_result = get_object_at_crosshair(ACTION_RANGE_LONG)  
        
        if !ray_result.empty() and ray_result["collider"] is RigidBody:
            action_reset_velocity()
            grabbed_object = ray_result["collider"]
            grabbed_object.mode = RigidBody.MODE_STATIC
            grabbed_object.collision_layer = 0
            grabbed_object.collision_mask = 0
            grab_distance = camera.global_transform.origin.distance_to(grabbed_object.global_transform.origin)
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
        
func action_freeze_object():
    var the_object : RigidBody = get_crosshair_or_grabbed(ACTION_RANGE_LONG)
    
    if the_object == null:
        return
        
    if the_object.mode != RigidBody.MODE_STATIC or the_object == grabbed_object:
        if the_object == grabbed_object:
            var object = grabbed_object.global_transform.origin
            var player = global_transform.origin
            var cam = camera.global_transform.origin
            
            var distance = object.distance_to(player)
            var distance2 = object.distance_to(cam)
            var min_distance = 5*grabbed_object.get_parent_spatial().scale.x
            if distance < min_distance or distance2 < min_distance:
                show_error("Can't freeze grabbed objects that close to player!")
                return
            
        the_object.get_parent_spatial().store_velocity()
        the_object.mode = RigidBody.MODE_STATIC
        
    else:
        the_object.mode = RigidBody.MODE_RIGID
        the_object.get_parent_spatial().resume_velocity()
        
    if grabbed_object != null:
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

func action_rotate_object():
    if mouse_event is InputEventMouseMotion:
        # Determine which object to rotate
        var the_object = get_crosshair_or_grabbed(ACTION_RANGE_LONG)
        
        if the_object == null or the_object.mode != RigidBody.MODE_STATIC:
            return
            
        # Determine how much to rotate the object
        var cam_xform = camera.get_global_transform()
        var rotation_vector = Vector2()
        
        rotation_vector.x = deg2rad(mouse_event.relative.y * MOUSE_SENSITIVITY)
        rotation_vector.y = deg2rad(mouse_event.relative.x * MOUSE_SENSITIVITY)
        mouse_event = null
            
        # Rotate the object
        var before = the_object.rotation
        the_object.rotate(cam_xform.basis[0], rotation_vector.x)
        the_object.rotate(cam_xform.basis[1], rotation_vector.y)
        grab_rotation += the_object.rotation - before    
    
func action_move_around() -> Vector3:
    var movement_direction : Vector3 = Vector3()    
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

func action_change_grab_distance():
    var change_rate = 2
    var delta
    
    if Input.is_action_just_released("increase_distance"):
        delta = change_rate
        
    if Input.is_action_just_released("decrease_distance"):
        delta = -change_rate
        
    if grabbed_object != null:
        grab_distance += delta

func action_scale_object():
    var rigidbody = get_crosshair_or_grabbed(ACTION_RANGE_LONG)
    
    if rigidbody == null:
        return
        
    var the_object = rigidbody.get_parent_spatial()
    
    if the_object == null:
        return
        
    var change_rate = Vector3(0.2, 0.2, 0.2)
    var delta = Vector3.ZERO
    
    if Input.is_action_just_released("increase_distance"):
        delta = change_rate
        
    elif Input.is_action_just_released("decrease_distance"):
        delta = -change_rate
        
    else:
        return
    
    var current_position = the_object.global_transform.origin
    
    the_object.scale = the_object.scale + delta
    if the_object.scale < Vector3(0.05, 0.05, 0.05):
        the_object.scale = Vector3(0.05, 0.05, 0.05)
    if the_object.scale > Vector3(10, 10, 10):
        the_object.scale = Vector3(10, 10, 10)
        
    the_object.global_transform.origin = current_position/the_object.scale

func action_alter_gravity():
    var the_object = get_crosshair_or_grabbed(ACTION_RANGE_LONG)
    
    if the_object == null:
        return
        
    var change_rate = 0.5
    var delta
    
    if Input.is_action_just_released("increase_distance"):
        delta = change_rate
        
    elif Input.is_action_just_released("decrease_distance"):
        delta = -change_rate
        
    else:
        return
        
    the_object.gravity_scale += delta
    the_object.gravity_scale = clamp(the_object.gravity_scale, -50, 50)
    
    if -0.01 < the_object.gravity_scale and the_object.gravity_scale < 0.01:
        the_object.gravity_scale = 0
        
    the_object.apply_impulse(Vector3(0, 0, 0), -camera.global_transform.basis.z.normalized())

func action_create_object(object):
    var spawned_object = object.instance()
    the_world.add_child(spawned_object)
    
    var spawn_distance = ACTION_RANGE_SHORT
    
    var wall_ray = get_object_at_crosshair(ACTION_RANGE_SHORT)
    if !wall_ray.empty() and wall_ray["collider"] is PhysicsBody:
        spawn_distance = min(camera.global_transform.origin.distance_to(wall_ray["position"]), spawn_distance)
    
    var spawn_position = -camera.global_transform.basis.z.normalized()*spawn_distance + camera.global_transform.origin
    spawned_object.global_transform.origin = spawn_position

func action_vanish_object():
    var the_object = get_crosshair_or_grabbed(ACTION_RANGE_LONG)
    
    if the_object == null:
        return
        
    the_object.get_parent().remove_child(the_object)

func action_reset_velocity():
    var the_object = get_crosshair_or_grabbed(ACTION_RANGE_LONG)
    
    if the_object == null:
        return
        
    the_object.linear_velocity = Vector3(0, 0, 0)
    the_object.angular_velocity = Vector3(0, 0, 0)
    the_object.get_parent_spatial().stored_linear = Vector3(0, 0, 0)
    the_object.get_parent_spatial().stored_angular = Vector3(0, 0, 0)
    
func action_toggle_noclip():
    if noclip:
        noclip = false
        collision_layer = 1
        collision_mask = 1
    
    else:
        noclip = true
        collision_layer = 2
        collision_mask = 2
