import Foundation

public enum AppConstants {
    public static let appName = "Parcelite"
    public static let bundleIdentifier = "com.oliwer.parcelite"
    public static let legacyBundleIdentifier = "com.oliwer.paczkometer"
    public static let packageStorageKey = "packages.v1"
    public static let legacyApiKeyStorageKey = "ship24ApiKey"
    public static let migrationFlagKey = "migration.paczkometer.v1.completed"
    public static let defaultRefreshInterval: TimeInterval = 300
}
