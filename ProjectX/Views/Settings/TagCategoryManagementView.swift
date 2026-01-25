import SwiftUI
import SwiftData

struct TagCategoryManagementView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Tag.name) private var tags: [Tag]

    @State private var selectedTab = 0
    @State private var showingCreateTag = false
    @State private var editingTag: Tag?
    @State private var tagToDelete: Tag?

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
            if selectedTab == 0 {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingCreateTag = true } label: {
                        Label("Add Tag", systemImage: "plus")
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
        .deleteConfirmation("Delete Tag?", item: $tagToDelete, message: { tag in
            "Delete \"\(tag.name)\"? This will remove it from all foods."
        }) { tag in
            context.delete(tag)
            try? context.save()
        }
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
                            .tint(.themeInfo)
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
                    if main.subcategories.isEmpty {
                        Text("No subcategories").foregroundStyle(.secondary).font(.subheadline)
                    } else {
                        ForEach(main.subcategories) { sub in
                            HStack {
                                Text("↳").foregroundStyle(.tertiary)
                                Text(sub.displayName)
                            }
                            .font(.subheadline)
                        }
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
