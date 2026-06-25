import Foundation
#if os(macOS)
import IOKit
#endif

struct MachineFingerprint {
    nonisolated static func generate() -> String {
        #if os(macOS)
        if let hardwareUUID = platformUUID() {
            return hardwareUUID
        }
        #endif
        return persistedFallbackUUID()
    }

    #if os(macOS)
    nonisolated private static func platformUUID() -> String? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        let key = kIOPlatformUUIDKey as CFString
        guard let uuid = IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String else {
            return nil
        }
        return uuid
    }
    #endif

    nonisolated private static func persistedFallbackUUID() -> String {
        let key = "com.mcappstools.machine-fingerprint"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newUUID = UUID().uuidString
        UserDefaults.standard.set(newUUID, forKey: key)
        return newUUID
    }
}
