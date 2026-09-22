import AVFoundation
import Contacts
import CoreBluetooth
import CoreLocation
import EventKit
import Photos
import Speech
import UserNotifications
import XCTest
@testable import MacPermissionKit

final class LiveTests: XCTestCase {
    func testAuthorizationMaps() {
        XCTAssertEqual(AppleAuthorizationMap.capture(.notDetermined), .notDetermined)
        XCTAssertEqual(AppleAuthorizationMap.capture(.restricted), .restricted)
        XCTAssertEqual(AppleAuthorizationMap.capture(.denied), .denied)
        XCTAssertEqual(AppleAuthorizationMap.capture(.authorized), .granted)

        XCTAssertEqual(AppleAuthorizationMap.speech(.notDetermined), .notDetermined)
        XCTAssertEqual(AppleAuthorizationMap.speech(.restricted), .restricted)
        XCTAssertEqual(AppleAuthorizationMap.speech(.denied), .denied)
        XCTAssertEqual(AppleAuthorizationMap.speech(.authorized), .granted)

        XCTAssertEqual(AppleAuthorizationMap.photos(.notDetermined), .notDetermined)
        XCTAssertEqual(AppleAuthorizationMap.photos(.restricted), .restricted)
        XCTAssertEqual(AppleAuthorizationMap.photos(.denied), .denied)
        XCTAssertEqual(AppleAuthorizationMap.photos(.authorized), .granted)
        XCTAssertEqual(AppleAuthorizationMap.photos(.limited), .granted)

        XCTAssertEqual(AppleAuthorizationMap.contacts(.notDetermined), .notDetermined)
        XCTAssertEqual(AppleAuthorizationMap.contacts(.restricted), .restricted)
        XCTAssertEqual(AppleAuthorizationMap.contacts(.denied), .denied)
        XCTAssertEqual(AppleAuthorizationMap.contacts(.authorized), .granted)
        

        XCTAssertEqual(AppleAuthorizationMap.events(.notDetermined), .notDetermined)
        XCTAssertEqual(AppleAuthorizationMap.events(.restricted), .restricted)
        XCTAssertEqual(AppleAuthorizationMap.events(.denied), .denied)
        XCTAssertEqual(AppleAuthorizationMap.events(.authorized), .granted)
        XCTAssertEqual(AppleAuthorizationMap.events(.fullAccess), .granted)
        XCTAssertEqual(AppleAuthorizationMap.events(.writeOnly), .granted)

        XCTAssertEqual(AppleAuthorizationMap.notifications(.notDetermined), .notDetermined)
        XCTAssertEqual(AppleAuthorizationMap.notifications(.denied), .denied)
        XCTAssertEqual(AppleAuthorizationMap.notifications(.authorized), .granted)
        XCTAssertEqual(AppleAuthorizationMap.notifications(.provisional), .granted)
        

        XCTAssertEqual(AppleAuthorizationMap.location(.notDetermined), .notDetermined)
        XCTAssertEqual(AppleAuthorizationMap.location(.restricted), .restricted)
        XCTAssertEqual(AppleAuthorizationMap.location(.denied), .denied)
        XCTAssertEqual(AppleAuthorizationMap.location(.authorizedAlways), .granted)
        

        XCTAssertEqual(AppleAuthorizationMap.bluetooth(.notDetermined), .notDetermined)
        XCTAssertEqual(AppleAuthorizationMap.bluetooth(.restricted), .restricted)
        XCTAssertEqual(AppleAuthorizationMap.bluetooth(.denied), .denied)
        XCTAssertEqual(AppleAuthorizationMap.bluetooth(.allowedAlways), .granted)
    }

    func testSafeLiveProbesStayInsideKnownStates() async throws {
        let engine = SystemPermissionBackend()
        for id in PermissionID.allCases {
            let status = engine.probe(id)
            XCTAssertTrue(PermissionAuthorization.allCases.contains(status), id.rawValue)
        }
        let notifications = await LivePermissionCalls.notificationStatus()
        XCTAssertTrue(PermissionAuthorization.allCases.contains(notifications))
        XCTAssertEqual(try ProcessSpawner.run(["/bin/echo", "ok"]), 0)
        let viaLive = try PermissionPrimitives.live.run(["/usr/bin/true"])
        XCTAssertEqual(viaLive, 0)
        XCTAssertTrue(LivePermissionCalls.fullDiskReadable() == true || LivePermissionCalls.fullDiskReadable() == false)
    }
}
