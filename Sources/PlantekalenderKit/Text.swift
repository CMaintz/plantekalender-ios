import Foundation

// Danish texts for the API's error codes, matching the web and Android apps.
private let messages = [
    "invalid_credentials": "Forkert e-mail eller adgangskode.",
    "email_taken": "Der findes allerede en konto med den e-mail.",
    "too_many_attempts": "For mange forsøg. Vent et kvarter, og prøv igen.",
    "invalid_body": "Nogle af felterne er ikke udfyldt korrekt.",
    "not_found": "Det findes ikke, eller du har ikke adgang til det.",
    "unknown_item": "Planten findes ikke længere. Vælg en anden.",
    "future_date": "Datoen ligger efter i dag.",
    "unauthenticated": "Du er blevet logget ud. Log ind igen.",
]

public func errorText(_ error: Error) -> String {
    if let api = error as? APIError { return messages[api.code] ?? "Noget gik galt. Prøv igen." }
    if error is URLError { return "Kunne ikke få forbindelse. Tjek din internetforbindelse og prøv igen." }
    return "Noget gik galt. Prøv igen."
}

public let harvestUnits: [(key: String, label: String)] = [
    ("kg", "kg"), ("g", "g"), ("stk", "stk."), ("bundt", "bundt"),
]

/// Accepts both "2,5" and "2.5", since Danish keyboards give a comma. Nil unless positive.
public func parseAmount(_ text: String) -> Double? {
    let normalised = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
    guard let value = Double(normalised), value > 0 else { return nil }
    return value
}

// The web app's labels for a planting's status.
private let itemStatuses = ["planned": "Planlagt", "active": "I haven", "removed": "Fjernet"]

/// "Planlagt, sæson 2027". The server sets a season only on annuals, so perennials show their status alone.
public func itemDetail(_ item: Item) -> String {
    let status = itemStatuses[item.status] ?? item.status
    return item.season.map { "\(status), sæson \($0)" } ?? status
}

private let danish = Locale(identifier: "da_DK")

public func amountText(_ amount: Double, unit: String) -> String {
    let formatter = NumberFormatter()
    formatter.locale = danish
    formatter.numberStyle = .decimal
    // Grams are entered for small pickings, so a kilo total needs three decimals to stay exact.
    formatter.maximumFractionDigits = 3
    let number = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    let label = harvestUnits.first { $0.key == unit }?.label ?? unit
    return "\(number) \(label)"
}

/// "17. maj" for an ISO date from the API.
public func dateText(_ iso: String) -> String {
    let parts = iso.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3, (1...12).contains(parts[1]) else { return iso }
    return "\(parts[2]). \(danishMonths[parts[1] - 1])"
}

public func windowText(start: String, end: String) -> String {
    start == end ? dateText(start) : "\(dateText(start)) til \(dateText(end))"
}

// Spelled out rather than taken from DateFormatter, whose month names depend on the ICU data the
// platform ships; the app must read the same on every device and in tests.
private let danishMonths = [
    "januar", "februar", "marts", "april", "maj", "juni",
    "juli", "august", "september", "oktober", "november", "december",
]
