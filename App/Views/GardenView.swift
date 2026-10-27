import PlantekalenderKit
import SwiftUI

struct GardenView: View {
    @State private var model: GardenModel
    @State private var addingTo: AreaGroup?

    init(api: GardenAPI, gardenId: String) {
        _model = State(initialValue: GardenModel(api: api, gardenId: gardenId))
    }

    var body: some View {
        List {
            if let error = model.error { Text(error).foregroundStyle(.red) }
            if model.loaded && model.groups.isEmpty { Text("Opret bede i webappen for at komme i gang.") }
            ForEach(model.groups) { group in
                Section(group.area?.name ?? "Uden bed") {
                    ForEach(group.items) { item in
                        VStack(alignment: .leading) {
                            Text(name(item.plantId) + (item.variety.map { " (\($0))" } ?? ""))
                            Text(itemDetail(item)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button("+ Tilføj plante") { addingTo = group }
                }
            }
        }
        .overlay { if model.loading { ProgressView() } }
        .navigationTitle("Haven")
        .task { await model.load() }
        .refreshable { await model.load() }
        .sheet(item: $addingTo) { group in
            PlantPicker(plants: model.plants) { plant in
                addingTo = nil
                Task { await model.plant(plant.id, in: group.area?.id) }
            }
        }
    }

    private func name(_ plantId: String) -> String {
        model.plants.first { $0.id == plantId }?.name ?? plantId
    }
}

private struct PlantPicker: View {
    let plants: [PlantSummary]
    let onPick: (PlantSummary) -> Void
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(plants.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { plant in
                Button(plant.name) { onPick(plant) }
            }
            .searchable(text: $query, prompt: "Søg i planter")
            .navigationTitle("Vælg plante")
        }
    }
}
