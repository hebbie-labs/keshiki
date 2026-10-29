/// The colours of one water theme: the floor and the water over it.
struct WaterPalette {
    let floor: Color
    let silt: Color
    let pebbles: [Color]
    let plants: [Color]
    /// The colour the water itself gives the light of the time of day.
    let water: Color
    /// How much the water hides of the floor, 0...1.
    let murk: Double
    /// Fallen leaves lying on the floor, browning as they rot.
    let litter: [Color]

    static func named(_ name: String) -> WaterPalette {
        name == "deep-clear" ? deepClear : pond
    }

    /// A garden pond: dark mud, fallen leaves and soft olive-brown water you see a little way into.
    static let pond = WaterPalette(
        floor: Color(0x6e6248),
        silt: Color(0x52483a),
        pebbles: [Color(0x857a64), Color(0x5e5546), Color(0x9a8e72), Color(0x443e34)],
        plants: [Color(0x2e4a2a), Color(0x3b5a30), Color(0x4d6e38), Color(0x637f42), Color(0x7d9450), Color(0x98a862)],
        water: Color(0x5e5a3a),
        murk: 0.6,
        litter: [Color(0x6b4a2a), Color(0x8a5e30), Color(0x5a3e26), Color(0x7a6a3a)]
    )

    /// A deep spring-fed basin: pale sand and gravel seen through clear blue water.
    static let deepClear = WaterPalette(
        floor: Color(0xd8cfb2),
        silt: Color(0xb8b096),
        pebbles: [Color(0x9a9a90), Color(0x76807e), Color(0xc2b494), Color(0x5e6a70), Color(0xe6dfcc)],
        plants: [Color(0x1d4d3a), Color(0x2a6b4a), Color(0x3b8a5a), Color(0x5aa86a), Color(0x8cc77a), Color(0xc0e494)],
        water: Color(0x1878b4),
        murk: 0.46,
        litter: []
    )
}
