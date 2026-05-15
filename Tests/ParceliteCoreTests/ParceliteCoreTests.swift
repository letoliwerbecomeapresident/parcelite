import XCTest
@testable import ParceliteCore

final class ParceliteCoreTests: XCTestCase {
    func testMilestoneDisplayAndProgressAreEnglish() {
        XCTAssertEqual(Milestone.pending.displayName, "Pending")
        XCTAssertEqual(Milestone.infoReceived.displayName, "Info received")
        XCTAssertEqual(Milestone.inTransit.displayName, "In transit")
        XCTAssertEqual(Milestone.outForDelivery.displayName, "Out for delivery")
        XCTAssertEqual(Milestone.availableForPickup.displayName, "Ready for pickup")
        XCTAssertEqual(Milestone.failedAttempt.displayName, "Delivery attempt failed")
        XCTAssertEqual(Milestone.delivered.displayName, "Delivered")
        XCTAssertEqual(Milestone.exception.displayName, "Exception")
        XCTAssertEqual(Milestone.unknown.displayName, "Unknown")
        XCTAssertEqual(Milestone.delivered.progress, 1.0)
        XCTAssertGreaterThan(Milestone.outForDelivery.progress, Milestone.inTransit.progress)
    }

    func testUnknownMilestoneDecodesAsUnknown() throws {
        let data = #""carrier_renamed_status""#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Milestone.self, from: data)
        XCTAssertEqual(decoded, .unknown)
    }

    func testShip24ResponseParsing() throws {
        let url = Bundle.module.url(forResource: "ship24-track-response", withExtension: "json")!
        let result = try Ship24Client.parse(Data(contentsOf: url))

        XCTAssertEqual(result.milestone, .inTransit)
        XCTAssertEqual(result.courier, "DHL Parcel")
        XCTAssertEqual(result.events.count, 2)
        XCTAssertEqual(result.events[0].status, "Shipment departed facility")
        XCTAssertEqual(result.events[0].location, "Warsaw, Poland")
    }

    @MainActor
    func testPackagePersistenceAndPlainApiKeyMigration() {
        let defaults = makeDefaults()
        let secrets = MemorySecretStore()
        defaults.set(" plain-token ", forKey: AppConstants.legacyApiKeyStorageKey)

        let store = TrackingStore(
            userDefaults: defaults,
            legacyDefaults: nil,
            secretStore: secrets,
            notificationPoster: MemoryNotifier(),
            startTimer: false,
            refreshOnLaunch: false
        )

        let result = store.add(label: "Home order", trackingNumber: " ABC 12345 ")
        guard case .added(let package) = result else {
            return XCTFail("Expected package to be added")
        }
        XCTAssertEqual(package.trackingNumber, "ABC12345")
        XCTAssertEqual(store.apiKey, "plain-token")
        XCTAssertEqual(try secrets.read(account: AppConstants.legacyApiKeyStorageKey), "plain-token")
        XCTAssertNil(defaults.string(forKey: AppConstants.legacyApiKeyStorageKey))

        let reloaded = TrackingStore(
            userDefaults: defaults,
            legacyDefaults: nil,
            secretStore: secrets,
            notificationPoster: MemoryNotifier(),
            startTimer: false,
            refreshOnLaunch: false
        )
        XCTAssertEqual(reloaded.packages.count, 1)
        XCTAssertEqual(reloaded.packages[0].label, "Home order")
        XCTAssertEqual(reloaded.packages[0].trackingNumber, "ABC12345")
    }

    @MainActor
    func testLegacyPackageMigrationUsesInjectedDefaults() throws {
        let current = makeDefaults()
        let legacy = makeDefaults()
        let package = Package(label: "Legacy", trackingNumber: "LM134239509CN")
        legacy.set(try JSONEncoder().encode([package]), forKey: AppConstants.packageStorageKey)

        let store = TrackingStore(
            userDefaults: current,
            legacyDefaults: legacy,
            secretStore: MemorySecretStore(),
            notificationPoster: MemoryNotifier(),
            startTimer: false,
            refreshOnLaunch: false
        )

        XCTAssertEqual(store.packages, [package])
        XCTAssertNotNil(current.data(forKey: AppConstants.packageStorageKey))
    }

    @MainActor
    func testDuplicateAndInvalidTrackingNumbersAreRejected() {
        let store = TrackingStore(
            userDefaults: makeDefaults(),
            legacyDefaults: nil,
            secretStore: MemorySecretStore(),
            notificationPoster: MemoryNotifier(),
            startTimer: false,
            refreshOnLaunch: false
        )

        XCTAssertEqual(store.add(label: "", trackingNumber: "A1").invalidMessage, "Enter a valid tracking number.")
        XCTAssertNotNil(store.add(label: "", trackingNumber: "ABCD1234").addedPackage)
        XCTAssertEqual(
            store.add(label: "", trackingNumber: " abcd 1234 ").duplicateMessage,
            "This tracking number is already in your list."
        )
        XCTAssertEqual(store.packages.count, 1)
    }

    func testKeychainSecretStoreRoundTripWithIsolatedService() throws {
        let service = "com.oliwer.parcelite.tests.\(UUID().uuidString)"
        let store = KeychainSecretStore(service: service)
        let account = "ship24ApiKey"

        try store.delete(account: account)
        XCTAssertNil(try store.read(account: account))

        try store.save("first", account: account)
        XCTAssertEqual(try store.read(account: account), "first")

        try store.save("second", account: account)
        XCTAssertEqual(try store.read(account: account), "second")

        try store.delete(account: account)
        XCTAssertNil(try store.read(account: account))
    }

    private func makeDefaults() -> UserDefaults {
        let name = "com.oliwer.parcelite.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}

private extension AddPackageResult {
    var addedPackage: Package? {
        if case .added(let package) = self { return package }
        return nil
    }

    var invalidMessage: String? {
        if case .invalid(let message) = self { return message }
        return nil
    }

    var duplicateMessage: String? {
        if case .duplicate(let message) = self { return message }
        return nil
    }
}

private final class MemorySecretStore: SecretStore, @unchecked Sendable {
    private var values: [String: String] = [:]

    func read(account: String) throws -> String? {
        values[account]
    }

    func save(_ value: String, account: String) throws {
        values[account] = value
    }

    func delete(account: String) throws {
        values.removeValue(forKey: account)
    }
}

private struct MemoryNotifier: NotificationPosting {
    func post(title: String, body: String) {}
}
