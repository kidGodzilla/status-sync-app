//
//  APIClient.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import Foundation

struct APIResponse<T: Codable>: Codable {
    let ok: Bool
    let error: String?
}

struct RequestsInboxResponse: Codable {
    let ok: Bool
    let requests: [PresenceRequest]
}

struct TokensInboxResponse: Codable {
    let ok: Bool
    let tokens: [TokenItem]
    
    struct TokenItem: Codable {
        let from: String
        let token: String
        let issuedAt: Int64
        let expiresAt: Int64
    }
}

struct PresenceGetResponse: Codable {
    let ok: Bool
    let presence: PresenceData?
    
    struct PresenceData: Codable {
        let user_id: String
        let state: String
        let device: String
        let timestamp: Int64
    }
}

struct ProfileGetResponse: Codable {
    let ok: Bool
    let profile: ProfileData?
    
    struct ProfileData: Codable {
        let user_id: String
        let displayName: String
        let handle: String
        let avatarData: String?
    }
}

class APIClient {
    private let baseURL: String
    
    init(baseURL: String) {
        // Normalize: trim whitespace and drop a trailing slash to avoid "//"
        var normalized = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        self.baseURL = normalized
    }
    
    private func url(path: String) -> URL? {
        URL(string: "\(baseURL)\(path)")
    }
    
    private func request<T: Codable>(_ request: URLRequest, responseType: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
    
    func updatePresence(userId: String, state: PresenceState, device: String = "mac") async throws {
        guard let url = url(path: "/presence/update") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "user_id": userId,
            "state": state.rawValue,
            "device": device,
            "timestamp": Int64(Date().timeIntervalSince1970)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        _ = try await self.request(request, responseType: APIResponse<Bool>.self)
    }
    
    func createRequest(fromUserId: String, toUserId: String) async throws {
        guard let url = url(path: "/requests/create") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "from_user_id": fromUserId,
            "to_user_id": toUserId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        _ = try await self.request(request, responseType: APIResponse<Bool>.self)
    }
    
    func getRequestsInbox(userId: String) async throws -> [PresenceRequest] {
        guard let url = url(path: "/requests/inbox?user_id=\(userId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let response = try await self.request(request, responseType: RequestsInboxResponse.self)
        return response.requests
    }
    
    func respondToRequest(toUserId: String, requestId: String, decision: String) async throws {
        guard let url = url(path: "/requests/respond") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "to_user_id": toUserId,
            "request_id": requestId,
            "decision": decision
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        _ = try await self.request(request, responseType: APIResponse<Bool>.self)
    }
    
    func getTokensInbox(userId: String) async throws -> [TokensInboxResponse.TokenItem] {
        guard let url = url(path: "/tokens/inbox?user_id=\(userId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let response = try await self.request(request, responseType: TokensInboxResponse.self)
        return response.tokens
    }
    
    func ackToken(userId: String, token: String) async throws {
        guard let url = url(path: "/tokens/ack") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "user_id": userId,
            "token": token
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        _ = try await self.request(request, responseType: APIResponse<Bool>.self)
    }
    
    func getPeerPresence(requesterUserId: String, targetUserId: String, capabilityToken: String) async throws -> PresenceGetResponse.PresenceData? {
        guard let url = url(path: "/presence/get") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "requester_user_id": requesterUserId,
            "target_user_id": targetUserId,
            "capability_token": capabilityToken
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let response = try await self.request(request, responseType: PresenceGetResponse.self)
        return response.presence
    }
    
    func updateProfile(userId: String, displayName: String, handle: String, avatarData: Data?) async throws {
        guard let url = url(path: "/profile/update") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "user_id": userId,
            "displayName": displayName,
            "handle": handle
        ]
        if let avatarData = avatarData {
            body["avatarData"] = avatarData.base64EncodedString()
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("DEBUG: updateProfile POST \(url.absoluteString) user_id=\(userId) displayName=\(displayName) handle=\(handle)")
        _ = try await self.request(request, responseType: APIResponse<Bool>.self)
    }
    
    func getProfile(userId: String) async throws -> ProfileGetResponse.ProfileData? {
        guard let url = url(path: "/profile/get?user_id=\(userId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        print("DEBUG: getProfile GET \(url.absoluteString)")
        let response = try await self.request(request, responseType: ProfileGetResponse.self)
        return response.profile
    }
}

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
}
