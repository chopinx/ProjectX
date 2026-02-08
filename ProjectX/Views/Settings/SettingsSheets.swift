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
    let settings: AppSettings
    let profileName: String

    @State private var selectedTypes: Set<ExportDataType> = Set(ExportDataType.allCases)
    @State private var isExporting = false
    @State private var exportedFileURL: URL?
    @State private var showingShareSheet = false
    @State private var showingConfirmation = false
    @State private var errorMessage: String?

    private var profileDataTypes: [ExportDataType] { [.trips, .meals] }
    private var globalDataTypes: [ExportDataType] { [.foods, .tags] }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(Color.themePrimary)
                        Text("Exporting for: **\(profileName)**")
                    }
                } footer: {
                    Text("Trips and Meals will be exported only for the current profile. Foods and Tags are shared across all profiles.")
                }

                Section("Profile Data (\(profileName))") {
                    ForEach(profileDataTypes, id: \.self) { type in
                        Toggle(isOn: setToggleBinding(for: type, in: $selectedTypes)) {
                            Label(type.rawValue, systemImage: type.icon)
                        }
                    }
                }

                Section("Global Data (All Profiles)") {
                    ForEach(globalDataTypes, id: \.self) { type in
                        Toggle(isOn: setToggleBinding(for: type, in: $selectedTypes)) {
                            Label(type.rawValue, systemImage: type.icon)
                        }
                    }
                }

                if let error = errorMessage {
                    Section { Text(error).foregroundStyle(Color.themeError) }
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") { showingConfirmation = true }.disabled(selectedTypes.isEmpty || isExporting)
                }
            }
            .confirmationDialog("Confirm Export", isPresented: $showingConfirmation, titleVisibility: .visible) {
                Button("Export Data") { exportData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Export \(selectedTypes.count) data type(s) for profile \"\(profileName)\"?")
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
            let data = try DataExportService(modelContext: context, profileId: settings.activeProfileId).exportData(types: selectedTypes)
            let filename = "ProjectX-\(profileName)-\(Date().formatted(.dateTime.year().month().day())).json"
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
    let settings: AppSettings
    let profileName: String
    let onComplete: (ImportResult) -> Void

    @State private var selectedTypes: Set<ExportDataType> = []
    @State private var isImporting = false
    @State private var showingConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(Color.themePrimary)
                        Text("Importing to: **\(profileName)**")
                    }
                } footer: {
                    Text("Trips and Meals will be imported to the current profile. Foods and Tags are shared across all profiles.")
                }

                if let date = preview.exportDate {
                    Section("Export Info") {
                        LabeledContent("Export Date", value: date.formatted(date: .abbreviated, time: .shortened))
                        if preview.profileId != nil {
                            LabeledContent("Source", value: "Profile-specific export")
                        } else {
                            LabeledContent("Source", value: "Legacy export (all data)")
                        }
                    }
                }

                if preview.tripsCount > 0 || preview.mealsCount > 0 {
                    Section("Profile Data (will import to \(profileName))") {
                        if preview.tripsCount > 0 {
                            Toggle(isOn: setToggleBinding(for: .trips, in: $selectedTypes)) {
                                Label("\(preview.tripsCount) Trips", systemImage: ExportDataType.trips.icon)
                            }
                        }
                        if preview.mealsCount > 0 {
                            Toggle(isOn: setToggleBinding(for: .meals, in: $selectedTypes)) {
                                Label("\(preview.mealsCount) Meals", systemImage: ExportDataType.meals.icon)
                            }
                        }
                    }
                }

                if preview.foodsCount > 0 || preview.tagsCount > 0 {
                    Section("Global Data (shared across profiles)") {
                        if preview.foodsCount > 0 {
                            Toggle(isOn: setToggleBinding(for: .foods, in: $selectedTypes)) {
                                Label("\(preview.foodsCount) Foods", systemImage: ExportDataType.foods.icon)
                            }
                        }
                        if preview.tagsCount > 0 {
                            Toggle(isOn: setToggleBinding(for: .tags, in: $selectedTypes)) {
                                Label("\(preview.tagsCount) Tags", systemImage: ExportDataType.tags.icon)
                            }
                        }
                    }
                }

                Section {
                    Text("Existing items with the same name will be updated. New items will be added.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = errorMessage {
                    Section { Text(error).foregroundStyle(Color.themeError) }
                }
            }
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { showingConfirmation = true }.disabled(selectedTypes.isEmpty || isImporting)
                }
            }
            .confirmationDialog("Confirm Import", isPresented: $showingConfirmation, titleVisibility: .visible) {
                Button("Import Data") { importData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Import \(selectedTypes.count) data type(s) to profile \"\(profileName)\"?")
            }
            .onAppear {
                if preview.tagsCount > 0 { selectedTypes.insert(.tags) }
                if preview.foodsCount > 0 { selectedTypes.insert(.foods) }
                if preview.tripsCount > 0 { selectedTypes.insert(.trips) }
                if preview.mealsCount > 0 { selectedTypes.insert(.meals) }
            }
        }
    }

    private func importData() {
        isImporting = true
        errorMessage = nil
        do {
            let result = try DataExportService(modelContext: context, profileId: settings.activeProfileId).importData(from: data, types: selectedTypes)
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
    var protein, carbohydrates, fat, saturatedFat, omega3, omega6, sugar, fiber, sodium: String
    var vitaminA, vitaminC, vitaminD, calcium, iron, potassium: String

    var calculatedCalories: Int {
        let p = (Double(protein) ?? 0) * 4
        let c = (Double(carbohydrates) ?? 0) * 4
        let f = (Double(fat) ?? 0) * 9
        return Int(p + c + f)
    }

    init(from t: NutritionTarget) {
        func s(_ v: Double) -> String { String(Int(v)) }
        protein = s(t.protein); carbohydrates = s(t.carbohydrates); fat = s(t.fat); saturatedFat = s(t.saturatedFat)
        omega3 = String(format: "%.1f", t.omega3); omega6 = s(t.omega6)
        sugar = s(t.sugar); fiber = s(t.fiber); sodium = s(t.sodium)
        vitaminA = s(t.vitaminA); vitaminC = s(t.vitaminC); vitaminD = s(t.vitaminD)
        calcium = s(t.calcium); iron = s(t.iron); potassium = s(t.potassium)
    }

    init(from level: ActivityLevel) {
        let b = level.baseline
        protein = "\(b.pro)"; carbohydrates = "\(b.carb)"; fat = "\(b.fat)"; saturatedFat = "20"
        omega3 = "1.6"; omega6 = "17"; sugar = "25"; fiber = "25"; sodium = "2300"
        vitaminA = "900"; vitaminC = "90"; vitaminD = "20"; calcium = "1000"; iron = "18"; potassium = "4700"
    }

    func toTarget() -> NutritionTarget {
        func d(_ s: String, _ fallback: Double) -> Double { Double(s) ?? fallback }
        return NutritionTarget(
            calories: Double(calculatedCalories), protein: d(protein, 50), carbohydrates: d(carbohydrates, 250),
            fat: d(fat, 65), saturatedFat: d(saturatedFat, 20), omega3: d(omega3, 1.6), omega6: d(omega6, 17),
            sugar: d(sugar, 50), fiber: d(fiber, 25), sodium: d(sodium, 2300),
            vitaminA: d(vitaminA, 900), vitaminC: d(vitaminC, 90), vitaminD: d(vitaminD, 20),
            calcium: d(calcium, 1000), iron: d(iron, 18), potassium: d(potassium, 4700)
        )
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
                    TargetRow("Omega-3", $fields.omega3, "g")
                    TargetRow("Omega-6", $fields.omega6, "g")
                } header: { Text("Daily Macros") } footer: {
                    Text("Calories = (Protein × 4) + (Carbs × 4) + (Fat × 9)")
                }

                Section("Daily Limits") {
                    TargetRow("Saturated Fat", $fields.saturatedFat, "g")
                    TargetRow("Sugar", $fields.sugar, "g")
                    TargetRow("Fiber", $fields.fiber, "g")
                    TargetRow("Sodium", $fields.sodium, "mg")
                }

                Section("Daily Micronutrients") {
                    TargetRow("Vitamin A", $fields.vitaminA, "mcg")
                    TargetRow("Vitamin C", $fields.vitaminC, "mg")
                    TargetRow("Vitamin D", $fields.vitaminD, "mcg")
                    TargetRow("Calcium", $fields.calcium, "mg")
                    TargetRow("Iron", $fields.iron, "mg")
                    TargetRow("Potassium", $fields.potassium, "mg")
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
