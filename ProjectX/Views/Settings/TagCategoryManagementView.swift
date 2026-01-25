import SwiftUI
import SwiftData

struct TagCategoryManagementView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Query(sort: \CustomSubcategory.name) private var customSubs: [CustomSubcategory]

    @State private var selectedTab = 0
    @State private var showingCreateTag = false
    @State private var editingTag: Tag?
    @State private var tagToDelete: Tag?
    @State private var showingAddSubcategory = false
    @State private var addingToCategory: FoodMainCategory?
    @State private var editingSubcategory: CustomSubcategory?
    @State private var subcategoryToDelete: CustomSubcategory?
    @State private var showResetConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $selectedTab) {
                Text("Tags").tag(0)
                Text("Categories").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                if selectedTab == 0 {
                    tagsList
                } else {
                    categoryList
                }
            }
            .animation(.default, value: selectedTab)
        }
        .navigationTitle("Tags & Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if selectedTab == 0 {
                    Button { showingCreateTag = true } label: {
                        Label("Add Tag", systemImage: "plus")
                    }
                } else {
                    Menu {
                        ForEach(FoodMainCategory.allCases) { cat in
                            Button {
                                addingToCategory = cat
                                showingAddSubcategory = true
                            } label: {
                                Label(cat.displayName, systemImage: cat.icon)
                            }
                        }
                        Divider()
                        Button(role: .destructive) { showResetConfirm = true } label: {
                            Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                        }
                        .disabled(customSubs.isEmpty)
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateTag) {
            NavigationStack {
                TagEditSheet(tag: nil, existingNames: Set(tags.map { $0.name.lowercased() })) { name, colorHex in
                    let tag = Tag(name: name, colorHex: colorHex)
                    context.insert(tag)
                    try? context.save()
                    showingCreateTag = false
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $editingTag) { tag in
            NavigationStack {
                TagEditSheet(tag: tag, existingNames: Set(tags.filter { $0.id != tag.id }.map { $0.name.lowercased() })) { name, colorHex in
                    tag.name = name
                    tag.colorHex = colorHex
                    try? context.save()
                    editingTag = nil
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingAddSubcategory) {
            if let cat = addingToCategory {
                NavigationStack {
                    SubcategoryEditSheet(
                        subcategory: nil,
                        mainCategory: cat,
                        existingNames: existingSubcategoryNames(for: cat)
                    ) { name in
                        let sub = CustomSubcategory(name: name, mainCategory: cat)
                        context.insert(sub)
                        try? context.save()
                        showingAddSubcategory = false
                        addingToCategory = nil
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .sheet(item: $editingSubcategory) { sub in
            if let cat = sub.mainCategory {
                NavigationStack {
                    SubcategoryEditSheet(
                        subcategory: sub,
                        mainCategory: cat,
                        existingNames: existingSubcategoryNames(for: cat, excluding: sub)
                    ) { name in
                        sub.name = name
                        try? context.save()
                        editingSubcategory = nil
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .deleteConfirmation("Delete Tag?", item: $tagToDelete, message: { tag in
            "Delete \"\(tag.name)\"? This will remove it from all foods."
        }) { tag in
            context.delete(tag)
            try? context.save()
        }
        .deleteConfirmation("Delete Subcategory?", item: $subcategoryToDelete, message: { sub in
            "Delete \"\(sub.name)\"? Foods using this will revert to the main category."
        }) { sub in
            context.delete(sub)
            try? context.save()
        }
        .alert("Reset Categories?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetToDefaults() }
        } message: {
            Text("This will delete all custom subcategories. Built-in categories are not affected.")
        }
    }

    // MARK: - Helper Functions

    private func existingSubcategoryNames(for category: FoodMainCategory, excluding: CustomSubcategory? = nil) -> Set<String> {
        var names = Set(category.subcategories.map { $0.displayName.lowercased() })
        for sub in customSubs where sub.mainCategoryRaw == category.rawValue {
            if sub.id != excluding?.id {
                names.insert(sub.name.lowercased())
            }
        }
        return names
    }

    private func customSubcategories(for category: FoodMainCategory) -> [CustomSubcategory] {
        customSubs.filter { $0.mainCategoryRaw == category.rawValue }
    }

    private func resetToDefaults() {
        for sub in customSubs {
            context.delete(sub)
        }
        try? context.save()
    }

    // MARK: - Tags List

    private var tagsList: some View {
        List {
            if tags.isEmpty {
                ContentUnavailableView("No Tags", systemImage: "tag", description: Text("Tap + to create a tag"))
            } else {
                ForEach(tags) { tag in
                    TagRowView(tag: tag, onEdit: { editingTag = tag })
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { DispatchQueue.main.async { tagToDelete = tag } } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { editingTag = tag } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(Color.themeInfo)
                        }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Category List

    private var categoryList: some View {
        List {
            ForEach(FoodMainCategory.allCases) { main in
                Section {
                    // Built-in subcategories
                    ForEach(main.subcategories) { sub in
                        HStack {
                            Text(sub.displayName)
                            Spacer()
                            Text("Built-in").font(.caption).foregroundStyle(.tertiary)
                        }
                        .font(.subheadline)
                    }
                    // Custom subcategories
                    ForEach(customSubcategories(for: main)) { sub in
                        HStack {
                            Text(sub.name)
                            Spacer()
                            Text("Custom").font(.caption).foregroundStyle(Color.themePrimary)
                        }
                        .font(.subheadline)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                DispatchQueue.main.async { subcategoryToDelete = sub }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { editingSubcategory = sub } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(Color.themeInfo)
                        }
                    }
                    // Add button
                    Button {
                        addingToCategory = main
                        showingAddSubcategory = true
                    } label: {
                        Label("Add Subcategory", systemImage: "plus.circle")
                            .font(.subheadline)
                            .foregroundStyle(Color.themePrimary)
                    }
                } header: {
                    HStack(spacing: 8) {
                        Image(systemName: main.icon).foregroundStyle(main.themeColor)
                        Text(main.displayName)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Tag Row

private struct TagRowView: View {
    let tag: Tag
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                Circle()
                    .fill(tag.color)
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tag.name).font(.headline)
                    Text("\(tag.foods.count) food\(tag.foods.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subcategory Edit Sheet

private struct SubcategoryEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let subcategory: CustomSubcategory?
    let mainCategory: FoodMainCategory
    let existingNames: Set<String>
    let onSave: (String) -> Void

    @State private var name: String

    init(subcategory: CustomSubcategory?, mainCategory: FoodMainCategory, existingNames: Set<String>, onSave: @escaping (String) -> Void) {
        self.subcategory = subcategory
        self.mainCategory = mainCategory
        self.existingNames = existingNames
        self.onSave = onSave
        _name = State(initialValue: subcategory?.name ?? "")
    }

    private var isDuplicate: Bool {
        existingNames.contains(name.trimmingCharacters(in: .whitespaces).lowercased())
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isDuplicate
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: mainCategory.icon).foregroundStyle(mainCategory.themeColor)
                    Text(mainCategory.displayName).foregroundStyle(.secondary)
                }
            } header: {
                Text("Parent Category")
            }

            Section {
                TextField("e.g., Frozen Vegetables, Fresh Pasta", text: $name)
                if isDuplicate {
                    Text("A subcategory with this name already exists")
                        .font(.caption).foregroundStyle(Color.themeError)
                }
            } header: {
                Text("Subcategory Name")
            }
        }
        .navigationTitle(subcategory == nil ? "New Subcategory" : "Edit Subcategory")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(subcategory == nil ? "Add" : "Save") {
                    onSave(name.trimmingCharacters(in: .whitespaces))
                }
                .disabled(!isValid)
            }
        }
    }
}
