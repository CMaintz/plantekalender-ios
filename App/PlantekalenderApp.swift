import PlantekalenderKit
import SwiftUI

@main
struct PlantekalenderApp: App {
    @State private var session: KeychainSession
    private let api: HTTPAPI

    init() {
        let session = KeychainSession()
        let base = URL(string: Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String ?? "")!
        let client = SessionAwareClient(inner: URLSessionClient(), baseURL: base, currentToken: session.box.read) {
            Task { @MainActor in session.signOut() }
        }
        _session = State(initialValue: session)
        api = HTTPAPI(baseURL: base, token: session.box.read, client: client)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if session.unreadable {
                    KeychainUnreadableView(session: session)
                } else if session.token == nil {
                    LoginView(api: api, session: session)
                } else {
                    SignedInView(api: api, session: session)
                }
            }
            .tint(Color(red: 0.18, green: 0.42, blue: 0.24))
        }
    }
}

private struct KeychainUnreadableView: View {
    let session: KeychainSession

    var body: some View {
        VStack(spacing: 12) {
            Text("Kunne ikke læse dit login. Lås telefonen op, og prøv igen.")
            Button("Prøv igen") { session.read() }
        }
        .padding()
    }
}
