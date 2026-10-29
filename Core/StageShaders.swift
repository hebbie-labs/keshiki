/// Metal shaders for `WaterStage`, compiled at runtime like `Shaders`.
enum StageShaders {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct StageVertex {
        float3 position;
        float3 normal;
        float2 spot;    // 0...1 across the pond
    };

    struct Stage {
        float4x4 viewProjection;
        float4 eye;     // camera position; how deep things look compared to how deep they are
        float4 pond;    // width and height in design units, world units per design unit, depth of the swimmers
        float4 water;   // the water's colour (linear); how steep the waves look
        float4 sun;     // towards the sun
        float4 slant;   // how far sunlight moves sideways per unit of depth in the water (design x, y); seconds
    };

    struct Fragment {
        float4 position [[position]];
        float3 world;
        float3 normal;
        float2 spot;
    };

    constexpr sampler crisp(filter::nearest, address::clamp_to_edge);
    // Past the pond's edges the floor carries on as its own mirror image.
    constexpr sampler floorSampler(filter::nearest, address::mirrored_repeat);
    constexpr sampler smooth(filter::linear, address::clamp_to_edge);
    constexpr sampler skySampler(filter::linear, address::repeat);

    // How much of the light the water swallows per design unit it travels through: red goes first,
    // so deep water turns blue rather than green.
    constant float3 absorption = float3(0.014, 0.009, 0.007);
    constant float3 sunColor = float3(1, 0.96, 0.88);

    // The water surface rises and falls with the waves; everything else lies still.
    vertex Fragment stageVertex(uint id [[vertex_id]], const device StageVertex *vertices [[buffer(0)]],
                                constant Stage &stage [[buffer(1)]], constant float &lift [[buffer(2)]],
                                texture2d<float> waves [[texture(0)]]) {
        StageVertex v = vertices[id];
        float3 position = v.position;
        position.y += lift * waves.sample(smooth, v.spot, level(0)).w * stage.pond.z;
        Fragment out;
        out.position = stage.viewProjection * float4(position, 1);
        out.world = position;
        out.normal = v.normal;
        out.spot = v.spot;
        return out;
    }

    // The layers hold premultiplied sRGB; shading works in linear light.
    float4 layerColor(texture2d<float> layer, float2 spot) {
        float4 color = layer.sample(crisp, spot);
        if (color.a < 0.004) return float4(0);
        return float4(pow(color.rgb / color.a, 2.2), color.a);
    }

    // How much light is left after going down to `depth` and back up to the eye.
    float3 clearness(float depth, float3 toEye) {
        return exp(-absorption * depth * (1 + 1 / max(toEye.y, 0.25)));
    }

    // What the waves and the things above do to the sunlight reaching `spot` at `depth`:
    // x how much brighter the waves focus it, y how much is left after spreading and shadows.
    // The light got here through the surface towards the sun, so that's where its waves and shadows are.
    float2 sunlight(constant Stage &stage, texture2d<float> waves, texture2d<float> floating, texture2d<float> swimming,
                    float2 spot, float depth) {
        float2 size = stage.pond.xy;
        float curvature = waves.sample(smooth, spot + stage.slant.xy * depth / size).z;
        // A crest is a lens: light only moves around, so the floor brightens where the waves bend it together
        // and darkens where they spread it (how much light lands = area before / area after).
        float gathered = 1 / max(1 + 1.6 * depth * curvature, 0.2);
        float shade = floating.sample(crisp, spot + stage.slant.xy * depth / size).a > 0.8 ? 1 : 0;
        float above = depth - stage.pond.w;
        if (above > 0 && swimming.sample(crisp, spot + stage.slant.xy * above / size).a > 0.5) shade = 1;
        float lit = 1 - 0.6 * shade;
        return float2(saturate(gathered - 1) * lit, (1 - saturate(1 - gathered) * 0.45) * lit);
    }

    // Looking down through a tilted surface shifts what lies below, the more the deeper it lies.
    float2 bent(texture2d<float> waves, float2 spot, float depth, float2 size) {
        return spot - waves.sample(smooth, spot).xy * depth * 0.25 / size;
    }

    fragment float4 floorFragment(Fragment in [[stage_in]], constant Stage &stage [[buffer(1)]],
                                  texture2d<float> floorTexture [[texture(0)]], texture2d<float> swimming [[texture(1)]],
                                  texture2d<float> floating [[texture(2)]], texture2d<float> waves [[texture(3)]]) {
        float depth = max(-in.world.y / stage.pond.z, 0.0) / stage.eye.w;
        float2 seen = bent(waves, in.spot, depth, stage.pond.xy);
        float2 light = sunlight(stage, waves, floating, swimming, seen, depth);
        float3 clear = clearness(depth, normalize(stage.eye.xyz - in.world));
        float3 ground = pow(floorTexture.sample(floorSampler, seen).rgb, 2.2);
        float lit = 0.45 + 0.75 * saturate(dot(normalize(in.normal), stage.sun.xyz)) * light.y;
        float3 color = ground * lit * clear + stage.water.rgb * (1 - clear) * 0.3 + sunColor * light.x * 0.6 * clear;
        return float4(color, 1);
    }

    fragment float4 swimmersFragment(Fragment in [[stage_in]], constant Stage &stage [[buffer(1)]],
                                     texture2d<float> swimming [[texture(1)]], texture2d<float> floating [[texture(2)]],
                                     texture2d<float> waves [[texture(3)]]) {
        float depth = stage.pond.w;
        float2 seen = bent(waves, in.spot, depth, stage.pond.xy);
        float4 swimmer = layerColor(swimming, seen);
        if (swimmer.a < 0.004) discard_fragment();
        float2 light = sunlight(stage, waves, floating, swimming, seen, depth);
        float3 clear = clearness(depth, normalize(stage.eye.xyz - in.world));
        float3 color = swimmer.rgb * (0.55 + 0.5 * light.y) * clear + stage.water.rgb * (1 - clear) * 0.3 + sunColor * light.x * 0.6 * clear;
        return float4(color, swimmer.a);
    }

    // Stands a sprite up at its root (normal: offset across and height in world units, phase), facing the camera
    // square on, so the pixel art stays undistorted however steeply the camera looks down, and sways it in the
    // wind, more towards the top.
    vertex Fragment standingVertex(uint id [[vertex_id]], const device StageVertex *vertices [[buffer(0)]],
                                   constant Stage &stage [[buffer(1)]]) {
        StageVertex v = vertices[id];
        float3 forward = normalize(v.position - stage.eye.xyz);
        float3 across = normalize(cross(forward, float3(0, 1, 0)));
        float3 up = cross(across, forward);
        float height = v.normal.y, time = stage.slant.z;
        float sway = (sin(time * 1.1 + v.normal.z) + 0.4 * sin(time * 2.7 + v.normal.z * 3)) * 0.1 * height * height;
        float3 position = v.position + across * (v.normal.x + sway) + up * height;
        Fragment out;
        out.position = stage.viewProjection * float4(position, 1);
        out.world = position;
        out.normal = float3(0, 1, 0);
        out.spot = v.spot;
        return out;
    }

    // The sheet is sRGB, so it samples linear; its pixels are either there or not.
    fragment float4 standingFragment(Fragment in [[stage_in]], texture2d<float> sheet [[texture(5)]]) {
        float4 color = sheet.sample(crisp, in.spot);
        if (color.a < 0.5) discard_fragment();
        return float4(color.rgb, 1);
    }

    // The sky the water reflects, stored as a panorama.
    float3 skyColor(texture2d<float> sky, float3 direction) {
        float2 spot = float2(atan2(direction.x, -direction.z) / (2 * M_PI_F) + 0.5, acos(clamp(direction.y, -1.0, 1.0)) / M_PI_F);
        return sky.sample(skySampler, spot).rgb;
    }

    // The surface reflects the sky as much as Fresnel says (2 % head-on, more where the waves tilt it),
    // glints where it mirrors the sun, and carries what floats. Its output is premultiplied: what it doesn't
    // reflect lets the water below show through.
    fragment float4 surfaceFragment(Fragment in [[stage_in]], constant Stage &stage [[buffer(1)]],
                                    texture2d<float> floating [[texture(2)]], texture2d<float> waves [[texture(3)]],
                                    texture2d<float> sky [[texture(4)]]) {
        float4 wave = waves.sample(smooth, in.spot);
        float3 normal = normalize(float3(-wave.x * stage.water.w, 1, -wave.y * stage.water.w));
        float3 toEye = normalize(stage.eye.xyz - in.world);
        float fresnel = 0.02 + 0.98 * pow(1 - saturate(dot(normal, toEye)), 5);
        float3 mirrored = reflect(-toEye, normal);
        float glint = pow(saturate(dot(mirrored, stage.sun.xyz)), 1500) * 30;
        float3 water = skyColor(sky, mirrored) * fresnel + sunColor * glint;
        float4 thing = layerColor(floating, in.spot);
        float3 thingLit = thing.rgb * (0.8 + 0.3 * saturate(dot(normal, stage.sun.xyz)));
        return float4(water * (1 - thing.a) + thingLit * thing.a, saturate(fresnel + glint) * (1 - thing.a) + thing.a);
    }
    """
}
