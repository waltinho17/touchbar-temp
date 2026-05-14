import IOKit
import Darwin

// Reads temperature from the Mac's thermal sensors.
//
// Apple Silicon: uses IOHIDEventSystemClient to query AppleARMPMUTempSensor
//                (PrimaryUsagePage 0xFF00, PrimaryUsage 0x0005).
//                These functions are in IOKit.framework but absent from
//                public Swift headers; we load them via dlsym at runtime.
//
// Intel fallback: traditional IOConnectCallStructMethod on AppleSMC.

final class TemperatureReader {

    private var cachedKey: String?
    private var scanned = false

    // Intel SMC connection (unused on Apple Silicon, kept for Intel fallback)
    private var smcConn: io_connect_t = 0
    private var smcConnected = false

    // Private IOHIDEventSystemClient functions, loaded once
    private let hid: HIDFunctions?

    init() {
        hid = HIDFunctions()
        let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        if svc != 0 {
            defer { IOObjectRelease(svc) }
            smcConnected = IOServiceOpen(svc, mach_task_self_, 0, &smcConn) == kIOReturnSuccess
        }
    }

    deinit { if smcConnected { IOServiceClose(smcConn) } }

    // MARK: - Public

    func currentTemperature() -> Double {
        if let t = hidTemperature(), t > 0 { return t }
        return intelSMCTemperature()
    }

    // MARK: - Apple Silicon (IOHIDEventSystem)

    private func hidTemperature() -> Double? {
        guard let fn = hid else { return nil }

        let client = fn.create(kCFAllocatorDefault)

        // Match AppleARMPMUTempSensor: AppleVendor usage page, TemperatureSensor usage
        let matching: CFDictionary = [
            "PrimaryUsagePage": 0xFF00,
            "PrimaryUsage":     0x0005
        ] as CFDictionary
        fn.setMatching(client, matching)

        guard let services = fn.copyServices(client) else {
            cfRelease(client)
            return nil
        }

        var maxTemp = 0.0
        for i in 0..<CFArrayGetCount(services) {
            guard let raw = CFArrayGetValueAtIndex(services, i) else { continue }
            let service = OpaquePointer(raw)
            guard let event = fn.copyEvent(service, 15, 0, 0.0) else { continue }
            let temp = fn.getFloat(event, UInt32(15) << 16)
            cfRelease(event)
            // Filter: valid temperatures are between 1 and 120 °C
            if temp > 1 && temp < 120 && temp > maxTemp { maxTemp = temp }
        }

        cfRelease(services)
        cfRelease(client)
        return maxTemp > 0 ? maxTemp : nil
    }

    // MARK: - Intel SMC fallback

    private func intelSMCTemperature() -> Double {
        if let key = cachedKey, let t = smcRead(key), valid(t) { return t }
        if scanned { return 0 }
        scanned = true

        let keys = ["TC0P", "TC0D", "TC0E", "TC0F"]
        for key in keys {
            if let t = smcRead(key), valid(t) {
                cachedKey = key
                return t
            }
        }
        return 0
    }

    private func valid(_ t: Double) -> Bool { t > 1 && t < 120 }

    // MARK: - SMC Read (Intel)

    private func smcRead(_ key: String) -> Double? {
        guard smcConnected else { return nil }

        var input = SMCKeyData()
        var output = SMCKeyData()
        var size = MemoryLayout<SMCKeyData>.size

        input.key = fourCC(key)
        input.data8 = 9  // kSMCGetKeyInfo
        guard IOConnectCallStructMethod(smcConn, 2, &input, size, &output, &size) == kIOReturnSuccess,
              output.result == 0 else { return nil }

        input.keyInfo_dataSize = output.keyInfo_dataSize
        input.data8 = 5  // kSMCReadKey
        size = MemoryLayout<SMCKeyData>.size
        guard IOConnectCallStructMethod(smcConn, 2, &input, size, &output, &size) == kIOReturnSuccess,
              output.result == 0 else { return nil }

        return parseTemp(bytes: output.bytes, type: output.keyInfo_dataType)
    }

    private func fourCC(_ s: String) -> UInt32 {
        s.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }

    private func parseTemp(bytes b: SMCKeyData.Bytes, type: UInt32) -> Double? {
        switch type {
        case fourCC("sp78"): return Double(b.0) + Double(b.1) / 256.0
        case fourCC("flt "):
            let bits = UInt32(b.0) << 24 | UInt32(b.1) << 16 | UInt32(b.2) << 8 | UInt32(b.3)
            return Double(Float(bitPattern: bits))
        default: return nil
        }
    }

    // MARK: - CF helpers

    private func cfRelease(_ ptr: OpaquePointer) {
        Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(ptr)).release()
    }

    private func cfRelease(_ arr: CFArray) {
        // CFArray is an ARC-managed CF type in Swift; explicit release via OpaquePointer
        cfRelease(OpaquePointer(Unmanaged.passUnretained(arr).toOpaque()))
    }
}

// MARK: - IOHIDEventSystemClient (private API, loaded dynamically from IOKit.framework)

private struct HIDFunctions {
    let create:      @convention(c) (CFAllocator?) -> OpaquePointer
    let setMatching: @convention(c) (OpaquePointer, CFDictionary) -> Void
    let copyServices: @convention(c) (OpaquePointer) -> CFArray?
    let copyEvent:   @convention(c) (OpaquePointer, UInt32, UInt32, Double) -> OpaquePointer?
    let getFloat:    @convention(c) (OpaquePointer, UInt32) -> Double

    init?() {
        // dlopen(nil) gives a handle that resolves symbols from all loaded images,
        // including IOKit.framework which is always linked by our app.
        let lib = dlopen(nil, RTLD_LAZY)

        guard
            let pCreate  = dlsym(lib, "IOHIDEventSystemClientCreate"),
            let pSetMatch = dlsym(lib, "IOHIDEventSystemClientSetMatching"),
            let pCopySvc = dlsym(lib, "IOHIDEventSystemClientCopyServices"),
            let pCopyEvt = dlsym(lib, "IOHIDServiceClientCopyEvent"),
            let pGetFlt  = dlsym(lib, "IOHIDEventGetFloatValue")
        else { return nil }

        create       = unsafeBitCast(pCreate,   to: (@convention(c) (CFAllocator?) -> OpaquePointer).self)
        setMatching  = unsafeBitCast(pSetMatch, to: (@convention(c) (OpaquePointer, CFDictionary) -> Void).self)
        copyServices = unsafeBitCast(pCopySvc,  to: (@convention(c) (OpaquePointer) -> CFArray?).self)
        copyEvent    = unsafeBitCast(pCopyEvt,  to: (@convention(c) (OpaquePointer, UInt32, UInt32, Double) -> OpaquePointer?).self)
        getFloat     = unsafeBitCast(pGetFlt,   to: (@convention(c) (OpaquePointer, UInt32) -> Double).self)
    }
}

// MARK: - SMC Struct (80 bytes, matches C SMCKeyData_t layout)
//
// Explicit padding fields reproduce compiler-inserted alignment gaps:
//   _pad0: aligns SMCPLimitData to 4-byte boundary after SMCVersion
//   _pad1: aligns data32 to 4-byte boundary after data8

private struct SMCKeyData {
    typealias Bytes = (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )
    var key: UInt32 = 0
    var vers_major: UInt8 = 0;    var vers_minor: UInt8 = 0
    var vers_build: UInt8 = 0;    var vers_reserved: UInt8 = 0
    var vers_release: UInt16 = 0; var _pad0: UInt16 = 0
    var pLimit_version: UInt16 = 0; var pLimit_length: UInt16 = 0
    var pLimit_cpuPLimit: UInt32 = 0; var pLimit_gpuPLimit: UInt32 = 0
    var pLimit_memPLimit: UInt32 = 0
    var keyInfo_dataSize: UInt32 = 0; var keyInfo_dataType: UInt32 = 0
    var keyInfo_dataAttr: UInt8 = 0
    var padding: UInt8 = 0; var result: UInt8 = 0
    var status: UInt8 = 0;  var data8: UInt8 = 0
    var _pad1: (UInt8, UInt8, UInt8) = (0, 0, 0)
    var data32: UInt32 = 0
    var bytes: Bytes = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}
