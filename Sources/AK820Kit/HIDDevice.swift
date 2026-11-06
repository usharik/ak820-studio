import Foundation
import IOKit
import IOKit.hid

/// Thin wrapper around one IOHIDDevice (one HID interface of the keyboard).
public final class HIDDevice {
    public let device: IOHIDDevice
    public let usagePage: Int
    public let productID: Int
    public let product: String

    // IOKit keeps writing into this buffer while input is scheduled, so it must not move.
    private let inputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: HIDDevice.inputBufferSize)
    private static let inputBufferSize = 4096
    private var lastInput: [UInt8]?

    init(_ device: IOHIDDevice) {
        self.device = device
        usagePage = HIDDevice.intProperty(device, kIOHIDPrimaryUsagePageKey) ?? 0
        productID = HIDDevice.intProperty(device, kIOHIDProductIDKey) ?? 0
        product = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "?"
    }

    deinit { inputBuffer.deallocate() }

    static func intProperty(_ d: IOHIDDevice, _ key: String) -> Int? {
        (IOHIDDeviceGetProperty(d, key as CFString) as? NSNumber)?.intValue
    }

    /// All HID interfaces with the given vendor/product IDs.
    public static func enumerate(vendorID: Int, productIDs: [Int]) -> [HIDDevice] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matches = productIDs.map { [kIOHIDVendorIDKey: vendorID, kIOHIDProductIDKey: $0] as CFDictionary }
        IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)
        guard let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [] }
        return set.map(HIDDevice.init)
    }

    public func open() throws {
        let r = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard r == kIOReturnSuccess else { throw AK820Error.io("open interface 0x\(hex(usagePage)) failed", r) }
    }

    public func close() {
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    // MARK: Feature reports (report ID 0, so the payload goes without an ID byte)

    public func setFeature(_ data: [UInt8]) throws {
        let r = data.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, 0, $0.baseAddress!, $0.count)
        }
        guard r == kIOReturnSuccess else { throw AK820Error.io("SetReport(feature) failed", r) }
    }

    public func getFeature(length: Int = 64) throws -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: length)
        var len = CFIndex(length)
        let r = buf.withUnsafeMutableBufferPointer {
            IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 0, $0.baseAddress!, &len)
        }
        guard r == kIOReturnSuccess else { throw AK820Error.io("GetReport(feature) failed", r) }
        return Array(buf.prefix(len))
    }

    // MARK: Output reports + waiting for an input report (TFT data interface)

    public func setOutput(_ data: [UInt8]) throws {
        let r = data.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0, $0.baseAddress!, $0.count)
        }
        guard r == kIOReturnSuccess else { throw AK820Error.io("SetReport(output) failed", r) }
    }

    /// Starts receiving input reports on the calling thread's run loop.
    public func beginInput() {
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, inputBuffer, HIDDevice.inputBufferSize, { ctx, _, _, _, _, report, length in
            let me = Unmanaged<HIDDevice>.fromOpaque(ctx!).takeUnretainedValue()
            me.lastInput = Array(UnsafeBufferPointer(start: report, count: length))
        }, ctx)
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }

    public func endInput() {
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }

    /// Runs the current run loop until an input report arrives or the timeout expires.
    public func waitInput(timeout: TimeInterval) -> [UInt8]? {
        lastInput = nil
        let deadline = Date().addingTimeInterval(timeout)
        while lastInput == nil, Date() < deadline {
            CFRunLoopRunInMode(.defaultMode, 0.01, true)
        }
        return lastInput
    }
}

public enum AK820Error: LocalizedError {
    case notFound
    case io(String, IOReturn)
    case rejected(String)
    case invalid(String)

    public var errorDescription: String? {
        switch self {
        case .notFound:
            return String(localized: "Keyboard not found. Connect the AK820 Pro with a USB-C cable (it can't be configured over Bluetooth).")
        case let .io(what, code):
            return "\(what) (IOReturn 0x\(String(UInt32(bitPattern: code), radix: 16)))"
        case let .rejected(what):
            return what
        case let .invalid(what):
            return what
        }
    }
}

func hex(_ v: Int) -> String { String(v, radix: 16, uppercase: true) }
