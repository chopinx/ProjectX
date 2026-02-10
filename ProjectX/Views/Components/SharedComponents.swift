import SwiftUI

// MARK: - Press Feedback Button Style

/// Button style that provides visual press feedback via opacity change
struct PressFeedbackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

extension ButtonStyle where Self == PressFeedbackButtonStyle {
    static var pressFeedback: PressFeedbackButtonStyle { PressFeedbackButtonStyle() }
}

// MARK: - Capsule Badge

/// Reusable capsule-styled badge for tags, categories, counts
struct CapsuleBadge: View {
    let text: String
    var color: Color = .secondary
    var style: Style = .filled

    enum Style { case filled, outlined }

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(style == .filled ? color.opacity(0.15) : Color.clear)
            .foregroundStyle(color)
            .overlay(style == .outlined ? Capsule().stroke(color, lineWidth: 1.5) : nil)
            .clipShape(Capsule())
    }
}

// MARK: - Loading View

struct LoadingStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text(message).font(.headline).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Error State View

struct ErrorStateView: View {
    let title: String
    let message: String
    let retryAction: (() -> Void)?

    init(_ title: String = "Error", message: String, retryAction: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(Color.themeWarning)
            Text(title).font(.title3).fontWeight(.semibold)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            if let retry = retryAction {
                Button("Try Again", action: retry)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.themePrimary)
            }
        }
    }
}

// MARK: - Delete Confirmation Modifier

struct DeleteConfirmationModifier<T>: ViewModifier {
    @Binding var item: T?
    let title: String
    let message: (T) -> String
    let onDelete: (T) -> Void

    @State private var showAlert = false
    @State private var cachedMessage = ""
    @State private var pendingDelete: T?

    func body(content: Content) -> some View {
        content
            .onChange(of: item != nil) { _, hasItem in
                if hasItem, let toDelete = item {
                    // Cache everything we need FIRST
                    cachedMessage = message(toDelete)
                    pendingDelete = toDelete
                    // Clear the binding to break connection to SwiftData object
                    item = nil
                    // THEN show alert (use async to ensure state updates complete)
                    DispatchQueue.main.async {
                        showAlert = true
                    }
                }
            }
            .alert(title, isPresented: $showAlert) {
                Button("Cancel", role: .cancel) { pendingDelete = nil }
                Button("Delete", role: .destructive) {
                    guard let toDelete = pendingDelete else { return }
                    pendingDelete = nil
                    // Delay deletion and wrap in animation
                    DispatchQueue.main.async {
                        withAnimation {
                            onDelete(toDelete)
                        }
                    }
                }
            } message: {
                Text(cachedMessage)
            }
    }
}

extension View {
    func deleteConfirmation<T>(
        _ title: String,
        item: Binding<T?>,
        message: @escaping (T) -> String,
        onDelete: @escaping (T) -> Void
    ) -> some View {
        modifier(DeleteConfirmationModifier(item: item, title: title, message: message, onDelete: onDelete))
    }
}

// MARK: - Unit Text Field

/// Text field with trailing unit label, commonly used for quantity/price inputs
struct UnitTextField: View {
    let placeholder: String
    @Binding var value: String
    let unit: String
    var keyboard: UIKeyboardType = .decimalPad

    var body: some View {
        HStack {
            TextField(placeholder, text: $value)
                .keyboardType(keyboard)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Filter Chip

/// Reusable capsule filter chip for categories/tags
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void

    init(_ title: String, isSelected: Bool, color: Color = .themePrimary, onTap: @escaping () -> Void) {
        self.title = title; self.isSelected = isSelected; self.color = color; self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            Text(title).font(.subheadline).fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(isSelected ? color : Color(.tertiarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule()).contentShape(Capsule())
        }
        .buttonStyle(.pressFeedback)
    }
}

// MARK: - AI Processing Overlay

/// Full-screen overlay for AI processing operations
struct AIProcessingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5)
                Text(message).font(.headline).foregroundStyle(.white)
            }
            .padding(32).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Color Picker Button

/// Circular color button for tag color selection
struct ColorPickerButton: View {
    let hex: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Circle()
                .fill(Color(hex: hex) ?? .blue)
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Color.primary, lineWidth: isSelected ? 3 : 0).padding(2))
                .overlay(Image(systemName: "checkmark").foregroundStyle(.white).opacity(isSelected ? 1 : 0))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag Edit Sheet

/// Unified sheet for creating or editing tags
struct TagEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let tag: Tag?
    let existingNames: Set<String>
    let onSave: (String, String) -> Void

    @State private var name: String
    @State private var colorHex: String

    init(tag: Tag?, existingNames: Set<String>, onSave: @escaping (String, String) -> Void) {
        self.tag = tag
        self.existingNames = existingNames
        self.onSave = onSave
        _name = State(initialValue: tag?.name ?? "")
        _colorHex = State(initialValue: tag?.colorHex ?? "007AFF")
    }

    private var isDuplicate: Bool {
        existingNames.contains(name.trimmingCharacters(in: .whitespaces).lowercased())
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isDuplicate
    }

    var body: some View {
        Form {
            Section("Tag Name") {
                TextField("e.g., Organic, Local, High Protein", text: $name)
                if isDuplicate {
                    Text("A tag with this name already exists")
                        .font(.caption).foregroundStyle(Color.themeError)
                }
            }

            Section("Color") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                    ForEach(Tag.presetColors, id: \.hex) { preset in
                        ColorPickerButton(hex: preset.hex, isSelected: colorHex == preset.hex) {
                            colorHex = preset.hex
                        }
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
                        .background(Capsule().fill((Color(hex: colorHex) ?? .blue).opacity(0.2)))
                        .overlay(Capsule().stroke(Color(hex: colorHex) ?? .blue, lineWidth: 2))
                        .foregroundStyle(Color(hex: colorHex) ?? .blue)
                }
            }
        }
        .navigationTitle(tag == nil ? "New Tag" : "Edit Tag")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(tag == nil ? "Add" : "Save") {
                    onSave(name.trimmingCharacters(in: .whitespaces), colorHex)
                }
                .disabled(!isValid)
            }
        }
    }
}

// MARK: - Tag Preview Badge

/// Preview badge showing tag with color
struct TagPreviewBadge: View {
    let name: String
    let color: Color

    var body: some View {
        Text(name.isEmpty ? "Tag Name" : name)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(color.opacity(0.2)))
            .overlay(Capsule().stroke(color, lineWidth: 2))
            .foregroundStyle(color)
    }
}

// MARK: - AI Action Button

/// Reusable button for AI-powered actions with loading state
struct AIActionButton: View {
    let title: String
    let loadingText: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView().controlSize(.small)
                    Text(loadingText).foregroundStyle(.secondary)
                } else {
                    Label(title, systemImage: "sparkles")
                }
            }
        }
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - Tag Chip

/// Reusable tag chip for tag selection and display
struct TagChip: View {
    let tag: Tag
    let isSelected: Bool
    var showColorDot: Bool = false
    var showDismiss: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if showColorDot {
                    Circle().fill(tag.color).frame(width: 10, height: 10)
                }
                Text(tag.name).font(.subheadline).fontWeight(isSelected ? .semibold : .regular)
                if showDismiss && isSelected {
                    Image(systemName: "xmark").font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, showColorDot ? 10 : 6)
            .background(Capsule().fill(isSelected ? tag.color.opacity(0.2) : Color(.systemGray6)))
            .overlay(Capsule().stroke(isSelected ? tag.color : Color.clear, lineWidth: showColorDot ? 1 : 2))
            .foregroundStyle(isSelected ? tag.color : .primary)
            .contentShape(Capsule())
        }
        .buttonStyle(.pressFeedback)
    }
}
