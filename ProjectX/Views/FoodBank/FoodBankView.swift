import SwiftUI
import SwiftData

struct FoodBankView: View {
    var settings: AppSettings

    @Environment(\.modelContext) private var context
    @Query(sort: \Food.name) private var foods: [Food]
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var searchText = ""
    @State private var selectedMainCategory: FoodMainCategory?
    @State private var selectedTag: Tag?
    @State private var showingAddFood = false

    var filteredFoods: [Food] {
        var result = foods
        if let mainCategory = selectedMainCategory {
            result = result.filter { $0.category.main == mainCategory }
        }
        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(where: { $0.id == tag.id }) }
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
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(food.name)
                                        .font(.headline)
                                    if let nutrition = food.nutrition {
                                        Text("\(Int(nutrition.calories)) kcal per 100g")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if !food.tags.isEmpty {
                                        HStack(spacing: 4) {
                                            ForEach(food.tags.prefix(3)) { tag in
                                                Text(tag.name)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(tag.color.opacity(0.2))
                                                    .foregroundStyle(tag.color)
                                                    .clipShape(Capsule())
                                            }
                                            if food.tags.count > 3 {
                                                Text("+\(food.tags.count - 3)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
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
                    HStack(spacing: 12) {
                        Menu {
                            Button("All Categories") { selectedMainCategory = nil }
                            Divider()
                            ForEach(FoodMainCategory.allCases) { category in
                                Button {
                                    selectedMainCategory = category
                                } label: {
                                    Label(category.displayName, systemImage: category.icon)
                                }
                            }
                        } label: {
                            Label("Category", systemImage: selectedMainCategory == nil
                                ? "line.3.horizontal.decrease.circle"
                                : "line.3.horizontal.decrease.circle.fill")
                        }

                        if !allTags.isEmpty {
                            Menu {
                                Button("All Tags") { selectedTag = nil }
                                Divider()
                                ForEach(allTags) { tag in
                                    Button {
                                        selectedTag = tag
                                    } label: {
                                        Label(tag.name, systemImage: selectedTag?.id == tag.id ? "checkmark" : "tag")
                                    }
                                }
                            } label: {
                                Label("Tag", systemImage: selectedTag == nil ? "tag" : "tag.fill")
                            }
                        }
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
