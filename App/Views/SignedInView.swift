import PlantekalenderKit
import SwiftUI

struct SignedInView: View {
    let api: HTTPAPI
    @State private var home: HomeModel

    init(api: HTTPAPI, session: SessionStore) {
        self.api = api
        _home = State(initialValue: HomeModel(auth: api, api: api, session: session))
    }

    var body: some View {
        Group {
            if home.loading {
                ProgressView()
            } else if home.failed {
                VStack(spacing: 12) {
                    Text(home.error ?? "Noget gik galt. Prøv igen.").foregroundStyle(.red)
                    Button("Prøv igen") { Task { await home.load() } }
                }
                .padding()
            } else if let garden = home.garden {
                Tabs(api: api, gardenId: garden.id, home: home)
            } else {
                FirstGardenView(home: home)
            }
        }
        .task { await home.load() }
    }
}

private enum Tab: Hashable { case board, garden, harvest, account }

private struct Tabs: View {
    let api: HTTPAPI
    let gardenId: String
    let home: HomeModel
    @State private var tab = Tab.board
    // Set by "Registrér høst" on a harvest task; the harvest tab opens on that planting.
    @State private var harvestItem: String?

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                BoardView(api: api, gardenId: gardenId) { itemId in
                    harvestItem = itemId
                    tab = .harvest
                }
            }
            .tabItem { Label("Oversigt", systemImage: "calendar") }.tag(Tab.board)
            NavigationStack { GardenView(api: api, gardenId: gardenId) }
                .tabItem { Label("Haven", systemImage: "leaf") }.tag(Tab.garden)
            NavigationStack {
                HarvestView(api: api, gardenId: gardenId, preselect: harvestItem, plantName: home.plantName)
                    .id(harvestItem)
            }
            .tabItem { Label("Høst", systemImage: "basket") }.tag(Tab.harvest)
            NavigationStack { AccountView(home: home) }
                .tabItem { Label("Konto", systemImage: "person.crop.circle") }.tag(Tab.account)
        }
    }
}

private struct FirstGardenView: View {
    let home: HomeModel
    @State private var name = "Min have"

    var body: some View {
        Form {
            Section("Velkommen") {
                Text("Giv din have et navn for at komme i gang.")
                TextField("Havens navn", text: $name)
            }
            if let error = home.error { Text(error).foregroundStyle(.red) }
            Button("Opret have") { Task { await home.createGarden(named: name) } }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

private struct AccountView: View {
    let home: HomeModel

    var body: some View {
        Form {
            Text("Bede, kasser og indstillinger redigeres i webappen.")
            Button("Log ud", role: .destructive) { Task { await home.logout() } }
        }
        .navigationTitle("Konto")
    }
}
