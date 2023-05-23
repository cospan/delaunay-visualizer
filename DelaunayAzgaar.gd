extends Node
class_name AzgaarDelaunay

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
    var m_bad_triangles: Array  = []
    var m_polygon: Array  = []

    func _init(rect: Rect2 = Rect2()):
        m_points = []
        set_rect(rect)

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

        # calcualte and cache triangles for super rectangle
        var c0 := Point2.new(Vector2(m_rect_super.position), 0xFFFFFF)
        var c1 := Point2.new(Vector2(m_rect_super.position + Vector2(m_rect_super.size.x,0)), 0xFFFFFF)
        var c2 := Point2.new(Vector2(m_rect_super.position + Vector2(0,m_rect_super.size.y)), 0xFFFFFF)
        var c3 := Point2.new(Vector2(m_rect_super.end), 0xFFFFFF)

        m_rect_super_corners.append_array([c0,c1,c2,c3])
        m_rect_super_triangle1 = Triangle.new(c0,c1,c2)
        m_rect_super_triangle2 = Triangle.new(c1,c2,c3)

    func triangulate() -> Array: # of Triangle
        var triangulation: Array = []

        # calculate rectangle if none
        if !(m_rect.has_area()):
            set_rect(calc_rect(m_points))

        triangulation.append(m_rect_super_triangle1)
        triangulation.append(m_rect_super_triangle2)

        for point in m_points:
            m_bad_triangles.clear()
            m_polygon.clear()

            _find_bad_triangles(point, triangulation, m_bad_triangles)
            for bad_tirangle in m_bad_triangles:
                triangulation.erase(bad_tirangle)

            _make_outer_polygon(m_bad_triangles, m_polygon)
            for edge in m_polygon:
                triangulation.append(Triangle.new(point, edge.a, edge.b))

        return triangulation

    var m_triangles: Array = []
    func triangulate_debug_init():
        m_triangles.clear()
        m_points.clear()
        if !(m_rect.has_area()):
            set_rect(calc_rect(m_points))

        m_triangles.append(m_rect_super_triangle1)
        m_triangles.append(m_rect_super_triangle2)

    func triangulate_debug_1_find_bad_triangles_from_point(point:Point2) -> Array:
        m_bad_triangles.clear()
        m_polygon.clear()
        m_points.append(point)
        _find_bad_triangles(point, m_triangles, m_bad_triangles)
        return m_bad_triangles

    func triangulate_debug_2_make_outer_polygon() -> Array:
        for bad_tirangle in m_bad_triangles:
            m_triangles.erase(bad_tirangle)

        _make_outer_polygon(m_bad_triangles, m_polygon)
        return m_polygon

    func triangulate_debug_3_finalize_triangle(point:Point2) -> Array:
        for edge in m_polygon:
            var triangle = Triangle.new(point, edge.a, edge.b)
            m_triangles.append(triangle)
        return m_triangles

    ##############################################################################
    # Private Functions
    ##############################################################################
    func _find_bad_triangles(point: Point2, triangles: Array, out_bad_triangles: Array) -> void:

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
