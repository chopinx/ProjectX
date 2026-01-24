import SwiftUI
import SwiftData

struct FoodBankView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Food.name) private var foods: [Food]

    @State private var searchText = ""
    @State private var selectedCategory: FoodCategory?
    @State private var showingAddFood = false

    var filteredFoods: [Food] {
        var result = foods
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                if foods.isEmpty {
                    ContentUnavailableView(
                        "No Foods Yet",
                        systemImage: "fork.knife",
                        description: Text("Tap + to add your first food item")
                    )
                } else {
                    ForEach(filteredFoods) { food in
                        NavigationLink {
                            FoodDetailView(food: food)
                        } label: {
                            HStack {
                                Image(systemName: food.category.icon)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text(food.name)
                                        .font(.headline)
                                    if let nutrition = food.nutrition {
                                        Text("\(Int(nutrition.calories)) kcal per 100g")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteFoods)
                }
            }
            .searchable(text: $searchText, prompt: "Search foods")
            .navigationTitle("Food Bank")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("All Categories") { selectedCategory = nil }
                        Divider()
                        ForEach(FoodCategory.allCases) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                Label(category.displayName, systemImage: category.icon)
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: selectedCategory == nil
                            ? "line.3.horizontal.decrease.circle"
                            : "line.3.horizontal.decrease.circle.fill")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddFood = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFood) {
                NavigationStack {
                    FoodDetailView(food: nil)
                }
            }
        }
    }

    private func deleteFoods(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filteredFoods[index])
        }
        try? context.save()
    }
}
