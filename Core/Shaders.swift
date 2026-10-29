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

    // ---- Layers: the floor, and the scene in two transparent layers at its own pixel size ----

    vertex float4 fullScreenVertex(uint vertexID [[vertex_id]]) {
        float2 corner = float2(vertexID & 1, vertexID >> 1);
        return float4(corner * 2 - 1, 0, 1);
    }

    fragment float4 coverFragment(float4 position [[position]], constant float4 &color [[buffer(0)]]) {
        return color;
    }

    // The scene flat, without water: what floats over what swims over the floor. The layers are premultiplied.
    fragment float4 flattenFragment(float4 position [[position]], texture2d<float> floorTexture [[texture(0)]],
                                    texture2d<float> swimming [[texture(1)]], texture2d<float> floating [[texture(2)]]) {
        uint2 pixel = uint2(position.xy);
        float4 below = swimming.read(pixel), above = floating.read(pixel);
        float3 color = floorTexture.read(pixel).rgb * (1 - below.a) + below.rgb;
        return float4(color * (1 - above.a) + above.rgb, 1);
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
        uint left = cell.x == 0 ? 0 : cell.x - 1, right = min(cell.x + 1, last.x);
        uint up = cell.y == 0 ? 0 : cell.y - 1, down = min(cell.y + 1, last.y);
        // Nine neighbours instead of four keep rings round instead of square.
        float sides = current.read(uint2(left, cell.y)).r + current.read(uint2(right, cell.y)).r
                    + current.read(uint2(cell.x, up)).r + current.read(uint2(cell.x, down)).r;
        float corners = current.read(uint2(left, up)).r + current.read(uint2(right, up)).r
                      + current.read(uint2(left, down)).r + current.read(uint2(right, down)).r;
        float curvature = (4 * sides + corners - 20 * here.r) / 6;
        float height = here.r + (here.r - here.g) * step.wave.y + step.wave.x * curvature;
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
        float4(0.3, 34, 0.0132, 290), float4(1.9, 27, 0.0116, 330), float4(3.6, 41, 0.0149, 240), float4(5.0, 23, 0.0099, 370),
        float4(2.6, 52, 0.0165, 190), float4(4.3, 31, 0.0116, 310), float4(1.1, 19, 0.0072, 420), float4(5.7, 45, 0.0132, 220),
        float4(0.8, 15, 0.0055, 470), float4(2.2, 21, 0.0077, 400), float4(3.1, 17, 0.0060, 440), float4(4.8, 13, 0.0039, 510)
    };

    // Turns heights into what the 3D water needs: the slope (x, y) and the curvature per design unit, and the height.
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
        float4 result = float4(right - left, down - up, 0, here) / float4(2 * unit, 2 * unit, 1, 1);
        result.z = (left + right + up + down - 4 * here) / (unit * unit);
        float2 position = (float2(cell) + 0.5) * unit;
        for (int index = 0; index < 12; index++) {
            float4 wave = breeze[index];
            float number = 2 * M_PI_F / wave.y;
            float2 direction = float2(cos(wave.x), sin(wave.x)) * number;
            float phase = dot(direction, position) - 2 * M_PI_F * wave.w * water.time.x / 600 + wave.x * 7;
            result.xy += direction * wave.z * cos(phase);
            result.z -= number * number * wave.z * sin(phase);
            result.w += wave.z * sin(phase);
        }
        shape.write(result, cell);
    }
    """
}
