extends SceneTree
func _initialize():call_deferred("run")
func run():
 var scene=load("res://Main.tscn").instantiate();scene.enable_save=false;scene.enable_sound=false;root.add_child(scene)
 await create_timer(1).timeout
 scene.trust=80;scene._open_stories()
 await create_timer(0.3).timeout
 var library=scene.story_reader
 assert(library.catalog.get_child_count()==6)
 var paths:Array[String]=[]
 for ident in library.GAME_IDS:
  var path:String=library.prepare_html(ident)
  assert(not path.is_empty() and path not in paths);paths.append(path)
  assert(FileAccess.get_file_as_bytes(path)==FileAccess.get_file_as_bytes("res://stories/html/"+ident+"/index.html"))
 assert(library.prepare_html("../escape").is_empty())
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://previews/StoryLibrary.png")
 library.open_native();library.reader.network_enabled=false;library.show_chapter(3)
 assert(library.reader.chapter==3 and scene.lesson_index==3)
 library.show_library();assert(library.catalog_scroll.visible and not library.reader.visible)
 scene._set_study_mode(false);scene._open_stories();assert(library.catalog_scroll.visible)
 scene.localization.set_language("en");assert(TranslationServer.translate("library_title")=="Stories · Mission library")
 scene.localization.set_language("es")
 root.size=Vector2i(540,960);await create_timer(0.5).timeout
 library.catalog_scroll.scroll_vertical=1000
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://previews/StoryLibraryPortrait.png")
 print("PASS LIBRARY: five separate entries; four exact HTML copies in isolated folders; path validation; native reader navigation; back/reopen; English/Spanish; portrait scroll.")
 scene.queue_free();await create_timer(0.3).timeout;quit()
