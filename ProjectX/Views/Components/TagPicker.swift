import SwiftUI
import SwiftData

struct TagPicker: View {
    @Binding var selectedTags: [Tag]
    @Environment(\.modelContext) private var context
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var showingCreateTag = false
    @State private var newTagName = ""
    @State private var newTagColorHex = "007AFF"
    @State private var duplicateError = false

    var body: some View {
        Section {
            if allTags.isEmpty && selectedTags.isEmpty {
                Text("No tags yet. Tap + to create one.")
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(allTags) { tag in
                        TagChip(
                            tag: tag,
                            isSelected: selectedTags.contains(where: { $0.id == tag.id }),
                            onTap: { toggleTag(tag) }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            HStack {
                Text("Tags")
                Spacer()
                Button {
                    showingCreateTag = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
        }
        .sheet(isPresented: $showingCreateTag) {
            NavigationStack {
                CreateTagSheet(
                    name: $newTagName,
                    colorHex: $newTagColorHex,
                    existingNames: Set(allTags.map { $0.name.lowercased() }),
                    onSave: createTag,
                    onCancel: { showingCreateTag = false }
                )
            }
            .presentationDetents([.medium])
        }
        .alert("Duplicate Tag", isPresented: $duplicateError) {
            Button("OK") {}
        } message: {
            Text("A tag with this name already exists.")
        }
    }

    private func toggleTag(_ tag: Tag) {
        if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }
    }

    private func createTag() {
        let trimmedName = newTagName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        // Check for duplicate name
        if allTags.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            duplicateError = true
            return
        }

        let tag = Tag(name: trimmedName, colorHex: newTagColorHex)
        context.insert(tag)
        try? context.save()

        selectedTags.append(tag)
        newTagName = ""
        newTagColorHex = "007AFF"
        showingCreateTag = false
    }
}

extension TagPicker {
    func isDuplicateTagName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces).lowercased()
        return allTags.contains { $0.name.lowercased() == trimmed }
    }
}

private struct TagChip: View {
    let tag: Tag
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(tag.name)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? tag.color.opacity(0.2) : Color(.systemGray6))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? tag.color : Color.clear, lineWidth: 2)
                )
                .foregroundStyle(isSelected ? tag.color : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct CreateTagSheet: View {
    @Binding var name: String
    @Binding var colorHex: String
    let existingNames: Set<String>
    let onSave: () -> Void
    let onCancel: () -> Void

    private var isDuplicate: Bool {
        existingNames.contains(name.trimmingCharacters(in: .whitespaces).lowercased())
    }

    var body: some View {
        Form {
            Section("Tag Name") {
                TextField("e.g., Red Meat, Organic, Local", text: $name)
                if isDuplicate {
                    Text("A tag with this name already exists")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Color") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                    ForEach(Tag.presetColors, id: \.hex) { preset in
                        ColorButton(
                            hex: preset.hex,
                            isSelected: colorHex == preset.hex,
                            onTap: { colorHex = preset.hex }
                        )
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                HStack {
                    Text("Preview")
                    Spacer()
                    Text(name.isEmpty ? "Tag Name" : name)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill((Color(hex: colorHex) ?? .blue).opacity(0.2))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color(hex: colorHex) ?? .blue, lineWidth: 2)
                        )
                        .foregroundStyle(Color(hex: colorHex) ?? .blue)
                }
            }
        }
        .navigationTitle("New Tag")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add", action: onSave)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isDuplicate)
            }
        }
    }
}

private struct ColorButton: View {
    let hex: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Circle()
                .fill(Color(hex: hex) ?? .blue)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(Color.primary, lineWidth: isSelected ? 3 : 0)
                        .padding(2)
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                        .opacity(isSelected ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        let totalHeight = currentY + lineHeight
        return (CGSize(width: maxWidth, height: totalHeight), frames)
    }
}
