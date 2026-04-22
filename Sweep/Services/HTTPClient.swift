//
//  HTTPClient.swift
//  Sweep
//

import Foundation

enum HTTPClient {
    static func bearerRequest(url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    static func execute(_ request: URLRequest, errorFor: (Int, Data) -> Error) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw errorFor(-1, data)
        }
        if httpResponse.statusCode >= 400 {
            throw errorFor(httpResponse.statusCode, data)
        }
        return data
    }

    static func decode<T: Decodable>(_ request: URLRequest, errorFor: (Int, Data) -> Error) async throws -> T {
        let data = try await execute(request, errorFor: errorFor)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

protocol AuthenticatedHTTPService {
    static func httpError(status: Int, data: Data) -> Error
}

extension AuthenticatedHTTPService {
    func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        try await HTTPClient.decode(request, errorFor: Self.httpError)
    }

    func performVoidRequest(_ request: URLRequest) async throws {
        _ = try await HTTPClient.execute(request, errorFor: Self.httpError)
    }
}
