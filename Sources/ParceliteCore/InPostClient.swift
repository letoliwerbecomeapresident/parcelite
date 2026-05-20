import Foundation

public struct InPostClient: TrackingProvider, Sendable {
    public let endpoint: URL

    public init(endpoint: URL = URL(string: "https://api-shipx-pl.easypack24.net/v1/tracking/")!) {
        self.endpoint = endpoint
    }

    public enum InPostError: Error, LocalizedError, Equatable {
        case notFound
        case invalidResponse
        case network(String)

        public var errorDescription: String? {
            switch self {
            case .notFound: return "No shipment was found for this InPost tracking number."
            case .invalidResponse: return "InPost returned an unexpected response."
            case .network(let msg): return "InPost network error: \(msg)"
            }
        }
    }

    public func track(trackingNumber: String) async throws -> TrackingResult {
        let url = endpoint.appendingPathComponent(trackingNumber)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw InPostError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw InPostError.invalidResponse
        }

        switch http.statusCode {
        case 200:
            return try Self.parse(data)
        case 404:
            throw InPostError.notFound
        default:
            throw InPostError.invalidResponse
        }
    }

    public static func parse(_ data: Data) throws -> TrackingResult {
        let decoder = JSONDecoder()
        let response: InPostResponse
        do {
            response = try decoder.decode(InPostResponse.self, from: data)
        } catch {
            throw InPostError.invalidResponse
        }

        let milestone = mapStatus(response.status)
        
        let events = response.trackingDetails.map { detail -> TrackingEvent in
            let location = detail.agency ?? detail.status
            return TrackingEvent(
                status: detail.originStatus ?? detail.status,
                datetime: detail.datetime,
                location: location
            )
        }

        return TrackingResult(
            milestone: milestone,
            events: events,
            courier: "InPost"
        )
    }

    private static func mapStatus(_ status: String) -> Milestone {
        switch status {
        case "created": return .pending
        case "prepared": return .infoReceived
        case "sent", "in_transit": return .inTransit
        case "out_for_delivery": return .outForDelivery
        case "ready_to_pickup": return .availableForPickup
        case "delivered": return .delivered
        case "returned_to_sender", "damaged", "lost": return .exception
        case "avizo": return .failedAttempt
        default: return .unknown
        }
    }
}

private struct InPostResponse: Decodable {
    let status: String
    let trackingNumber: String
    let trackingDetails: [InPostDetail]

    private enum CodingKeys: String, CodingKey {
        case status
        case trackingNumber = "tracking_number"
        case trackingDetails = "tracking_details"
    }
}

private struct InPostDetail: Decodable {
    let status: String
    let originStatus: String?
    let datetime: String?
    let agency: String?

    private enum CodingKeys: String, CodingKey {
        case status
        case originStatus = "origin_status"
        case datetime
        case agency
    }
}
