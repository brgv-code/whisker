import Foundation
import IOKit.hid
import WhiskerCore

struct ConnectedDevice: Hashable, Identifiable, Sendable {
    var id: DeviceID
    var name: String
}

/// Watches HID devices. CGEvents do not say which device sent them, so this tracks the last mouse that moved
/// and the last keyboard interface that typed (some mice type shortcuts through one).
final class DeviceMonitor: @unchecked Sendable {
    // Confined to the input thread: only touched from callbacks on the run loop it was scheduled on.
    private(set) var lastPointer: DeviceID?
    private(set) var lastKeyboard: DeviceID?
    private var pointers: [ObjectIdentifier: ConnectedDevice] = [:]
    private var keyboards: [ObjectIdentifier: DeviceID] = [:]
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private let onChange: @Sendable ([ConnectedDevice]) -> Void

    init(onChange: @escaping @Sendable ([ConnectedDevice]) -> Void) {
        self.onChange = onChange
    }

    func schedule(on runLoop: CFRunLoop) {
        let matches: [[String: Int]] = [kHIDUsage_GD_Mouse, kHIDUsage_GD_Pointer, kHIDUsage_GD_Keyboard].map {
            [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: $0]
        }
        IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)
        let context = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterDeviceMatchingCallback(
            manager,
            { context, _, _, device in
                DeviceMonitor.from(context).added(device)
            }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(
            manager,
            { context, _, _, device in
                DeviceMonitor.from(context).removed(device)
            }, context)
        IOHIDManagerRegisterInputValueCallback(
            manager,
            { context, _, _, value in
                DeviceMonitor.from(context).received(value)
            }, context)

        IOHIDManagerScheduleWithRunLoop(manager, runLoop, CFRunLoopMode.defaultMode.rawValue)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result != kIOReturnSuccess {
            NSLog("Whisker: HID manager failed to open (\(result)); Input Monitoring is probably not granted")
        }
    }

    private static func from(_ context: UnsafeMutableRawPointer?) -> DeviceMonitor {
        Unmanaged<DeviceMonitor>.fromOpaque(context!).takeUnretainedValue()
    }

    private func added(_ device: IOHIDDevice) {
        let vendor = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int ?? 0
        let product = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int ?? 0
        // A device without IDs cannot be matched to saved settings or a profile.
        guard vendor != 0 || product != 0 else { return }
        let id = DeviceID(vendorID: vendor, productID: product)
        let usage = IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsageKey as CFString) as? Int
        if usage == kHIDUsage_GD_Keyboard {
            keyboards[ObjectIdentifier(device)] = id
            return
        }
        let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown mouse"
        pointers[ObjectIdentifier(device)] = ConnectedDevice(id: id, name: name)
        publish()
    }

    private func removed(_ device: IOHIDDevice) {
        keyboards.removeValue(forKey: ObjectIdentifier(device))
        if pointers.removeValue(forKey: ObjectIdentifier(device)) != nil { publish() }
    }

    private func received(_ value: IOHIDValue) {
        let device = ObjectIdentifier(IOHIDElementGetDevice(IOHIDValueGetElement(value)))
        if let keyboard = keyboards[device] {
            lastKeyboard = keyboard
        } else {
            lastPointer = pointers[device]?.id
        }
    }

    private func publish() {
        var seen = Set<DeviceID>()
        let devices = pointers.values.filter { seen.insert($0.id).inserted }.sorted { $0.name < $1.name }
        onChange(devices)
    }
}
