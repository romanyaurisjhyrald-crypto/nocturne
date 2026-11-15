shader_type canvas_item;
uniform float drift_pixels : hint_range(0.0, 2.0) = 1.1;
uniform float twinkle_strength : hint_range(0.0, 0.2) = 0.08;
float star_mask(vec3 color){
 return smoothstep(0.40,0.82,min(color.r,color.g));
}
void fragment(){
 vec4 original=texture(TEXTURE,UV);
 vec2 drift=vec2(sin(TIME*0.13+UV.y*11.0),cos(TIME*0.11+UV.x*9.0));
 vec2 sample_uv=clamp(UV+drift*TEXTURE_PIXEL_SIZE*drift_pixels,TEXTURE_PIXEL_SIZE,vec2(1.0)-TEXTURE_PIXEL_SIZE);
 vec3 moved=texture(TEXTURE,sample_uv).rgb;
 float phase=UV.x*34.0+UV.y*27.0;
 float breath=sin(TIME*0.24+phase);
 float glint=pow(max(sin(TIME*0.17+phase*1.8),0.0),16.0);
 float brightness=1.0+twinkle_strength*(breath*0.70+glint*0.85);
 vec3 base=original.rgb-original.rgb*star_mask(original.rgb);
 vec3 result=base+moved*star_mask(moved)*brightness;
 COLOR=vec4(result,original.a);
}
