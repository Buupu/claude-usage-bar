import Foundation
import Security

// MARK: - API response

struct UsageSnapshot: Decodable {
    let limits: [Limit]
    let spend: Spend?

    struct Limit: Decodable, Identifiable {
        let kind: String
        let percent: Double?
        let severity: String?
        let resetsAt: Date?
        let scope: Scope?

        var id: String { kind + (scope?.model?.displayName ?? "") }

        var label: String {
            switch kind {
            case "session": return "Session"
            case "weekly_all": return "Weekly"
            default:
                if let model = scope?.model?.displayName { return "Weekly · \(model)" }
                return kind.replacingOccurrences(of: "_", with: " ").capitalized
            }
        }

        struct Scope: Decodable {
            let model: Model?
            struct Model: Decodable { let displayName: String? }
        }
    }

    struct Spend: Decodable {
        let enabled: Bool?
        let used: Money?
        let limit: Money?

        struct Money: Decodable {
            let amountMinor: Int
            let currency: String
            let exponent: Int

            var formatted: String {
                let value = Decimal(amountMinor) / pow(10, exponent)
                return value.formatted(.currency(code: currency))
            }
        }
    }
}

// MARK: - Errors

enum UsageError: LocalizedError {
    case noCredentials
    case tokenExpired
    case badResponse(Int)
    case network(String)
    case parsing

    var errorDescription: String? {
        switch self {
        case .noCredentials: return "Not signed in to Claude Code"
        case .tokenExpired: return "Claude Code token expired"
        case .badResponse(let code): return "Anthropic API returned HTTP \(code)"
        case .network: return "Couldn't reach api.anthropic.com"
        case .parsing: return "Unexpected API response"
        }
    }

    var hint: String {
        switch self {
        case .noCredentials: return "Run `claude` in a terminal and sign in, then refresh."
        case .tokenExpired: return "Open Claude Code — it refreshes the token automatically."
        case .badResponse, .parsing: return "The undocumented usage endpoint may have changed. Please open an issue."
        case .network: return "Check your connection, then refresh."
        }
    }

    var menuBarBadge: String {
        switch self {
        case .noCredentials: return "sign in"
        case .tokenExpired: return "expired"
        case .network: return "offline"
        case .badResponse, .parsing: return "⚠︎"
        }
    }
}

// MARK: - Model

@MainActor
final class UsageModel: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var error: UsageError?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading = false

    private var refreshLoop: Task<Void, Never>?

    // Token cache — the Keychain is only read once per launch (or when the
    // token expires / the API rejects it). Reading it on every refresh would
    // trigger a Keychain permission dialog each time on some setups.
    private var cachedToken: String?
    private var tokenExpiry: Date?

    init() {
        refreshLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(120))
            }
        }
    }

    var menuBarTitle: String {
        if let error, snapshot == nil { return "✳ \(error.menuBarBadge)" }
        guard let worst = snapshot?.limits.max(by: { ($0.percent ?? 0) < ($1.percent ?? 0) }),
              let percent = worst.percent
        else { return "✳" }
        return "✳ \(Int(percent))%"
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            snapshot = try await Self.fetchUsage(token: try validToken())
            error = nil
            lastUpdated = Date()
        } catch UsageError.tokenExpired {
            // Claude Code may have rotated the token since we cached it —
            // re-read the Keychain once before giving up.
            cachedToken = nil
            do {
                snapshot = try await Self.fetchUsage(token: try validToken())
                error = nil
                lastUpdated = Date()
            } catch {
                self.error = (error as? UsageError) ?? .network(error.localizedDescription)
            }
        } catch {
            self.error = (error as? UsageError) ?? .network(error.localizedDescription)
        }
    }

    // MARK: Keychain

    private func validToken() throws -> String {
        if let cachedToken, let tokenExpiry, tokenExpiry > Date() {
            return cachedToken
        }
        let credentials = try Self.readCredentials()
        cachedToken = credentials.token
        tokenExpiry = credentials.expiry
        return credentials.token
    }

    private static func readCredentials() throws -> (token: String, expiry: Date) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { throw UsageError.noCredentials }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String
        else { throw UsageError.parsing }

        // expiresAt is epoch milliseconds; fall back to 30 minutes if absent.
        let expiry: Date
        if let expiresAt = oauth["expiresAt"] as? Double {
            expiry = Date(timeIntervalSince1970: expiresAt > 1e12 ? expiresAt / 1000 : expiresAt)
        } else {
            expiry = Date().addingTimeInterval(30 * 60)
        }
        return (token, expiry)
    }

    // MARK: API

    private static func fetchUsage(token: String) async throws -> UsageSnapshot {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UsageError.network(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            if http.statusCode == 401 || http.statusCode == 403 { throw UsageError.tokenExpired }
            throw UsageError.badResponse(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) { return date }
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Unrecognised date: \(string)"
            ))
        }
        guard let snapshot = try? decoder.decode(UsageSnapshot.self, from: data) else {
            throw UsageError.parsing
        }
        return snapshot
    }
}

// MARK: - Shared formatting

func resetText(_ date: Date) -> String {
    let calendar = Calendar.current
    let days = calendar.dateComponents(
        [.day],
        from: calendar.startOfDay(for: Date()),
        to: calendar.startOfDay(for: date)
    ).day ?? 0
    let time = date.formatted(date: .omitted, time: .shortened)
    switch days {
    case 0: return "resets \(time)"
    case 1: return "resets tomorrow \(time)"
    default: return "resets \(date.formatted(.dateTime.weekday(.abbreviated))) \(time)"
    }
}
