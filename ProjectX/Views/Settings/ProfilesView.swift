import SwiftUI
import SwiftData

struct ProfilesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Bindable var settings: AppSettings

    @State private var editingProfile: Profile?
    @State private var showingNewProfile = false

    var body: some View {
        List {
            ForEach(profiles) { profile in
                Button {
                    settings.activeProfileId = profile.id
                } label: {
                    ProfileRow(profile: profile, isActive: settings.activeProfileId == profile.id)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    if profiles.count > 1 {
                        Button(role: .destructive) {
                            deleteProfile(profile)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    Button { editingProfile = profile } label: {
                        Label("Edit", systemImage: "pencil")
                    }.tint(Color.themeSecondary)
                }
            }
        }
        .navigationTitle("Profiles")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingNewProfile = true } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editingProfile) { profile in
            NavigationStack {
                ProfileEditorSheet(profile: profile) { editingProfile = nil }
            }
        }
        .sheet(isPresented: $showingNewProfile) {
            NavigationStack {
                ProfileEditorSheet(profile: nil) { showingNewProfile = false }
            }
        }
        .onAppear { ensureActiveProfile() }
    }

    private func ensureActiveProfile() {
        // Ensure activeProfileId points to a valid profile
        if settings.activeProfileId == nil || !profiles.contains(where: { $0.id == settings.activeProfileId }) {
            if let defaultProfile = profiles.first(where: { $0.isDefault }) ?? profiles.first {
                settings.activeProfileId = defaultProfile.id
            }
        }
    }

    private func deleteProfile(_ profile: Profile) {
        guard profiles.count > 1 else { return }
        let wasActive = settings.activeProfileId == profile.id
        context.delete(profile)
        try? context.save()
        if wasActive, let next = profiles.first(where: { $0.id != profile.id }) {
            settings.activeProfileId = next.id
        }
    }
}

// MARK: - Profile Row

private struct ProfileRow: View {
    let profile: Profile
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: profile.iconName)
                .font(.title2)
                .foregroundStyle(profile.color)
                .frame(width: 40, height: 40)
                .background(profile.color.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name).font(.headline)
                if profile.isDefault {
                    Text("Default").font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.themeSuccess)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Profile Editor Sheet

struct ProfileEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var iconName: String
    @State private var colorHex: String
    @State private var isDefault: Bool

    private let existingProfile: Profile?
    private let onDismiss: () -> Void

    init(profile: Profile?, onDismiss: @escaping () -> Void) {
        self.existingProfile = profile
        self.onDismiss = onDismiss
        _name = State(initialValue: profile?.name ?? "")
        _iconName = State(initialValue: profile?.iconName ?? "person.fill")
        _colorHex = State(initialValue: profile?.colorHex ?? "007AFF")
        _isDefault = State(initialValue: profile?.isDefault ?? false)
    }

    var body: some View {
        Form {
            Section("Profile Info") {
                TextField("Name", text: $name)
            }

            Section("Icon") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 12) {
                    ForEach(Profile.availableIcons, id: \.self) { icon in
                        Button {
                            iconName = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(iconName == icon ? selectedColor.opacity(0.2) : Color.clear)
                                .clipShape(Circle())
                                .overlay {
                                    Circle().stroke(iconName == icon ? selectedColor : .clear, lineWidth: 2)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Color") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 12) {
                    ForEach(Profile.availableColors, id: \.hex) { color in
                        Button {
                            colorHex = color.hex
                        } label: {
                            Circle()
                                .fill(Color(hex: color.hex) ?? .blue)
                                .frame(width: 44, height: 44)
                                .overlay {
                                    if colorHex == color.hex {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.white)
                                            .fontWeight(.bold)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                Toggle("Default Profile", isOn: $isDefault)
            }
        }
        .navigationTitle(existingProfile == nil ? "New Profile" : "Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss(); onDismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }.disabled(name.isEmpty)
            }
        }
    }

    private var selectedColor: Color {
        Color(hex: colorHex) ?? .blue
    }

    private func save() {
        let profile = existingProfile ?? Profile()
        profile.name = name
        profile.iconName = iconName
        profile.colorHex = colorHex
        profile.isDefault = isDefault

        if existingProfile == nil {
            context.insert(profile)
        }
        try? context.save()
        dismiss()
        onDismiss()
    }
}
