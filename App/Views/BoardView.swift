import PlantekalenderKit
import SwiftUI

private let bucketTitles = [
    "overdue": "Overskredet", "now": "Nu", "week": "Denne uge",
    "month": "Denne måned", "season": "Senere i sæsonen", "later": "Senere",
]

struct BoardView: View {
    @State private var model: BoardModel
    let onLogHarvest: (String) -> Void

    init(api: BoardAPI, gardenId: String, onLogHarvest: @escaping (String) -> Void) {
        _model = State(initialValue: BoardModel(api: api, gardenId: gardenId))
        self.onLogHarvest = onLogHarvest
    }

    var body: some View {
        List {
            if let error = model.error { Text(error).foregroundStyle(.red) }
            ForEach(model.alerts, id: \.night) { alert in
                Text(alert.explanation).listRowBackground(Color.red.opacity(0.12))
            }
            ForEach(model.sections) { section in
                Section(bucketTitles[section.bucket] ?? section.bucket) {
                    ForEach(section.tasks) { TaskRow(task: $0, model: model, onLogHarvest: onLogHarvest) }
                }
            }
            if !model.finished.isEmpty {
                Section("Udført eller afvist") {
                    ForEach(model.finished) { TaskRow(task: $0, model: model, onLogHarvest: onLogHarvest) }
                }
            }
        }
        .overlay { if model.loading { ProgressView() } }
        .navigationTitle("Oversigt")
        .task { await model.load() }
        .refreshable { await model.load() }
    }
}

private struct TaskRow: View {
    let task: BoardTask
    let model: BoardModel
    let onLogHarvest: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title).font(.headline)
            Text(windowText(start: task.start, end: task.end)).font(.caption).foregroundStyle(.secondary)
            if let detail = task.detail { Text(detail).font(.caption) }
        }
        .swipeActions(edge: .trailing) { actions }
        .contextMenu { actions }
    }

    @ViewBuilder private var actions: some View {
        if task.status == "done" || task.status == "dismissed" {
            Button("Fortryd") { Task { await model.reopen(task) } }
        } else if task.status == "snoozed" {
            Button("Udført") { Task { await model.done(task) } }.tint(.green)
            Button("Fortryd udsættelse") { Task { await model.reopen(task) } }
        } else {
            Button("Udført") { Task { await model.done(task) } }.tint(.green)
            Button("Udsæt en uge") { Task { await model.snooze(task) } }.tint(.orange)
            Button("Ikke relevant") { Task { await model.dismiss(task) } }
        }
        if let generated = task.task, generated.activity == "harvest" {
            Button("Registrér høst") { onLogHarvest(generated.itemId) }.tint(.blue)
        }
    }
}
