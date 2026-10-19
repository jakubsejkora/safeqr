import Foundation

protocol CloudChecking: Sendable {
    func check(_ request: CheckRequest,
               onProgress: @escaping @MainActor @Sendable ([CheckStep]) -> Void) async throws -> CloudVerdict
}

enum CloudError: Error {
    case unavailable, invalidResponse, timedOut
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
    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession? = nil) {
        self.baseURL = baseURL
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 45
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        self.session = session ?? URLSession(configuration: configuration, delegate: APIRedirectPolicy(), delegateQueue: nil)
    }

    func check(_ request: CheckRequest,
               onProgress: @escaping @MainActor @Sendable ([CheckStep]) -> Void) async throws -> CloudVerdict {
        guard baseURL.scheme == "https", baseURL.user == nil, baseURL.password == nil,
              !request.payload.isEmpty, request.payload.utf16.count <= 4096,
              (request.scene?.image.count ?? 0) <= 2_000_000 else { throw CloudError.invalidResponse }
        return try await withThrowingTaskGroup(of: CloudVerdict.self) { group in
            group.addTask { try await poll(request, onProgress: onProgress) }
            group.addTask {
                try await Task.sleep(for: .seconds(45))
                throw CloudError.timedOut
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw CloudError.unavailable }
            return result
        }
    }

    private func poll(_ body: CheckRequest,
                      onProgress: @escaping @MainActor @Sendable ([CheckStep]) -> Void) async throws -> CloudVerdict {
        var request = URLRequest(url: baseURL.appending(path: "v1/checks"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let accepted: CheckAccepted = try await send(request, status: 202)
        guard accepted.status == "running",
              accepted.id.range(of: "^chk_[A-Za-z0-9]{20,}$", options: .regularExpression) != nil else {
            throw CloudError.invalidResponse
        }
        var delay = accepted.pollAfterMs
        while !Task.isCancelled {
            try await Task.sleep(for: .milliseconds(max(100, delay)))
            let poll = URLRequest(url: baseURL.appending(path: "v1/checks").appending(path: accepted.id))
            let check: CloudCheck = try await send(poll, status: 200)
            guard check.id == accepted.id else { throw CloudError.invalidResponse }
            await onProgress(check.steps)
            switch check.status {
            case .completed:
                guard let verdict = check.result, (0...100).contains(verdict.score),
                      verdict.level == .init(score: verdict.score) else { throw CloudError.invalidResponse }
                return verdict
            case .failed:
                throw CloudError.unavailable
            case .running:
                delay = check.pollAfterMs ?? accepted.pollAfterMs
            }
        }
        throw CancellationError()
    }

    private func send<T: Decodable>(_ request: URLRequest, status: Int) async throws -> T {
        var request = request
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == status,
              data.count <= 4_000_000 else { throw CloudError.unavailable }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

#if DEBUG
struct PreviewCloudClient: CloudChecking {
    func check(_ request: CheckRequest,
               onProgress: @escaping @MainActor @Sendable ([CheckStep]) -> Void) async throws -> CloudVerdict {
        let labels = ["Following redirects", "Checking the website", "Checking the surroundings", "Checking known scams", "Preparing the result"]
        let ids = ["redirects", "sandbox", "scene", "intel", "verdict"]
        for index in ids.indices {
            try await Task.sleep(for: .milliseconds(350))
            await onProgress(ids.enumerated().map { offset, id in
                CheckStep(id: id, status: offset <= index ? .done : .pending, label: L10n.text(labels[offset]))
            })
        }
        return CloudVerdict(score: request.device.score, level: .init(score: request.device.score),
                            headline: L10n.text("This is a demonstration. No website was visited."), findings: [],
                            consequences: [], limitations: [L10n.text("Demo evidence is not a real safety check.")],
                            link: nil, scene: nil, intel: nil, models: ["demo"])
    }
}
#endif
