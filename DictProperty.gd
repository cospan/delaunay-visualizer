extends GridContainer

class_name  DictProperty

signal property_changed(property_name, property_value)

var m_widget_dict = {}

func _init(property_dict = null):
    if property_dict != null:
        update_dict(property_dict)

func update_dict(property_dict = {}):
    for key in property_dict:
        if key in m_widget_dict:
            m_widget_dict[key]["label"].queue_free()
            m_widget_dict[key]["widget"].queue_free()
            m_widget_dict.erase(key)

    for key in property_dict:
        var label = Label.new()
        label.text = property_dict[key]["name"]
        add_child(label)
        match property_dict[key]["type"]:
            "Button":
                #print ("Button")
                label.text = ""
                var prop = Button.new()
                prop.text = property_dict[key]["name"]
                add_child(prop)
                m_widget_dict[key] = {"type": property_dict[key]["type"], "label": label, "widget": prop}
                prop.connect("pressed", func() : _property_update(key, true))
            "CheckBox":
                #print ("BOOL")
                var prop = CheckBox.new()
                prop.button_pressed = property_dict[key]["value"]
                add_child(prop)
                m_widget_dict[key] = {"type": property_dict[key]["type"], "label": label, "widget": prop}
                prop.connect("pressed", func() : _property_update(key, prop.button_pressed))
            "OptionButton":
                #print ("OPTION")
                var prop = OptionButton.new()
                for option in property_dict[key]["options"]:
                    prop.add_item(option)
                prop.selected = property_dict[key]["value"]
                add_child(prop)
                m_widget_dict[key] = {"type": property_dict[key]["type"], "label": label, "widget": prop}
                prop.connect("item_selected", func(_val) : _property_update(key, _val))
            "SpinBox":
                #print("FLOAT")
                var prop = SpinBox.new()
                prop.min_value = property_dict[key]["min"]
                prop.max_value = property_dict[key]["max"]
                prop.value = property_dict[key]["value"]
                if "step" in property_dict[key]:
                    prop.step = property_dict[key]["step"]
                else:
                    prop.step = 1.0
                if "readonly" in property_dict[key]:
                    prop.editable = !property_dict[key]["readonly"]
                add_child(prop)
                m_widget_dict[key] = {"type": property_dict[key]["type"], "label": label, "widget": prop}
                prop.connect("value_changed", func(_val) : _property_update(key, _val))
            "HSlider":
                #print("FLOAT")
                var prop = HSlider.new()
                prop.min_value = property_dict[key]["min"]
                prop.max_value = property_dict[key]["max"]
                prop.value = property_dict[key]["value"]
                if "step" in property_dict[key]:
                    prop.step = property_dict[key]["step"]
                else:
                    prop.step = 1.0
                add_child(prop)
                m_widget_dict[key] = {"type": property_dict[key]["type"], "label": label, "widget": prop}
                prop.connect("value_changed", func(_val) : _property_update(key, _val))
            "LineEdit":
                #print("STRING")
                var prop = LineEdit.new()
                prop.text = property_dict[key]["value"]
                if "readonly" in property_dict[key]:
                    prop.editable = !property_dict[key]["readonly"]

                add_child(prop)
                m_widget_dict[key] = {"type": property_dict[key]["type"], "label": label, "widget": prop}
                prop.connect("text_submitted", func(_val) : _property_update(key, _val))

# Called when the node enters the scene tree for the first time.
func _ready():
    columns = 2

func set_label(n, text):
    m_widget_dict[n]["label"].text = text

func set_value(n, value):
    match(m_widget_dict[n]["type"]):
        "CheckBox":
            m_widget_dict[n]["widget"].button_pressed = value
        "SpinBox":
            var v:SpinBox = m_widget_dict[n]["widget"]
            v.value = value
        "LineEdit":
            m_widget_dict[n]["widget"].text = value
        "HSlider":
            m_widget_dict[n]["widget"].value = value
        "Button":
            m_widget_dict[n]["widget"].text = value
        "OptionButton":
            m_widget_dict[n]["widget"].selected = value

func _property_update(property_name, property_value):
    property_changed.emit(property_name, property_value)
