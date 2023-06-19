extends Node2D

enum STATE {RESET, INIT, INIT_THREADED_MODE, WAIT_FOR_THREAD, ADD_POINT, MAKE_OUTER_POLYGON, FINALIZE_TRIANGLE, DONE, WAIT}

@export var WAIT_TIME = 0.1
@export var LINE_WIDTH:float = 2
@export var ENABLE_RANDOM = true
@export var ENABLE_SHUFFLE = false
@export var ENABLE_STEP = false
@export var X_COUNT = 5
@export var Y_COUNT = 5

@onready var verbose_timer = $VerboseTimer
@onready var execute_timer = $ExecuteTimer
@onready var delaunay_texture_map = $TabContainer/TexureMap

var panel
var m_dict_property

var m_enable_debug = true
var m_state = STATE.RESET
var m_next_state = STATE.RESET
var m_point_index = 0
var m_bad_triangle_lines = []
var m_circumcircles = []
var m_outer_polygon = null
var m_points = []
var m_drawn_points = []
var m_curr_triangles = []
var m_shuffle_flag = ENABLE_SHUFFLE
var m_random_flag = ENABLE_RANDOM
var m_repeat_test_flag = false
var m_enable_step = ENABLE_STEP
var m_draw_triangles = []
var m_second_timer = 0
var m_total_triangles_searched = 0
var m_skip_timer = false
var m_task_generate_delaunay_start_time = 0
var m_task_generate_delaunay_triangles = null

var delaunay_types = {"Iterate": AzgaarIterateDelaunay, "Experimental": AzgaarExperimentalDelaunay}
#var delaunay_types_key = "Iterate"
var delaunay_types_key = "Experimental"

var delaunay = null

# Called when the node enters the scene tree for the first time.
func _ready():
    var d = {}
    var key_index = delaunay_types.keys().find(delaunay_types_key)
    #d["test_button"] = {"type": "Button", "name": "Test"}
    #d["test_bool"] = {"type": "CheckBox", "value": true, "name": "bool"}
    #d["test_int"] = {"type": "SpinBox", "min": 0, "max": 100, "value": 1, "name": "Int"}
    #d["test_float"] = {"type": "SpinBox", "min": 0.0, "max": 100.0, "value": 1.0, "name": "Float"}
    #d["test_string"] = {"type": "LineEdit", "value": "test", "name": "String"}
    #d["enable_debug"] = {"type": "CheckBox", "value" : m_enable_debug, "name" :"Enable Debug"} # enable debug
    d["delaunay_select"] = {"type": "OptionButton", "name": "Delaunay Select", "options":delaunay_types.keys(), "value":key_index} # delaunay select
    d["x_count_points"] = {"type": "SpinBox", "min": 0, "max": 100, "value": X_COUNT, "name": "X Count Points"} # x count points
    d["y_count_points"] = {"type": "SpinBox", "min": 0, "max": 100, "value": Y_COUNT, "name": "Y Count Points"} # y count points
    d["shuffle_points"] = {"type": "CheckBox", "value" : m_shuffle_flag, "name" :"Shuffle"} # shuffle points
    d["hard_random"] = {"type": "CheckBox", "value" : m_random_flag, "name" :"Random"} # randomize points
    d["repeat_test"] = {"type": "CheckBox", "value" : false, "name" :"Repeat Test"} # repeat test
    d["enable_step"] = {"type": "CheckBox", "value" : m_enable_step, "name" :"Enable Step"} # enable step
    d["wait_time"] = {"type": "HSlider", "min": 0.0, "max": 2.0, "value": WAIT_TIME, "step": 0.1, "name": "Wait Time"} # wait time between steps
    d["wait_time_read_only"] = {"type": "SpinBox", "min": 0.0, "max": 2.0, "step": 0.1, "value": WAIT_TIME, "name": "Wait Time", "readonly": true} # wait time between steps
    d["num_triangle_search"] = {"type": "SpinBox", "min": 0, "max": 100000, "value": 0, "name": "Num Triangles Search", "readonly": true} # number of triangles to search
    d["total_triangles_searched"] = {"type": "SpinBox", "min": 0, "max": 100000000, "value": 0, "name": "Total Triangles Searched", "readonly": true} # total number of triangles searchedk
    d["num_points"] = {"type": "SpinBox", "min": 0, "max": 100000, "value": 0, "name": "Num Points", "readonly": true} # number of points
    d["execution_time"] = {"type": "SpinBox", "min": 0.0, "max": 100000.0, "value": 0.0, "name": "Execution Time", "readonly": true} # execution time
    d["step_button"] = {"type": "Button", "name": "Step"} # step
    d["start_stop_button"] = {"type": "Button", "name": "Start"} # start triangulation
    d["save_image"] = {"type": "Button", "name": "Save Image"} # save image
    d["state"] = {"type": "LineEdit", "value": "RESET", "name": "State", "readonly": true} # state

    panel = $TabContainer/Main/Panel
    m_dict_property = $TabContainer/Main/DictProperty
    m_dict_property.update_dict(d)
    initialize()
    m_state = STATE.RESET
    execute_timer.autostart = false
    execute_timer.stop()

func initialize():
    for line in m_draw_triangles:
        line.queue_free()
    if len(m_drawn_points) > 0:
        for point in m_drawn_points:
            point.queue_free()
        m_drawn_points.clear()
    m_draw_triangles.clear()
    m_second_timer = 0
    m_dict_property.set_value("execution_time", m_second_timer)
    execute_timer.autostart = true
    execute_timer.start(1.0)

    if delaunay != null:
        remove_child(delaunay)
        delaunay.queue_free()

    delaunay = delaunay_types[delaunay_types_key].new(get_viewport_rect())
    m_total_triangles_searched = 0
    m_dict_property.set_value("total_triangles_searched", m_total_triangles_searched)
    add_child(delaunay)

    delaunay_texture_map.initialize(delaunay, Vector2i(get_viewport_rect().size))
    m_points.clear()
    var width = (get_viewport_rect().size.x * 0.8)
    var height = (get_viewport_rect().size.y * 0.8)
    if m_random_flag:
        for i in range(X_COUNT * Y_COUNT):
            var point = DelaunayBase.Point2.new(Vector2(randi_range(50, (width - 50)), randi_range(50, (height - 50))), null)
            m_points.append(point)
    else:
        for i in range(X_COUNT):
            for j in range(Y_COUNT):
                var point = DelaunayBase.Point2.new(Vector2(50 + i*(width / X_COUNT) + randi_range(-15,15), 50 + j * (height / Y_COUNT) + randi_range(-15,15)), null)
                #delaunay.add_direct_point(point)
                m_points.append(point)
        if m_shuffle_flag:
            m_points.shuffle()

    if m_repeat_test_flag:
        print ("Repeat Flag Set!")
        m_points = m_points + m_points
    verbose_timer.stop()

func _process(_delta):
    match(m_state):
        STATE.RESET:
            pass
        STATE.INIT:
            m_dict_property.set_value("state", "INIT")
            delaunay.triangulate_init()
            m_point_index = 0
            if !m_enable_debug:
                m_state = STATE.INIT_THREADED_MODE
            else:
                m_state = STATE.ADD_POINT
        STATE.INIT_THREADED_MODE:
            m_task_generate_delaunay_start_time = Time.get_ticks_usec()
            m_task_generate_delaunay_triangles = TaskManager.create_task(_generate_delaunay_triangles_thread, true, "Generate Delaunay Triangles")
            m_task_generate_delaunay_triangles.completed.connect(_generate_delaunay_triangles_thread_finished)
            m_state = STATE.WAIT_FOR_THREAD
        STATE.WAIT_FOR_THREAD:
            pass
        STATE.ADD_POINT:
            m_dict_property.set_value("state", "ADD_POINT")
            var bad_triangles = delaunay.triangulate_find_bad_triangles_from_point(m_points[m_point_index])
            if len(bad_triangles) == 0:
                m_point_index += 1
                m_state = STATE.WAIT
                if m_point_index < len(m_points):
                    m_next_state = STATE.ADD_POINT
                else:
                    m_next_state = STATE.DONE
            else:
                show_point(m_points[m_point_index].v)

                show_bad_triangles(bad_triangles)
                m_next_state = STATE.MAKE_OUTER_POLYGON
                m_state = STATE.WAIT
                if !m_enable_step:
                    if m_skip_timer:
                        _on_verbose_timer_timeout()
                    else:
                        verbose_timer.start(WAIT_TIME)
        STATE.MAKE_OUTER_POLYGON:
            m_dict_property.set_value("state", "MAKE_OUTER_POLYGON")
            var outer_polygon = delaunay.triangulate_make_outer_polygon()
            m_outer_polygon = add_outer_polygon(outer_polygon)
            m_next_state = STATE.FINALIZE_TRIANGLE
            m_state = STATE.WAIT
            if !m_enable_step:
                if m_skip_timer:
                    _on_verbose_timer_timeout()
                else:
                    verbose_timer.start(WAIT_TIME)
        STATE.FINALIZE_TRIANGLE:
            m_dict_property.set_value("state", "FINALIZE_TRIANGLE")
            var search_count = delaunay.get_search_count()

            m_curr_triangles = delaunay.triangulate_finalize_triangle(m_points[m_point_index])
            delaunay_texture_map.triangles_updated()
            m_point_index += 1

            update_triangles(m_curr_triangles)

            m_state = STATE.WAIT
            if m_point_index < len(m_points):
                m_next_state = STATE.ADD_POINT
            else:
                m_next_state = STATE.DONE
            m_dict_property.set_value("num_points", len(delaunay.m_points))
            m_dict_property.set_value("num_triangle_search", search_count)
            m_total_triangles_searched += search_count
            m_dict_property.set_value("total_triangles_searched", m_total_triangles_searched)
            if !m_enable_step:
                if m_skip_timer:
                    _on_verbose_timer_timeout()
                else:
                    verbose_timer.start(WAIT_TIME)

        STATE.DONE:
            m_dict_property.set_value("state", "DONE")
            m_dict_property.set_value("start_stop_button", "Start")
            execute_timer.stop()
            m_state = STATE.RESET
            m_next_state = STATE.RESET


        STATE.WAIT:
            pass

func update_triangles(triangles: Array) -> void:
    for draw_triangle in m_draw_triangles:
        draw_triangle.queue_free()
    m_draw_triangles.clear()
    for triangle in triangles:
        if !delaunay.is_border_triangle(triangle): # do not render border triangles
            m_draw_triangles.append(show_triangle(triangle))
        else:
            m_draw_triangles.append(show_triangle(triangle, Color.GRAY))

#func add_outer_polygon(polygon: Array, color: Color) -> Line2D:
#    var line = Line2D.new()
#    var p = PackedVector2Array()
#    p.append(polygon[0].a.v)
#    for edge in polygon:
#        p.append(edge.b.v)
#    p.append(polygon[0].a.v)
#    line.points = p
#    line.width = LINE_WIDTH
#    line.antialiased = true
#    line.default_color = color
#    panel.add_child(line)
#    return line

func add_outer_polygon(polygon_points: Array) -> Polygon2D:
    var polygon = Polygon2D.new()
    #var polygon = ConvexPolygonShape2D.new()
    var p = PackedVector2Array()
    p.append(polygon_points[0].a.v)
    for edge in polygon_points:
        p.append(edge.b.v)

    #for point in polygon_points:
    #    p.append(point)
    polygon.polygon = Geometry2D.convex_hull(p)
    polygon.color = Color(0.0, 1.0, 0.0, 0.5)
    panel.add_child(polygon)
    return polygon


func show_point(point) -> void:
    var circle = Line2D.new()
    var p = PackedVector2Array()
    var radius = 4
    for i in range(0, 360 + 1, 90):
        p.append(Vector2(cos(deg_to_rad(i)), sin(deg_to_rad(i))) * radius + point)
    circle.points = p
    circle.width = LINE_WIDTH
    circle.antialiased = true
    circle.default_color = Color.ORANGE
    m_drawn_points.append(circle)
    panel.add_child(circle)

func show_bad_triangles(bad_triangles: Array) -> void:
    for triangle in bad_triangles:
        m_bad_triangle_lines.append(show_triangle(triangle, Color.RED))
        m_circumcircles.append(add_circumcircle(triangle.center, sqrt(triangle.radius_sqr)))
    queue_redraw()

func add_circumcircle(center: Vector2, radius: float, color:Color = Color.PURPLE) -> Line2D:
    var circle = Line2D.new()
    var p = PackedVector2Array()
    for i in range(0, 360 + 1, 5):
        p.append(Vector2(cos(deg_to_rad(i)), sin(deg_to_rad(i))) * radius + center)
    circle.points = p
    circle.width = LINE_WIDTH
    circle.antialiased = true
    circle.default_color = color
    panel.add_child(circle)
    return circle

#func add_point(point: Vector2) -> Polygon2D:
#    var polygon = Polygon2D.new()
#    var p = PackedVector2Array()
#    var s = 5
#    p.append(Vector2(-s,s))
#    p.append(Vector2(s,s))
#    p.append(Vector2(s,-s))
#    p.append(Vector2(-s,-s))
#    polygon.polygon = p
#    polygon.color = Color.BURLYWOOD
#    polygon.position = point
#    panel.add_child(polygon)
#    #delaunay.add_point(point, null)
#    return polygon

func show_triangle(triangle: DelaunayBase.Triangle, color: Color = Color.WHITE) -> Line2D:
    var line = Line2D.new()
    var p = PackedVector2Array()
    p.append(triangle.a.v)
    p.append(triangle.b.v)
    p.append(triangle.c.v)
    p.append(triangle.a.v)
    line.points = p
    line.width = LINE_WIDTH
    line.antialiased = true
    line.default_color = color
    panel.add_child(line)
    return line

func _on_verbose_timer_timeout():
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
        "x_count_points":
            X_COUNT = property_value
        "y_count_points":
            Y_COUNT = property_value
        "delaunay_select":
            delaunay_types_key = property_value
        "enable_debug":
            m_enable_debug = property_value
        "enable_step":
            m_enable_step = property_value
        "step_button":
            _on_verbose_timer_timeout()
        "hard_random":
            m_random_flag = property_value
        "shuffle_points":
            m_shuffle_flag = property_value
        "repeat_test":
            m_repeat_test_flag = property_value
        "start_stop_button":
            if m_state == STATE.RESET:
                initialize()
                m_dict_property.set_value("start_stop_button", "Stop")
                m_dict_property.set_value("num_triangle_search", 0)
                m_dict_property.set_value("num_points", 0)
                m_state = STATE.INIT
                m_next_state = STATE.INIT
            else:
                m_dict_property.set_value("start_stop_button", "Start")
                execute_timer.stop()
                m_state = STATE.RESET
                m_next_state = STATE.RESET
        "wait_time":
            WAIT_TIME = property_value
            if WAIT_TIME < 0.1:
                WAIT_TIME = 0.1
                m_skip_timer = true
            else:
                m_skip_timer = false
            m_dict_property.set_value("wait_time_read_only", property_value)
        "save_image":
            delaunay_texture_map.save_image("test.png")
        _:
            pass

func _on_execute_timer_timeout():
    m_second_timer += 1

    # Schedule the function
    m_dict_property.set_value("execution_time", m_second_timer)


func _generate_delaunay_triangles_thread():
    # Iterate through all the points and add them to delaunay generator, updating the number of triangles
    for point in m_points:
        delaunay.triangulate_add_point(point)
        m_dict_property.set_value("num_points", len(delaunay.m_points))
        m_dict_property.set_value("num_triangle_search", delaunay.get_search_count())
        m_total_triangles_searched += delaunay.get_search_count()
        m_dict_property.set_value("total_triangles_searched", m_total_triangles_searched)

func _generate_delaunay_triangles_thread_finished():
    var elapsed_time = Time.get_ticks_usec() - m_task_generate_delaunay_start_time
    elapsed_time = elapsed_time / 1000000.0
    print ("Delaunay Type: %s" % delaunay_types_key)
    print ("Total Points: %d" % len(m_points))
    print ("Generate Threaded Elapsed Time: %f" % elapsed_time)
    print ("")
    m_state = STATE.DONE
