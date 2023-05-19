extends Node2D

enum STATE {RESET, INIT, ADD_POINT, MAKE_OUTER_POLYGON, FINALIZE_TRIANGLE, DONE, WAIT}

@export var WAIT_TIME = 0.2
@onready var debug_timer = $DebugTimer
@onready var execute_timer = $ExecuteTimer

var panel
var m_dict_property

var m_state = STATE.RESET
var m_next_state = STATE.RESET
var m_point_index = 0
var m_bad_triangle_lines = []
var m_circumcircles = []
var m_outer_polygon = null
var m_points = []
var m_curr_triangles = []
var m_prev_triangles = []
var m_shuffle_flag = false
var m_random_flag = false
var m_child_lines = []
var m_enable_step = false
var m_second_timer = 0

var delaunay:AzgaarDelaunay.Delaunay

# Called when the node enters the scene tree for the first time.
func _ready():
    var d = {}
    #d["test_button"] = {"type": "Button", "name": "Test"}
    #d["test_bool"] = {"type": "CheckBox", "value": true, "name": "bool"}
    #d["test_int"] = {"type": "SpinBox", "min": 0, "max": 100, "value": 1, "name": "Int"}
    #d["test_float"] = {"type": "SpinBox", "min": 0.0, "max": 100.0, "value": 1.0, "name": "Float"}
    #d["test_string"] = {"type": "LineEdit", "value": "test", "name": "String"}
    d["shuffle_points"] = {"type": "CheckBox", "value" : m_shuffle_flag, "name" :"Shuffle"} # shuffle points
    d["hard_random"] = {"type": "CheckBox", "value" : m_random_flag, "name" :"Random"} # randomize points
    d["wait_time"] = {"type": "HSlider", "min": 0.0, "max": 2.0, "value": WAIT_TIME, "step": 0.1, "name": "Wait Time"} # wait time between steps
    d["wait_time_read_only"] = {"type": "SpinBox", "min": 0.0, "max": 2.0, "step": 0.1, "value": WAIT_TIME, "name": "Wait Time", "readonly": true} # wait time between steps
    d["enable_step"] = {"type": "CheckBox", "value" : m_enable_step, "name" :"Enable Step"} # enable step
    d["num_triangle_search"] = {"type": "SpinBox", "min": 0, "max": 2000, "value": 0, "name": "Num Triangles Search", "readonly": true} # number of triangles to search
    d["num_points"] = {"type": "SpinBox", "min": 0, "max": 2000, "value": 0, "name": "Num Points", "readonly": true} # number of points
    d["execution_time"] = {"type": "SpinBox", "min": 0.0, "max": 100000.0, "value": 0.0, "name": "Execution Time", "readonly": true} # execution time
    d["step_button"] = {"type": "Button", "name": "Step"} # step
    d["start_stop_button"] = {"type": "Button", "name": "Start"} # start triangulation

    panel = $HBox/Panel
    m_dict_property = $HBox/DictProperty
    m_dict_property.update_dict(d)
    initialize()
    m_state = STATE.RESET
    execute_timer.autostart = false
    execute_timer.stop()

func initialize():
    for line in m_child_lines:
        line.queue_free()
    m_child_lines.clear()
    m_second_timer = 0
    m_dict_property.set_value("execution_time", m_second_timer)
    execute_timer.autostart = true
    execute_timer.start(1.0)

    delaunay = AzgaarDelaunay.Delaunay.new(get_viewport_rect())
    m_points.clear()
    var width = (get_viewport_rect().size.x * 0.8)
    var height = (get_viewport_rect().size.y * 0.8)
    if m_random_flag:
        for i in range(100):
            var point = AzgaarDelaunay.Point2.new(Vector2(randi_range(50, (width - 50)), randi_range(50, (height - 50))), null)
            m_points.append(point)
    else:
        for i in range(10):
            for j in range(10):
                var point = AzgaarDelaunay.Point2.new(Vector2(50 + i*(width / 10) + randi_range(-15,15), 50 + j * (height / 10) + randi_range(-15,15)), null)
                #delaunay.add_direct_point(point)
                m_points.append(point)
        if m_shuffle_flag:
            m_points.shuffle()

func _process(_delta):
    match(m_state):
        STATE.RESET:
            pass
        STATE.INIT:
            delaunay.triangulate_debug_init()
            m_state = STATE.ADD_POINT
            m_point_index = 0
        STATE.ADD_POINT:
            var bad_triangles = delaunay.triangulate_debug_1_find_bad_triangles_from_point(m_points[m_point_index])
            show_bad_triangles(bad_triangles)
            m_next_state = STATE.MAKE_OUTER_POLYGON
            m_state = STATE.WAIT
            if !m_enable_step:
                debug_timer.start(WAIT_TIME)
        STATE.MAKE_OUTER_POLYGON:
            var outer_polygon = delaunay.triangulate_debug_2_make_outer_polygon()
            m_outer_polygon = add_outer_polygon(outer_polygon, Color.GREEN)
            m_next_state = STATE.FINALIZE_TRIANGLE
            m_state = STATE.WAIT
            if !m_enable_step:
                debug_timer.start(WAIT_TIME)
        STATE.FINALIZE_TRIANGLE:
            m_curr_triangles = delaunay.triangulate_debug_3_finalize_triangle(m_points[m_point_index])
            m_point_index += 1
            for triangle in m_prev_triangles:
                triangle.queue_free()
            for triangle in m_curr_triangles:
                if !delaunay.is_border_triangle(triangle): # do not render border triangles
                    m_child_lines.append(show_triangle(triangle))
            m_state = STATE.WAIT
            if m_point_index < len(m_points):
                m_next_state = STATE.ADD_POINT
            else:
                m_next_state = STATE.DONE
            m_dict_property.set_value("num_points", len(delaunay.m_points))
            m_dict_property.set_value("num_triangle_search", len(delaunay.debug_triangulation))
            if !m_enable_step:
                debug_timer.start(WAIT_TIME)

        STATE.DONE:
            execute_timer.stop()

        STATE.WAIT:
            pass

func update_triangles(triangles: Array) -> void:
    for triangle in m_curr_triangles:
        triangle.queue_free()
    m_curr_triangles.clear()
    for triangle in triangles:
        m_curr_triangles.append(show_triangle(triangle))

func add_outer_polygon(polygon: Array, color: Color) -> Line2D:
    var line = Line2D.new()
    var p = PackedVector2Array()
    for edge in polygon:
        p.append(edge.b.v)
    p.append(polygon[0].a.v)
    line.points = p
    line.width = 1
    line.antialiased = true
    line.default_color = color
    panel.add_child(line)
    return line

func show_bad_triangles(bad_triangles: Array) -> void:
    for triangle in bad_triangles:
        m_bad_triangle_lines.append(show_triangle(triangle, Color.RED))
        m_circumcircles.append(add_circumcircle(triangle.center, sqrt(triangle.radius_sqr)))
    queue_redraw()

func add_circumcircle(center: Vector2, radius: float, color:Color = Color.PURPLE) -> Line2D:
    var circle = Line2D.new()
    var p = PackedVector2Array()
    for i in range(0, 360, 10):
        p.append(Vector2(cos(deg_to_rad(i)), sin(deg_to_rad(i))) * radius + center)
    circle.points = p
    circle.width = 1
    circle.antialiased = true
    circle.default_color = color
    panel.add_child(circle)
    return circle

func add_point(point: Vector2) -> Polygon2D:
    var polygon = Polygon2D.new()
    var p = PackedVector2Array()
    var s = 5
    p.append(Vector2(-s,s))
    p.append(Vector2(s,s))
    p.append(Vector2(s,-s))
    p.append(Vector2(-s,-s))
    polygon.polygon = p
    polygon.color = Color.BURLYWOOD
    polygon.position = point
    panel.add_child(polygon)
    #delaunay.add_point(point, null)
    return polygon

func show_triangle(triangle: AzgaarDelaunay.Triangle, color: Color = Color.WHITE) -> Line2D:
    var line = Line2D.new()
    var p = PackedVector2Array()
    p.append(triangle.a.v)
    p.append(triangle.b.v)
    p.append(triangle.c.v)
    p.append(triangle.a.v)
    line.points = p
    line.width = 1
    line.antialiased = true
    line.default_color = color
    panel.add_child(line)
    return line

func _on_debug_timer_timeout():
    if len(m_bad_triangle_lines) > 0:
        for line in m_bad_triangle_lines:
            line.queue_free()
        m_bad_triangle_lines.clear()
    if len(m_circumcircles) > 0:
        for circle in m_circumcircles:
            circle.queue_free()
        m_circumcircles.clear()
    if m_outer_polygon != null:
        m_outer_polygon.queue_free()
        m_outer_polygon = null
    m_state = m_next_state

func _on_dict_property_property_changed(property_name, property_value):
    #print("Property: %s" % str([property_name, property_value]))
    match(property_name):
        "enable_step":
            m_enable_step = property_value
        "step_button":
            _on_debug_timer_timeout()
        "hard_random":
            m_random_flag = property_value
        "shuffle_points":
            m_shuffle_flag = property_value
        "start_stop_button":
            if m_state == STATE.RESET:
                m_dict_property.set_label("start_stop_button", "Stop")
                initialize()
                m_dict_property.set_value("num_triangle_search", 0)
                m_dict_property.set_value("num_points", 0)
                m_state = STATE.INIT
                m_next_state = STATE.INIT
            else:
                m_dict_property.set_label("start_stop_button", "Start")
                execute_timer.stop()
                m_state = STATE.RESET
                m_next_state = STATE.RESET
        "wait_time":
            WAIT_TIME = property_value
            m_dict_property.set_value("wait_time_read_only", property_value)
        _:
            pass

func _on_execute_timer_timeout():
    m_second_timer += 1
    m_dict_property.set_value("execution_time", m_second_timer)
