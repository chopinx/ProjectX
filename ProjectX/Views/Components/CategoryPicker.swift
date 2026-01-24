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
            Section("Main Category") {
                ForEach(FoodMainCategory.allCases) { main in
                    Button {
                        selectedMain = main
                        if selectedSub?.parent != main { selectedSub = nil }
                    } label: {
                        HStack {
                            Image(systemName: main.icon)
                                .frame(width: 24)
                            Text(main.displayName)
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
                                Text(sub.displayName)
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
        }
        .navigationTitle("Select Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    selection = FoodCategory(main: selectedMain, sub: selectedSub)
                    dismiss()
                }
            }
        }
    }
}
