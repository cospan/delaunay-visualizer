extends TextureRect

class_name DelaunayTextureRect

var m_delaunay:AzgaarDelaunay.Delaunay
var m_image:Image
#@onready var m_sub_viewport:SubViewport = $SubViewportContainer/SubViewport
var m_sub_viewport:SubViewport
var m_sub_viewport_container:SubViewportContainer
var m_viewport_texture:ViewportTexture

# Called when the node enters the scene tree for the first time.
func _ready():
    #m_sub_viewport = $SubViewportContainer/SubViewport
    #m_sub_viewport.size = get_viewport_rect().size
    pass

func save_image(_path):
    if m_sub_viewport == null:
        return
    if m_sub_viewport.get_child_count() > 0:
        for child in m_sub_viewport.get_children():
            child.queue_free()

    var points = PackedVector2Array()
    var colour = Color.hex(0x000000FE)
    var r = Rect2(Vector2(), m_sub_viewport.size)
    points = [Vector2(0, 0), Vector2(0, r.end.y), Vector2(r.end.x, r.end.y), Vector2(r.end.x, 0)]
    var p = Polygon2D.new()
    p.polygon = points
    p.color = colour
    m_sub_viewport.add_child(p)

    for i in range(len(m_delaunay.m_triangles)):
        var triangle = m_delaunay.m_triangles[i]
        if m_delaunay.is_border_triangle(triangle):
            continue
        points = [triangle.a.v, triangle.b.v, triangle.c.v]
        colour = [Color.hex(0x000000FF | (i << 8))]
        p = Polygon2D.new()
        p.polygon = points
        p.color = Color.hex(0x000000FF | (i << 8))
        m_sub_viewport.add_child(p)

    #m_image = get_viewport().get_texture().get_image()
    m_image = m_sub_viewport.get_texture().get_image()
    #m_image = get_texture().get_image()
    await RenderingServer.frame_post_draw
    m_image.save_png(_path)

func initialize(delaunay:AzgaarDelaunay.Delaunay, image_size:Vector2i):
    m_delaunay = delaunay
    m_image = Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
    m_image.fill(Color.hex(0x000000FE))
    texture = ImageTexture.create_from_image(m_image)

    # Sub Viewport Container
    m_sub_viewport_container = SubViewportContainer.new()
    add_child(m_sub_viewport_container)

    # Sub Viewport
    m_sub_viewport = SubViewport.new()
    m_sub_viewport.size = image_size
    m_sub_viewport.disable_3d = true
    m_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    m_sub_viewport.size = image_size
    m_sub_viewport_container.add_child(m_sub_viewport)


func triangles_updated():
    if m_sub_viewport == null:
        return
    if m_sub_viewport.get_child_count() > 0:
        for child in m_sub_viewport.get_children():
            child.queue_free()

    var points = PackedVector2Array()
    var colour = Color.hex(0x000000FE)
    var r = Rect2(Vector2(), m_sub_viewport.size)
    points = [Vector2(0, 0), Vector2(0, r.end.y), Vector2(r.end.x, r.end.y), Vector2(r.end.x, 0)]
    var p = Polygon2D.new()
    p.polygon = points
    p.color = colour
    m_sub_viewport.add_child(p)

    for i in range(len(m_delaunay.m_triangles)):
        var triangle = m_delaunay.m_triangles[i]
        if m_delaunay.is_border_triangle(triangle):
            continue
        points = [triangle.a.v, triangle.b.v, triangle.c.v]
        colour = [Color.hex(0x000000FF | (i << 8))]
        p = Polygon2D.new()
        p.polygon = points
        p.color = Color.hex(0x000000FF | (i << 8))
        m_sub_viewport.add_child(p)
    #    draw_polygon(points, colour, PackedVector2Array(), texture)
    #    #texture.draw(points.get_id(), Vector2(0, 0), colour, false)
    queue_redraw()

func get_index_from_color(_colour):
    return (_colour >> 8) & 0xFFFFFF

func redraw(_value):
    queue_redraw()

func _draw():
    var points = PackedVector2Array()
    var colour = PackedColorArray()
    #var r = get_viewport_rect()
    #points = [Vector2(0, 0), Vector2(0, r.end.y), Vector2(r.end.x, r.end.y), Vector2(r.end.x, 0)]
    #colour = [Color.hex(0x000000FE)]
    #draw_polygon(points, colour)
    for i in range(len(m_delaunay.m_triangles)):
        var triangle = m_delaunay.m_triangles[i]
        if m_delaunay.is_border_triangle(triangle):
            continue
        points = PackedVector2Array()
        colour = PackedColorArray()
        points = [triangle.a.v, triangle.b.v, triangle.c.v]
        colour = [Color.hex(0x000000FF | (i << 8))]
        #draw_polygon(points, colour, PackedVector2Array(), texture)
        draw_polygon(points, colour)
