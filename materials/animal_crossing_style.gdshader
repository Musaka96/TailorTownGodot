shader_type spatial;

render_mode specular_disabled, cull_back;


// ============================================================
// PER-MATERIAL SETTINGS
// These are different for House, Floor, Grass, etc.
// ============================================================

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;

uniform vec4 albedo_color : source_color = vec4(1.0);

uniform float texture_strength : hint_range(0.0, 1.0) = 1.0;

uniform vec2 albedo_tiling = vec2(1.0, 1.0);

uniform vec2 albedo_offset = vec2(0.0, 0.0);


// ============================================================
// GLOBAL STYLE SETTINGS
// These are shared by EVERY material using this shader.
// ============================================================

global uniform float ac_brightness;

global uniform float ac_saturation;

global uniform float ac_roughness;

global uniform float ac_shadow_softness;

global uniform float ac_shadow_lift;

global uniform vec4 ac_shadow_tint : source_color;

global uniform float ac_highlight_strength;

global uniform vec4 ac_highlight_tint : source_color;

global uniform float ac_color_variation;


// ============================================================
// WORLD POSITION
// ============================================================

varying vec3 world_position;


// ============================================================
// VERTEX
// ============================================================

void vertex()
{
    world_position =
        (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


// ============================================================
// SATURATION
// ============================================================

vec3 apply_saturation(vec3 color, float amount)
{
    float luminance = dot(
        color,
        vec3(0.299, 0.587, 0.114)
    );

    return mix(
        vec3(luminance),
        color,
        amount
    );
}


// ============================================================
// FRAGMENT
// ============================================================

void fragment()
{
    // --------------------------------------------------------
    // TILING
    // --------------------------------------------------------

    vec2 tiled_uv =
        UV * albedo_tiling +
        albedo_offset;

    vec4 tex =
        texture(
            albedo_texture,
            tiled_uv
        );

    // --------------------------------------------------------
    // ALBEDO
    // --------------------------------------------------------

    vec3 base_color =
        mix(
            albedo_color.rgb,
            albedo_color.rgb * tex.rgb,
            texture_strength
        );

    // --------------------------------------------------------
    // GLOBAL SATURATION
    // --------------------------------------------------------

    base_color =
        apply_saturation(
            base_color,
            ac_saturation
        );

    // --------------------------------------------------------
    // GLOBAL BRIGHTNESS
    // --------------------------------------------------------

    base_color *= ac_brightness;

    // --------------------------------------------------------
    // SUBTLE WORLD-SPACE COLOR VARIATION
    // --------------------------------------------------------

    float random_value = fract(
        sin(
            dot(
                world_position.xz,
                vec2(12.9898, 78.233)
            )
        ) * 43758.5453
    );

    base_color *=
        1.0 +
        (random_value - 0.5) *
        ac_color_variation;

    // --------------------------------------------------------
    // MATERIAL
    // --------------------------------------------------------

    ALBEDO = base_color;

    ROUGHNESS = ac_roughness;

    METALLIC = 0.0;

    SPECULAR = 0.0;
}


// ============================================================
// LIGHTING
// ============================================================

void light()
{
    // --------------------------------------------------------
    // Surface → Light angle
    // --------------------------------------------------------

    float NdotL =
        dot(NORMAL, LIGHT);

    // --------------------------------------------------------
    // Soft stylized light transition
    // --------------------------------------------------------

    float soft_light =
        smoothstep(
            -ac_shadow_softness,
            0.65,
            NdotL
        );

    // --------------------------------------------------------
    // Shadow color
    // --------------------------------------------------------

    vec3 shadow_color =
        ALBEDO *
        ac_shadow_tint.rgb;

    // --------------------------------------------------------
    // Lit color
    // --------------------------------------------------------

    vec3 lit_color =
        ALBEDO;

    vec3 surface_color =
        mix(
            shadow_color,
            lit_color,
            soft_light
        );

    // --------------------------------------------------------
    // Lift dark shadows
    // --------------------------------------------------------

    surface_color +=
        ac_shadow_tint.rgb *
        ac_shadow_lift *
        (1.0 - soft_light);

    // --------------------------------------------------------
    // Warm highlights
    // --------------------------------------------------------

    float highlight =
        smoothstep(
            0.55,
            1.0,
            NdotL
        );

    surface_color =
        mix(
            surface_color,
            surface_color *
            ac_highlight_tint.rgb,
            highlight *
            ac_highlight_strength
        );

    // --------------------------------------------------------
    // Direct light
    // --------------------------------------------------------

    DIFFUSE_LIGHT +=
        surface_color *
        LIGHT_COLOR *
        ATTENUATION *
        soft_light;
}