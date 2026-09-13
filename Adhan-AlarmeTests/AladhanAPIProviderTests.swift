import Foundation
import Testing
@testable import Adhan_Alarme

/// Tests du fournisseur Aladhan avec réponses simulées.
/// Le JSON nominal reprend la forme réelle (Évry, 13-09-2026, MWL),
/// avec un suffixe " (CEST)" sur Fajr pour valider le parsing robuste.
struct AladhanAPIProviderTests {
    private let paris = TimeZone(identifier: "Europe/Paris") ?? .current
    private let evry = Coordinates(latitude: 48.6298, longitude: 2.4412)

    private static let successJSON = """
        {
          "code": 200,
          "status": "OK",
          "data": {
            "timings": {
              "Fajr": "05:34 (CEST)",
              "Sunrise": "07:24",
              "Dhuhr": "13:46",
              "Asr": "17:18",
              "Sunset": "20:07",
              "Maghrib": "20:07",
              "Isha": "21:50",
              "Midnight": "01:46"
            },
            "date": {
              "readable": "13 Sep 2026",
              "timestamp": "1789275600"
            },
            "meta": {
              "latitude": 48.6298,
              "longitude": 2.4412,
              "timezone": "Europe/Paris",
              "method": {
                "id": 3,
                "name": "Muslim World League",
                "params": { "Fajr": 18, "Isha": 17 }
              },
              "school": "STANDARD"
            }
          }
        }
        """

    /// Boîte de capture pour l'URL (usage sériel dans un seul test).
    private final class URLBox: @unchecked Sendable {
        var url: URL?
    }

    private func provider(returning json: String = successJSON) -> AladhanAPIProvider {
        AladhanAPIProvider(dataLoader: { _ in ((json.data(using: .utf8) ?? Data()), URLResponse()) })
    }

    private func day() throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = paris
        return try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 13)))
    }

    @Test func parsesTimingsAndTimezone() async throws {
        let times = try await provider().fetchPrayerTimes(
            date: try day(),
            coordinates: evry,
            timeZone: paris,
            configuration: PrayerCalculationConfiguration()
        )

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = paris
        func expected(_ hour: Int, _ minute: Int) throws -> Date {
            try #require(calendar.date(from: DateComponents(
                year: 2026, month: 9, day: 13, hour: hour, minute: minute
            )))
        }

        let fajr = try expected(5, 34)
        let sunrise = try expected(7, 24)
        let dhuhr = try expected(13, 46)
        let asr = try expected(17, 18)
        let maghrib = try expected(20, 7)
        let isha = try expected(21, 50)

        #expect(times.timeZone.identifier == "Europe/Paris")
        #expect(times.fajr == fajr)
        #expect(times.sunrise == sunrise)
        #expect(times.dhuhr == dhuhr)
        #expect(times.asr == asr)
        #expect(times.maghrib == maghrib)
        #expect(times.isha == isha)
    }

    @Test func requestURL_containsParameters() async throws {
        let box = URLBox()
        let provider = AladhanAPIProvider(dataLoader: { url in
            box.url = url
            return ((Self.successJSON.data(using: .utf8) ?? Data()), URLResponse())
        })
        var configuration = PrayerCalculationConfiguration()
        configuration.method = .diyanet
        configuration.asrMethod = .hanafi
        configuration.highLatitudeRule = .oneSeventh

        _ = try await provider.fetchPrayerTimes(
            date: try day(),
            coordinates: evry,
            timeZone: paris,
            configuration: configuration
        )

        let absolute = try #require(box.url?.absoluteString)
        #expect(absolute.contains("13-09-2026"))
        #expect(absolute.contains("method=13"))
        #expect(absolute.contains("school=1"))
        #expect(absolute.contains("latitudeAdjustmentMethod=2"))
    }

    @Test func loaderError_becomesRequestFailed() async throws {
        struct LoaderError: Error {}
        let provider = AladhanAPIProvider(dataLoader: { _ in throw LoaderError() })
        await #expect(throws: AladhanError.requestFailed) {
            try await provider.fetchPrayerTimes(
                date: Date(),
                coordinates: evry,
                timeZone: paris,
                configuration: PrayerCalculationConfiguration()
            )
        }
    }

    @Test func malformedJSON_becomesInvalidResponse() async throws {
        await #expect(throws: AladhanError.invalidResponse) {
            try await provider(returning: "not json").fetchPrayerTimes(
                date: Date(),
                coordinates: evry,
                timeZone: paris,
                configuration: PrayerCalculationConfiguration()
            )
        }
    }

    @Test func missingTimezone_throws() async throws {
        let json = """
            {
              "code": 200,
              "status": "OK",
              "data": {
                "timings": {
                  "Fajr": "05:34",
                  "Sunrise": "07:24",
                  "Dhuhr": "13:46",
                  "Asr": "17:18",
                  "Maghrib": "20:07",
                  "Isha": "21:50"
                },
                "meta": {}
              }
            }
            """
        await #expect(throws: AladhanError.missingTimezone) {
            try await provider(returning: json).fetchPrayerTimes(
                date: Date(),
                coordinates: evry,
                timeZone: paris,
                configuration: PrayerCalculationConfiguration()
            )
        }
    }

    @Test func non200Code_becomesInvalidResponse() async throws {
        let json = """
            {
              "code": 500,
              "status": "Error",
              "data": {
                "timings": {
                  "Fajr": "05:34",
                  "Sunrise": "07:24",
                  "Dhuhr": "13:46",
                  "Asr": "17:18",
                  "Maghrib": "20:07",
                  "Isha": "21:50"
                },
                "meta": { "timezone": "Europe/Paris" }
              }
            }
            """
        await #expect(throws: AladhanError.invalidResponse) {
            try await provider(returning: json).fetchPrayerTimes(
                date: Date(),
                coordinates: evry,
                timeZone: paris,
                configuration: PrayerCalculationConfiguration()
            )
        }
    }
}
