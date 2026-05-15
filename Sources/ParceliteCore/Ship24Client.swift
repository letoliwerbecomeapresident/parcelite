import Foundation

public protocol TrackingProvider: Sendable {
    func track(trackingNumber: String) async throws -> TrackingResult
}

public struct TrackingResult: Equatable, Sendable {
    public let milestone: Milestone
    public let events: [TrackingEvent]
    public let courier: String?

    public init(milestone: Milestone, events: [TrackingEvent], courier: String?) {
        self.milestone = milestone
        self.events = events
        self.courier = courier
    }
}

public struct Ship24Client: TrackingProvider {
    public let apiKey: String
    public let endpoint: URL
    public let timeout: TimeInterval

    public init(
        apiKey: String,
        endpoint: URL = URL(string: "https://api.ship24.com/public/v1/trackers/track")!,
        timeout: TimeInterval = 90
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.timeout = timeout
    }

    public enum Ship24Error: Error, LocalizedError, Equatable {
        case missingKey
        case unauthorized
        case notFound
        case rateLimited
        case timedOut
        case http(Int)
        case malformedResponse
        case network(String)

        public var errorDescription: String? {
            switch self {
            case .missingKey:
                return "Add your Ship24 API key in Settings."
            case .unauthorized:
                return "Ship24 rejected the API key."
            case .notFound:
                return "No shipment was found for this tracking number."
            case .rateLimited:
                return "Ship24 rate limit reached. Try again later."
            case .timedOut:
                return "The Ship24 request timed out."
            case .http(let code):
                return "Ship24 request failed (HTTP \(code))."
            case .malformedResponse:
                return "Ship24 returned an unexpected response."
            case .network(let message):
                return "Network request failed: \(message)"
            }
        }
    }

    public func track(trackingNumber: String) async throws -> TrackingResult {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Ship24Error.missingKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(TrackRequest(trackingNumber: trackingNumber))
        request.timeoutInterval = timeout

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw Ship24Error.timedOut
        } catch {
            throw Ship24Error.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw Ship24Error.malformedResponse
        }

        switch http.statusCode {
        case 200..<300:
            return try Self.parse(data)
        case 401, 403:
            throw Ship24Error.unauthorized
        case 404:
            throw Ship24Error.notFound
        case 429:
            throw Ship24Error.rateLimited
        default:
            throw Ship24Error.http(http.statusCode)
        }
    }

    public static func parse(_ data: Data) throws -> TrackingResult {
        let response: TrackResponse
        do {
            response = try JSONDecoder().decode(TrackResponse.self, from: data)
        } catch {
            throw Ship24Error.malformedResponse
        }

        guard let tracking = response.data.trackings.first else {
            throw Ship24Error.notFound
        }

        let milestone = tracking.shipment?.statusMilestone ?? .unknown
        let courier = tracking.shipment?.delivery?.service ?? tracking.trackers.first?.courierCode
        let events = tracking.events.prefix(15).map {
            TrackingEvent(status: $0.status, datetime: $0.datetime, location: $0.location)
        }

        return TrackingResult(milestone: milestone, events: events, courier: courier)
    }
}

private struct TrackRequest: Encodable {
    let trackingNumber: String
}

private struct TrackResponse: Decodable {
    let data: Payload
}

private struct Payload: Decodable {
    let trackings: [Tracking]
}

private struct Tracking: Decodable {
    let shipment: Shipment?
    let trackers: [Tracker]
    let events: [Event]

    private enum CodingKeys: String, CodingKey {
        case shipment
        case trackers
        case events
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shipment = try container.decodeIfPresent(Shipment.self, forKey: .shipment)
        trackers = try container.decodeIfPresent([Tracker].self, forKey: .trackers) ?? []
        events = try container.decodeIfPresent([Event].self, forKey: .events) ?? []
    }
}

private struct Shipment: Decodable {
    let statusMilestone: Milestone?
    let delivery: Delivery?
}

private struct Delivery: Decodable {
    let service: String?
}

private struct Tracker: Decodable {
    let courierCode: String?
}

private struct Event: Decodable {
    let status: String
    let datetime: String?
    let location: String?

    private enum CodingKeys: String, CodingKey {
        case status
        case datetime
        case location
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        datetime = try container.decodeIfPresent(String.self, forKey: .datetime)
        location = try container.decodeIfPresent(String.self, forKey: .location)
    }
}
