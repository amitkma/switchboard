import Foundation
import Testing
@testable import Switchboard

@MainActor
struct DomainMatcherTests {
    private static let rules = [
        Rule(domain: "github.com", browser: .firefox),
        Rule(domain: "*.Example.org", browser: .firefox),
        Rule(domain: "https://bücher.de/path", browser: .firefox),
        Rule(domain: "3.4", browser: .firefox),
        Rule(domain: "8.8.8.8", browser: .firefox),
        Rule(domain: "bad domain", browser: .firefox),
        Rule(domain: "", browser: .firefox),
    ]

    private func route(_ link: String) throws -> Browser {
        let url = try #require(URL(string: link))
        return DomainMatcher.browser(for: url, rules: Self.rules, fallback: .chrome)
    }

    @Test(arguments: [
        "https://github.com/",
        "http://GITHUB.com:8080/a",
        "https://api.github.com/",
        "https://a.b.github.com",
        "https://github.com./x",
        "https://example.org",
        "https://x.example.org",
        "https://xn--bcher-kva.de/",
        "https://bücher.de/",
        "https://www.bücher.de/",
        "https://8.8.8.8/",
    ])
    func matchesDomainAndSubdomains(link: String) throws {
        #expect(try route(link) == .firefox)
    }

    @Test(arguments: [
        "https://notgithub.com/",
        "https://github.com.evil.com/",
        "https://github.com@evil.com/",
        "https://user:password@github.com/",
        "https://evil.com%2F.github.com/",
        "https://github.com\\@evil.com/",
        "https://evil.com/github.com",
        "https://evil.com?.github.com",
        "https://evil.com#.github.com",
        "https://evil.com/?u=https://github.com",
        "https://1.2.3.4/",
        "https://github.co/",
        "https://[::1]/",
        "file:///tmp/github.com.html",
        "file://github.com/page.html",
    ])
    func rejectsLookalikesAndSpoofedHosts(link: String) throws {
        #expect(try route(link) == .chrome)
    }

    @Test func firstMatchingRuleWins() throws {
        let safari = Browser(bundleID: "com.apple.Safari", name: "Safari")
        let rules = [
            Rule(domain: "a.github.com", browser: safari),
            Rule(domain: "github.com", browser: .firefox),
        ]
        let url = try #require(URL(string: "https://a.github.com"))
        #expect(DomainMatcher.browser(for: url, rules: rules, fallback: .chrome) == safari)
    }

    @Test(arguments: ["bad domain", "a..b", "", "*", "http://"])
    func rejectsInvalidRuleText(text: String) {
        #expect(DomainMatcher.normalizedDomain(text) == nil)
    }
}
