extends VBoxContainer
## Catalog of isolated HTML games plus the native Space Guardians reader.
signal chapter_changed(index:int)
const GAME_IDS:Array[String]=["small_discoveries","voyager_one","oppy","silent_mirror"]
var heading:Label
var narrative:Label
var catalog:VBoxContainer
var catalog_scroll:ScrollContainer
var status:Label
var reader
var back:Button
var chapter:int=0
func _ready() -> void:
    add_theme_constant_override("separation",10)
    heading=Label.new();heading.text="library_title";heading.add_theme_font_size_override("font_size",26);heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(heading)
    narrative=Label.new();narrative.text="library_hint";narrative.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;narrative.add_theme_font_size_override("font_size",15);add_child(narrative)
    catalog_scroll=ScrollContainer.new();catalog_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;add_child(catalog_scroll)
    catalog=VBoxContainer.new();catalog.size_flags_horizontal=Control.SIZE_EXPAND_FILL;catalog.add_theme_constant_override("separation",14);catalog_scroll.add_child(catalog)
    card("space_title","library_guardians_description","library_native",open_native,Color("60e3cf"))
    var colors:Array[Color]=[Color("ffd085"),Color("bda5ff"),Color("ff967d"),Color("91ccff")]
    for i in GAME_IDS.size():
        var ident:String=GAME_IDS[i]
        card("library_"+ident+"_title","library_"+ident+"_description","library_web",open_web.bind(ident),colors[i])
    var note:=Label.new();note.text="library_browser_note";note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.add_theme_font_size_override("font_size",13);catalog.add_child(note)
    status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.add_theme_font_size_override("font_size",14);add_child(status)
    back=Button.new();back.text="library_back";back.custom_minimum_size.y=40;back.pressed.connect(show_library);add_child(back);back.hide()
func card(title_key:String,description_key:String,action_key:String,callback:Callable,accent:Color) -> void:
    var panel:=PanelContainer.new();catalog.add_child(panel)
    var style:=StyleBoxFlat.new();style.bg_color=Color("15213a");style.border_color=accent;style.border_width_left=4;style.content_margin_left=16;style.content_margin_right=16;style.content_margin_top=13;style.content_margin_bottom=13;panel.add_theme_stylebox_override("panel",style)
    var column:=VBoxContainer.new();column.add_theme_constant_override("separation",8);panel.add_child(column)
    var title:=Label.new();title.text=title_key;title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.add_theme_color_override("font_color",accent);title.add_theme_font_size_override("font_size",21);column.add_child(title)
    var description:=Label.new();description.text=description_key;description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description.add_theme_font_size_override("font_size",16);column.add_child(description)
    var button:=Button.new();button.text=action_key;button.custom_minimum_size.y=38;button.pressed.connect(callback);column.add_child(button)
func open_native() -> void:
    if not is_instance_valid(reader):
        reader=preload("res://stories/SpaceStory.gd").new();reader.size_flags_vertical=Control.SIZE_EXPAND_FILL;add_child(reader);move_child(reader,get_child_count()-2)
        reader.chapter_changed.connect(func(value:int):chapter=value;chapter_changed.emit(value))
    catalog_scroll.hide();narrative.hide();status.hide();heading.hide();back.show();reader.show();reader.show_chapter(chapter)
func show_library() -> void:
    stop_audio()
    if is_instance_valid(reader):reader.hide()
    catalog_scroll.show();narrative.show();status.show();heading.show();back.hide()
func show_chapter(value:int) -> void:
    chapter=value
    if is_instance_valid(reader) and reader.visible:reader.show_chapter(value)
func stop_audio() -> void:
    if is_instance_valid(reader):reader.stop_audio()
func prepare_html(ident:String) -> String:
    if ident not in GAME_IDS:return ""
    var directory:String="user://story_games/"+ident
    if DirAccess.make_dir_recursive_absolute(directory)!=OK:return ""
    var bytes:=FileAccess.get_file_as_bytes("res://stories/html/"+ident+"/index.html")
    if bytes.is_empty():return ""
    var target:String=directory+"/index.html"
    var file:=FileAccess.open(target,FileAccess.WRITE)
    if file==null:return ""
    file.store_buffer(bytes);file.close()
    return ProjectSettings.globalize_path(target)
func open_web(ident:String) -> void:
    stop_audio()
    var target:=prepare_html(ident)
    status.text="library_error" if target.is_empty() or OS.shell_open(target)!=OK else "library_opened"
func _exit_tree() -> void:
    stop_audio()
