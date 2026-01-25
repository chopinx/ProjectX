import SwiftUI

struct FamilyGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settings: AppSettings
    @State private var step = 0
    @State private var members: [FamilyMember] = []
    @State private var activitySelections: [UUID: ActivityLevel] = [:]
    @State private var dietSelections: [UUID: DietType] = [:]
    @State private var editingMember: FamilyMember?
    @State private var suggestion: SuggestedNutritionTargets?
    @State private var editedTarget: NutritionTarget?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let titles = ["Members", "Activity", "Review", "Generate", "Adjust"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 4) { ForEach(0..<5, id: \.self) { Capsule().fill($0 <= step ? Color.themePrimary : Color.gray.opacity(0.3)).frame(height: 4) } }
                    .padding(.horizontal).padding(.vertical, 8)
                Divider()
                stepContent
            }
            .navigationTitle(titles[step]).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { nextButton }
            }
            .onAppear { loadMembers() }
            .alert("Error", isPresented: .constant(errorMessage != nil)) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
            .sheet(item: $editingMember) { m in
                MemberEditSheet(member: m) { updated in
                    if let i = members.firstIndex(where: { $0.id == updated.id }) { members[i] = updated }
                    editingMember = nil
                }
            }
        }
    }

    private func loadMembers() {
        guard members.isEmpty else { return }
        members = settings.familyMembers.isEmpty ? [FamilyMember(name: "Member 1")] : settings.familyMembers
        for m in members {
            activitySelections[m.id] = m.activityLevel
            dietSelections[m.id] = m.dietType
        }
    }

    private func activity(for id: UUID) -> Binding<ActivityLevel> {
        Binding(get: { activitySelections[id] ?? .moderate }, set: { activitySelections[id] = $0 })
    }

    private func diet(for id: UUID) -> Binding<DietType> {
        Binding(get: { dietSelections[id] ?? .standard }, set: { dietSelections[id] = $0 })
    }

    private func finalMembers() -> [FamilyMember] {
        members.map { m in
            var updated = m
            updated.activityLevel = activitySelections[m.id] ?? m.activityLevel
            updated.dietType = dietSelections[m.id] ?? m.dietType
            return updated
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: membersView
        case 1: detailsView
        case 2: reviewView
        case 3: generateView
        default: editView
        }
    }

    private var membersView: some View {
        List {
            Section("Household") {
                ForEach(members) { m in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(m.name.isEmpty ? "Unnamed" : m.name).font(.headline)
                            Text("\(m.age)y, \(Int(m.weight))kg").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { editingMember = m } label: { Image(systemName: "pencil").frame(width: 44, height: 44).contentShape(Rectangle()) }
                    }
                }.onDelete { idx in
                    for i in idx { activitySelections.removeValue(forKey: members[i].id); dietSelections.removeValue(forKey: members[i].id) }
                    members.remove(atOffsets: idx)
                }
            }
            Section {
                Button {
                    let m = FamilyMember(name: "Member \(members.count + 1)")
                    members.append(m)
                    activitySelections[m.id] = m.activityLevel
                    dietSelections[m.id] = m.dietType
                } label: { Label("Add", systemImage: "plus.circle.fill") }
            }
        }
    }

    private var detailsView: some View {
        List {
            ForEach(members) { m in
                Section(m.name.isEmpty ? "Member" : m.name) {
                    Picker("Activity", selection: activity(for: m.id)) { ForEach(ActivityLevel.allCases) { Text($0.rawValue).tag($0) } }
                    Text((activitySelections[m.id] ?? m.activityLevel).description).font(.caption).foregroundStyle(.secondary)
                    Picker("Diet", selection: diet(for: m.id)) { ForEach(DietType.allCases) { Text($0.rawValue).tag($0) } }
                    Text((dietSelections[m.id] ?? m.dietType).description).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var reviewView: some View {
        let final = finalMembers()
        return List {
            ForEach(final) { m in
                Section(m.name) {
                    LabeledContent("Age", value: "\(m.age)y"); LabeledContent("Weight", value: "\(Int(m.weight))kg")
                    LabeledContent("Activity", value: m.activityLevel.rawValue); LabeledContent("Diet", value: m.dietType.rawValue)
                    LabeledContent("Est. Calories", value: "\(m.estimatedCalories) kcal")
                }
            }
            Section { LabeledContent("Total", value: "\(final.reduce(0) { $0 + $1.estimatedCalories }) kcal").fontWeight(.semibold) }
        }
    }

    private var generateView: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) { ProgressView().scaleEffect(1.5); Text("Generating...").foregroundStyle(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let s = suggestion {
                List {
                    Section("AI Recommendation") { Text(s.explanation).font(.callout).foregroundStyle(.secondary) }
                    Section("Daily Targets") {
                        LabeledContent("Calories", value: "\(Int(s.calories)) kcal"); LabeledContent("Protein", value: "\(Int(s.protein))g")
                        LabeledContent("Carbs", value: "\(Int(s.carbohydrates))g"); LabeledContent("Fat", value: "\(Int(s.fat))g")
                        LabeledContent("Sugar", value: "≤\(Int(s.sugar))g"); LabeledContent("Fiber", value: "\(Int(s.fiber))g"); LabeledContent("Sodium", value: "≤\(Int(s.sodium))mg")
                    }
                    Section { Button { Task { await generate() } } label: { Label("Regenerate", systemImage: "arrow.clockwise") } }
                }
            } else { ContentUnavailableView("Ready", systemImage: "sparkles", description: Text("Tap Next for AI targets")) }
        }.task { if suggestion == nil { await generate() } }
    }

    private var editView: some View {
        let t = Binding(get: { editedTarget ?? suggestion?.toNutritionTarget() ?? .default }, set: { editedTarget = $0 })
        return List {
            Section("Adjust Targets") {
                TR("Calories", t.calories, "kcal"); TR("Protein", t.protein, "g"); TR("Carbs", t.carbohydrates, "g")
                TR("Fat", t.fat, "g"); TR("Sugar", t.sugar, "g"); TR("Fiber", t.fiber, "g"); TR("Sodium", t.sodium, "mg")
            }
        }
    }

    @ViewBuilder private var nextButton: some View {
        switch step {
        case 0: Button("Next") { step = 1 }.disabled(members.isEmpty)
        case 1: Button("Next") { step = 2 }
        case 2: Button("Generate") { step = 3 }
        case 3: Button("Next") { editedTarget = suggestion?.toNutritionTarget(); step = 4 }.disabled(suggestion == nil || isLoading)
        default: Button("Save") { save() }
        }
    }

    private func generate() async {
        guard settings.isConfigured else { errorMessage = "Configure API key first"; return }
        isLoading = true
        defer { isLoading = false }
        do { if let svc = LLMServiceFactory.create(settings: settings) { suggestion = try await svc.suggestNutritionTargets(for: finalMembers()) } }
        catch { errorMessage = error.localizedDescription }
    }

    private func save() {
        settings.familyMembers = finalMembers()
        settings.dailyNutritionTarget = editedTarget ?? suggestion?.toNutritionTarget() ?? .default
        settings.hasCompletedFamilyGuide = true
        dismiss()
    }
}

private struct MemberEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var member: FamilyMember
    let onSave: (FamilyMember) -> Void
    private var dobRange: ClosedRange<Date> { Calendar.current.date(byAdding: .year, value: -120, to: Date())!...Calendar.current.date(byAdding: .year, value: -1, to: Date())! }

    var body: some View {
        NavigationStack {
            Form {
                Section("Info") {
                    TextField("Name", text: $member.name)
                    DatePicker("DOB", selection: $member.dateOfBirth, in: dobRange, displayedComponents: .date)
                    HStack { Text("Weight"); Spacer(); TextField("", value: $member.weight, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 60); Text("kg").foregroundStyle(.secondary) }
                }
                Section { LabeledContent("Age", value: "\(member.age) years").foregroundStyle(.secondary) }
            }
            .navigationTitle("Edit").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { onSave(member); dismiss() } }
            }
        }
    }
}

private struct TR: View {
    let l: String; @Binding var v: Double; let u: String
    init(_ l: String, _ v: Binding<Double>, _ u: String) { self.l = l; _v = v; self.u = u }
    var body: some View { HStack { Text(l); Spacer(); TextField("", value: $v, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 70); Text(u).foregroundStyle(.secondary).frame(width: 35) } }
}
