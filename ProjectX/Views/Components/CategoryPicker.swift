import SwiftUI

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
                    Text(selection.displayName)
                }
                .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                CategoryPickerSheet(selection: $selection)
            }
            .presentationDetents([.medium, .large])
        }
    }
}

struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: FoodCategory

    @State private var selectedMain: FoodMainCategory
    @State private var selectedSub: FoodSubcategory?

    init(selection: Binding<FoodCategory>) {
        _selection = selection
        _selectedMain = State(initialValue: selection.wrappedValue.main)
        _selectedSub = State(initialValue: selection.wrappedValue.sub)
    }

    var body: some View {
        List {
            // Level 1: Main Category
            Section("Main Category") {
                ForEach(FoodMainCategory.allCases) { main in
                    Button {
                        selectedMain = main
                        // Reset sub when main changes
                        if selectedSub?.parent != main {
                            selectedSub = nil
                        }
                    } label: {
                        HStack {
                            Image(systemName: main.icon)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(main.displayName)
                                if !main.healthNote.isEmpty {
                                    Text(main.healthNote)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if selectedMain == main {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // Level 2: Subcategory
            if !selectedMain.subcategories.isEmpty {
                Section("Subcategory (Optional)") {
                    Button {
                        selectedSub = nil
                    } label: {
                        HStack {
                            Text("General \(selectedMain.displayName)")
                                .foregroundStyle(.secondary)
                            Spacer()
                            if selectedSub == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    ForEach(selectedMain.subcategories) { sub in
                        Button {
                            selectedSub = sub
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sub.displayName)
                                    if let note = sub.healthNote {
                                        Text(note)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if selectedSub == sub {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Preview
            Section {
                HStack {
                    Text("Selected:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currentCategory.fullPath)
                        .fontWeight(.medium)
                }
            }
        }
        .navigationTitle("Select Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    selection = currentCategory
                    dismiss()
                }
            }
        }
    }

    private var currentCategory: FoodCategory {
        FoodCategory(main: selectedMain, sub: selectedSub)
    }
}

// Simple inline picker for quick selection (main categories only)
struct SimpleCategoryPicker: View {
    @Binding var selection: FoodCategory

    var body: some View {
        Picker("Category", selection: Binding(
            get: { selection.main },
            set: { selection = FoodCategory(main: $0) }
        )) {
            ForEach(FoodMainCategory.allCases) { main in
                Label(main.displayName, systemImage: main.icon).tag(main)
            }
        }
    }
}
