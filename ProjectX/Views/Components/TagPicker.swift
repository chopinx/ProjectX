import SwiftUI
import SwiftData

struct TagPicker: View {
    @Binding var selectedTags: [Tag]
    @Environment(\.modelContext) private var context
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var showingCreateTag = false

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
                Button { showingCreateTag = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.themePrimary)
                }
            }
        }
        .sheet(isPresented: $showingCreateTag) {
            NavigationStack {
                TagEditSheet(tag: nil, existingNames: Set(allTags.map { $0.name.lowercased() })) { name, colorHex in
                    let tag = Tag(name: name, colorHex: colorHex)
                    context.insert(tag)
                    try? context.save()
                    selectedTags.append(tag)
                    showingCreateTag = false
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func toggleTag(_ tag: Tag) {
        if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
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

        return (CGSize(width: maxWidth, height: currentY + lineHeight), frames)
    }
}
