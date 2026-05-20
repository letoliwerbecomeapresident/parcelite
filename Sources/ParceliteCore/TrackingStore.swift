import Combine
import Foundation

public enum AddPackageResult: Equatable {
    case added(Package)
    case invalid(String)
    case duplicate(String)
}

@MainActor
public final class TrackingStore: ObservableObject {
    @Published public var packages: [Package] = []
    @Published public var apiKey: String {
        didSet { persistApiKey() }
    }
    @Published public var isRefreshing = false
    @Published public var inputError: String?

    private let userDefaults: UserDefaults
    private let legacyDefaults: UserDefaults?
    private let secretStore: SecretStore
    private let notificationPoster: NotificationPosting
    private let providerFactory: @Sendable (String) -> any TrackingProvider
    private let refreshInterval: TimeInterval
    private var timer: Timer?

    public var anyInTransit: Bool {
        packages.contains { $0.milestone != .delivered && $0.milestone != .unknown }
    }

    public init(
        userDefaults: UserDefaults = .standard,
        legacyDefaults: UserDefaults? = UserDefaults(suiteName: AppConstants.legacyBundleIdentifier),
        secretStore: SecretStore = KeychainSecretStore(),
        notificationPoster: NotificationPosting = LocalNotificationNotifier(),
        refreshInterval: TimeInterval = AppConstants.defaultRefreshInterval,
        providerFactory: @escaping @Sendable (String) -> any TrackingProvider = { RoutingProvider(apiKey: $0) },
        startTimer: Bool = true,
        refreshOnLaunch: Bool = true
    ) {
        self.userDefaults = userDefaults
        self.legacyDefaults = legacyDefaults
        self.secretStore = secretStore
        self.notificationPoster = notificationPoster
        self.refreshInterval = refreshInterval
        self.providerFactory = providerFactory
        self.apiKey = ""

        migrateLegacyPreferences()
        self.apiKey = (try? secretStore.read(account: AppConstants.legacyApiKeyStorageKey)) ?? ""
        removePlainApiKeyIfPresent()
        load()

        if startTimer {
            timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in await self?.refreshAll() }
            }
        }

        if refreshOnLaunch {
            Task { await refreshAll() }
        }
    }

    deinit {
        timer?.invalidate()
    }

    public func load() {
        guard let data = userDefaults.data(forKey: AppConstants.packageStorageKey),
              let decoded = try? JSONDecoder().decode([Package].self, from: data) else { return }
        packages = decoded
    }

    public func save() {
        if let data = try? JSONEncoder().encode(packages) {
            userDefaults.set(data, forKey: AppConstants.packageStorageKey)
        }
    }

    @discardableResult
    public func add(label: String, trackingNumber: String) -> AddPackageResult {
        let normalized = Self.normalizedTrackingNumber(trackingNumber)
        guard Self.isValidTrackingNumber(normalized) else {
            let message = "Enter a valid tracking number."
            inputError = message
            return .invalid(message)
        }

        if packages.contains(where: { Self.normalizedTrackingNumber($0.trackingNumber).caseInsensitiveCompare(normalized) == .orderedSame }) {
            let message = "This tracking number is already in your list."
            inputError = message
            return .duplicate(message)
        }

        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let package = Package(label: cleanLabel.isEmpty ? normalized : cleanLabel, trackingNumber: normalized)
        packages.append(package)
        inputError = nil
        save()
        Task { await refresh(package.id) }
        return .added(package)
    }

    public func remove(_ id: UUID) {
        packages.removeAll { $0.id == id }
        save()
    }

    public func archive(_ id: UUID) {
        if let index = packages.firstIndex(where: { $0.id == id }) {
            packages[index].isArchived = true
            save()
        }
    }

    public func unarchive(_ id: UUID) {
        if let index = packages.firstIndex(where: { $0.id == id }) {
            packages[index].isArchived = false
            save()
        }
    }


    public func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }
        for package in packages {
            if package.isArchived { continue }
            if !TrackingStore.isInPost(package.trackingNumber) && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            await refresh(package.id)
        }
    }

    public func refresh(_ id: UUID) async {
        guard let index = packages.firstIndex(where: { $0.id == id }) else { return }
        let trackingNumber = packages[index].trackingNumber
        let previousMilestone = packages[index].milestone
        let previousEventCount = packages[index].events.count
        let label = packages[index].label

        do {
            let provider = providerFactory(apiKey)
            let result = try await provider.track(trackingNumber: trackingNumber)
            packages[index].milestone = result.milestone
            packages[index].events = result.events
            packages[index].courier = result.courier ?? packages[index].courier
            packages[index].lastUpdated = Date()
            packages[index].lastError = nil

            if previousMilestone != .unknown, result.milestone != previousMilestone {
                notificationPoster.post(title: label, body: "Status: \(result.milestone.displayName)")
            } else if previousMilestone != .unknown,
                      result.events.count > previousEventCount,
                      let latest = result.events.first {
                notificationPoster.post(title: label, body: latest.status)
            }
        } catch {
            packages[index].lastError = error.localizedDescription
        }

        save()
    }

    public static func normalizedTrackingNumber(_ value: String) -> String {
        value.filter { !$0.isWhitespace && !$0.isNewline }
    }

    public static func isValidTrackingNumber(_ value: String) -> Bool {
        guard (4...80).contains(value.count) else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_./"))
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private func persistApiKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if trimmed.isEmpty {
                try secretStore.delete(account: AppConstants.legacyApiKeyStorageKey)
            } else {
                try secretStore.save(trimmed, account: AppConstants.legacyApiKeyStorageKey)
                if trimmed != apiKey {
                    apiKey = trimmed
                }
            }
            removePlainApiKeyIfPresent()
        } catch {
            inputError = "Could not save the API key to Keychain: \(error.localizedDescription)"
        }
    }

    private func migrateLegacyPreferences() {
        let currentHasPackages = userDefaults.data(forKey: AppConstants.packageStorageKey) != nil

        if !currentHasPackages,
           let legacyData = legacyDefaults?.data(forKey: AppConstants.packageStorageKey) {
            userDefaults.set(legacyData, forKey: AppConstants.packageStorageKey)
        }

        if (try? secretStore.read(account: AppConstants.legacyApiKeyStorageKey)) == nil {
            let plainKey = userDefaults.string(forKey: AppConstants.legacyApiKeyStorageKey)
                ?? legacyDefaults?.string(forKey: AppConstants.legacyApiKeyStorageKey)
            if let plainKey, !plainKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try? secretStore.save(
                    plainKey.trimmingCharacters(in: .whitespacesAndNewlines),
                    account: AppConstants.legacyApiKeyStorageKey
                )
            }
        }

        legacyDefaults?.removeObject(forKey: AppConstants.legacyApiKeyStorageKey)
        userDefaults.set(true, forKey: AppConstants.migrationFlagKey)
    }

    private func removePlainApiKeyIfPresent() {
        userDefaults.removeObject(forKey: AppConstants.legacyApiKeyStorageKey)
    }

    nonisolated public static func isInPost(_ value: String) -> Bool {
        value.range(of: "^[0-9]{24}$", options: .regularExpression) != nil
    }
}

public struct RoutingProvider: TrackingProvider, Sendable {
    public let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func track(trackingNumber: String) async throws -> TrackingResult {
        if TrackingStore.isInPost(trackingNumber) {
            return try await InPostClient().track(trackingNumber: trackingNumber)
        } else {
            return try await Ship24Client(apiKey: apiKey).track(trackingNumber: trackingNumber)
        }
    }
}

