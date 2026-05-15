import Foundation

public enum Milestone: String, Codable, Equatable, CaseIterable, Sendable {
    case pending
    case infoReceived = "info_received"
    case inTransit = "in_transit"
    case outForDelivery = "out_for_delivery"
    case availableForPickup = "available_for_pickup"
    case failedAttempt = "failed_attempt"
    case delivered
    case exception
    case unknown

    public init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = Milestone(rawValue: rawValue) ?? .unknown
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var progress: Double {
        switch self {
        case .pending: return 0.05
        case .infoReceived: return 0.15
        case .inTransit: return 0.5
        case .outForDelivery: return 0.8
        case .availableForPickup: return 0.9
        case .delivered: return 1.0
        case .failedAttempt, .exception: return 0.6
        case .unknown: return 0.0
        }
    }

    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .infoReceived: return "Info received"
        case .inTransit: return "In transit"
        case .outForDelivery: return "Out for delivery"
        case .availableForPickup: return "Ready for pickup"
        case .failedAttempt: return "Delivery attempt failed"
        case .delivered: return "Delivered"
        case .exception: return "Exception"
        case .unknown: return "Unknown"
        }
    }
}

public struct TrackingEvent: Codable, Identifiable, Equatable, Sendable {
    public var id: String { (datetime ?? "") + status + (location ?? "") }
    public let status: String
    public let datetime: String?
    public let location: String?

    public init(status: String, datetime: String? = nil, location: String? = nil) {
        self.status = status
        self.datetime = datetime
        self.location = location
    }
}

public struct Package: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var label: String
    public var trackingNumber: String
    public var courier: String?
    public var milestone: Milestone
    public var lastUpdated: Date?
    public var events: [TrackingEvent]
    public var lastError: String?

    public init(
        id: UUID = UUID(),
        label: String,
        trackingNumber: String,
        courier: String? = nil,
        milestone: Milestone = .unknown,
        lastUpdated: Date? = nil,
        events: [TrackingEvent] = [],
        lastError: String? = nil
    ) {
        self.id = id
        self.label = label
        self.trackingNumber = trackingNumber
        self.courier = courier
        self.milestone = milestone
        self.lastUpdated = lastUpdated
        self.events = events
        self.lastError = lastError
    }
}
