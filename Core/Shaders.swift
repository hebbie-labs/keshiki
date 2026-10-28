/// Metal shaders, compiled at runtime so building needs no Metal toolchain.
enum Shaders {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    // ---- Shapes: instanced quads, one per Primitive ----

    struct Primitive {
        float4 bounds;
        float4 color;
        float4 disc;
    };

    struct ShapeFragment {
        float4 position [[position]];
        float4 color [[flat]];
        float4 disc [[flat]];
    };

    vertex ShapeFragment shapeVertex(uint vertexID [[vertex_id]], uint instanceID [[instance_id]],
                                     const device Primitive *primitives [[buffer(0)]],
                                     constant float2 &viewport [[buffer(1)]]) {
        Primitive shape = primitives[instanceID];
        float2 corner = float2(vertexID & 1, vertexID >> 1);
        float2 pixel = mix(shape.bounds.xy, shape.bounds.zw, corner);
        ShapeFragment out;
        out.position = float4(pixel / viewport * float2(2, -2) + float2(-1, 1), 0, 1);
        out.color = shape.color;
        out.disc = shape.disc;
        return out;
    }

    // Discs use the same whole-pixel rows as the CPU painter, so both look identical.
    fragment float4 shapeFragment(ShapeFragment in [[stage_in]]) {
        if (in.disc.w > 0.5) {
            float2 pixel = floor(in.position.xy);
            float dy = pixel.y - in.disc.y;
            float radiusSquared = in.disc.z * in.disc.z;
            if (dy * dy > radiusSquared) discard_fragment();
            if (abs(pixel.x - in.disc.x) > floor(sqrt(radiusSquared - dy * dy))) discard_fragment();
        }
        return in.color;
    }

    // ---- Backdrop: the painted floor plus the moving net of light ----

    struct Backdrop {
        float4 drift;   // x, y offset into the caustics tile, pixel scale, caustics frame
        float4 light;   // rgb, and 1 if the scene has caustics
    };

    vertex float4 fullScreenVertex(uint vertexID [[vertex_id]]) {
        float2 corner = float2(vertexID & 1, vertexID >> 1);
        return float4(corner * 2 - 1, 0, 1);
    }

    // The overlay is stored as one palette index per pixel; index 0 is transparent.
    fragment float4 overlayFragment(float4 position [[position]], texture2d<float> overlay [[texture(0)]],
                                    constant float4 *palette [[buffer(0)]]) {
        return palette[uint(overlay.read(uint2(position.xy)).r * 255 + 0.5)];
    }

    fragment float4 backdropFragment(float4 position [[position]],
                                     texture2d<float> floorTexture [[texture(0)]],
                                     texture2d_array<float> caustics [[texture(1)]],
                                     constant Backdrop &backdrop [[buffer(0)]]) {
        uint2 pixel = uint2(position.xy);
        float4 color = floorTexture.read(pixel);
        if (backdrop.light.w < 0.5) return color;
        int2 design = int2(floor(position.xy / backdrop.drift.z));
        uint2 tile = uint2((design + int2(backdrop.drift.xy)) & int2(caustics.get_width() - 1));
        float level = caustics.read(tile, uint(backdrop.drift.w)).r * 255;
        float strength = level > 1.5 ? 0.17 : (level > 0.5 ? 0.07 : 0);
        return float4(mix(color.rgb, backdrop.light.rgb, strength), 1);
    }
    """
}
