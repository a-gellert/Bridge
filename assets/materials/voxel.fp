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

    // warm key light + cool sky fill + a touch of ground bounce: voxels stay readable
    // without shadow maps, and vertical faces get a slight rim so silhouettes pop.
    vec3 sky_col = vec3(0.72, 0.84, 1.0);
    vec3 sun_col = vec3(1.0, 0.96, 0.88);
    vec3 bounce_col = vec3(0.85, 0.78, 0.68);
    float hemi = 0.5 + 0.5 * n.y;
    float amb = 0.31 + 0.17 * hemi;
    float top = max(n.y, 0.0);
    float bounce = 0.09 * max(-n.y, 0.0);
    float rim = pow(1.0 - max(n.z, 0.0), 3.0) * 0.07;

    vec3 light = sky_col * (amb + rim) + sun_col * (ndl * 0.62 + top * 0.04) + bounce_col * bounce;
    vec3 lit = base.rgb * tint.rgb * light;
    float mix_amount = overlay.w;
    lit = mix(lit, overlay.rgb * (0.55 + ndl * 0.55), mix_amount);
    out_fragColor = vec4(lit, base.a * tint.w);
}
