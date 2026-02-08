import SwiftUI

/// Shared view for linking items to foods with AI suggestions
struct FoodMatchingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let itemName: String
    let foods: [Food]
    let currentMatch: Food?
    let settings: AppSettings
    let onSelect: (Food?) -> Void
    var suggestedCategory: String = "other"

    @State private var selectedFood: Food?
    @State private var suggestedFood: Food?
    @State private var isLoading = true
    @State private var showingNewFood = false
    @State private var searchText = ""

    private var filtered: [Food] {
        searchText.isEmpty ? foods : foods.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            if isLoading && !itemName.isEmpty {
                Section("AI Suggestion") {
                    HStack { ProgressView(); Text("Finding best match...").foregroundStyle(.secondary) }
                }
            } else if let suggested = suggestedFood {
                Section("AI Suggestion") {
                    FoodSelectionRow(food: suggested, isSelected: selectedFood?.id == suggested.id, badge: "Suggested") {
                        selectedFood = suggested
                    }
                }
            }

            Section {
                Button { showingNewFood = true } label: {
                    Label("Create New Food", systemImage: "plus.circle.fill")
                }
            }

            Section("All Foods") {
                if filtered.isEmpty {
                    Text("No foods found").foregroundStyle(.secondary)
                } else {
                    ForEach(filtered) { food in
                        FoodSelectionRow(food: food, isSelected: selectedFood?.id == food.id) { selectedFood = food }
                    }
                }
            }

            Section {
                Button(role: .destructive) { selectedFood = nil } label: {
                    Label("Remove Link", systemImage: "link.badge.minus")
                }.disabled(selectedFood == nil && currentMatch == nil)
            }
        }
        .searchable(text: $searchText, prompt: "Search foods")
        .navigationTitle("Link to Food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Done") { onSelect(selectedFood) } }
        }
        .task { selectedFood = currentMatch; await findSuggestion() }
        .sheet(isPresented: $showingNewFood) {
            NavigationStack {
                FoodDetailView(suggestedName: itemName, suggestedCategory: suggestedCategory, settings: settings) { newFood in
                    selectedFood = newFood
                    showingNewFood = false
                }
            }
        }
    }

    private func findSuggestion() async {
        guard !foods.isEmpty, !itemName.isEmpty,
              let service = LLMServiceFactory.create(settings: settings) else { isLoading = false; return }
        do {
            let match = try await service.matchFood(itemName: itemName, existingFoods: foods.map(\.name))
            if !match.isNewFood, let name = match.foodName {
                suggestedFood = foods.first { $0.name.lowercased() == name.lowercased() }
                if match.confidence >= 0.7, currentMatch == nil, let s = suggestedFood { selectedFood = s }
            }
        } catch {}
        isLoading = false
    }
}

// MARK: - Food Selection Row

struct FoodSelectionRow: View {
    let food: Food
    let isSelected: Bool
    var badge: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(food.name).font(.headline)
                        if let b = badge { CapsuleBadge(text: b, color: Color.themePrimary) }
                    }
                    if let n = food.nutrition {
                        Text("\(Int(n.calories)) kcal/100g").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.themePrimary) }
            }.padding(.vertical, 4).contentShape(Rectangle())
        }.buttonStyle(.pressFeedback)
    }
}
