import PlantekalenderKit
import SwiftUI

struct GardenView: View {
    @State private var model: GardenModel
    @State private var addingTo: AreaGroup?
    let plants: [PlantSummary]
    let plantName: (String) -> String

    init(api: GardenAPI, gardenId: String, plants: [PlantSummary], plantName: @escaping (String) -> String) {
        _model = State(initialValue: GardenModel(api: api, gardenId: gardenId))
        self.plants = plants
        self.plantName = plantName
    }

    var body: some View {
        List {
            if let error = model.error { Text(error).foregroundStyle(.red) }
            if model.loaded && model.groups.isEmpty { Text("Opret bede i webappen for at komme i gang.") }
            ForEach(model.groups) { group in
                Section(group.area?.name ?? "Uden bed") {
                    ForEach(group.items) { item in
                        VStack(alignment: .leading) {
                            Text(plantName(item.plantId) + (item.variety.map { " (\($0))" } ?? ""))
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
            PlantPicker(plants: plants) { plant in
                addingTo = nil
                Task { await model.plant(plant.id, in: group.area?.id) }
            }
        }
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
