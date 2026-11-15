extends VBoxContainer
## Native reader adapted from the supplied HTML; the original remains available.
signal chapter_changed(index:int)
var chapter:int=0
var heading:Label
var narrative:Label
var scroll:ScrollContainer
var photo:TextureRect
var status:Label
var selector:OptionButton
var request:HTTPRequest
var generation:int=0
var metadata:Array=[]
var cache:Dictionary={}
var network_enabled:bool=true
func _ready() -> void:
    add_theme_constant_override("separation",10)
    metadata=JSON.parse_string(FileAccess.get_file_as_string("res://stories/chapters.json"))
    var series:=Label.new();series.text="space_title";series.add_theme_color_override("font_color",Color("60e3cf"));add_child(series)
    selector=OptionButton.new();selector.custom_minimum_size.y=40;add_child(selector)
    selector.item_selected.connect(show_chapter)
    scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;add_child(scroll)
    var content:=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",12);scroll.add_child(content)
    heading=Label.new();heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;heading.add_theme_font_size_override("font_size",27);heading.add_theme_color_override("font_color",Color("f2c66d"));content.add_child(heading)
    photo=TextureRect.new();photo.custom_minimum_size.y=200;photo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;photo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;content.add_child(photo)
    status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.add_theme_font_size_override("font_size",13);content.add_child(status)
    narrative=Label.new();narrative.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;narrative.add_theme_font_size_override("font_size",20);content.add_child(narrative)
    var credit:=Label.new();credit.text="space_credit";credit.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;credit.add_theme_font_size_override("font_size",12);content.add_child(credit)
    var row:=HBoxContainer.new();add_child(row)
    button(row,"space_previous",func():show_chapter((chapter+7)%8))
    button(row,"space_next",func():show_chapter((chapter+1)%8))
    button(row,"space_read",read_aloud)
    button(row,"space_stop",stop_audio)
    var original:=Button.new();original.text="space_browser";original.custom_minimum_size.y=34;original.pressed.connect(open_original);add_child(original)
    show_chapter(0)
func button(row:Control,key:String,callback:Callable) -> void:
    var b:=Button.new();b.text=key;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.custom_minimum_size.y=40;b.pressed.connect(callback);row.add_child(b)
func show_chapter(value:int) -> void:
    if heading==null:return
    stop_audio();generation+=1
    if is_instance_valid(request):request.cancel_request();request.queue_free()
    chapter=clampi(value,0,7)
    selector.clear()
    for i in 8:selector.add_item("%02d · %s" % [i+1,tr("space_chapter_%d_title"%i)])
    selector.select(chapter)
    heading.text=tr("space_chapter_%d_title"%chapter)
    narrative.text=tr("space_chapter_%d_body"%chapter)
    scroll.set_deferred("scroll_vertical",0)
    photo.texture=null;status.text=tr("space_loading")
    chapter_changed.emit(chapter)
    if cache.has(chapter):
        photo.texture=cache[chapter].texture;status.text=cache[chapter].credit;return
    if not network_enabled:status.text=tr("space_offline");return
    fetch("https://images-api.nasa.gov/search?q="+str(metadata[chapter].query).uri_encode()+"&media_type=image&page_size=12",false,generation,"")
func fetch(url:String,is_image:bool,ticket:int,credit:String) -> void:
    if not url.begins_with("https://"):status.text=tr("space_offline");return
    request=HTTPRequest.new();request.timeout=15;request.body_size_limit=12000000;add_child(request)
    request.request_completed.connect(received.bind(is_image,ticket,credit,request))
    if request.request(url)!=OK:status.text=tr("space_offline");request.queue_free()
func received(result:int,code:int,_headers:PackedStringArray,body:PackedByteArray,is_image:bool,ticket:int,credit:String,source:HTTPRequest) -> void:
    source.queue_free()
    if ticket!=generation:return
    if result!=HTTPRequest.RESULT_SUCCESS or code!=200:status.text=tr("space_offline");return
    if is_image:
        var image:=Image.new()
        var error:=image.load_jpg_from_buffer(body)
        if error!=OK:error=image.load_png_from_buffer(body)
        if error!=OK:error=image.load_webp_from_buffer(body)
        if error!=OK:status.text=tr("space_offline");return
        photo.texture=ImageTexture.create_from_image(image);status.text=credit
        cache[chapter]={"texture":photo.texture,"credit":credit};return
    var parsed:Variant=JSON.parse_string(body.get_string_from_utf8())
    if parsed is Dictionary:
        for item in parsed.get("collection",{}).get("items",[]):
            for link in item.get("links",[]):
                if link.get("render","")=="image":
                    var data:Array=item.get("data",[])
                    var title:String=str(data[0].get("title","")) if not data.is_empty() else ""
                    fetch(str(link.href),true,ticket,"NASA · "+title);return
    status.text=tr("space_offline")
func read_aloud() -> void:
    var voices:=DisplayServer.tts_get_voices_for_language(TranslationServer.get_locale().substr(0,2))
    if voices.is_empty():status.text=tr("space_voice_missing");return
    DisplayServer.tts_speak(heading.text+". "+narrative.text,voices[0],70,1.0,0.92,0,true)
func stop_audio() -> void:
    DisplayServer.tts_stop()
func open_original() -> void:
    stop_audio()
    var destination: String="user://space_guardians.html"
    var file:=FileAccess.open(destination,FileAccess.WRITE)
    if file==null:status.text=tr("space_browser_error");return
    file.store_buffer(FileAccess.get_file_as_bytes("res://stories/space_guardians.html"));file.close()
    if OS.shell_open(ProjectSettings.globalize_path(destination))!=OK:status.text=tr("space_browser_error")
func _exit_tree() -> void:
    stop_audio()
    if is_instance_valid(request):request.cancel_request()
