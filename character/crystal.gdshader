shader_type spatial;
uniform vec4 mood_color : source_color = vec4(0.08,0.85,0.95,1.0);
uniform float glow_strength : hint_range(0.0,4.0) = 0.75;
varying vec3 local_position;
void vertex(){ local_position=VERTEX; }
void fragment(){
 float gradient=0.5+0.5*sin(local_position.y*5.5+local_position.x*1.4);
 vec3 tint=mix(mood_color.rgb*0.38,mix(mood_color.rgb,vec3(0.85,1.0,0.97),0.38),gradient);
 ALBEDO=tint; ROUGHNESS=0.10; METALLIC=0.18; SPECULAR=0.8;
 CLEARCOAT=0.9; CLEARCOAT_ROUGHNESS=0.05;
 EMISSION=tint*glow_strength;
}
