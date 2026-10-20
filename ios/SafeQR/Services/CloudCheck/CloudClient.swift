import Foundation

typealias CheckRequestProvider = @MainActor @Sendable () async -> CheckRequest?

protocol CloudChecking: Sendable {
    func check(_ makeRequest: @escaping CheckRequestProvider,
               onProgress: @escaping @MainActor @Sendable ([CheckStep]) -> Void) async throws -> CloudVerdict
}

enum CloudError: Error, Equatable {
    case unavailable, invalidResponse, timedOut, rateLimited
}

final class APIRedirectPolicy: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        // A redirected POST must not send a scanned payload to another origin.
        completionHandler(nil)
    }
}

struct CloudClient: CloudChecking {
    let baseURL: URL?
    private let session: URLSession
    private let starts = CheckStartLimiter()

    init(baseURL: URL?, session: URLSession? = nil) {
        self.baseURL = baseURL
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 45
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        self.session = session ?? URLSession(configuration: configuration, delegate: APIRedirectPolicy(), delegateQueue: nil)
    }

    func check(_ makeRequest: @escaping CheckRequestProvider,
               onProgress: @escaping @MainActor @Sendable ([CheckStep]) -> Void) async throws -> CloudVerdict {
        guard let baseURL, baseURL.scheme == "https", baseURL.host()?.isEmpty == false,
              baseURL.user == nil, baseURL.password == nil, baseURL.query == nil, baseURL.fragment == nil else {
            throw CloudError.invalidResponse
        }
        return try await withThrowingTaskGroup(of: CloudVerdict.self) { group in
            group.addTask {
                try await starts.acquire()
                let accepted = try await submit(makeRequest, baseURL: baseURL)
                return try await poll(accepted, baseURL: baseURL, onProgress: onProgress)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(45))
                throw CloudError.timedOut
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw CloudError.unavailable }
            return result
        }
    }

    private func submit(_ makeRequest: CheckRequestProvider, baseURL: URL) async throws -> CheckAccepted {
        guard let body = await makeRequest() else {
            try Task.checkCancellation()
            throw CloudError.unavailable
        }
        try Task.checkCancellation()
        guard !body.payload.isEmpty, body.payload.utf16.count <= 4096,
              (body.scene?.image.count ?? 0) <= 2_000_000 else { throw CloudError.invalidResponse }
        var request = URLRequest(url: baseURL.appending(path: "v1/checks"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let accepted: CheckAccepted = try await send(request, status: 202)
        guard accepted.status.value == .running,
              accepted.id.range(of: "^chk_[A-Za-z0-9]{20,}$", options: .regularExpression) != nil else {
            throw CloudError.invalidResponse
        }
        return accepted
    }

    private func poll(_ accepted: CheckAccepted, baseURL: URL,
                      onProgress: @escaping @MainActor @Sendable ([CheckStep]) -> Void) async throws -> CloudVerdict {
        var delay = accepted.pollAfterMs
        while !Task.isCancelled {
            try await Task.sleep(for: .milliseconds(max(100, delay)))
            let poll = URLRequest(url: baseURL.appending(path: "v1/checks").appending(path: accepted.id))
            let check: CloudCheck = try await send(poll, status: 200)
            guard check.id == accepted.id else { throw CloudError.invalidResponse }
            await onProgress(check.steps)
            switch check.status {
            case .known(.completed):
                guard let verdict = check.result, verdict.isValid else { throw CloudError.invalidResponse }
                return verdict
            case .known(.failed):
                throw CloudError.unavailable
            case .known(.running):
                delay = check.pollAfterMs ?? accepted.pollAfterMs
            case .unknown:
                throw CloudError.invalidResponse
            }
        }
        throw CancellationError()
    }

    private func send<T: Decodable>(_ request: URLRequest, status: Int) async throws -> T {
        var request = request
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            let delay = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init) ?? 60
            await starts.postpone(seconds: delay)
            throw CloudError.rateLimited
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == status,
              data.count <= 4_000_000 else { throw CloudError.unavailable }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw CloudError.invalidResponse }
    }
}

