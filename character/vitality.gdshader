shader_type canvas_item;
// Grades the rendered character: grey and dull when abandoned, brighter when radiant.
uniform float abandonment: hint_range(0.0,1.0)=0.0;
uniform float glow: hint_range(0.0,1.0)=0.0;
uniform float pulse=0.0;

void fragment(){
	vec4 pixel=texture(TEXTURE,UV);
	float grey=dot(pixel.rgb,vec3(0.299,0.587,0.114));
	vec3 dull=vec3(grey)*0.62;
	vec3 lit=pixel.rgb*(1.0+glow*(0.26+0.10*pulse))+pixel.rgb*pixel.rgb*glow*0.25;
	COLOR=vec4(mix(lit,dull,abandonment),pixel.a);
}
