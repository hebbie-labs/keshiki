import Foundation
import IOKit.ps

enum SystemConditions {
    static var isOnBattery: Bool {
        IOPSGetProvidingPowerSourceType(nil)?.takeRetainedValue() as String? == kIOPSBatteryPowerValue
    }

    static var isDarkMode: Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }
}
