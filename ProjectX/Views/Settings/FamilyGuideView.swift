import SwiftUI

struct FamilyGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settings: AppSettings
    @State private var step: Step = .members
    @State private var members: [FamilyMember] = []
    @State private var editingMember: FamilyMember?
    @State private var suggestion: SuggestedNutritionTargets?
    @State private var editedTarget: NutritionTarget?
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum Step: Int, CaseIterable {
        case members, details, review, generate, edit

        var title: String {
            switch self {
            case .members: return "Family Members"
            case .details: return "Activity & Diet"
            case .review: return "Review"
            case .generate: return "AI Suggestion"
            case .edit: return "Adjust Targets"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator
                Divider()
                content
            }
            .navigationTitle(step.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) { nextButton }
            }
            .onAppear { members = settings.familyMembers.isEmpty ? [FamilyMember(name: "Member 1")] : settings.familyMembers }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .sheet(item: $editingMember) { member in
                MemberEditSheet(member: member) { updated in
                    if let idx = members.firstIndex(where: { $0.id == updated.id }) {
                        members[idx] = updated
                    }
                    editingMember = nil
                }
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 4) {
            ForEach(Step.allCases, id: \.self) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? Color.themePrimary : Color.gray.opacity(0.3))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal).padding(.vertical, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch step {
        case .members: membersStep
        case .details: detailsStep
        case .review: reviewStep
        case .generate: generateStep
        case .edit: editStep
        }
    }

    // MARK: - Members Step

    private var membersStep: some View {
        List {
            Section {
                ForEach(members) { member in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(member.name.isEmpty ? "Unnamed" : member.name).font(.headline)
                            Text("\(member.age) years, \(Int(member.weight)) kg").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { editingMember = member } label: {
                            Image(systemName: "pencil")
                                .font(.body)
                                .foregroundStyle(Color.themePrimary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                    }
                }
                .onDelete { members.remove(atOffsets: $0) }
            } header: { Text("Household Members") }

            Section {
                Button { members.append(FamilyMember(name: "Member \(members.count + 1)")) } label: {
                    Label("Add Member", systemImage: "plus.circle.fill")
                }
            }
        }
    }

    // MARK: - Details Step

    private var detailsStep: some View {
        List {
            ForEach(members.indices, id: \.self) { index in
                let member = members[index]
                Section(member.name.isEmpty ? "Member" : member.name) {
                    Picker("Activity", selection: $members[index].activityLevel) {
                        ForEach(ActivityLevel.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Text(member.activityLevel.description).font(.caption).foregroundStyle(.secondary)

                    Picker("Diet", selection: $members[index].dietType) {
                        ForEach(DietType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Text(member.dietType.description).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Review Step

    private var reviewStep: some View {
        List {
            ForEach(members) { member in
                Section(member.name) {
                    LabeledContent("Age", value: "\(member.age) years")
                    LabeledContent("Weight", value: "\(Int(member.weight)) kg")
                    LabeledContent("Activity", value: member.activityLevel.rawValue)
                    LabeledContent("Diet", value: member.dietType.rawValue)
                    LabeledContent("Est. Calories", value: "\(member.estimatedCalories) kcal")
                }
            }
            Section {
                let total = members.reduce(0) { $0 + $1.estimatedCalories }
                LabeledContent("Household Total", value: "\(total) kcal").fontWeight(.semibold)
            }
        }
    }

    // MARK: - Generate Step

    private var generateStep: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.5)
                    Text("Generating personalized targets...").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let suggestion {
                List {
                    Section("AI Recommendation") {
                        Text(suggestion.explanation).font(.callout).foregroundStyle(.secondary)
                    }
                    Section("Suggested Daily Targets") {
                        LabeledContent("Calories", value: "\(Int(suggestion.calories)) kcal")
                        LabeledContent("Protein", value: "\(Int(suggestion.protein)) g")
                        LabeledContent("Carbs", value: "\(Int(suggestion.carbohydrates)) g")
                        LabeledContent("Fat", value: "\(Int(suggestion.fat)) g")
                        LabeledContent("Sugar", value: "≤ \(Int(suggestion.sugar)) g")
                        LabeledContent("Fiber", value: "\(Int(suggestion.fiber)) g")
                        LabeledContent("Sodium", value: "≤ \(Int(suggestion.sodium)) mg")
                    }
                    Section {
                        Button { Task { await generateSuggestion() } } label: {
                            Label("Regenerate Suggestion", systemImage: "arrow.clockwise")
                        }
                    }
                }
            } else {
                ContentUnavailableView("Ready to Generate", systemImage: "sparkles", description: Text("Tap Next to get AI-powered nutrition targets"))
            }
        }
        .task { if suggestion == nil { await generateSuggestion() } }
    }

    // MARK: - Edit Step

    private var editStep: some View {
        let target = Binding(
            get: { editedTarget ?? suggestion?.toNutritionTarget() ?? .default },
            set: { editedTarget = $0 }
        )
        return List {
            Section("Adjust Your Targets") {
                TargetEditRow("Calories", value: target.calories, unit: "kcal")
                TargetEditRow("Protein", value: target.protein, unit: "g")
                TargetEditRow("Carbs", value: target.carbohydrates, unit: "g")
                TargetEditRow("Fat", value: target.fat, unit: "g")
                TargetEditRow("Sugar", value: target.sugar, unit: "g")
                TargetEditRow("Fiber", value: target.fiber, unit: "g")
                TargetEditRow("Sodium", value: target.sodium, unit: "mg")
            }
        }
    }

    // MARK: - Next Button

    @ViewBuilder
    private var nextButton: some View {
        switch step {
        case .members:
            Button("Next") { step = .details }.disabled(members.isEmpty)
        case .details:
            Button("Next") { step = .review }
        case .review:
            Button("Generate") { step = .generate }
        case .generate:
            Button("Next") { editedTarget = suggestion?.toNutritionTarget(); step = .edit }
                .disabled(suggestion == nil || isLoading)
        case .edit:
            Button("Save") { save() }
        }
    }

    // MARK: - Actions

    private func generateSuggestion() async {
        guard settings.isConfigured else {
            errorMessage = "Please configure your API key in Settings first."
            return
        }
        isLoading = true
        do {
            guard let service = LLMServiceFactory.create(settings: settings) else { return }
            suggestion = try await service.suggestNutritionTargets(for: members)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func save() {
        settings.familyMembers = members
        settings.dailyNutritionTarget = editedTarget ?? suggestion?.toNutritionTarget() ?? .default
        settings.hasCompletedFamilyGuide = true
        dismiss()
    }
}

// MARK: - Member Edit Sheet

private struct MemberEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var member: FamilyMember
    let onSave: (FamilyMember) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Name", text: $member.name)
                    Stepper("Age: \(member.age)", value: $member.age, in: 1...120)
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("kg", value: $member.weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("kg").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { onSave(member); dismiss() } }
            }
        }
    }
}

// MARK: - Target Edit Row

private struct TargetEditRow: View {
    let label: String
    @Binding var value: Double
    let unit: String

    init(_ label: String, value: Binding<Double>, unit: String) {
        self.label = label
        self._value = value
        self.unit = unit
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit).foregroundStyle(.secondary).frame(width: 40, alignment: .leading)
        }
    }
}
