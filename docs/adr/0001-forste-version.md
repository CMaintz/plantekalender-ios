# 0001: Første version af iOS-appen

**Status:** Antaget (2026-10-26)

## Kontekst

Ejeren valgte native Swift til iOS og Kotlin til Android. Webappens server ejer al
forretningslogik, og dens API-beskrivelse er kontrakten for web, Android og iOS. Repoet er
public, så CI kan bygge på macOS uden at bruge betalte minutter.

## Beslutning

- **Tynd klient** med et lille omfang: log ind eller opret konto, opgavetavlen med
  udført/udsæt/ikke relevant/fortryd og frostvarsler, havens bede med plantning via
  plantevælger, og høstregistrering. Resten bliver i webappen indtil videre.
- **`PlantekalenderKit`** er en Swift-pakke uden UIKit og SwiftUI: modeller, API-klient og view
  models (`@Observable`). Den bygger og testes med `swift test` på enhver platform med Swift 6.
  HTTP går gennem et `HTTPClient`-protokol, så klienten testes uden server.
- **Appen** i `App/` er SwiftUI og genereres som Xcode-projekt med XcodeGen fra `project.yml`.
  Der checkes ingen `.pbxproj` ind.
- **Ét protokol pr. API-område** (`AuthAPI`, `GardenAPI`, `BoardAPI`, `HarvestAPI`).
- **Fremadkompatibel parsing.** Ukendte felter ignoreres, og enum-lignende værdier er strenge.
- **Token i Keychain** med `WhenUnlockedThisDeviceOnly`, så det ikke kommer med i en backup. Et
  401 uden for `/api/auth` logger ud.
- **Debug** taler med en lokal udviklingsserver (`API_BASE_URL` i `project.yml`), **Release** med
  den deployede app.

## Konsekvenser

- Foundry har ingen Swift-gate; `gate.yml` kører `mise run gate` og bygger appen på `macos-15`.
- Pakken kan bygges overalt med Swift 6; appen kræver en Mac med Xcode.
