import SwiftUI
import SwiftData

struct CategoryPicker: View {
    @Binding var selection: FoodCategory
    @State private var showingPicker = false

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            HStack {
                Text("Category")
                    .foregroundStyle(.primary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: selection.icon)
                    Text(selection.fullPath)
                }
                .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                MainCategoryList(selection: $selection, dismiss: { showingPicker = false })
            }
            .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Main Category List (Level 1)

private struct MainCategoryList: View {
    @Binding var selection: FoodCategory
    let dismiss: () -> Void

    var body: some View {
        List {
            ForEach(FoodMainCategory.allCases) { main in
                NavigationLink {
                    SubcategoryList(mainCategory: main, selection: $selection, dismiss: dismiss)
                } label: {
                    HStack {
                        Image(systemName: main.icon)
                            .foregroundStyle(Color.themePrimary)
                            .frame(width: 28)
                        Text(main.displayName)
                        Spacer()
                        if selection.main == main {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.themePrimary)
                                .font(.footnote)
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}

// MARK: - Subcategory List (Level 2)

private struct SubcategoryList: View {
    let mainCategory: FoodMainCategory
    @Binding var selection: FoodCategory
    let dismiss: () -> Void

    @Query(sort: \CustomSubcategory.name) private var allCustomSubs: [CustomSubcategory]

    private var customSubcategories: [CustomSubcategory] {
        allCustomSubs.filter { $0.mainCategoryRaw == mainCategory.rawValue }
    }

    var body: some View {
        List {
            // Option to select main category only (no subcategory)
            Section {
                Button {
                    selection = FoodCategory(main: mainCategory, sub: nil)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: mainCategory.icon)
                            .foregroundStyle(Color.themePrimary)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mainCategory.displayName)
                            Text("General / All")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selection.main == mainCategory && selection.sub == nil && selection.customSub == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.themePrimary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            // Built-in subcategories
            if !mainCategory.subcategories.isEmpty {
                Section("Subcategories") {
                    ForEach(mainCategory.subcategories) { sub in
                        Button {
                            selection = FoodCategory(main: mainCategory, sub: sub)
                            dismiss()
                        } label: {
                            HStack {
                                Text(sub.displayName)
                                Spacer()
                                if selection.main == mainCategory && selection.sub == sub {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.themePrimary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Custom subcategories
            if !customSubcategories.isEmpty {
                Section("Custom") {
                    ForEach(customSubcategories) { custom in
                        Button {
                            selection = FoodCategory(main: mainCategory, customSub: custom.name)
                            dismiss()
                        } label: {
                            HStack {
                                Text(custom.name)
                                Spacer()
                                if selection.main == mainCategory && selection.customSub == custom.name {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.themePrimary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(mainCategory.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
