/// The colours of one water theme, from the pond floor up to the light on the surface.
struct WaterPalette {
    let floor: Color
    let silt: Color
    let pebbles: [Color]
    let plants: [Color]
    let shallowWater: Color
    let deepWater: Color
    let light: Color

    static func named(_ name: String) -> WaterPalette {
        name == "deep-clear" ? deepClear : pond
    }

    static let pond = WaterPalette(
        floor: Color(0x9fc8a0),
        silt: Color(0x7fb08a),
        pebbles: [Color(0x6f9c7c), Color(0x86b190), Color(0xb4d4b0), Color(0x5d8a6c)],
        plants: [Color(0x174d27), Color(0x22672f), Color(0x2f8a3a), Color(0x4caf44), Color(0x7cc443), Color(0xb2e05a)],
        shallowWater: Color(0x63b89c),
        deepWater: Color(0x236a62),
        light: Color(0xe2fff2)
    )

    static let deepClear = WaterPalette(
        floor: Color(0xc9c2a2),
        silt: Color(0xa9a487),
        pebbles: [Color(0x8a8f86), Color(0x6f7a76), Color(0xb0a58a), Color(0x5f6c6e)],
        plants: [Color(0x1d4d3a), Color(0x2a6b4a), Color(0x3b8a5a), Color(0x5aa86a), Color(0x8cc77a), Color(0xc0e494)],
        shallowWater: Color(0x6cc4cf),
        deepWater: Color(0x1f5f86),
        light: Color(0xe8fbff)
    )
}
