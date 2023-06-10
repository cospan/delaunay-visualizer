extends Node2D

class_name DelaunayTriangleDrawer

var m_triangles = []
var m_image:Image

class Triangle:
    var points:PackedVector2Array
    var color:Color

    func _init(array_draw_data: Array):
        points = Geometry2D.convex_hull(PackedVector2Array(array_draw_data[0]))
        color = array_draw_data[1]

# Called when the node enters the scene tree for the first time.
func _init(s:Vector2i):
    m_image = Image.create(s.x, s.y, false, Image.FORMAT_RGBA8)

func _ready():
    m_triangles.clear()

func add_triangle(array_draw_data):
    var triangle = Triangle.new(array_draw_data)
    m_triangles.append(triangle)

func is_ready():
    return m_triangles.size() == 0

func update():
    queue_redraw()

func _draw():
    draw_line(Vector2(0, 0), Vector2(0, 100), Color(1, 0, 0), 1)
    for triangle in m_triangles:
        print ("Triangle Points: %s" % str(triangle.points))
        draw_colored_polygon(triangle.points, triangle.color)
    m_image = get_parent().get_texture().get_image()
    m_triangles.clear()
    m_image.save_png("debug_texture_error.png")
    print ("Redraw!")

func get_triangle_index(pos: Vector2):
    print ("Position: %s" % str(pos))
    print ("Color: %s" % str(m_image.get_pixel(floori(pos.x), floori(pos.y)).to_rgba32() >> 8))
    return (m_image.get_pixel(floori(pos.x), floori(pos.y)).to_rgba32() >> 8) & 0xFFFFFF
