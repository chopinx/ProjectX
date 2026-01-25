import SwiftUI

struct FoodMatchingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let item: ExtractedReceiptItem
    let foods: [Food]
    let currentMatch: Food?
    let onSelect: (Food?) -> Void

    @State private var selectedFood: Food?
    @State private var suggestedFood: Food?
    @State private var isLoadingSuggestion = true
    @State private var showingNewFood = false
    @State private var searchText = ""
    @State private var settings = AppSettings()

    private var filteredFoods: [Food] {
        if searchText.isEmpty {
            return foods
        }
        return foods.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            if isLoadingSuggestion {
                Section("AI Suggestion") {
                    HStack {
                        ProgressView()
                        Text("Finding best match...")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let suggested = suggestedFood {
                Section("AI Suggestion") {
                    FoodSelectionRow(
                        food: suggested,
                        isSelected: selectedFood?.id == suggested.id,
                        isSuggested: true
                    ) {
                        selectedFood = suggested
                    }
                }
            }

            Section {
                Button {
                    showingNewFood = true
                } label: {
                    Label("Create New Food", systemImage: "plus.circle.fill")
                }
            }

            Section("All Foods") {
                if filteredFoods.isEmpty {
                    Text("No foods in your food bank")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredFoods) { food in
                        FoodSelectionRow(
                            food: food,
                            isSelected: selectedFood?.id == food.id,
                            isSuggested: false
                        ) {
                            selectedFood = food
                        }
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    selectedFood = nil
                } label: {
                    Label("Remove Link", systemImage: "link.badge.minus")
                }
                .disabled(selectedFood == nil && currentMatch == nil)
            }
        }
        .searchable(text: $searchText, prompt: "Search foods")
        .navigationTitle("Link to Food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    onSelect(selectedFood)
                }
            }
        }
        .task {
            selectedFood = currentMatch
            await findSuggestion()
        }
        .sheet(isPresented: $showingNewFood) {
            NavigationStack {
                NewFoodSheet(suggestedName: item.name, suggestedCategory: item.category) { newFood in
                    selectedFood = newFood
                    showingNewFood = false
                }
            }
        }
    }

    private func findSuggestion() async {
        guard !foods.isEmpty else {
            isLoadingSuggestion = false
            return
        }

        guard let service = LLMServiceFactory.create(settings: settings) else {
            isLoadingSuggestion = false
            return
        }

        do {
            let match = try await service.matchFood(
                itemName: item.name,
                existingFoods: foods.map { $0.name }
            )

            if !match.isNewFood, let matchedName = match.foodName {
                suggestedFood = foods.first { $0.name.lowercased() == matchedName.lowercased() }

                // Auto-select if confidence is high enough and no current match
                if match.confidence >= 0.7, currentMatch == nil, let suggested = suggestedFood {
                    selectedFood = suggested
                }
            }
        } catch {
            // Silently fail - suggestion is optional
        }

        isLoadingSuggestion = false
    }
}

private struct FoodSelectionRow: View {
    let food: Food
    let isSelected: Bool
    let isSuggested: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(food.name).font(.headline)
                        if isSuggested { CapsuleBadge(text: "Suggested", color: .themePrimary) }
                    }
                    if let nutrition = food.nutrition {
                        Text("\(Int(nutrition.calories)) kcal/100g").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(Color.themePrimary)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressFeedback)
    }
}
