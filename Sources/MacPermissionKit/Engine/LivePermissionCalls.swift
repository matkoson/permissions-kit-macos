import AppKit
 import ApplicationServices
import AVFoundation
import Contacts
import CoreBluetooth
import CoreGraphics
import CoreLocation
import Darwin
import EventKit
import Foundation
import IOKit.hid
import Photos
import Speech
import UserNotifications

enum AppleAuthorizationMap {
    static func capture(_ status: AVAuthorizationStatus) -> PermissionAuthorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .granted
        @unknown default: return .unknown
        }
    }

    static func speech(_ status: SFSpeechRecognizerAuthorizationStatus) -> PermissionAuthorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .granted
        @unknown default: return .unknown
        }
    }

    static func photos(_ status: PHAuthorizationStatus) -> PermissionAuthorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized, .limited: return .granted
        @unknown default: return .unknown
        }
    }

    static func contacts(_ status: CNAuthorizationStatus) -> PermissionAuthorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized, .limited: return .granted
        @unknown default: return .unknown
        }
    }

    static func events(_ status: EKAuthorizationStatus) -> PermissionAuthorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized, .fullAccess, .writeOnly: return .granted
        @unknown default: return .unknown
        }
    }

    static func notifications(_ status: UNAuthorizationStatus) -> PermissionAuthorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized, .provisional, .ephemeral: return .granted
        @unknown default: return .unknown
        }
    }

    static func location(_ status: CLAuthorizationStatus) -> PermissionAuthorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized, .authorizedAlways, .authorizedWhenInUse: return .granted
        @unknown default: return .unknown
        }
    }

    static func bluetooth(_ status: CBManagerAuthorization) -> PermissionAuthorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .allowedAlways: return .granted
        @unknown default: return .unknown
        }
    }

    static func inputMonitoring(_ access: IOHIDAccessType) -> PermissionAuthorization {
        switch access {
        case kIOHIDAccessTypeGranted: return .granted
        case kIOHIDAccessTypeDenied: return .denied
        default: return .unknown
        }
    }
}

enum LivePermissionCalls {
    static var primitives: PermissionPrimitives {
        PermissionPrimitives(
            accessibilityTrusted: { accessibilityTrusted(prompt: $0) },
            screenPreflight: { screenPreflight() },
            screenRequest: { screenRequest() },
            inputStatus: { inputStatus() },
            inputRequest: { inputRequest() },
            captureStatus: { captureStatus(video: $0) },
            captureRequest: { await captureRequest(video: $0) },
            speechStatus: { speechStatus() },
            speechRequest: { await speechRequest() },
            photosStatus: { photosStatus(addOnly: $0) },
            photosRequest: { await photosRequest(addOnly: $0) },
            contactsStatus: { contactsStatus() },
            contactsRequest: { await contactsRequest() },
            eventsStatus: { eventsStatus(reminders: $0) },
            eventsRequest: { await eventsRequest(reminders: $0) },
            mediaStatus: { mediaStatus() },
            mediaRequest: { await mediaRequest() },
            notificationStatus: { await notificationStatus() },
            notificationRequest: { await notificationRequest() },
            locationStatus: { locationStatus() },
            locationRequest: { await locationRequest() },
            bluetoothStatus: { bluetoothStatus() },
            bluetoothRequest: { await bluetoothRequest() },
            automationRequest: { automationRequest() },
            localNetworkNudge: { localNetworkNudge() },
            fullDiskReadable: { fullDiskReadable() },
            openURL: { await openURL($0) },
            run: { try ProcessSpawner.run($0) }
        )
    }

    static func accessibilityTrusted(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func screenPreflight() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func screenRequest() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    static func inputStatus() -> PermissionAuthorization {
        AppleAuthorizationMap.inputMonitoring(IOHIDCheckAccess(kIOHIDRequestTypeListenEvent))
    }

    static func inputRequest() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    static func captureStatus(video: Bool) -> PermissionAuthorization {
        let media: AVMediaType = video ? .video : .audio
        return AppleAuthorizationMap.capture(AVCaptureDevice.authorizationStatus(for: media))
    }

    static func captureRequest(video: Bool) async -> Bool {
        let media: AVMediaType = video ? .video : .audio
        return await AVCaptureDevice.requestAccess(for: media)
    }

    static func speechStatus() -> PermissionAuthorization {
        AppleAuthorizationMap.speech(SFSpeechRecognizer.authorizationStatus())
    }

    static func speechRequest() async -> PermissionAuthorization {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: AppleAuthorizationMap.speech(status))
            }
        }
    }

    static func photosStatus(addOnly: Bool) -> PermissionAuthorization {
        let level: PHAccessLevel = addOnly ? .addOnly : .readWrite
        return AppleAuthorizationMap.photos(PHPhotoLibrary.authorizationStatus(for: level))
    }

    static func photosRequest(addOnly: Bool) async -> PermissionAuthorization {
        let level: PHAccessLevel = addOnly ? .addOnly : .readWrite
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: level) { status in
                continuation.resume(returning: AppleAuthorizationMap.photos(status))
            }
        }
    }

    static func contactsStatus() -> PermissionAuthorization {
        AppleAuthorizationMap.contacts(CNContactStore.authorizationStatus(for: .contacts))
    }

    static func contactsRequest() async -> PermissionAuthorization {
        let store = CNContactStore()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            return granted ? .granted : .denied
        } catch {
            return .denied
        }
    }

    static func eventsStatus(reminders: Bool) -> PermissionAuthorization {
        let entity: EKEntityType = reminders ? .reminder : .event
        return AppleAuthorizationMap.events(EKEventStore.authorizationStatus(for: entity))
    }

    static func eventsRequest(reminders: Bool) async -> PermissionAuthorization {
        let store = EKEventStore()
        do {
            let granted = reminders
                ? try await store.requestFullAccessToReminders()
                : try await store.requestFullAccessToEvents()
            return granted ? .granted : .denied
        } catch {
            return .denied
        }
    }

    static func mediaStatus() -> PermissionAuthorization {
        .unknown
    }

    static func mediaRequest() async -> PermissionAuthorization {
        .unknown
    }

    static func notificationStatus() async -> PermissionAuthorization {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            return .unknown
        }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return AppleAuthorizationMap.notifications(settings.authorizationStatus)
    }

    static func notificationRequest() async -> PermissionAuthorization {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            return .unknown
        }
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            return granted ? .granted : .denied
        } catch {
            return .denied
        }
    }

    static func locationStatus() -> PermissionAuthorization {
        let manager = CLLocationManager()
        return AppleAuthorizationMap.location(manager.authorizationStatus)
    }

    static func locationRequest() async -> PermissionAuthorization {
        await MainActor.run {
            LocationPromptBox.shared.request()
        }
        return locationStatus()
    }

    static func bluetoothStatus() -> PermissionAuthorization {
        AppleAuthorizationMap.bluetooth(CBManager.authorization)
    }

    static func bluetoothRequest() async -> PermissionAuthorization {
        await MainActor.run {
            BluetoothPromptBox.shared.request()
        }
        return bluetoothStatus()
    }

    static func automationRequest() -> PermissionAuthorization {
        let source = "tell application \"System Events\" to get name"
        guard let script = NSAppleScript(source: source) else {
            return .unknown
        }
        var error: NSDictionary?
        _ = script.executeAndReturnError(&error)
        guard let error else {
            return .granted
        }
        if let number = error[NSAppleScript.errorNumber] as? Int, number == -1743 {
            return .denied
        }
        if let number = error[NSAppleScript.errorNumber] as? NSNumber, number.intValue == -1743 {
            return .denied
        }
        return .unknown
    }

    static func localNetworkNudge() {
        let descriptor = socket(AF_INET, SOCK_DGRAM, 0)
        guard descriptor >= 0 else { return }
        defer { close(descriptor) }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = UInt16(5353).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("224.0.0.251"))
        let payload: [UInt8] = [0x00]
        _ = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { rebound in
                sendto(descriptor, payload, payload.count, 0, rebound, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }

    static func fullDiskReadable() -> Bool {
        FileManager.default.isReadableFile(atPath: "/Library/Preferences/com.apple.TimeMachine.plist")
    }

    static func openURL(_ url: URL) async -> Bool {
        await MainActor.run {
            NSWorkspace.shared.open(url)
        }
    }
}

@MainActor
private final class LocationPromptBox: NSObject, CLLocationManagerDelegate {
    static let shared = LocationPromptBox()
    private let manager = CLLocationManager()

    func request() {
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {}
}

@MainActor
private final class BluetoothPromptBox: NSObject, CBCentralManagerDelegate {
    static let shared = BluetoothPromptBox()
    private var manager: CBCentralManager?

    func request() {
        if manager == nil {
            manager = CBCentralManager(delegate: self, queue: nil)
        }
    }

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {}
}
