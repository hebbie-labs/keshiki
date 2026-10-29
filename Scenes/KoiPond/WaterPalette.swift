/// The colours of one water theme: the floor and the water over it.
struct WaterPalette {
    let floor: Color
    let silt: Color
    let pebbles: [Color]
    let plants: [Color]
    /// What the water turns the floor towards where it's deep.
    let deepWater: Color

    static func named(_ name: String) -> WaterPalette {
        name == "deep-clear" ? deepClear : pond
    }

    static let pond = WaterPalette(
        floor: Color(0xb8ab86),
        silt: Color(0x9a8f6e),
        pebbles: [Color(0x8a8072), Color(0x6f675c), Color(0xc4b89a), Color(0x5c5850)],
        plants: [Color(0x174d27), Color(0x22672f), Color(0x2f8a3a), Color(0x4caf44), Color(0x7cc443), Color(0xb2e05a)],
        deepWater: Color(0x1d4f5e)
    )

    static let deepClear = WaterPalette(
        floor: Color(0xc9c2a2),
        silt: Color(0xa9a487),
        pebbles: [Color(0x8a8f86), Color(0x6f7a76), Color(0xb0a58a), Color(0x5f6c6e)],
        plants: [Color(0x1d4d3a), Color(0x2a6b4a), Color(0x3b8a5a), Color(0x5aa86a), Color(0x8cc77a), Color(0xc0e494)],
        deepWater: Color(0x184a72)
    )
}
