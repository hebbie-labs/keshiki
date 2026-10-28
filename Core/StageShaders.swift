/// RealityKit shaders for `WaterStage`, compiled at runtime like `Shaders`. RealityKit's own header is
/// inlined (`RealityKitHeader`, made by the Makefile from the SDK), so building needs no Metal toolchain.
///
/// Every material gets the same textures, in slots RealityKit leaves to custom shaders:
/// base colour = the painted floor, ambient occlusion = what swims, emissive = what floats, custom = the waves.
/// Its custom value holds the pond's width and height in design units, world units per design unit,
/// and how deep the swimmers swim; its base colour tint is the colour of the water.
enum StageShaders {
    static let source = RealityKitHeader.source + """

    using namespace metal;

    constexpr sampler crisp(filter::nearest, address::clamp_to_edge);
    // Past the pond's edges the floor carries on as its own mirror image.
    constexpr sampler floorSampler(filter::nearest, address::mirrored_repeat);
    constexpr sampler smooth(filter::linear, address::clamp_to_edge);

    // The sun stands to the top left. Bent into the water, its light slants this far sideways per unit of depth,
    // so the light and shade the waves cast, and the shadows of what floats and swims, land beside them.
    constant float2 towardsSun = float2(-0.16, -0.21);
    // How much of the light the water swallows per design unit it travels through it.
    constant float absorption = 0.009;

    // The layers hold premultiplied sRGB; shading works in linear light.
    half4 layerColor(texture2d<half> layer, float2 spot) {
        half4 color = layer.sample(crisp, spot);
        if (color.a < 0.004h) return half4(0);
        return half4(pow(color.rgb / color.a, 2.2h), color.a);
    }

    half3 floorColor(texture2d<half> floorTexture, float2 spot) {
        return pow(floorTexture.sample(floorSampler, spot).rgb, 2.2h);
    }

    // How much light is left after going down to `depth` and back up to the eye.
    float clearness(float depth, float3 view) {
        return exp(-absorption * depth * (1 + 1 / max(abs(view.y), 0.25)));
    }

    // What the waves and the things above do to the light reaching `spot` at `depth`:
    // x how much brighter the waves focus it, y how much it's left after spreading and shadows.
    float2 sunlight(realitykit::texture::textures textures, float2 spot, float depth, float swimmerDepth, float2 size) {
        float2 sunward = towardsSun * depth / size;
        float curvature = float(textures.custom().sample(smooth, spot + sunward).z);
        // A crest is a lens: light only moves around, so the floor brightens where the waves bend it together
        // and darkens where they spread it (how much light lands = area before / area after).
        float gathered = 1 / max(1 + 1.6 * depth * curvature, 0.2);
        float floating = textures.emissive_color().sample(crisp, spot + sunward).a > 0.8h ? 1 : 0;
        float swimming = depth > swimmerDepth
            ? (textures.ambient_occlusion().sample(crisp, spot + towardsSun * (depth - swimmerDepth) / size).a > 0.5h ? 1 : 0) : 0;
        float shade = 1 - 0.6 * max(floating, swimming);
        return float2(saturate(gathered - 1) * shade, (1 - saturate(1 - gathered) * 0.45) * shade);
    }

    [[visible]] void pondFloor(realitykit::surface_parameters params) {
        float4 pond = params.uniforms().custom_parameter();
        auto textures = params.textures();
        float2 spot = params.geometry().uv0();
        float depth = max(-params.geometry().world_position().y / pond.z, 0.0);
        // Looking down through a tilted surface shifts what lies below, the more the deeper it lies.
        float4 wave = float4(textures.custom().sample(smooth, spot));
        float2 seen = spot - wave.xy * depth * 0.25 / pond.xy;
        float2 light = sunlight(textures, seen, depth, pond.w, pond.xy);
        float clear = clearness(depth, params.geometry().view_direction());
        half3 water = half3(params.material_constants().base_color_tint());
        params.surface().set_base_color(floorColor(textures.base_color(), seen) * half(light.y * clear));
        params.surface().set_emissive_color(water * half(1 - clear) * 0.25h + half3(1, 0.97, 0.88) * half(light.x * clear * 0.6));
        params.surface().set_roughness(1);
        params.surface().set_metallic(0);
        params.surface().set_specular(0.1);
    }

    [[visible]] void pondSwimmers(realitykit::surface_parameters params) {
        float4 pond = params.uniforms().custom_parameter();
        auto textures = params.textures();
        float2 spot = params.geometry().uv0();
        float4 wave = float4(textures.custom().sample(smooth, spot));
        float2 seen = spot - wave.xy * pond.w * 0.25 / pond.xy;
        half4 swimmer = layerColor(textures.ambient_occlusion(), seen);
        float2 light = sunlight(textures, seen, pond.w, pond.w + 1, pond.xy);
        float clear = clearness(pond.w, params.geometry().view_direction());
        half3 water = half3(params.material_constants().base_color_tint());
        half3 color = swimmer.rgb * half(light.y * clear) + water * half(1 - clear) * 0.25h + half3(1, 0.97, 0.88) * half(light.x * clear * 0.6);
        params.surface().set_base_color(color);
        params.surface().set_emissive_color(color);
        params.surface().set_opacity(swimmer.a);
    }

    // The surface rises and falls with the simulated waves and tilts with them, so it catches the sky and the sun.
    [[visible]] void pondWaves(realitykit::geometry_parameters params) {
        float4 pond = params.uniforms().custom_parameter();
        float4 wave = float4(params.textures().custom().sample(smooth, params.geometry().uv0()));
        params.geometry().set_model_position_offset(float3(0, wave.w * pond.z, 0));
        params.geometry().set_normal(normalize(float3(-wave.x * 2.5, 1, -wave.y * 2.5)));
    }

    [[visible]] void pondSurface(realitykit::surface_parameters params) {
        auto textures = params.textures();
        float2 spot = params.geometry().uv0();
        half4 floating = layerColor(textures.emissive_color(), spot);
        half3 water = half3(params.material_constants().base_color_tint());
        // What floats keeps most of its own colour and takes a little of the sun's shading.
        params.surface().set_base_color(mix(water * 0.15h, floating.rgb * 0.35h, floating.a));
        params.surface().set_emissive_color(floating.rgb * floating.a * 1.05h);
        params.surface().set_roughness(mix(0.025h, 0.85h, floating.a));
        params.surface().set_metallic(0);
        // Water reflects 2 % head-on (specular 0.25 in RealityKit's terms).
        params.surface().set_specular(mix(0.25h, 0.2h, floating.a));
        params.surface().set_opacity(mix(0.12h, 1.0h, floating.a));
    }
    """
}
