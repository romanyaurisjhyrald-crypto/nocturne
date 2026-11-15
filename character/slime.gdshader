shader_type spatial;
render_mode blend_mix, cull_back;
uniform vec4 base_color : source_color = vec4(0.065,0.55,0.53,1.0);
uniform float opacity : hint_range(0.0,1.0) = 0.88;
uniform float saturation = 0.92;
uniform float density = 24.0;
uniform bool screentone = false;
varying vec3 rest_position;
void vertex(){ rest_position=VERTEX; }
void fragment() {
 float edge=pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),3.0);
 ALBEDO=mix(base_color.rgb,vec3(0.22,0.83,0.85),edge*0.32);
 float gray=dot(ALBEDO,vec3(0.299,0.587,0.114));
 ALBEDO=mix(vec3(gray),ALBEDO,saturation);
 if(screentone){vec2 cell=fract(rest_position.xy*density)-0.5; float dots=1.0-smoothstep(0.16,0.23,length(cell)); ALBEDO=mix(ALBEDO,vec3(0.06,0.3,0.6),dots*0.16);}
 ROUGHNESS=0.13; METALLIC=0.035; SPECULAR=0.7;
 CLEARCOAT=0.85; CLEARCOAT_ROUGHNESS=0.08;
 BACKLIGHT=base_color.rgb*0.3;

 EMISSION=base_color.rgb*(0.025+edge*0.13);
 ALPHA=mix(opacity,0.96,edge);
}
