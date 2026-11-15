shader_type spatial;
render_mode blend_mix, cull_disabled;
void fragment(){
 float stripe=1.0-smoothstep(0.055,0.11,abs(UV.x+UV.y*0.38-0.38-VIEW.x*0.12));
 float thin=1.0-smoothstep(0.01,0.025,abs(UV.x+UV.y*0.38-0.53-VIEW.x*0.12));
 float shine=max(stripe*0.85,thin*0.65);
 ALBEDO=mix(vec3(0.94,0.69,0.34),vec3(0.82,0.96,1.0),shine);
 ROUGHNESS=0.055;METALLIC=0.12;SPECULAR=0.85;
 CLEARCOAT=1.0;CLEARCOAT_ROUGHNESS=0.03;
 ALPHA=0.15+shine*0.70;
 EMISSION=vec3(0.75,0.9,1.0)*shine*0.85;
}
