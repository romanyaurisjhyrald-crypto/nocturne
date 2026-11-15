shader_type canvas_item;
uniform float radius = 39.0;
varying float local_height;
void vertex() {
    local_height = VERTEX.y / max(radius, 0.01);
}
void fragment() {
    float blend = smoothstep(-0.8, 0.65, local_height);
    COLOR.rgb *= mix(vec3(0.68, 0.81, 0.76), vec3(1.0), blend);
}
