extends Node
class_name AzgaarIterateDelaunay

##############################################################################
# Classes
##############################################################################

class Point2:
    var data
    var x:
        set(nv):
            v.x = nv
        get:
            return v.x
    var y:
        set(nv):
            v.y = nv
        get:
            return v.y
    var v:Vector2:
          get:
              return v
    func _init(point: Vector2, d):
        v = point
        self.data = d

class Edge:
    var a: Point2
    var b: Point2

    func _init(new_a: Point2, new_b: Point2):
        self.a = new_a
        self.b = new_b

    func equals(edge: Edge) -> bool:
        return (a == edge.a && b == edge.b) || (a == edge.b && b == edge.a)

    func length() -> float:
        return a.distance_to(b)

    func center() -> Vector2:
        return (a.v + b.v) * 0.5

class Triangle:
    var a: Point2
    var b: Point2
    var c: Point2

    var edge_ab: Edge
    var edge_bc: Edge
    var edge_ca: Edge

    var center: Vector2
    var radius_sqr: float

    func _init(new_a: Point2, new_b: Point2, new_c: Point2):
        self.a = new_a
        self.b = new_b
        self.c = new_c
        edge_ab = Edge.new(a,b)
        edge_bc = Edge.new(b,c)
        edge_ca = Edge.new(c,a)
        recalculate_circumcircle()

    func recalculate_circumcircle() -> void:
        var ab := a.v.length_squared()
        var cd := b.v.length_squared()
        var ef := c.v.length_squared()

        var cmb := c.v - b.v
        var amc := a.v - c.v
        var bma := b.v - a.v

        var circum := Vector2(
            (ab * cmb.y + cd * amc.y + ef * bma.y) / (a.x * cmb.y + b.x * amc.y + c.x * bma.y),
            (ab * cmb.x + cd * amc.x + ef * bma.x) / (a.y * cmb.x + b.y * amc.x + c.y * bma.x)
        )

        center = circum * 0.5
        radius_sqr = a.v.distance_squared_to(center)


    func is_point_inside_circumcircle(point: Point2) -> bool:
        return center.distance_squared_to(point.v) < radius_sqr

    func is_corner(point: Point2) -> bool:
        return point.v == a.v || point.v == b.v || point.v == c.v

    func get_corner_opposite_edge(corner: Point2) -> Edge:
        if corner.v == a.v:
            return edge_bc
        elif corner.v == b.v:
            return edge_ca
        elif corner.v == c.v:
            return edge_ab
        else:
            return null

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

class Delaunay:
    var m_points: Array
    var m_rect: Rect2
    var m_rect_super: Rect2
    var m_rect_super_corners: Array
    var m_rect_super_triangle1: Triangle
    var m_rect_super_triangle2: Triangle

    var m_curr_index: int = 0
    var m_bad_triangles: Array  = []
    var m_triangles: Array = []

    var m_triangle_dict: Dictionary = {}
    var m_bad_triangle_dict: Dictionary = {}
    var m_add_triangle_dict: Dictionary = {}

    var m_polygon: Array  = []

    var m_sub_viewport: SubViewport
    var m_sv_polygons: Dictionary = {}
    var m_image:Image

    func _init(rect: Rect2i = Rect2i()):
        m_points = []
        set_rect(rect)
        m_sub_viewport = SubViewport.new()
        m_sub_viewport.disable_3d = true
        m_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        m_sub_viewport.size = rect.size
        m_curr_index = 0
        m_image = Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
        m_image.fill(Color.hex(0x000000FE))

        m_triangle_dict.clear()
        m_bad_triangle_dict.clear()
        m_add_triangle_dict.clear()


    func add_point(coor: Vector2, data) -> void:
        m_points.append(Point2.new(coor, data))

    func calc_rect(points: Array, padding: float = 0.0) -> Rect2:
        var rect := Rect2(points[0].v, Vector2.ZERO)
        for point in points:
            rect = rect.expand(point.v)
        return rect.grow(padding)

    func is_border_triangle(triangle: Triangle) -> bool:
        return m_rect_super_corners.has(triangle.a) || m_rect_super_corners.has(triangle.b) || m_rect_super_corners.has(triangle.c)

    func set_rect(rect: Rect2) -> void:
        m_rect = rect # save original rect
        # we expand rect to super rect to make sure
        # all future points won't be too close to broder
        var rect_max_size = max(m_rect.size.x, m_rect.size.y)
        m_rect_super = m_rect.grow(rect_max_size * 1)

    func triangulate_verbose_init():
        m_triangle_dict.clear()
        m_add_triangle_dict.clear()
        m_bad_triangle_dict.clear()

        m_triangles.clear()
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

        m_rect_super_triangle1 = Triangle.new(c0,c1,c2)
        m_add_triangle_dict[m_curr_index] = m_rect_super_triangle1
        m_curr_index += 1
        m_rect_super_triangle2 = Triangle.new(c1,c2,c3)
        m_add_triangle_dict[m_curr_index] = m_rect_super_triangle2
        m_curr_index += 1

        m_triangles.append(m_rect_super_triangle1)
        m_triangles.append(m_rect_super_triangle2)
        update_viewport(m_bad_triangle_dict, m_add_triangle_dict)

    func triangulate_verbose_find_bad_triangles_from_point(point:Point2) -> Array:
        m_bad_triangles.clear()
        m_polygon.clear()
        m_points.append(point)
        _find_bad_triangles(point, m_triangles, m_bad_triangles)
        update_viewport(m_bad_triangle_dict, m_add_triangle_dict)
        return m_bad_triangles

    func triangulate_verbose_make_outer_polygon() -> Array:
        for bad_tirangle in m_bad_triangles:
            m_triangles.erase(bad_tirangle)
        _make_outer_polygon(m_bad_triangles, m_polygon)
        return m_polygon

    func triangulate_verbose_finalize_triangle(point:Point2) -> Array:
        for edge in m_polygon:
            var triangle = Triangle.new(point, edge.a, edge.b)
            m_triangles.append(triangle)
        return m_triangles

    ##############################################################################
    # Private Functions
    ##############################################################################
    func update_viewport(delete_triangle_dict: Dictionary, added_triangle_dict: Dictionary)->void:
        for key in delete_triangle_dict:
            var p = m_sv_polygons[key]
            m_sub_viewport.remove_child(p)
            m_triangle_dict.erase(key)
            print ("Delete: %d" % int(key))

        for key in added_triangle_dict:
            var points = PackedByteArray()
            var r = Rect2(Vector2(), m_sub_viewport.size)
            points = [Vector2(0, 0), Vector2(0, r.end.y), Vector2(r.end.x, r.end.y), Vector2(r.end.x, 0)]
            var p = Polygon2D.new()
            p.polygon = points
            p.color = Color.hex(0x000000FF | key << 8)
            m_sub_viewport.add_child(p)
            m_sv_polygons[key] = p
            m_triangle_dict[key] = added_triangle_dict[key]
            print ("Add: %d" % int(key))

        delete_triangle_dict.clear()
        added_triangle_dict.clear()
        m_image = m_sub_viewport.get_texture().get_image()

    func _get_triangle_from_point(pos: Vector2) -> Triangle:
        var colour = m_image.get_pixel(roundi(pos.x), roundi(pos.y))
        var index = colour.to_rgba32()
        return m_triangle_dict[index]

    func _find_bad_triangles(point: Point2, triangles: Array, out_bad_triangles: Array) -> void:
        #get_triangle_from_point(point.v)
        for triangle in triangles:
            if triangle.is_point_inside_circumcircle(point):
                out_bad_triangles.append(triangle)

    func _make_outer_polygon(triangles: Array, out_polygon: Array) -> void:
        var duplicates: Array = [] # of Edge

        for triangle in triangles:
            out_polygon.append(triangle.edge_ab)
            out_polygon.append(triangle.edge_bc)
            out_polygon.append(triangle.edge_ca)

        for edge1 in out_polygon:
            for edge2 in out_polygon:
                if edge1 != edge2 && edge1.equals(edge2):
                    duplicates.append(edge1)
                    duplicates.append(edge2)

        for edge in duplicates:
            out_polygon.erase(edge)

class DelaunayExperimental:
    var m_points: Array
    var m_rect: Rect2
    var m_rect_super: Rect2
    var m_rect_super_corners: Array
    var m_rect_super_triangle1: Triangle
    var m_rect_super_triangle2: Triangle

    var m_curr_index: int = 0
    var m_bad_triangles: Array  = []

    var m_triangle_dict: Dictionary = {}
    var m_bad_triangle_dict: Dictionary = {}
    var m_add_triangle_dict: Dictionary = {}

    var m_polygon: Array  = []

    var m_sub_viewport: SubViewport
    var m_sv_polygons: Dictionary = {}
    var m_image:Image

    func _init(rect: Rect2i = Rect2i()):
        m_points = []
        set_rect(rect)
        m_sub_viewport = SubViewport.new()
        m_sub_viewport.disable_3d = true
        m_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        m_sub_viewport.size = rect.size
        m_curr_index = 0
        m_image = Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
        m_image.fill(Color.hex(0x000000FE))

        m_triangle_dict.clear()
        m_bad_triangle_dict.clear()
        m_add_triangle_dict.clear()

    func add_point(coor: Vector2, data) -> void:
        m_points.append(Point2.new(coor, data))

    func calc_rect(points: Array, padding: float = 0.0) -> Rect2:
        var rect := Rect2(points[0].v, Vector2.ZERO)
        for point in points:
            rect = rect.expand(point.v)
        return rect.grow(padding)

    func is_border_triangle(triangle: Triangle) -> bool:
        return m_rect_super_corners.has(triangle.a) || m_rect_super_corners.has(triangle.b) || m_rect_super_corners.has(triangle.c)

    func set_rect(rect: Rect2) -> void:
        m_rect = rect # save original rect
        # we expand rect to super rect to make sure
        # all future points won't be too close to broder
        var rect_max_size = max(m_rect.size.x, m_rect.size.y)
        m_rect_super = m_rect.grow(rect_max_size * 1)

    func triangulate_verbose_init():
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

        m_rect_super_triangle1 = Triangle.new(c0,c1,c2)
        m_add_triangle_dict[m_curr_index] = m_rect_super_triangle1
        m_curr_index += 1
        m_rect_super_triangle2 = Triangle.new(c1,c2,c3)
        m_add_triangle_dict[m_curr_index] = m_rect_super_triangle2
        m_curr_index += 1
        update_viewport(m_bad_triangle_dict, m_add_triangle_dict)

    func triangulate_verbose_find_bad_triangles_from_point(point:Point2) -> Array:
        m_bad_triangle_dict.clear()
        m_polygon.clear()
        m_points.append(point)
        _find_bad_triangles(point)
        update_viewport(m_bad_triangle_dict, m_add_triangle_dict)
        return m_bad_triangle_dict.values()

    func triangulate_verbose_make_outer_polygon() -> Array:
        for key in m_bad_triangles:
            m_triangle_dict.erase(key)
        _make_outer_polygon()
        return m_polygon

    func triangulate_verbose_finalize_triangle(point:Point2) -> Array:
        for edge in m_polygon:
            var triangle = Triangle.new(point, edge.a, edge.b)
            m_triangle_dict[m_curr_index] = triangle
        return m_triangle_dict.values()

    ##############################################################################
    # Private Functions
    ##############################################################################
    func update_viewport(delete_triangle_dict: Dictionary, added_triangle_dict: Dictionary)->void:
        for key in delete_triangle_dict:
            var p = m_sv_polygons[key]
            m_sub_viewport.remove_child(p)
            m_triangle_dict.erase(key)
            print ("Delete: %d" % int(key))

        for key in added_triangle_dict:
            var points = PackedByteArray()
            var r = Rect2(Vector2(), m_sub_viewport.size)
            points = [Vector2(0, 0), Vector2(0, r.end.y), Vector2(r.end.x, r.end.y), Vector2(r.end.x, 0)]
            var p = Polygon2D.new()
            p.polygon = points
            p.color = Color.hex(0x000000FF | key << 8)
            m_sub_viewport.add_child(p)
            m_sv_polygons[key] = p
            m_triangle_dict[key] = added_triangle_dict[key]
            print ("Add: %d" % int(key))

        delete_triangle_dict.clear()
        added_triangle_dict.clear()
        m_image = m_sub_viewport.get_texture().get_image()

    func _get_triangle_from_point(pos: Vector2) -> Triangle:
        var colour = m_image.get_pixel(roundi(pos.x), roundi(pos.y))
        var index = colour.to_rgba32()
        return m_triangle_dict[index]

    func _find_bad_triangles(point: Point2) -> void:
        #_get_triangle_from_point(point.v)
        for key in m_triangle_dict.keys():
            var triangle = m_triangle_dict[key]
            if triangle.is_point_inside_circumcircle(point):
                m_bad_triangle_dict[key] = triangle

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


    ##############################################################################
    # Faster triangulation
    ##############################################################################
    #func triangulate() -> Array: # of Triangle
    #    var triangulation: Array = []

    #    # calculate rectangle if none
    #    if !(m_rect.has_area()):
    #        set_rect(calc_rect(m_points))

    #    triangulation.append(m_rect_super_triangle1)
    #    triangulation.append(m_rect_super_triangle2)

    #    for point in m_points:
    #        m_bad_triangles.clear()
    #        m_polygon.clear()

    #        _find_bad_triangles(point, triangulation, m_bad_triangles)
    #        for bad_tirangle in m_bad_triangles:
    #            triangulation.erase(bad_tirangle)

    #        _make_outer_polygon(m_bad_triangles, m_polygon)
    #        for edge in m_polygon:
    #            triangulation.append(Triangle.new(point, edge.a, edge.b))

    #    return triangulation
