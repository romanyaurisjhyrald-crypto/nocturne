extends SceneTree
var scene
var checks:int=0
func _initialize() -> void:call_deferred("run_tests")
func check(value:bool,message:String) -> void:
    if not value:
        push_error("FAIL: "+message)
        quit(1)
        assert(value,message)
    checks+=1
func click(point:Vector2) -> void:
    var motion:=InputEventMouseMotion.new();motion.position=point
    root.push_input(motion,true)
    await process_frame
    var press:=InputEventMouseButton.new();press.position=point;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
    root.push_input(press,true)
    await process_frame
    var release:=InputEventMouseButton.new();release.position=point;release.button_index=MOUSE_BUTTON_LEFT
    root.push_input(release,true)
    await process_frame
func touch(point:Vector2,index:int,pressed:bool,canceled:bool=false) -> void:
    var event:=InputEventScreenTouch.new();event.position=point;event.index=index;event.pressed=pressed;event.canceled=canceled
    root.push_input(event,true)
func run_tests() -> void:
    scene=load("res://Main.tscn").instantiate()
    scene.enable_save=false;scene.enable_sound=false
    root.add_child(scene)
    await create_timer(1.0).timeout
    var field=scene.playfield
    check(field.bounds.size.distance_to(scene.size-Vector2(4,4))<1.0,"Full-window collision bounds")
    check(scene.character.rig.ear_skeleton.get_bone_count()==17,"Mouse skeleton loaded")
    check(scene.character.rig.crystal_surfaces.size()==15,"Crystal mouse, not old character")
    scene._advance_dialogue()
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://Preview.png")
    # Verify transparent padding on every edge of the moving render tile.
    var tile:Image=scene.get_node("Stage/View").get_texture().get_image()
    var opaque_edges:int=0
    for x in tile.get_width():
        if tile.get_pixel(x,0).a>0.02 or tile.get_pixel(x,tile.get_height()-1).a>0.02:opaque_edges+=1
    for y in tile.get_height():
        if tile.get_pixel(0,y).a>0.02 or tile.get_pixel(tile.get_width()-1,y).a>0.02:opaque_edges+=1
    check(opaque_edges==0,"Ears and tail do not clip inside the render tile")
    # Real mouse events: GUI gets first refusal when the mouse overlaps a button.
    var pet:Button=scene.get_node("Interface/Commands/Pet")
    field.state="flying";field.flight_remaining=5;field.actor.freeze=true
    field.actor.position=pet.get_global_rect().get_center()
    await process_frame
    var trust_before:float=scene.trust
    scene.cooldown=0
    await click(pet.get_global_rect().get_center())
    check(scene.trust>trust_before and field.pointer_id==-2,"Overlapped Pet button remains usable")
    field.actor.position=field.home;field.state="idle"
    await physics_frame
    touch(field.home,0,true)
    check(field.pointer_id==0,"Primary touch capture")
    touch(field.home,1,true)
    check(field.pointer_id==0,"Second finger cannot steal capture")
    var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=Vector2(scene.size.x-100,180)
    root.push_input(drag,true)
    check(field.drag_target.x>field.home.x,"Captured touch can leave the former playfield")
    touch(drag.position,0,false,true)
    check(field.state=="returning" and field.pointer_id==-2,"Canceled touch returns safely")
    await create_timer(1.0).timeout
    check(field.state=="idle" and field.actor.position.distance_to(field.home)<1,"Smooth automatic return")
    var press:=InputEventMouseButton.new();press.position=field.home;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
    root.push_input(press,true)
    check(field.pointer_id==-1,"Mouse press captures the character")
    var motion:=InputEventMouseMotion.new();motion.position=pet.get_global_rect().get_center();motion.button_mask=MOUSE_BUTTON_MASK_LEFT
    root.push_input(motion,true)
    check(field.pointer_id==-1 and field.state=="held","Mouse drag stays captured over buttons")
    var release:=InputEventMouseButton.new();release.position=motion.position;release.button_index=MOUSE_BUTTON_LEFT
    root.push_input(release,true)
    check(field.pointer_id==-2,"Mouse release ends capture")
    field.start_return();await create_timer(1.0).timeout
    # Use real physics, not a position tween, to collide with the viewport walls.
    field.actor.position=Vector2(scene.size.x-field.radius-15,field.home.y)
    field.reset_streak()
    field.launch(Vector2(1400,-200))
    await create_timer(0.32).timeout
    check(field.impact_count>0,"RigidBody wall collision")
    check(field.actor.linear_velocity.x<0,"Collision reverses horizontal velocity")
    check(field.actor.position.x>scene.size.x*0.5,"Flight outside old render box")
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://Flight.png")
    field.start_return();await create_timer(1.0).timeout
    # Talking and teaching start locked until trust is earned.
    scene.trust=10;await process_frame
    check(scene.commands.get_node("Converse").disabled and scene.commands.get_node("Stories").disabled,"Talk and teaching locked at low trust")
    scene.trust=70;await process_frame
    check(not scene.commands.get_node("Converse").disabled and not scene.commands.get_node("Stories").disabled,"Talk and teaching unlock with trust")
    # Every command emits through its actual button connection.
    for name in ["Converse","Feed","Observe"]:
        scene.cooldown=0
        var old_trust:float=scene.trust
        await click(scene.get_node("Interface/Commands/"+name).get_global_rect().get_center())
        check(scene.trust>old_trust,"Action button "+name)
    await click(scene.get_node("Interface/Commands/Stories").get_global_rect().get_center())
    check(scene.study_mode and scene.study_board.visible and scene.lesson_title.text==TranslationServer.translate("lesson_1_title"),"Stories opens the NASA lesson chalkboard")
    check(not scene.commands.visible and not scene.dialogue.visible and scene.study_ruler.visible,"Study screen hides commands and dialogue")
    await create_timer(1.2).timeout
    check(field.home.x>scene.study_board.get_global_rect().end.x,"Character rests beside the chalkboard")
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://Study.png")
    await click(scene.study_back.get_global_rect().get_center())
    check(not scene.study_mode and scene.commands.visible and scene.dialogue.visible and not scene.study_board.visible,"Back button restores the care screen")
    await create_timer(1.2).timeout
    await click(scene.get_node("Interface/Utility/Settings").get_global_rect().get_center())
    check(is_instance_valid(scene.modal) and scene.modal.find_child("BodyColorPicker",true,false)!=null,"Settings controls connected")
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://Settings.png")
    scene._change_language("en")
    check(scene.localization.locale=="en" and scene.get_node("Interface/Commands/Pet").text=="command_pet","English translation preserves keys")
    check(TranslationServer.translate("command_pet")=="Pet","English catalog active")
    scene._change_language("es")
    check(TranslationServer.translate("command_pet")=="Acariciar","Spanish remains selectable")
    scene._close_modal();await process_frame;await process_frame
    var selected:=Color("73bfa2")
    scene._change_body_color(selected)
    field.reset_streak()
    for i in 3:field.launch(Vector2(250,-100))
    check(scene.anger_remaining>0 and scene.character.emotion=="angry","Three throws trigger anger")
    scene.anger_remaining=0.01
    await create_timer(1.0).timeout
    check(scene._get_body_color().is_equal_approx(selected),"Selected color restored after anger")
    # Existing save sections and dialogue order survive a read/write round trip.
    scene.save_path="user://mouse_validation.cfg"
    scene.enable_save=true
    scene.dialogue_bags={"talk":[2,1]};scene.total_throws=17
    scene._save_state()
    scene.trust=0;scene.total_throws=0;scene.dialogue_bags={}
    scene._load_state()
    check(scene.trust>0 and scene.total_throws==17 and scene.dialogue_bags.talk==[2,1],"Legacy save fields and dialogue order round trip")
    var cfg:=ConfigFile.new();cfg.load(scene.save_path)
    check(cfg.has_section("slime") and cfg.get_value("look","base_color").is_equal_approx(selected),"Save schema and selected color retained")
    scene.enable_save=false
    scene.background_storage_path="user://mouse_validation_background.png"
    var input_path: String="user://mouse_validation_input.png"
    (load("res://assets/laboratory.png") as Texture2D).get_image().save_png(input_path)
    check(scene._load_background(input_path),"Local background image loader")
    check(scene.custom_background_enabled and scene.background.material==null,"Custom background mode")
    scene._restore_custom_background()
    check(scene.background.texture!=null,"Saved background reload")
    scene._reset_background()
    check(not scene.custom_background_enabled and scene.background.material!=null,"Original star background restored")
    check(not scene.has_node("Interface/Utility/Journal"),"Journal removed")
    # Judges' demo: abandonment greys him out and makes him cry; time brings colour and glow back.
    await click(scene.get_node("Interface/Utility/Demo").get_global_rect().get_center())
    check(is_instance_valid(scene.demo_panel) and scene.demo_panel.visible,"Demo panel opens")
    await process_frame
    await click(scene.demo_panel.find_child("Abandon",true,false).get_global_rect().get_center())
    await create_timer(0.6).timeout
    check(scene.abandoned and scene.trust<5 and scene.abandonment>0.9 and scene._is_crying() and scene.character.emotion=="sad","Abandonment is grey, sad and crying")
    check(scene.commands.get_node("Converse").disabled,"Abandonment locks talking again")
    await create_timer(1.0).timeout
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://Abandoned.png")
    scene.perform_action("talk")
    var advance_button:Button=scene.demo_panel.find_child("Advance",true,false)
    for i in 6:await click(advance_button.get_global_rect().get_center())
    await create_timer(3.0).timeout
    check(scene.trust>=90 and not scene._is_crying() and scene.abandonment<0.05 and scene.radiance>0.9,"Advancing time restores colour and makes him glow")
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://Radiant.png")
    scene.cooldown=0;scene.perform_action("talk")
    check(scene.last_dialogue_id.begins_with("memory_"),"Talking after abandonment shares astronaut memories")
    await click(scene.demo_tears_button.get_global_rect().get_center())
    check(scene._is_crying(),"Tears can be forced on")
    await click(scene.demo_tears_button.get_global_rect().get_center())
    check(not scene._is_crying(),"Tears can be forced off")
    var key:=InputEventKey.new();key.keycode=KEY_X;key.pressed=true
    root.push_input(key,true)
    await process_frame
    check(scene.character.emotion=="sad" and scene.gaze_hold>0 and scene.current_dialogue_key=="close_key_dialogue_1","X key gets a sad reaction")
    scene.tears_forced=-1;scene.tear_burst=0;scene.abandoned=false
    scene._toggle_demo_panel()
    var before_sound:bool=scene.enable_sound
    await click(scene.sound_button.get_global_rect().get_center())
    check(scene.enable_sound!=before_sound,"Sound toggle connected")
    # Resize/orientation safely cancels an active hold and rebuilds the walls.
    field.start_return();await create_timer(1.0).timeout
    field.begin_hold(field.home,-1)
    root.size=Vector2i(540,960)
    await create_timer(1.0).timeout
    check(field.pointer_id==-2,"Resize releases stale pointer ownership")
    check(field.bounds.size.distance_to(scene.size-Vector2(4,4))<1,"Portrait boundary rebuild")
    check(scene.size.x<scene.size.y,"Portrait canvas adapts its logical resolution")
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://Portrait.png")
    root.size=Vector2i(1280,800)
    await create_timer(0.5).timeout
    field.begin_hold(field.actor.position,-1)
    scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    check(field.pointer_id==-2,"Focus loss releases capture")
    check(scene.localization.catalogs.en.keys().size()==scene.localization.catalogs.es.keys().size(),"Catalog parity")
    print("PASS ",checks," integration checks: collisions, render padding, input, UI, moods, localization, save compatibility, resize and recovery.")
    scene.queue_free()
    await process_frame
    await process_frame
    quit()
