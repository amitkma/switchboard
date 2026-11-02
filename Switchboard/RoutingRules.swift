import Foundation

/// A browser identified by bundle ID. The name is saved with it so that a rule can
/// still show which browser it means after that browser is uninstalled.
struct Browser: Codable, Hashable, Identifiable {
    var bundleID: String
    var name: String

    var id: String { bundleID }

    static let chrome = Browser(bundleID: "com.google.Chrome", name: "Google Chrome")
    static let firefox = Browser(bundleID: "org.mozilla.firefox", name: "Firefox")

    static func == (lhs: Browser, rhs: Browser) -> Bool { lhs.bundleID == rhs.bundleID }
    func hash(into hasher: inout Hasher) { hasher.combine(bundleID) }
}

struct Rule: Identifiable, Codable, Equatable {
    var id = UUID()
    var domain: String
    var browser: Browser
}

enum DomainMatcher {
    /// The first matching rule wins, which is why rule order matters.
    static func browser(for url: URL, rules: [Rule], fallback: Browser) -> Browser {
        guard let host = host(of: url) else { return fallback }
        return rules.first { rule in
            normalizedDomain(rule.domain).map { matches(host: host, domain: $0) } ?? false
        }?.browser ?? fallback
    }

    /// True for the domain itself and its subdomains. Comparing against "." + domain
    /// stops `notgithub.com` and `github.com.evil.com` from matching `github.com`.
    /// IPv4 addresses have no subdomains, so they must match exactly.
    static func matches(host: String, domain: String) -> Bool {
        if host == domain { return true }
        let isIPv4 = host.split(separator: ".").last?.allSatisfy(\.isNumber) ?? false
        return !isIPv4 && host.hasSuffix("." + domain)
    }

    /// Turns rule text such as `*.GitHub.com` or `https://github.com/x` into `github.com`.
    /// Returns nil if it isn't a usable domain.
    static func normalizedDomain(_ text: String) -> String? {
        var text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let scheme = text.range(of: "://") { text.removeSubrange(..<scheme.upperBound) }
        while text.hasPrefix("*") || text.hasPrefix(".") { text.removeFirst() }
        guard !text.isEmpty, let url = URL(string: "https://" + text) else { return nil }
        return validated(url.host(percentEncoded: false))
    }

    /// The host to match, or nil if no rule should apply to this URL. URLs with embedded
    /// credentials are excluded because browsers and Foundation can disagree about the real
    /// host of ones like `https://github.com\@evil.com`.
    private static func host(of url: URL) -> String? {
        guard ["http", "https"].contains(url.scheme?.lowercased()), url.user == nil else { return nil }
        return validated(url.host(percentEncoded: false))
    }

    /// Lowercases a host and rejects anything that isn't plain dot-separated labels,
    /// such as a decoded `evil.com/.github.com`. IPv6 addresses are rejected too.
    /// Non-ASCII names are already in punycode (`xn--…`) by this point.
    private static func validated(_ host: String?) -> String? {
        guard var host = host?.lowercased() else { return nil }
        if host.hasSuffix(".") { host.removeLast() }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-_")
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        let isValid = labels.allSatisfy { label in
            !label.isEmpty && label.unicodeScalars.allSatisfy(allowed.contains)
        }
        return isValid ? host : nil
    }
}
