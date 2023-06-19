extends DelaunayBase
class_name AzgaarExperimentalDelaunay

@export var MAX_INDEX_VAL = 1000000
##############################################################################
# Classes
##############################################################################

##############################################################################
# Public Static Functions
##############################################################################
# calculates rect that contains all given points

##############################################################################
# Constructor
##############################################################################

##############################################################################
# Main Class
##############################################################################

var m_points: Array
var m_wip_point: Point2
var m_rect: Rect2
var m_rect_super: Rect2
var m_rect_super_corners: Array
var m_rect_super_triangle1: Triangle
var m_rect_super_triangle2: Triangle

var m_curr_index: int = 0

var m_triangle_dict: Dictionary = {}
var m_bad_triangle_dict: Dictionary = {}
var m_add_triangle_dict: Dictionary = {}

#var m_draw_triangles: Array = []

var m_polygon: Array  = []

var m_sub_viewport_container: SubViewportContainer
var m_sub_viewport: SubViewport
#var m_delaunay_triangle_drawer: DelaunayTriangleDrawer
var m_sv_polygons: Dictionary = {}
var m_image:Image
var m_search_count:int = 0

func _ready() -> void:
    #m_sub_viewport = get_parent().get_node("SubViewportContainer/SubViewport")
    m_sub_viewport_container = SubViewportContainer.new()
    m_sub_viewport = SubViewport.new()
    m_sub_viewport_container.add_child(m_sub_viewport)
    m_sub_viewport_container.visible = false
    add_child(m_sub_viewport_container)
    #m_draw_triangles.clear()
    m_sub_viewport.disable_3d = true
    m_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    m_sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
    #m_sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
    m_sub_viewport.size = m_rect.size
    #m_delaunay_triangle_drawer = DelaunayTriangleDrawer.new(m_rect.size)
    #m_sub_viewport.add_child(m_delaunay_triangle_drawer)

func triangulate_add_points(points: Array) -> void:
    for point in points:
        triangulate_add_point(point)

func triangulate_add_point(point: Point2) -> void:
    m_wip_point = point
    #m_points.append(point)
    triangulate_find_bad_triangles_from_point(point)
    if len(m_bad_triangle_dict) == 0:
        return
    triangulate_make_outer_polygon()
    triangulate_finalize_triangle(point)



func _init(rect: Rect2i = Rect2i()):
    m_points = []
    set_rect(rect)

#func add_point(coor: Vector2, data) -> void:
#    #m_points.append(Point2.new(coor, data))
#    m_wip_point = Point2.new(coor, data)
#    m_points.append(m_wip_point)

func calc_rect(points: Array, padding: float = 0.0) -> Rect2:
    var rect := Rect2(points[0].v, Vector2.ZERO)
    for point in points:
        rect = rect.expand(point.v)
    return rect.grow(padding)

func is_border_triangle(triangle: Triangle) -> bool:
    return m_rect_super_corners.has(triangle.a) || m_rect_super_corners.has(triangle.b) || m_rect_super_corners.has(triangle.c)

func set_rect(rect: Rect2) -> void:
    m_rect = rect # save original rect
    m_rect_super = m_rect

func increment_index() -> void:
    m_curr_index += 1
    if m_curr_index > MAX_INDEX_VAL:
        m_curr_index = 0
    while (m_triangle_dict.has(m_curr_index)):
        m_curr_index += 1
        if m_curr_index > MAX_INDEX_VAL:
            m_curr_index = 0


# Verbose Version
func triangulate_init():
    m_triangle_dict.clear()
    m_add_triangle_dict.clear()
    m_bad_triangle_dict.clear()
    m_points.clear()
    m_curr_index = 0

    if !(m_rect.has_area()):
        set_rect(calc_rect(m_points))

    # calcualte and cache triangles for super rectangle
    var c0 := Point2.new(Vector2(m_rect_super.position), 0xFFFFFF)
    var c1 := Point2.new(Vector2(m_rect_super.position + Vector2(m_rect_super.size.x,0)), 0xFFFFFF)
    var c2 := Point2.new(Vector2(m_rect_super.position + Vector2(0,m_rect_super.size.y)), 0xFFFFFF)
    var c3 := Point2.new(Vector2(m_rect_super.end), 0xFFFFFF)

    m_rect_super_corners.append_array([c0,c1,c2,c3])

    m_rect_super_triangle1 = Triangle.new(m_curr_index, c0,c1,c2)
    m_add_triangle_dict[m_curr_index] = m_rect_super_triangle1
    #m_delaunay_triangle_drawer.add_triangle(m_rect_super_triangle1.get_draw_data())
    increment_index()
    m_rect_super_triangle2 = Triangle.new(m_curr_index, c1,c2,c3)
    m_add_triangle_dict[m_curr_index] = m_rect_super_triangle2
    #m_delaunay_triangle_drawer.add_triangle(m_rect_super_triangle2.get_draw_data())
    increment_index()
    _update_triangles()

func triangulate_find_bad_triangles_from_point(point:Point2) -> Array:
    m_bad_triangle_dict.clear()
    m_polygon.clear()
    m_wip_point = point
    m_points.append(point)
    _find_bad_triangles(point)
    if m_bad_triangle_dict.size() == 0:
        m_points.find(m_wip_point)
        if m_points.rfind(m_wip_point):
            #print ("Found Duplicate Point: %s" % str(m_wip_point))
            pass
    return m_bad_triangle_dict.values()

func triangulate_make_outer_polygon() -> Array:
    _make_outer_polygon()
    return m_polygon

func triangulate_finalize_triangle(point:Point2) -> Array:
    for edge in m_polygon:
        var triangle = Triangle.new(m_curr_index, point, edge.a, edge.b)
        m_add_triangle_dict[m_curr_index] = triangle
        #m_delaunay_triangle_drawer.add_triangle(triangle.get_draw_data())
        increment_index()
    _update_triangles()
    return m_triangle_dict.values()

func get_search_count() -> int:
    return m_search_count

##############################################################################
# Private Functions
##############################################################################
func _update_triangles()->void:
    for p in m_sv_polygons.values():
        m_sub_viewport.remove_child(p)
        p.queue_free()
    m_sv_polygons.clear()

    for key in m_bad_triangle_dict:
        #var p = m_sv_polygons[key]
        m_triangle_dict[key].remove()
        m_triangle_dict.erase(key)
        #m_sub_viewport.remove_child(p)
        #m_triangle_dict.erase(key)
        #m_sv_polygons.erase(key)

    for key in m_add_triangle_dict:
        #m_draw_triangles.append(m_add_triangle_dict[key])
        var triangle = m_add_triangle_dict[key]
        var points = PackedVector2Array()
        points = [triangle.a.v, triangle.b.v, triangle.c.v]
        var p = Polygon2D.new()
        p.polygon = Geometry2D.convex_hull(points)
        p.color = Color.hex(0x000000FF | key << 8)
        #draw_colored_polygon(points, Color.hex(0x000000FF) | key << 8)
        m_sub_viewport.add_child(p)
        m_sv_polygons[key] = p
        m_triangle_dict[key] = m_add_triangle_dict[key]

    #m_delaunay_triangle_drawer.update()
    queue_redraw()
    await RenderingServer.frame_post_draw
    m_bad_triangle_dict.clear()
    m_add_triangle_dict.clear()
    #m_image = m_sub_viewport.get_texture().get_image()

func _get_triangles_from_point(pos: Vector2) -> Array:
    m_image = m_sub_viewport.get_texture().get_image()
    #print ("Get Triangle from Point: %s" % str(pos))
    var colour = m_image.get_pixel(roundi(pos.x), roundi(pos.y))
    #print ("Color: %s" % colour.to_html())
    #XXX: Polygon Version, can I erase the polygon after they are drawn??
    var index = (colour.to_rgba32() >> 8) & 0xFFFFFF
    var test_index = index
    #var test_index = m_delaunay_triangle_drawer.get_triangle_index(pos)
    var found_triangles = []
    #print ("Polygon Based Index: %d" % int(index))
    if index != test_index:
        print ("Polygon Based Index: %d" % int(index))
        print ("Triangle Based Index: %d" % int(test_index))
        print ("Error: Indexes do not match")
        m_image.save_png("image_polygon_image.png")
        #m_delaunay_triangle_drawer.m_image.save_png("image_dtw_image.png")
        # Save the triangle dictionary in JSON file
        var file = FileAccess.open("triangle_dict.json", FileAccess.WRITE)
        file.store_string(JSON.stringify(m_triangle_dict))
        file.close()

    if index not in m_triangle_dict:
        m_image.save_png("debug_at_error.png")
    found_triangles.append(m_triangle_dict[index])

    #Find Neightboring Triangles
    # Go through each of the points and find all the triangles that use this point
    var points = []
    points.append(m_triangle_dict[index].a)
    points.append(m_triangle_dict[index].b)
    points.append(m_triangle_dict[index].c)

    var first_edges = []
    for point in points:
        first_edges.append(point.edges)

    # Add another layer of edges
    var edges = []
    for edge_pair in first_edges:
        for edge in edge_pair:
            edges.append(edge.a.edges)
            edges.append(edge.b.edges)
        edges.append(edge_pair)

    # Go through each of the edges and find all the triangles that use this edge
    for edge_pair in edges:
        for edge in edge_pair:
            for triangle in edge.triangles:
                # If the triangle is not already in the list, add it
                found_triangles.append(triangle)

    return found_triangles

func _find_bad_triangles(point:Point2) -> void:
    var sdict = {}
    var triangles = _get_triangles_from_point(point.v)
    for triangle in triangles:
        var key = triangle.key
        if key in sdict:
            continue
        sdict[key] = triangle
        if triangle.is_point_inside_circumcircle(point):
            m_bad_triangle_dict[triangle.key] = triangle
            #m_triangle_dict[key].remove()
            #m_triangle_dict.erase(triangle.key)
    m_search_count = len(sdict)

func _make_outer_polygon() -> void:
    var duplicates: Array = [] # of Edge

    for key in m_bad_triangle_dict:
        var triangle = m_bad_triangle_dict[key]
        m_polygon.append(triangle.edge_ab)
        m_polygon.append(triangle.edge_bc)
        m_polygon.append(triangle.edge_ca)

    for edge1 in m_polygon:
        for edge2 in m_polygon:
            if edge1 != edge2 && edge1.equals(edge2):
                duplicates.append(edge1)
                duplicates.append(edge2)

    for edge in duplicates:
        m_polygon.erase(edge)

    if len(m_polygon) == 0:
        print ("Polygon has size 0")
        print ("WIP Point: %s" % str(m_wip_point))
        m_image.save_png("image_polygon_size_0.png")
        var file = FileAccess.open("triangle_dict.json", FileAccess.WRITE)
        file.store_string(JSON.stringify(m_triangle_dict))
        file.close()
        print ("Duplicates: %s" % str(duplicates))


#func _draw():
#    for triangle in m_draw_triangles:
#        var points = PackedVector2Array()
#        points = [triangle.a.v, triangle.b.v, triangle.c.v]
#        draw_colored_polygon(Geometry2D.convex_hull(points), Color.hex(0x000000FF | triangle.key << 8))
#    m_draw_triangles.clear()

