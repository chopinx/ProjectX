import SwiftUI
import SwiftData

struct FoodBankView: View {
    var settings: AppSettings

    @Environment(\.modelContext) private var context
    @Query(sort: \Food.name) private var foods: [Food]
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var searchText = ""
    @State private var selectedMainCategory: FoodMainCategory?
    @State private var selectedSubcategory: FoodSubcategory?
    @State private var selectedTag: Tag?
    @State private var showingAddFood = false
    @State private var foodToDelete: Food?

    private var filteredFoods: [Food] {
        foods.filter { food in
            (selectedMainCategory == nil || food.category.main == selectedMainCategory) &&
            (selectedSubcategory == nil || food.category.sub == selectedSubcategory) &&
            (selectedTag == nil || food.tags.contains { $0.id == selectedTag?.id }) &&
            (searchText.isEmpty || food.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    private var foodCountByCategory: [FoodMainCategory: Int] {
        Dictionary(grouping: foods, by: { $0.category.main }).mapValues(\.count)
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                categorySideBar
                Divider()
                contentArea
            }
            .navigationTitle("Food Bank")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search foods")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddFood = true } label: { Label("Add Food", systemImage: "plus") }
                }
            }
        }
        .sheet(isPresented: $showingAddFood) {
            NavigationStack { FoodDetailView(food: nil) }
        }
        .deleteConfirmation("Delete Food?", item: $foodToDelete, message: { "Delete \"\($0.name)\"?" }) { food in
            withAnimation { context.delete(food) }
            try? context.save()
        }
    }

    // MARK: - Side Bar

    private var categorySideBar: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 4) {
                SideTabItem(icon: "square.grid.2x2", title: "All", count: foods.count,
                           isSelected: selectedMainCategory == nil, color: .themePrimary) {
                    withAnimation { selectedMainCategory = nil; selectedSubcategory = nil }
                }
                Divider().padding(.vertical, 4)
                ForEach(FoodMainCategory.allCases) { cat in
                    SideTabItem(icon: cat.icon, title: cat.displayName, count: foodCountByCategory[cat] ?? 0,
                               isSelected: selectedMainCategory == cat, color: cat.themeColor) {
                        withAnimation { selectedMainCategory = cat; selectedSubcategory = nil }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .frame(width: 72)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Content Area

    private var contentArea: some View {
        VStack(spacing: 0) {
            if let cat = selectedMainCategory, !cat.subcategories.isEmpty {
                filterBar {
                    FilterChip("All", isSelected: selectedSubcategory == nil, color: cat.themeColor) {
                        selectedSubcategory = nil
                    }
                    ForEach(cat.subcategories) { sub in
                        FilterChip(sub.displayName, isSelected: selectedSubcategory == sub, color: cat.themeColor) {
                            selectedSubcategory = sub
                        }
                    }
                }
            }
            if !allTags.isEmpty {
                filterBar {
                    ForEach(allTags) { tag in
                        TagChip(tag: tag, isSelected: selectedTag?.id == tag.id) {
                            withAnimation { selectedTag = selectedTag?.id == tag.id ? nil : tag }
                        }
                    }
                }
            }
            foodList
        }
    }

    private func filterBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8, content: content).padding(.horizontal).padding(.vertical, 8)
        }
        .background(Color(.secondarySystemBackground))
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Food List

    private var foodList: some View {
        List {
            if foods.isEmpty {
                ContentUnavailableView("No Foods Yet", systemImage: "fork.knife",
                    description: Text("Tap + to add a food manually"))
            } else if filteredFoods.isEmpty {
                ContentUnavailableView("No Results", systemImage: "magnifyingglass",
                    description: Text("Try adjusting your filters"))
            } else {
                ForEach(filteredFoods) { food in
                    NavigationLink { FoodDetailView(food: food) } label: { FoodRow(food: food) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { foodToDelete = food } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Components

private struct SideTabItem: View {
    let icon: String, title: String, count: Int, isSelected: Bool, color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.title3)
                        .frame(width: 44, height: 32)
                        .background(isSelected ? color : .clear)
                        .foregroundStyle(isSelected ? .white : color)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(isSelected ? Color.white.opacity(0.3) : color)
                            .clipShape(Capsule())
                            .offset(x: 4, y: -4)
                    }
                }
                Text(title)
                    .font(.system(size: 10))
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? color : .secondary)
            }
            .frame(width: 64).padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

private struct FilterChip: View {
    let title: String, isSelected: Bool, color: Color
    let onTap: () -> Void

    init(_ title: String, isSelected: Bool, color: Color, onTap: @escaping () -> Void) {
        self.title = title; self.isSelected = isSelected; self.color = color; self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption).fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isSelected ? color : Color(.tertiarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct TagChip: View {
    let tag: Tag, isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Circle().fill(tag.color).frame(width: 8, height: 8)
                Text(tag.name).font(.caption).fontWeight(isSelected ? .semibold : .regular)
                if isSelected { Image(systemName: "xmark").font(.caption2) }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(isSelected ? tag.color.opacity(0.2) : Color(.secondarySystemBackground))
            .foregroundStyle(isSelected ? tag.color : .primary)
            .clipShape(Capsule())
            .overlay(isSelected ? Capsule().stroke(tag.color, lineWidth: 1) : nil)
        }
        .buttonStyle(.plain)
    }
}

private struct FoodRow: View {
    let food: Food

    var body: some View {
        HStack {
            Image(systemName: food.category.icon).foregroundStyle(.secondary).frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name).font(.headline)
                HStack(spacing: 8) {
                    if let n = food.nutrition { Text("\(Int(n.calories)) kcal").font(.caption).foregroundStyle(.secondary) }
                    if food.category.sub != nil { CapsuleBadge(text: food.category.displayName) }
                }
                if !food.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(food.tags.prefix(3)) { CapsuleBadge(text: $0.name, color: $0.color) }
                        if food.tags.count > 3 { Text("+\(food.tags.count - 3)").font(.caption2).foregroundStyle(.secondary) }
                    }
                }
            }
        }
    }
}
