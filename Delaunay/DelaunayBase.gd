extends Node2D
class_name DelaunayBase


##############################################################################
# Classes
##############################################################################

class Point2:
    var data
    var edges = []
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

    func remove(edge: Edge) -> void:
        edges.erase(edge)

    func find_edge(point: Point2) -> Edge:
        for edge in edges:
            if edge.has(point):
                return edge
        return null

    func _to_string():
        return "Point2: " + str(v)

    func _eq(other):
        return v == other.v


class Edge:
    var a: Point2
    var b: Point2

    var triangles = []

    func _init(new_a: Point2, new_b: Point2):
        self.a = new_a
        self.a.edges.append(self)
        self.b = new_b
        self.b.edges.append(self)

    func equals(edge: Edge) -> bool:
        return (a == edge.a && b == edge.b) || (a == edge.b && b == edge.a)

    func length() -> float:
        return a.distance_to(b)

    func center() -> Vector2:
        return (a.v + b.v) * 0.5

    func has(point: Point2) -> bool:
        return a == point || b == point

    func remove() -> void:
        a.remove(self)
        b.remove(self)

class Triangle:
    var a: Point2
    var b: Point2
    var c: Point2

    var edge_ab: Edge
    var edge_bc: Edge
    var edge_ca: Edge

    var center: Vector2
    var radius_sqr: float
    var key: int

    func _init(_key: int, new_a: Point2, new_b: Point2, new_c: Point2):
        self.key = _key
        self.a = new_a
        self.b = new_b
        self.c = new_c

        #Check if the edges already exist
        if a.edges.has(b.edges):
            edge_ab = a.edges.find_edge(b.edges)
        else:
            edge_ab = Edge.new(a,b)
        edge_ab.triangles.append(self)

        if b.edges.has(c.edges):
            edge_bc = b.edges.find_edge(c.edges)
        else:
            edge_bc = Edge.new(b,c)
        edge_bc.triangles.append(self)

        if c.edges.has(a.edges):
            edge_ca = c.edges.find_edge(a.edges)
        else:
            edge_ca = Edge.new(c,a)
        edge_ca.triangles.append(self)

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

    func remove() -> void:
        edge_ab.triangles.erase(self)
        edge_bc.triangles.erase(self)
        edge_ca.triangles.erase(self)

        if edge_ab.triangles.size() == 0:
            edge_ab.remove()
        if edge_bc.triangles.size() == 0:
            edge_bc.remove()
        if edge_ca.triangles.size() == 0:
            edge_ca.remove()

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

    func get_draw_data() -> Array:
        return [[a.v, b.v, b.v], Color.hex(0x000000FF | key << 8)]

    func _to_string():
        return "Triangle: " + str(key) + " " + str(a.v) + " " + str(b.v) + " " + str(c.v)


##############################################################################
# Public Functions
##############################################################################

