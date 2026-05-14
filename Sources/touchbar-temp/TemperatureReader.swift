import IOKit
import Foundation

// Reads CPU temperature from the System Management Controller (SMC).
// Tries a prioritized list of sensor keys compatible with Intel and Apple Silicon.
final class TemperatureReader {

    private var conn: io_connect_t = 0
    private var connected = false

    // Intel: TC0P (CPU proximity), TC0D/E/F (CPU die)
    // Apple Silicon M1/M2: Tp01–Tp0r (PMIC), Tf04/Tf09 (P-cores/E-cores), Te05/Te09
    private let candidateKeys = ["TC0P", "TC0D", "TC0E", "TC0F",
                                  "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0T",
                                  "Tp0b", "Tp0d", "Tp0f", "Tp0h", "Tp0j",
                                  "Tf04", "Tf09", "Tf0A", "Tf0B",
                                  "Te05", "Te09"]
    private var cachedKey: String?

    init() {
        // Verify struct matches the C SMCKeyData_t layout exactly (80 bytes).
        // If this assertion fires, the temperature reading will silently fail.
        assert(MemoryLayout<SMCKeyData>.size == 80, "SMCKeyData layout mismatch: got \(MemoryLayout<SMCKeyData>.size), expected 80")
        openConnection()
    }
    deinit { if connected { IOServiceClose(conn) } }

    // MARK: - Public

    func currentTemperature() -> Double {
        if let key = cachedKey, let t = readKey(key), valid(t) { return t }
        return scanForTemperature()
    }

    // MARK: - Connection

    private func openConnection() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("AppleSMC"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        connected = IOServiceOpen(service, mach_task_self_, 0, &conn) == kIOReturnSuccess
    }

    private func scanForTemperature() -> Double {
        for key in candidateKeys {
            if let t = readKey(key), valid(t) {
                cachedKey = key
                return t
            }
        }
        return 0
    }

    private func valid(_ t: Double) -> Bool { t > 1 && t < 120 }

    // MARK: - SMC Read

    private func readKey(_ key: String) -> Double? {
        guard connected else { return nil }

        var input = SMCKeyData()
        var output = SMCKeyData()
        var size = MemoryLayout<SMCKeyData>.size

        input.key = fourCC(key)
        input.data8 = 9  // kSMCGetKeyInfo

        guard IOConnectCallStructMethod(conn, 2, &input, size, &output, &size) == kIOReturnSuccess,
              output.result == 0 else { return nil }

        let dataSize = output.keyInfo_dataSize
        let dataType = output.keyInfo_dataType

        input.keyInfo_dataSize = dataSize
        input.data8 = 5  // kSMCReadKey
        size = MemoryLayout<SMCKeyData>.size

        guard IOConnectCallStructMethod(conn, 2, &input, size, &output, &size) == kIOReturnSuccess,
              output.result == 0 else { return nil }

        return parseTemperature(bytes: output.bytes, type: dataType)
    }

    private func fourCC(_ s: String) -> UInt32 {
        s.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }

    private func parseTemperature(bytes b: SMCKeyData.Bytes, type: UInt32) -> Double? {
        switch type {
        case fourCC("sp78"):
            // Fixed-point signed 7.8: integer part in byte 0, fractional in byte 1
            return Double(b.0) + Double(b.1) / 256.0
        case fourCC("flt "):
            // IEEE 754 single precision, big-endian
            let bits = UInt32(b.0) << 24 | UInt32(b.1) << 16 | UInt32(b.2) << 8 | UInt32(b.3)
            return Double(Float(bitPattern: bits))
        case fourCC("ui16"):
            return Double(UInt16(b.0) << 8 | UInt16(b.1))
        default:
            return nil
        }
    }
}

// MARK: - SMC Struct
//
// Must exactly match the C layout of SMCKeyData_t (80 bytes).
// Explicit padding fields are used to reproduce the compiler-inserted gaps:
//   _pad0 (2 bytes): aligns SMCPLimitData to a 4-byte boundary after SMCVersion
//   _pad1 (3 bytes): aligns data32 to a 4-byte boundary after data8
private struct SMCKeyData {
    typealias Bytes = (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )

    var key: UInt32 = 0                              // offset  0
    var vers_major: UInt8 = 0                        // offset  4
    var vers_minor: UInt8 = 0                        // offset  5
    var vers_build: UInt8 = 0                        // offset  6
    var vers_reserved: UInt8 = 0                     // offset  7
    var vers_release: UInt16 = 0                     // offset  8
    var _pad0: UInt16 = 0                            // offset 10 – aligns pLimitData to 12
    var pLimit_version: UInt16 = 0                   // offset 12
    var pLimit_length: UInt16 = 0                    // offset 14
    var pLimit_cpuPLimit: UInt32 = 0                 // offset 16
    var pLimit_gpuPLimit: UInt32 = 0                 // offset 20
    var pLimit_memPLimit: UInt32 = 0                 // offset 24
    var keyInfo_dataSize: UInt32 = 0                 // offset 28
    var keyInfo_dataType: UInt32 = 0                 // offset 32
    var keyInfo_dataAttr: UInt8 = 0                  // offset 36
    var padding: UInt8 = 0                           // offset 37
    var result: UInt8 = 0                            // offset 38
    var status: UInt8 = 0                            // offset 39
    var data8: UInt8 = 0                             // offset 40
    var _pad1: (UInt8, UInt8, UInt8) = (0, 0, 0)    // offset 41 – aligns data32 to 44
    var data32: UInt32 = 0                           // offset 44
    var bytes: Bytes = (                             // offset 48
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    )
}
