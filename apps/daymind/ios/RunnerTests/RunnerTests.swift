import Flutter
import Security
import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  func testScopedKeyValidation() {
    for key in ["session", "installation", "test_probe", "offline.session",
      "production.daymind-prod.session", "production.daymind-prod.installation"] {
      XCTAssertTrue(DayMindKeychain.validKey(key))
    }
    for key in ["", "../session", "x.session", "production.X.session", "production.daymind-prod.session\n", "offline.test_probe"] {
      XCTAssertFalse(DayMindKeychain.validKey(key))
    }
  }
  func testNativeKeychainRoundTripIsolationAndDeletion() throws {
    // Synthetic values only; test target host owns this app's Keychain service.
    let keys = ["test_probe", "offline.session", "production.daymind-ci.session"]
    defer { for key in keys { try? DayMindKeychain.delete(key) } }
    for key in keys { try DayMindKeychain.delete(key) }
    XCTAssertNil(try DayMindKeychain.read(keys[0]))
    try DayMindKeychain.write(keys[0], "probe-1")
    XCTAssertEqual(try DayMindKeychain.read(keys[0]), "probe-1")
    try DayMindKeychain.write(keys[0], "probe-2")
    try DayMindKeychain.write(keys[1], "offline-probe")
    try DayMindKeychain.write(keys[2], "production-probe")
    XCTAssertEqual(try DayMindKeychain.read(keys[0]), "probe-2")
    XCTAssertEqual(try DayMindKeychain.read(keys[1]), "offline-probe")
    XCTAssertEqual(try DayMindKeychain.read(keys[2]), "production-probe")
    XCTAssertThrowsError(try DayMindKeychain.write(keys[0], String(repeating: "a", count: 65537)))
    XCTAssertEqual(try DayMindKeychain.read(keys[0]), "probe-2")
    try DayMindKeychain.delete(keys[0]); try DayMindKeychain.delete(keys[0])
    XCTAssertNil(try DayMindKeychain.read(keys[0]))
  }
}
