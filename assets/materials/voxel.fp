#version 140

// tint    : multiplies the palette color (theme colors for terrain, alpha in w)
// overlay : rgb mixed over the lit color by overlay.w (beam stress, ghost preview, flashes)
in highp vec4 var_position;
in mediump vec3 var_normal;
in mediump vec2 var_texcoord0;
in mediump vec4 var_light;

out vec4 out_fragColor;

uniform mediump sampler2D tex0;

uniform fs_uniforms
{
    mediump vec4 tint;
    mediump vec4 overlay;
};

void main()
{
    vec4 base = texture(tex0, var_texcoord0);
    vec3 n = normalize(var_normal);
    vec3 l = normalize(var_light.xyz);
    float ndl = max(dot(n, l), 0.0);
    // soft sky fill from above + key light: readable voxels without shadow maps
    float sky = 0.5 + 0.5 * n.y;
    float light_factor = 0.42 + ndl * 0.62 + sky * 0.08;
    vec3 lit = base.rgb * tint.rgb * light_factor;
    lit = mix(lit, overlay.rgb * (0.55 + ndl * 0.55), overlay.w);
    out_fragColor = vec4(lit, base.a * tint.w);
}
