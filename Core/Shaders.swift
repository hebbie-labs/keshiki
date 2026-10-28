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

    // ---- Layers: the floor alone, then the scene in two layers drawn at its own pixel size ----

    vertex float4 fullScreenVertex(uint vertexID [[vertex_id]]) {
        float2 corner = float2(vertexID & 1, vertexID >> 1);
        return float4(corner * 2 - 1, 0, 1);
    }

    fragment float4 backdropFragment(float4 position [[position]], texture2d<float> floorTexture [[texture(0)]]) {
        return floorTexture.read(uint2(position.xy));
    }

    // The overlay is stored as one palette index per pixel; index 0 is transparent.
    fragment float4 overlayFragment(float4 position [[position]], texture2d<float> overlay [[texture(0)]],
                                    constant float4 *palette [[buffer(0)]]) {
        return palette[uint(overlay.read(uint2(position.xy)).r * 255 + 0.5)];
    }

    // ---- Water: a height field on a grid of cells, simulated on the GPU ----

    struct WaterStep {
        float4 wave;    // speed (0...0.5), damping, number of drops
    };

    // Each cell holds its height and its height one step ago. Neighbours past the edge repeat the cell,
    // so waves bounce back; obstacle cells stay flat, so waves bounce off them too.
    kernel void waterStep(texture2d<float, access::read> current [[texture(0)]],
                          texture2d<float, access::write> next [[texture(1)]],
                          texture2d<float, access::read> obstacles [[texture(2)]],
                          constant float4 *drops [[buffer(0)]],
                          constant WaterStep &step [[buffer(1)]],
                          uint2 cell [[thread_position_in_grid]]) {
        uint2 last = uint2(current.get_width(), current.get_height()) - 1;
        if (any(cell > last)) return;
        if (obstacles.read(cell).r > 0.5) { next.write(float4(0), cell); return; }
        float2 here = current.read(cell).rg;
        float around = current.read(uint2(cell.x == 0 ? 0 : cell.x - 1, cell.y)).r
                     + current.read(uint2(min(cell.x + 1, last.x), cell.y)).r
                     + current.read(uint2(cell.x, cell.y == 0 ? 0 : cell.y - 1)).r
                     + current.read(uint2(cell.x, min(cell.y + 1, last.y))).r;
        float height = here.r + (here.r - here.g) * step.wave.y + step.wave.x * (around - 4 * here.r);
        for (uint index = 0; index < uint(step.wave.z); index++) {
            float4 drop = drops[index];   // x, y, radius in cells, strength
            float2 offset = float2(cell) - drop.xy;
            height -= drop.w * exp(-dot(offset, offset) / (drop.z * drop.z));
        }
        next.write(float4(height, here.r, 0, 0), cell);
    }

    struct WaterShape {
        float4 time;    // seconds (looping), design units per cell
    };

    // A breeze that never stops: a few long waves added to the simulated ones,
    // so the floor always carries a moving net of light. Whole cycles per 600 s, so time can loop.
    constant float4 breeze[12] = {   // direction (radians), wavelength, height, cycles per 600 s
        float4(0.3, 34, 0.040, 290), float4(1.9, 27, 0.035, 330), float4(3.6, 41, 0.045, 240), float4(5.0, 23, 0.030, 370),
        float4(2.6, 52, 0.050, 190), float4(4.3, 31, 0.035, 310), float4(1.1, 19, 0.022, 420), float4(5.7, 45, 0.040, 220),
        float4(0.8, 15, 0.016, 470), float4(2.2, 21, 0.024, 400), float4(3.1, 17, 0.018, 440), float4(4.8, 13, 0.012, 510)
    };

    // Turns heights into what shading needs: the slope (x, y) and the curvature, per design unit.
    kernel void waterShape(texture2d<float, access::read> heights [[texture(0)]],
                           texture2d<float, access::write> shape [[texture(1)]],
                           constant WaterShape &water [[buffer(0)]],
                           uint2 cell [[thread_position_in_grid]]) {
        uint2 last = uint2(heights.get_width(), heights.get_height()) - 1;
        if (any(cell > last)) return;
        float unit = water.time.y;
        float here = heights.read(cell).r;
        float left = heights.read(uint2(cell.x == 0 ? 0 : cell.x - 1, cell.y)).r;
        float right = heights.read(uint2(min(cell.x + 1, last.x), cell.y)).r;
        float up = heights.read(uint2(cell.x, cell.y == 0 ? 0 : cell.y - 1)).r;
        float down = heights.read(uint2(cell.x, min(cell.y + 1, last.y))).r;
        float3 result = float3(right - left, down - up, 0) / (2 * unit);
        result.z = (left + right + up + down - 4 * here) / (unit * unit);
        float2 position = (float2(cell) + 0.5) * unit;
        for (int index = 0; index < 12; index++) {
            float4 wave = breeze[index];
            float number = 2 * M_PI_F / wave.y;
            float2 direction = float2(cos(wave.x), sin(wave.x)) * number;
            float phase = dot(direction, position) - 2 * M_PI_F * wave.w * water.time.x / 600 + wave.x * 7;
            result.xy += direction * wave.z * cos(phase);
            result.z -= number * number * wave.z * sin(phase);
        }
        shape.write(float4(result, 0), cell);
    }

    struct WaterLook {
        float4 size;    // target width, height; scene width, height in design units
        float4 optics;  // refraction, depth for the light net, wave relief for glints, 1 if there is water
        float4 light;   // rgb, strength of the light net
    };

    // Puts the frame together at the display's full resolution: the layer below the surface is bent by the waves
    // and lit by the light they focus on the floor, the waves catch the sun, and the layer above sits on top.
    fragment float4 waterFragment(float4 position [[position]],
                                  texture2d<float> below [[texture(0)]],
                                  texture2d<float> above [[texture(1)]],
                                  texture2d<float> shape [[texture(2)]],
                                  constant WaterLook &look [[buffer(0)]]) {
        constexpr sampler pixels(filter::nearest, address::clamp_to_edge);
        constexpr sampler smooth(filter::linear, address::clamp_to_edge);
        float2 spot = position.xy / look.size.xy;
        float4 top = above.sample(pixels, spot);
        if (look.optics.w < 0.5) return float4(below.sample(pixels, spot).rgb * (1 - top.a) + top.rgb, 1);
        float3 surface = shape.sample(smooth, spot).xyz;
        float3 color = below.sample(pixels, spot - surface.xy * look.optics.x / look.size.zw).rgb;
        // A crest is a lens: where it bends light together the floor brightens (1 / how much the light spreads).
        float spread = max(1 + look.optics.y * surface.z, 0.12);
        float focus = pow(saturate((1 / spread - 1) * 0.6), 1.6);
        color = mix(color, look.light.rgb, focus * look.light.w);
        float3 normal = normalize(float3(-surface.xy * look.optics.z, 1));
        float glint = pow(saturate(dot(normal, normalize(float3(-0.38, -0.5, 1.8)))), 900);
        float sky = saturate(length(surface.xy) * look.optics.z * 0.6) * 0.1;
        color = mix(color, look.light.rgb, saturate(glint * 0.8 + sky));
        return float4(color * (1 - top.a) + top.rgb, 1);
    }
    """
}
