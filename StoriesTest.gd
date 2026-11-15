extends SceneTree
func _initialize():call_deferred("run")
func run():
 var scene=load("res://Main.tscn").instantiate()
 scene.enable_save=false;scene.enable_sound=false
 root.add_child(scene)
 await create_timer(1).timeout
 scene.trust=80
 scene._open_stories()
 await create_timer(12).timeout
 scene.story_reader.open_native()
 var reader=scene.story_reader.reader
 assert(reader.selector.item_count==8)
 assert(reader.narrative.text.length()>300)
 print("LIVE IMAGE: ",reader.photo.texture!=null," STATUS: ",reader.status.text)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://previews/SpaceGuardians.png")
 reader.network_enabled=false
 for i in 8:
  reader.show_chapter(i)
  assert(scene.lesson_index==i and reader.narrative.text.length()>300)
 scene.localization.set_language("en");scene._show_lesson()
 assert(reader.heading.text=="Never forgotten")
 scene.localization.set_language("es");scene._show_lesson()
 assert(reader.heading.text=="Nunca olvidados")
 reader.show_chapter(0)
 scene._next_lesson();assert(reader.chapter==1)
 scene._set_study_mode(false);assert(not scene.study_board.visible)
 scene._open_stories();assert(scene.study_board.visible and reader.chapter==1)
 root.size=Vector2i(540,960)
 await create_timer(0.5).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://previews/SpaceGuardiansPortrait.png")
 print("PASS STORIES: eight chapters, both languages, chapter sync, next, close/reopen, offline text, portrait.")
 scene.queue_free();await create_timer(0.3).timeout;quit()
