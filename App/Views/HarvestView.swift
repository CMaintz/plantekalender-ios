import PlantekalenderKit
import SwiftUI

struct HarvestView: View {
    @State private var model: HarvestModel
    let plantName: (String) -> String

    init(api: GardenAPI & HarvestAPI, gardenId: String, preselect: String?, plantName: @escaping (String) -> String) {
        _model = State(initialValue: HarvestModel(gardens: api, api: api, gardenId: gardenId, preselect: preselect))
        self.plantName = plantName
    }

    var body: some View {
        Form {
            if model.loading {
                ProgressView()
            } else if model.choices.isEmpty {
                if let error = model.error {
                    Text(error).foregroundStyle(.red)
                    Button("Prøv igen") { Task { await model.load() } }
                } else {
                    Text("Tilføj planter til haven, før du registrerer høst.")
                }
            } else {
                Section("Registrér høst") {
                    Picker("Plante", selection: $model.itemId) {
                        ForEach(model.choices) { Text(plantName($0.plantId)).tag(Optional($0.id)) }
                    }
                    TextField("Mængde", text: $model.amount).keyboardType(.decimalPad)
                    Picker("Enhed", selection: $model.unit) {
                        ForEach(harvestUnits, id: \.key) { Text($0.label).tag($0.key) }
                    }
                    if let error = model.error { Text(error).foregroundStyle(.red) }
                    Button("Registrér høst") { Task { await model.submit() } }.disabled(model.busy)
                }
            }
            Section("Høst i år") {
                if model.loaded && model.harvests.isEmpty { Text("Ingen høst registreret i år endnu.") }
                ForEach(model.harvests) { harvest in
                    VStack(alignment: .leading) {
                        Text("\(plantName(harvest.plantId)) \(amountText(harvest.amount, unit: harvest.unit))")
                        Text(dateText(harvest.harvestedOn)).font(.caption).foregroundStyle(.secondary)
                    }
                    .swipeActions { Button("Slet", role: .destructive) { Task { await model.delete(harvest) } } }
                }
            }
        }
        .navigationTitle("Høst")
        .task { await model.load() }
        .refreshable { await model.load() }
    }
}
