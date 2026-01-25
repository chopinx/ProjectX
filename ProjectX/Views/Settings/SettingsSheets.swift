import SwiftUI
import SwiftData

// MARK: - Set Toggle Binding Helper

func setToggleBinding<T: Hashable>(for item: T, in set: Binding<Set<T>>) -> Binding<Bool> {
    Binding(
        get: { set.wrappedValue.contains(item) },
        set: { if $0 { set.wrappedValue.insert(item) } else { set.wrappedValue.remove(item) } }
    )
}

// MARK: - Export Data Sheet

struct ExportDataSheet: View {
    @Environment(\.dismiss) private var dismiss
    let context: ModelContext
    @State private var selectedTypes: Set<ExportDataType> = Set(ExportDataType.allCases)
    @State private var isExporting = false
    @State private var exportedFileURL: URL?
    @State private var showingShareSheet = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Select Data to Export") {
                    ForEach(ExportDataType.allCases) { type in
                        Toggle(isOn: setToggleBinding(for: type, in: $selectedTypes)) {
                            Label(type.rawValue, systemImage: type.icon)
                        }
                    }
                }
                if let error = errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") { exportData() }.disabled(selectedTypes.isEmpty || isExporting)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedFileURL { ShareSheet(items: [url]) }
            }
        }
    }

    private func exportData() {
        isExporting = true
        errorMessage = nil
        do {
            let data = try DataExportService(modelContext: context).exportData(types: selectedTypes)
            let filename = "ProjectX-Export-\(Date().formatted(.dateTime.year().month().day())).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: tempURL)
            exportedFileURL = tempURL
            showingShareSheet = true
        } catch { errorMessage = "Export failed: \(error.localizedDescription)" }
        isExporting = false
    }
}

// MARK: - Import Data Sheet

struct ImportDataSheet: View {
    @Environment(\.dismiss) private var dismiss
    let data: Data
    let preview: ImportPreview
    let context: ModelContext
    let onComplete: (ImportResult) -> Void
    @State private var selectedTypes: Set<ExportDataType> = []
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if let date = preview.exportDate {
                    Section { LabeledContent("Export Date", value: date.formatted(date: .abbreviated, time: .shortened)) }
                }
                Section("Select Data to Import") {
                    if preview.tagsCount > 0 {
                        Toggle(isOn: setToggleBinding(for: .tags, in: $selectedTypes)) {
                            Label("\(preview.tagsCount) Tags", systemImage: ExportDataType.tags.icon)
                        }
                    }
                    if preview.foodsCount > 0 {
                        Toggle(isOn: setToggleBinding(for: .foods, in: $selectedTypes)) {
                            Label("\(preview.foodsCount) Foods", systemImage: ExportDataType.foods.icon)
                        }
                    }
                    if preview.tripsCount > 0 {
                        Toggle(isOn: setToggleBinding(for: .trips, in: $selectedTypes)) {
                            Label("\(preview.tripsCount) Trips", systemImage: ExportDataType.trips.icon)
                        }
                    }
                }
                Section { Text("Existing items with the same name will be replaced.").font(.caption).foregroundStyle(.secondary) }
                if let error = errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { importData() }.disabled(selectedTypes.isEmpty || isImporting)
                }
            }
            .onAppear {
                if preview.tagsCount > 0 { selectedTypes.insert(.tags) }
                if preview.foodsCount > 0 { selectedTypes.insert(.foods) }
                if preview.tripsCount > 0 { selectedTypes.insert(.trips) }
            }
        }
    }

    private func importData() {
        isImporting = true
        errorMessage = nil
        do {
            let result = try DataExportService(modelContext: context).importData(from: data, types: selectedTypes)
            onComplete(result)
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
            isImporting = false
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Nutrition Target Sheet

private struct TargetFields {
    var protein, carbohydrates, fat, sugar, fiber, sodium: String

    var calculatedCalories: Int {
        let p = (Double(protein) ?? 0) * 4
        let c = (Double(carbohydrates) ?? 0) * 4
        let f = (Double(fat) ?? 0) * 9
        return Int(p + c + f)
    }

    init(from target: NutritionTarget) {
        protein = String(Int(target.protein)); carbohydrates = String(Int(target.carbohydrates))
        fat = String(Int(target.fat)); sugar = String(Int(target.sugar))
        fiber = String(Int(target.fiber)); sodium = String(Int(target.sodium))
    }

    init(from level: ActivityLevel) {
        let b = level.baseline
        protein = "\(b.pro)"; carbohydrates = "\(b.carb)"; fat = "\(b.fat)"
        sugar = "25"; fiber = "25"; sodium = "2300"
    }

    func toTarget() -> NutritionTarget {
        NutritionTarget(calories: Double(calculatedCalories), protein: Double(protein) ?? 50,
            carbohydrates: Double(carbohydrates) ?? 250, fat: Double(fat) ?? 65,
            sugar: Double(sugar) ?? 50, fiber: Double(fiber) ?? 25, sodium: Double(sodium) ?? 2300)
    }
}

struct NutritionTargetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var target: NutritionTarget
    @State private var fields: TargetFields
    @State private var activity: ActivityLevel = .moderate

    init(target: Binding<NutritionTarget>) {
        _target = target
        _fields = State(initialValue: TargetFields(from: target.wrappedValue))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Activity Level", selection: $activity) {
                        ForEach(ActivityLevel.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Text(activity.description).font(.caption).foregroundStyle(.secondary)
                    Button("Apply Baseline for 60kg Adult") { fields = TargetFields(from: activity) }
                        .foregroundStyle(Color.themePrimary)
                } header: { Text("Reference Baseline") } footer: {
                    let b = activity.baseline
                    Text("60kg adult: \(b.cal) kcal, \(b.pro)g protein, \(b.carb)g carbs, \(b.fat)g fat")
                }

                Section {
                    HStack {
                        Text("Calories").fontWeight(.medium)
                        Spacer()
                        Text("\(fields.calculatedCalories)").foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                        Text("kcal").foregroundStyle(.tertiary).frame(width: 40, alignment: .leading)
                    }
                    .listRowBackground(Color(.secondarySystemBackground))
                    TargetRow("Protein", $fields.protein, "g", hint: "4 kcal/g")
                    TargetRow("Carbohydrates", $fields.carbohydrates, "g", hint: "4 kcal/g")
                    TargetRow("Fat", $fields.fat, "g", hint: "9 kcal/g")
                } header: { Text("Daily Macros") } footer: {
                    Text("Calories = (Protein × 4) + (Carbs × 4) + (Fat × 9)")
                }

                Section("Daily Limits") {
                    TargetRow("Sugar", $fields.sugar, "g")
                    TargetRow("Fiber", $fields.fiber, "g")
                    TargetRow("Sodium", $fields.sodium, "mg")
                }
            }
            .navigationTitle("Nutrition Targets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { target = fields.toTarget(); dismiss() } }
            }
        }
    }
}

private struct TargetRow: View {
    let label: String, unit: String, hint: String?
    @Binding var value: String

    init(_ label: String, _ value: Binding<String>, _ unit: String, hint: String? = nil) {
        self.label = label; self._value = value; self.unit = unit; self.hint = hint
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                if let hint { Text(hint).font(.caption2).foregroundStyle(.tertiary) }
            }
            Spacer()
            TextField("0", text: $value).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 80)
            Text(unit).foregroundStyle(.secondary).frame(width: 40, alignment: .leading)
        }
    }
}
